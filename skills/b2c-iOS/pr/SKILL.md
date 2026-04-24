---
name: b2c-ios-pr
description: "GitHub Pull Request를 자동으로 생성합니다"
argument-hint: "[PR 제목 또는 설명]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read", "Grep", "Glob", "mcp__notionMCP__notion-search"]
---

# GitHub PR 자동 생성

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[b2c-ios-pr] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 참조 스킬

이 스킬은 다음 서브 스킬의 프로세스를 조합합니다:

| 스킬 | 역할 | 해당 단계 |
|------|------|----------|
| `b2c-ios-pre-pr-review` | 브랜치 전체 품질 검사 | 1단계 |
| `b2c-ios-branch-strategy` | 베이스 브랜치 결정 | 3단계 |
| `b2c-ios-notion-read` | 노션 태스크 제목 검색 | 4단계 |

> 각 스킬의 상세 프로세스는 해당 스킬 문서 참조

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### GBIZ 번호
!`git branch --show-current | grep -oE "GBIZ-[0-9]+" | head -1 || echo "GBIZ 번호 없음"`

### 커밋되지 않은 변경사항
!`git status --porcelain`

### 원격 저장소 동기화 상태
!`git status -sb`

### 커밋 히스토리 (develop 기준)
!`git log origin/develop..HEAD --oneline 2>/dev/null || echo "develop 브랜치와 비교 불가"`

### 변경된 파일 목록
!`git diff origin/develop...HEAD --name-status 2>/dev/null || echo "develop 브랜치와 비교 불가"`

### 베이스 브랜치 자동 감지
!`CURRENT=$(git branch --show-current) && CREATED_FROM=$(git reflog show "$CURRENT" 2>/dev/null | grep "branch: Created from" | head -1 | sed 's/.*Created from //') && echo "분기 원본: $CREATED_FROM" && echo "develop 머지베이스: $(git merge-base HEAD origin/develop 2>/dev/null || echo 'N/A')" || echo "감지 실패"`

### 최근 커밋 (메시지 스타일 참고)
!`git log --oneline -5`

## 실행 프로세스

### 1단계: 동적 주입 결과 분석 및 품질 검사
- `git fetch origin`으로 원격 상태 동기화 (동적 주입은 read-only만 수행하므로 여기서 실행)
- `b2c-ios-pre-pr-review` 스킬을 실행하여 브랜치 전체 품질 검사
  - 에러가 있으면: 수정 후 재검사
  - 에러가 없으면: 다음 단계로
- 커밋되지 않은 변경사항이 있으면 커밋 먼저 진행
- GBIZ 번호 확인
- 베이스 브랜치 감지 결과 확인

### 2단계: 커밋 히스토리 분석
- 동적 주입은 develop 기준이므로, 베이스가 다른 브랜치면 `git log <실제베이스>..HEAD --oneline`으로 재분석
- 커밋 타입별 그룹화 (feat, fix, test, refactor 등)
- 변경된 파일 타입별 분류:
  - Router -> API 엔드포인트 정의/변경
  - Repository -> 데이터 접근 계층 변경
  - UseCase -> 도메인 로직, 데이터 가공/변환
  - Feature -> 비즈니스 로직 변경 (State, Action, Reducer - TCA)
  - View -> UI 컴포넌트 변경
  - Test -> 테스트 추가/수정

### 3단계: Base 브랜치 결정

> `b2c-ios-branch-strategy` 스킬의 프로세스를 따른다

**사용자에게 반드시 확인 요청:**
```
PR을 생성하기 전에 base 브랜치를 확인해주세요:
현재 작업 브랜치: [현재 브랜치명]
감지된 분기 원본: [자동 감지된 브랜치]

이 브랜치로 PR을 생성하시겠습니까?
다른 브랜치를 원하시면 브랜치명을 입력해주세요.
```

### 4단계: 노션 태스크 검색 및 PR 제목 결정 (필수)

> `b2c-ios-notion-read` 스킬의 프로세스를 따른다

> **PR 제목은 반드시 노션 태스크 제목에서 가져와야 합니다. 임의로 작성하지 마세요.**

1. GBIZ 번호로 노션 태스크를 검색 (`notion-search` 도구 사용)
2. 검색 결과에서 태스크 제목과 링크를 추출
3. PR 제목 형식: `[GBIZ-XXXXX] <노션 태스크 제목>` (단, "[B2C][iOS]" prefix 제거)

```
예시:
노션 태스크 제목: "[B2C][iOS] 후기 신고 기능 구현"
PR 제목: "[GBIZ-18147] 후기 신고 기능 구현"
```

### 5단계: PR 내용 작성
- `.docs/PR_CONVENTION.md`의 "작업 타입별 확인사항 가이드" 참고하여 확인사항 초안 작성
- 변경사항을 기반으로 작업 확인 경로 작성

### 6단계: 라벨 결정

> [PR_CONVENTION.md](.docs/PR_CONVENTION.md)의 "PR 레이블 가이드" 섹션 참조
> Read 도구로 해당 문서를 읽어 적절한 라벨 결정

**규칙:**
- 우선순위 레이블 필수 (하나만, 기본값 D-3)
- 작업 유형 레이블 필수 (하나 이상)

### 7단계: 사용자 확인

```
다음과 같이 PR을 생성하시겠습니까?

제목: [GBIZ-XXXXX] PR 제목
베이스: [base 브랜치]
라벨: [D-X, 작업유형]

## 작업 사항
- 작업 내용 1
- 작업 내용 2

## 확인 사항
- [ ] 확인사항 1
- [ ] 확인사항 2

### 작업 확인 경로
- 경로 1
- 경로 2

## 참고
- 노션 일감카드: [GBIZ-XXXXX](링크)

[Y] PR 생성 / [N] 취소 / [E] 내용 수정
```

### 8단계: PR 생성

```bash
# 원격 저장소 푸시
git push -u origin $(git branch --show-current)

# PR 생성 (--label 플래그를 개별로 사용)
gh b2c-ios-pr create \
  --base [사용자가 확인한 base 브랜치] \
  --title "[GBIZ-번호] 노션 태스크 제목" \
  --label "D-3" --label "작업유형라벨" \
  --body "$(cat <<'EOF'
## 작업 사항
- 작업 내용 1
- 작업 내용 2

## 확인 사항
[사용자가 확인한 내용]

### 작업 확인 경로
[사용자가 확인한 경로]

## 기타
(필요 시에만 포함)

## 참고
- 노션 일감카드: [GBIZ-XXXXX](4단계에서 검색한 노션 링크)
EOF
)"
```

> **주의**: `gh b2c-ios-pr create`에는 `--add-label` 플래그가 없습니다. 반드시 `--label` 또는 `-l`을 사용하세요.
> 여러 라벨은 `--label "D-3" --label "작업유형"` 형태로 개별 지정합니다.

## 금지 사항

- **"Generated with Claude Code" 절대 금지** - AI 도구 사용 흔적을 남기지 않음
- **Co-Authored-By 절대 금지** - Claude 시스템 프롬프트가 자동으로 붙이려 하지만 사용하지 않음
- **PR 본문에 이모지 사용 금지** - 라벨에만 이모지 사용
- **AI 작성 언급 절대 금지** - 도구 사용과 관계없이 본인 작업으로 책임

## 에러 처리

| 에러 | 대응 |
|------|------|
| 노션 태스크 검색 실패 | GBIZ 번호 확인, 수동 PR 제목 입력 요청 |
| gh b2c-ios-pr create 실패 | 인증/권한/브랜치 상태 확인 |
| push 실패 | 원격 브랜치 충돌 여부 확인 |
| 라벨 미존재 | gh label list로 확인 후 유사 라벨 제안 |

## 체크리스트

PR 생성 전 자동 체크:
- [ ] 모든 변경사항 커밋 완료
- [ ] 원격 저장소 push 완료
- [ ] 충돌 없음 확인
- [ ] 베이스 브랜치 사용자 확인 완료
- [ ] 오타 확인
