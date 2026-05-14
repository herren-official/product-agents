---
name: b2c-android-from-issue
description: GitHub 이슈로부터 노션 일감 카드 → 브랜치 → 코드 수정 → PR 까지 일괄 실행. Use when: GitHub 이슈를 받아 작업 시작, 이슈 → PR 자동화, 깃헙 이슈로 일감 만들기
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Skill, Agent, mcp__notionMCP__notion-fetch, mcp__notionMCP__notion-update-page
---

# /from-issue — GitHub 이슈에서 PR 까지 (B2C)

GitHub 이슈 URL/번호를 입력받아 **노션 일감 카드 생성 → 브랜치 생성 → 코드 수정 → PR 생성** 까지 일괄 실행한다.

`/b2c-android-flow-plan` 이 노션 에픽/PDF/피그마 기반의 큰 피처용이라면, **`/from-issue` 는 GitHub 이슈 단일 단위의 작은 작업** 용이다.

## 사용 예시

```
/from-issue 1234                                        # GitHub 이슈 번호
/from-issue https://github.com/herren-official/.../issues/1234
/from-issue 1234 --no-notion                            # 노션 카드 생성 건너뜀
/from-issue 1234 --dry-run                              # 계획만 출력
```

## 입력 규격

| 패턴 | 처리 |
|------|------|
| 정수 (`1234`) | 현재 레포의 이슈 번호 |
| GitHub 이슈 URL | URL 에서 owner/repo/number 추출 |

## 실행 단계

### 1단계: 이슈 조회

```bash
gh issue view <NUMBER> --json number,title,body,labels,assignees,milestone,url
```

추출 정보:
- 제목, 본문, URL
- labels (분류 힌트: `bug` / `enhancement` / `documentation` / `chore` 등)
- assignees, milestone (있으면 노션 카드에 매핑)

이슈가 없거나 권한 없으면 즉시 중단 + 에러 메시지.

### 1.5단계: 이슈 해결 여부 사전 확인 (필수)

`Agent` 도구로 `issue-stale-checker` 1회 호출 (격리 컨텍스트 — Read + Grep + `git log -p` 후 판정 + 근거만 회수):
- `subagent_type`: `issue-stale-checker`
- `description`: `Stale check issue #{번호}`
- `prompt`: §1 의 `gh issue view --json` 결과(번호 / 제목 / 본문 / `createdAt` / `url`)를 그대로 전달. "판정: stale / valid / uncertain + 근거를 agent 출력 형식에 맞게 반환."

**stale 판정 시**:
- 워크플로우 즉시 중단
- 사용자에게 에이전트 근거 보고 + 다음 옵션 제시:
  - 이슈 close + 노션 카드 정리 (이미 만든 경우 상태 "이슈아님" 으로)
  - 다른 이슈로 재시도
  - 그냥 종료
- 노션 카드 생성 (§3) 전에 판정하면 카드 생성도 skip 가능 → 본 단계는 항상 §3 이전 실행

**uncertain 판정 시**: 에이전트가 명확히 결론 못 낸 경우 — 사용자에게 근거 보여주고 결정 요청.

> 판정 기준 / 변경 대상 추출 / 출력 형식은 에이전트 정의(`.claude/agents/issue-stale-checker.md`) 가 단일 진실 소스.

### 2단계: 작업 유형 판별

이슈 라벨/제목/본문을 보고 자동 판정:

| 신호 | 작업 유형 | 브랜치 prefix |
|------|---------|--------------|
| `bug`, "버그", "오류", "fix" | `fix` | `fix/` |
| `enhancement`, `feature`, "기능", "추가" | `feat` | `feat/` |
| `documentation`, "문서", "docs" | `docs` | `docs/` |
| `chore`, "정리", "설정", "리팩토링" | `chore` | `chore/` |
| `refactor` | `refactor` | `refactor/` |
| 그 외 | 기본 `chore` (사용자 확인) | `chore/` |

판정 결과는 §2.5 계획 요약에 포함.

### 2.5단계: 승인 체크포인트 1 — 계획 (필수)

§3 이전에 **계획 요약**을 한 번에 제시하고 `AskUserQuestion` 으로 진행 승인 받는다. 이 승인 이후 §3~§7 은 자동 진행된다.

요약 항목:
- 이슈 요약 (제목 + 본문 핵심 1~2줄)
- stale 판정 결과 (생존 / 이미 해결됨)
- 작업 유형 (bug / feat / docs / chore / refactor)
- 노션 카드 초안 (이름 / 유형 / 플랫폼 / 서비스 / SP / 본문 요약)
- 브랜치명 초안 (`{type}/GBIZ-xxxxx-{slug}` + baseline)
- 수정 대상 파일 목록 + 각 파일 변경 의도

승인 없이 §3 (노션 카드 생성) 진행 금지. 사용자가 수정 요청 시 항목만 조정 후 재승인.

### 3단계: 노션 백로그 카드 생성 (--no-notion 아니면)

§2.5 에서 승인된 카드 초안으로 **`/create-backlog` 호출**. 템플릿 복제 / 고정 속성 (플랫폼=Android, 서비스=공비서-B2C, 상태=백로그, 작업자=self) / SP 추정 가이드 / 본문 구조는 모두 create-backlog 가 단일 진실 소스로 처리.

전달할 정보:
- 제목: `[B2C][Android] {이슈 제목}` (Breadcrumb 형식이면 그대로)
- 유형: §2 판정 결과를 작업/버그로 매핑 (`fix` → 버그, 그 외 → 작업)
- SP: 이슈 본문 분석 기반 추정값 (단순 변경 0.1~0.25 / 보통 0.5 / 복잡 0.75~1.0)
- 본문:
  ```
  ## 작업내용
  ### 내용
  {GitHub 이슈 본문 요약 1~3줄}
  - {할 일 불릿 1}
  - {할 일 불릿 2}

  ### 참고
  - GitHub Issue: [#{번호}]({이슈 URL})
  - 라벨: {labels 콤마}
  ```

create-backlog 응답에서 GBIZ-xxxx 번호와 노션 페이지 URL 회수.

> **직접 `notion-duplicate-page` / `notion-create-pages` 호출 금지** — 데이터 소스 ID, 작업자 처리, SP 가이드 등은 create-backlog 가 단일 진실 소스. 우회하면 정합성 깨짐.

### 4단계: 브랜치 생성

§2.5 에서 승인된 브랜치명으로 `Skill create-branch` 호출 — 인자로 GBIZ 번호 전달. create-branch 가:
- 노션 카드 fetch
- 브랜치명 생성 (`{type}/GBIZ-xxxxx-{slug}`)
- `git checkout -b` 실행
- baseline 은 `develop` 기본

브랜치 prefix 는 §2 판정 결과로 override.

### 5단계: 코드 수정

§2.5 에서 승인된 수정 대상 파일 범위 내에서 Edit/Write 진행. 범위 밖 파일 수정이 필요하면 여기서 멈추고 §2.5 로 돌아가 재승인 받는다.

이슈 본문에 따라 자동/수동 분기:

**자동 처리 가능 케이스**:
- 단순 문구 변경 (이슈에 "X 를 Y 로" 명시)
- 라이브러리 업데이트 (이슈에 버전 명시)
- 미사용 import 정리 / 포맷팅
→ 자동 Edit 후 사용자 확인

**수동 영역**:
- 신규 기능 / 복잡한 버그 수정 / 디자인 의존
→ 사용자에게 가이드 제시 후 함께 진행
→ 또는 큰 피처면 안내: "에픽/피그마/PDF 기반 큰 작업이면 `/b2c-android-flow-plan` 로 분해부터"

### 6단계: 컴파일 검증

```bash
./gradlew :{module}:compileDevDebugKotlin
```

- 변경 모듈 감지: `.claude/scripts/git-context.sh` 의 `### Changed Modules` 섹션 사용
- 실패 시 사용자에게 수정 요청

### 7단계: 테스트 실행 + 실패 시 수정

```bash
./gradlew :{module}:testDevDebugUnitTest --continue
```

- 변경 모듈의 단위 테스트 실행
- **테스트 실패 케이스**:
  - 본인 변경으로 깨졌으면 → `Agent unit-test` 호출해서 자율 수정 (테스트 코드 또는 구현 코드 분석 후 통과까지 반복)
  - 본인 변경과 무관한 기존 깨진 테스트면 → 사용자에게 알리고 별도 일감으로 분리 권장
- 깨진 테스트가 없거나 모두 통과하면 다음 단계
- 변경 모듈에 테스트 파일 자체가 없으면 skip + 콘솔 안내

### 7.5단계: 승인 체크포인트 2 — 최종 반영 (필수)

§8 이전에 **실제 변경 결과 + 반영 계획**을 한 번에 제시하고 `AskUserQuestion` 으로 최종 승인 받는다. 이 승인 이후 §8~§10 은 일괄 자동 실행된다.

요약 항목:
- 변경 요약: `.claude/scripts/git-context.sh` 출력 (파일 목록 + diff stat) + 파일별 before → after 핵심 라인
- 컴파일 / 테스트 결과 (성공 / 실패, pre-existing 여부)
- 커밋 메시지 초안 (분리 커밋이면 각각 제시)
- PR 제목 / 본문 / base / label 초안 (확인 사항 섹션은 §9 규칙대로 유형별 분기)
- GitHub 이슈 코멘트 초안
- 노션 카드 GitHub PR 속성 연결 예정 URL

승인 후 일괄 실행 순서:
1. 커밋 (`create-commit`, 필요 시 분리 커밋)
2. PR 생성 (`create-pr` 가 `git push` + PR 본문 + 노션 카드 GitHub PR 속성 연결까지 일괄 처리)
3. GitHub 이슈 코멘트 (`--no-comment` 플래그 없으면)

사용자가 수정 요청 시 해당 항목만 조정 후 재승인 → 그대로 일괄 실행.

### 8단계: 커밋

§7.5 에서 승인된 커밋 메시지로 `Skill create-commit` 호출. 테스트 수정이 동반됐으면 분리 커밋:
- `{type}: {이슈 제목}` (코드 변경)
- `test: {모듈명} 테스트 회귀 수정` (테스트 변경)

### 9단계: PR 생성

§7.5 에서 승인된 PR 본문으로 `Skill create-pr` 호출:
- base: `develop` (기본) 또는 §2.5/§7.5 에서 지정
- 노션 카드 URL (3단계 결과)

create-pr 이 PR 본문 생성 + 노션 카드 GitHub 풀 리퀘스트 속성 / 내용 / 참고 섹션 자동 업데이트.

**PR 본문 "확인 사항" 섹션 작성 규칙 (작업 유형별 분기)**:
| 작업 유형 | 확인 사항 섹션 |
|---------|---------------|
| `docs` / `chore` | **생략** (문서·정리 작업은 회귀 QA 불필요) |
| `fix` / `feat` / `refactor` | **포함** — 화면 경로 + 검증 시나리오 최소 1~2개. create-pr 기본 포맷 따르되 실제 QA 포인트만 기입 (억지 불릿 금지) |

**참고 섹션에 추가**:
- GitHub Issue: [#{번호}]({이슈 URL})

### 10단계: GitHub 이슈에 PR 링크 코멘트 (선택)

§7.5 에서 승인된 코멘트 본문으로 등록:

```bash
gh issue comment <NUMBER> --body "PR: {PR URL}\n노션: {노션 카드 URL}"
```

### 11단계: 결과 보고

```
완료: GitHub Issue #{번호} → PR #{PR 번호}

GitHub Issue : {URL}
노션 카드    : {GBIZ-xxxxx 카드 URL}
브랜치       : {브랜치명}
PR           : {PR URL}
변경 파일    : N개
컴파일       : 성공/실패
테스트       : {통과}/{실패}/{스킵} (실패 → 수정 후 재통과 시 표기)
```

## 모드

### --dry-run
실제 변경 없이 §1~§8 계획만 출력. 노션 카드/브랜치/PR 생성 안 함.

### --no-notion
노션 카드 생성 건너뜀. GBIZ 번호 없이 브랜치명 `{type}/issue-{번호}-{slug}` 형식. PR 생성 시 노션 동기화도 건너뜀.

## 작성 규칙

### 필수
- 이슈 번호와 GBIZ 번호 양쪽 모두 PR 본문에 포함
- 브랜치 prefix 는 작업 유형 판정 따라 (다나님 컨벤션 준수)
- 노션 카드 → 브랜치 → 커밋 → PR 4단계 모두 동기화
- **승인 체크포인트 2회 구조** (그 외는 자동 진행, Auto Mode 여도 이 2회는 예외 없음):
  - **§2.5 계획 승인** (§3 이전): 이슈 요약 / stale 판정 / 작업 유형 / 노션 카드 초안 / 브랜치명 / 수정 대상 파일 목록 일괄 검토
  - **§7.5 최종 반영 승인** (§8 이전): 실제 diff / 컴파일·테스트 결과 / 커밋 메시지 / PR 본문 / 이슈 코멘트 초안 일괄 검토 → 승인 후 §8~§10 일괄 실행
- §1 이슈 조회 / §1.5 stale 체크 / §2 유형 판별 / §6 컴파일 / §7 테스트 는 read-only 또는 사전 조사 단계 — 승인 없이 진행.
- 단일 파일 / 1~3줄 급 변경이 아니라 §5 범위가 §2.5 승인 범위를 벗어나면 §2.5 로 돌아가 재승인 (scope creep 방지).

### 금지
- 이슈 본문을 그대로 PR 본문에 복사 (요약 + 작업 사항 형태로 가공)
- 큰 피처/에픽 단위 작업을 본 스킬로 처리 (→ `/b2c-android-flow-plan` 권장)
- GitHub 이슈에 사용자 승인 없이 자동 코멘트 (§7.5 일괄 승인에 포함)
- 노션 카드 직접 생성 (→ `/create-backlog` 위임 필수)

## 후속

- 큰 피처면 본 스킬 대신 `/b2c-android-flow-plan` 사용
- PR 머지 후 `gh issue close <NUMBER>` 로 이슈 자동 클로즈 (선택)

## 관련 스킬·에이전트

- `create-backlog` (3단계 — 노션 카드 생성 단일 진실 소스)
- `create-branch` (4단계)
- `unit-test` 에이전트 (7단계 — 테스트 실패 자율 수정)
- `create-commit` (8단계)
- `create-pr` (9단계)
- `b2c-android-flow-plan` (큰 피처 대안)
