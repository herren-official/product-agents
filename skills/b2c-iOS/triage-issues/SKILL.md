---
name: b2c-ios-triage-issues
description: "GitHub 이슈 목록을 조회하여 사용자가 처리할 이슈를 선택하면 각 이슈에 대해 /from-issue 스킬을 순차 호출하는 트리아지 스킬입니다. 라벨/작성자/상태로 필터링할 수 있고 복수 선택을 지원합니다."
argument-hint: "[옵션: --label=<name>] [--author=<login>] [--state=open|closed|all] [--limit=<n>] [dry-run]"
disable-model-invocation: false
allowed-tools: ["Bash", "Skill"]
---

# /triage-issues - GitHub 이슈 트리아지

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[triage-issues] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 개요

여러 이슈를 한 번에 훑어보고 처리할 대상을 선택하는 **어댑터 스킬**이다. 실제 이슈 처리는 `/from-issue` 스킬에 위임한다.

- 단일 이슈 처리: `/from-issue <번호>` (직접 호출)
- 여러 이슈 트리아지: `/triage-issues` (본 스킬)

## 처리 흐름

```
사용자: /triage-issues [옵션]
   ↓
Step 1. gh issue list로 이슈 목록 조회 (필터 적용)
   ↓
Step 2. 이슈 표 출력 (번호/제목/라벨/작성자/코멘트 수/작성일)
   ↓
Step 3. 사용자에게 처리할 이슈 번호 선택 요청
   ↓
Step 4. 선택된 이슈 각각에 대해 순차 처리:
          /from-issue <번호> 호출
   ↓
Step 5. 전체 처리 결과 요약 리포트
```

## 0. 현재 상태 (동적 주입)

### 현재 레포
!`gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "gh CLI 로그인 필요"`

### 현재 브랜치
!`git branch --show-current`

### 입력 인자
$ARGUMENTS

## 실행 프로세스

### Step 1: 이슈 목록 조회

인자를 파싱하여 필터를 구성한다.

**지원 옵션:**

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--label=<name>` | 없음 | 특정 라벨만 필터 (복수 시 콤마 구분 `--label=bug,priority:high`) |
| `--author=<login>` | 없음 | 특정 작성자만 필터 |
| `--state=<open\|closed\|all>` | `open` | 이슈 상태 필터 |
| `--limit=<n>` | `30` | 최대 조회 개수 |
| `dry-run` | off | Step 3 이후 실제 `/from-issue` 호출 건너뜀 |

**조회 명령:**
```bash
gh issue list \
  --state <state> \
  --limit <limit> \
  [--label "<labels>"] \
  [--author "<author>"] \
  --json number,title,state,labels,author,comments,createdAt,updatedAt,url
```

**이슈 0건 처리:**
- 결과가 없으면 "조건에 맞는 이슈가 없습니다" 출력 후 종료
- 필터를 완화할지 사용자에게 질문

### Step 2: 이슈 표 출력

조회된 이슈를 **우선순위 순**으로 정렬하여 표로 출력한다.

**정렬 규칙:**
1. `priority:high` 라벨 보유 이슈 상단
2. `bug` 라벨 보유 이슈 그 다음
3. 코멘트 수 많은 순
4. 생성일 오래된 순 (오래된 이슈 먼저)

**출력 포맷:**

```
[이슈 목록 - N건]

 #    번호    제목                                          라벨         작성자        코멘트  작성일
 1    #123   [버그] 예약 완료 화면 크래시                    bug          @user1        3       2026-04-20
 2    #118   결제 실패 처리 개선                             enhancement  @user2        1       2026-04-18
 3    #115   콕예약 리스트 회원가 표시 누락                  bug          @user3        0       2026-04-15
 ...
```

> 제목이 너무 길면 40자로 자르고 `...` 추가

### Step 3: 사용자 선택

사용자에게 처리할 이슈 번호를 입력받는다.

```
처리할 이슈를 선택하세요:
- 단일:   "1" 또는 "#123"
- 복수:   "1,3,5" 또는 "#123,#115"
- 범위:   "1-3"
- 전체:   "all"
- 일부:   "1-3,5" (복합)
- 취소:   "none" 또는 빈 입력
```

**입력 파싱:**
- `1,3,5` → 표 인덱스 1, 3, 5
- `1-3` → 표 인덱스 1, 2, 3
- `#123` → 이슈 번호 123 (직접 매칭)
- `all` → 조회된 모든 이슈

**선택 확정 전 재확인:**
```
다음 3개 이슈를 순차 처리합니다:
- #123 [버그] 예약 완료 화면 크래시
- #118 결제 실패 처리 개선
- #115 콕예약 리스트 회원가 표시 누락

진행할까요? [Y/N]
```

### Step 4: 순차 처리

선택된 각 이슈에 대해 `/from-issue` 스킬을 Skill 도구로 호출한다.

**호출 흐름:**
```
[1/3] #123 처리 시작
  → /from-issue 123 호출
  → /from-issue 내부: issue-analyzer → 사용자 컨펌 → notion-create → orchestrator
  → 완료 시: 노션 URL + PR URL 수집

[2/3] #118 처리 시작
  ...

[3/3] #115 처리 시작
  ...
```

**중단 처리:**
- `/from-issue` 내부에서 사용자가 취소(N)하면: 해당 이슈만 건너뛰고 다음으로 진행
- `/from-issue` 실행 중 에러 발생: 에러 로그 수집 후 다음 이슈 처리 여부 사용자 확인

**dry-run 옵션:**
- `dry-run` 플래그가 있으면 이 단계에서 각 이슈에 대해 `/from-issue <번호> dry-run`만 호출
- 분석 결과만 쭉 출력하고 노션/오케스트레이터 미호출

**순차 vs 병렬:**
- 기본은 **순차 처리** (노션 카드 생성과 orchestrator 호출은 리소스를 많이 쓰므로)
- Skill 도구는 동시 호출을 지원하지 않으므로 병렬 옵션은 현재 없음

### Step 5: 요약 리포트

모든 이슈 처리 완료 후 최종 리포트를 출력한다.

**리포트 포맷:**

```
[트리아지 완료]

처리 이슈: N건
성공: M건
건너뜀: K건
실패: L건

---

성공 목록:
- #123 → 노션: <URL> | PR: <URL>
- #118 → 노션: <URL> | PR: <URL>

건너뜀 목록:
- #115 사용자 취소

실패 목록:
- (없음)
```

## 사용 예시

### 기본 사용 (open 이슈 전체 트리아지)
```
/triage-issues
```

### 버그 라벨만 보기
```
/triage-issues --label=bug
```

### 특정 작성자의 이슈만
```
/triage-issues --author=gu-gyodong
```

### 분석만 (실제 노션 생성/오케스트레이터 호출 없음)
```
/triage-issues dry-run
```

### 복합 필터
```
/triage-issues --label=bug --state=open --limit=10
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| `gh` CLI 미로그인 | `gh auth login` 안내 후 중단 |
| 조회 결과 0건 | 필터 완화 여부 사용자 확인 |
| 선택 입력 파싱 실패 | 입력 예시 재안내 후 재입력 요청 |
| 사용자 취소(N/none) | "작업을 중단합니다" 출력 후 종료 |
| 개별 이슈 `/from-issue` 실패 | 에러 기록 후 다음 이슈 진행 여부 확인 |

## 금지 사항

- Step 3 컨펌 없이 이슈 처리 시작 금지
- 사용자가 선택하지 않은 이슈 임의 처리 금지
- 선택된 이슈 중 일부를 말없이 건너뛰기 금지 (반드시 리포트에 명시)
- `dry-run` 옵션에서 쓰기 작업(노션 생성 등) 금지

## 참조

- 단일 이슈 처리 스킬: `.claude/skills/from-issue/SKILL.md`
- 이슈 분석 에이전트: `.claude/agents/issue-analyzer.md`
- 노션 카드 생성 스킬: `.claude/skills/notion-create/SKILL.md`
- 오케스트레이터 에이전트: `.claude/agents/orchestrator.md`

## 주의사항

- **어댑터 스킬**이다: 실제 로직은 `/from-issue`에 위임. 본 스킬은 목록 조회 + 선택 + 디스패치만 담당
- 대량 이슈(10개 이상) 트리아지는 시간이 오래 걸리므로, `dry-run`으로 먼저 훑어보길 권장
- 에픽급 이슈를 여러 개 묶어서 처리하려면 본 스킬 대신 수동으로 `/from-issue`를 개별 호출하는 게 더 안전
- 이슈가 이미 PR에 연결된 경우(`Closes #N`) `/from-issue` 내부에서 플래그되므로, 트리아지 단계에서 선택 시 주의
