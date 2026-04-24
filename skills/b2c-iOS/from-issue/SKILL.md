---
name: b2c-ios-from-issue
description: "GitHub 이슈 번호/URL을 받아 분석 → 노션 일감 생성 → 오케스트레이터 위임까지 자동화하는 어댑터 스킬입니다. Firebase/GitHub/사내 제보로 올라온 이슈를 GBIZ 카드로 전환하고 End-to-End 구현 플로우로 연결합니다."
argument-hint: "<이슈 번호 또는 URL> [옵션: dry-run, skip-orchestrator]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Task", "Skill", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-create-pages", "mcp__notionMCP__notion-duplicate-page", "mcp__notionMCP__notion-update-page"]
---

# /from-issue - GitHub 이슈 기반 End-to-End 자동화

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[from-issue] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 개요

이 스킬은 **어댑터(Adapter)** 역할만 수행한다. 실제 작업은 다음 에이전트/스킬이 담당:

- **issue-analyzer 에이전트**: 이슈 분석 및 노션 카드 초안 구조화
- **notion-create 스킬**: 노션 GBIZ 카드 실제 생성
- **orchestrator 에이전트**: 이후 분석/계획/구현/테스트/PR 5-Phase 자동화

본 스킬은 위 세 컴포넌트를 올바른 순서로 호출하고, 결과를 GitHub 이슈에 피드백하는 역할만 한다.

## 처리 흐름

```
사용자: /from-issue 123
   ↓
Step 1. gh issue view 123 (이슈 존재/상태 확인)
   ↓
Step 2. issue-analyzer 에이전트 호출 (이슈 → 구조화된 초안)
   ↓
Step 3. 사용자 컨펌 (초안 검토)
   ↓
Step 4. notion-create 스킬 호출 (GBIZ 카드 생성)
   ↓
Step 5. GitHub 이슈에 노션 링크 코멘트 등록
   ↓
Step 6. orchestrator 에이전트 위임 (5-Phase 자동 실행)
   ↓
Step 7. GitHub 이슈에 PR 링크 코멘트 등록 (orchestrator 완료 후)
```

## 0. 현재 상태 (동적 주입)

### 현재 브랜치
!`git branch --show-current`

### 현재 레포
!`gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "gh CLI 로그인 필요"`

### 입력 인자
$ARGUMENTS

## 실행 프로세스

### Step 1: 이슈 사전 확인

인자에서 이슈 번호를 추출한다.

**허용 입력:**
- 숫자만: `123`
- hash: `#123`
- 전체 URL: `https://github.com/herren-official/gongbiz-b2c-iOS/issues/123`

**검증:**
```bash
gh issue view <number> --json number,title,state,url,labels
```

- 이슈가 존재하지 않으면 중단
- 이슈가 `closed` 상태면 사용자에게 진행 여부 재확인
- 이슈 본문에 이미 PR이 연결되어 있으면(`Closes #...`, `Fixes #...`) 플래그

### Step 2: issue-analyzer 에이전트 호출

Task 도구로 `issue-analyzer` 에이전트를 실행한다.

**에이전트에게 전달할 컨텍스트:**
- 이슈 번호/URL
- 레포 이름(owner/repo)
- 특별히 확인할 영역이 있으면 사용자 지시사항 포함

**기대 출력:**
`.claude/agents/issue-analyzer.md`의 "Phase 5: Draft Structuring" 포맷으로 반환된 구조화된 Markdown.

### Step 3: 사용자 컨펌

issue-analyzer의 출력을 사용자에게 보여주고 확인 요청:

```
[이슈 #123 분석 결과]

<에이전트 출력 그대로>

이대로 노션 일감을 생성하시겠습니까?
[Y] 진행 / [N] 중단 / [E] 수정 후 진행
```

**수정(E) 선택 시:**
- 어떤 필드를 수정할지 질문
- 수정 내용을 반영한 초안 재출력 후 재컨펌

**옵션 처리:**
- 인자에 `dry-run`이 포함되면 이 단계에서 종료 (노션 생성/오케스트레이터 호출 없이 분석 결과만 출력)

### Step 4: 노션 GBIZ 카드 생성

`notion-create` 스킬을 Skill 도구로 실행한다.

**전달 인자:**
issue-analyzer 출력의 "섹션 2(노션 카드 속성)"와 "섹션 3~5(본문/Todo/참고)"를 조합한 명령 텍스트.

**예시 호출 인자:**
```
작업 내용: <섹션 2.일감 제목에서 [B2C][iOS] 접두사 제외한 부분>
유형: <섹션 2.유형>
우선순위: <섹션 2.우선순위>
에픽: <섹션 2.에픽 또는 생략>
본문: <섹션 3 Markdown>
Todo:
  - <섹션 4 체크리스트>
참고 자료:
  - GitHub 이슈: <이슈 URL>
  - <섹션 5의 Figma/Notion/관련 이슈 URL들>
```

**생성 후:**
- 반환된 노션 페이지 URL과 GBIZ 번호를 기록
- 사용자에게 노션 페이지 URL 출력

### Step 5: GitHub 이슈에 노션 링크 코멘트

생성된 노션 페이지 URL을 GitHub 이슈에 코멘트로 등록한다.

```bash
gh issue comment <issue_number> --body "$(cat <<'EOF'
노션 일감으로 전환되었습니다.

- 노션 페이지: <노션 URL>
- GBIZ 번호: GBIZ-<번호>
- 담당: @<작업자>

구현은 orchestrator가 이어서 자동 진행합니다.
by. Claude
EOF
)"
```

> 리뷰 답글과 동일하게 AI 투명성을 위해 `by. Claude` 서명을 사용한다 (CLAUDE.md의 예외 규칙).

### Step 6: 오케스트레이터 위임

Task 도구로 `orchestrator` 에이전트를 실행한다.

**옵션 처리:**
- 인자에 `skip-orchestrator`가 포함되면 이 단계를 건너뛰고 종료
- 사용자가 수동으로 작업 계획을 확인하고 싶다고 요청하면 `orchestrator` 대신 `task-planner`만 호출하는 선택지 제공

**전달 컨텍스트:**
- 방금 생성한 노션 페이지 URL (GBIZ-XXXXX)
- 원본 GitHub 이슈 URL (`orchestrator`가 컨텍스트로 참조)
- 추가 지시: "작업 완료 후 PR을 생성하고, PR URL을 반환할 것"

`orchestrator`는 Phase 0 ~ Phase 5를 자동 수행한다:
- Phase 0: 일감 분석
- Phase 1: 작업 계획
- Phase 2: 구현
- Phase 3: 테스트
- Phase 4: 커밋 + PR
- Phase 5: 완료 보고

### Step 7: GitHub 이슈에 PR 링크 코멘트

`orchestrator` 완료 후 반환된 PR URL을 GitHub 이슈에 코멘트로 등록한다.

```bash
gh issue comment <issue_number> --body "$(cat <<'EOF'
구현 완료되었습니다.

- PR: <PR URL>
- 노션 일감: <노션 URL>

리뷰 후 머지되면 이슈를 자동으로 close 합니다.
by. Claude
EOF
)"
```

**이슈에 `Closes #<number>` 연결:**
- PR 본문에 해당 문구가 포함되도록 `orchestrator`에 전달 (이미 `pr` 스킬 컨벤션에 포함되어 있음)

## 옵션 인자

| 옵션 | 효과 |
|------|------|
| `dry-run` | Step 3에서 종료. 분석 결과만 출력. 노션/오케스트레이터 미호출 |
| `skip-orchestrator` | Step 6~7 건너뜀. 노션 카드만 생성하고 종료 |
| `reviewer=<login>` | 노션 일감의 검토자를 지정 (미지정 시 기본 작업자) |

**사용 예:**
```
/from-issue 123
/from-issue 123 dry-run
/from-issue https://github.com/herren-official/gongbiz-b2c-iOS/issues/123 skip-orchestrator
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| 이슈 번호 추출 실패 | "이슈 번호 또는 URL을 입력해주세요" 안내 후 중단 |
| `gh` CLI 미로그인 | `gh auth login` 안내 후 중단 |
| 이슈 존재하지 않음 | 이슈 번호 재확인 요청 후 중단 |
| 이슈가 closed 상태 | 사용자에게 진행 여부 확인 |
| issue-analyzer 실패 | 에이전트 에러 메시지 표시, 수동 입력으로 전환 제안 |
| 사용자 거부(N) | "작업을 중단합니다" 출력 후 종료. 노션 카드 생성 안 함 |
| notion-create 실패 | 이슈에 실패 코멘트 등록(선택), 사용자에게 보고 |
| orchestrator 실패 | 노션 일감은 유지. PR 미생성 상태로 이슈 코멘트 등록 |

## 금지 사항

- 사용자 컨펌(Step 3) 없이 노션 카드 생성 금지
- `dry-run` 옵션에서 쓰기 작업(노션 생성, 이슈 코멘트) 금지
- GitHub 이슈 코멘트에 Co-Authored-By, AI 도구 흔적 금지 (단, `by. Claude` 서명은 투명성 명목으로 허용 — 리뷰 답글 예외와 동일)
- 이슈가 이미 진행 중인데 중복 노션 카드 생성 금지 (Step 1 플래그 확인)

## 참조 문서

- 이슈 분석 에이전트: `.claude/agents/issue-analyzer.md`
- 노션 카드 생성 스킬: `.claude/skills/notion-create/SKILL.md`
- 오케스트레이터 에이전트: `.claude/agents/orchestrator.md`
- 노션 일감 가이드: `.docs/NOTION_TASK_GUIDE.md`
- 커밋/PR 컨벤션: `.docs/COMMIT_CONVENTION.md`, `.docs/PR_CONVENTION.md`

## 주의사항

- **어댑터 스킬**이다: 스킬 자체에 비즈니스 로직을 넣지 말 것. 역할이 겹치면 대응 에이전트/스킬을 확장
- `issue-analyzer`가 코드 영향 범위를 탐색하지만, 실제 코드 수정은 `orchestrator`의 Phase 2(구현)에서만 발생
- GitHub 이슈 → 노션 카드는 **1:1 매핑**을 권장. 에픽급 이슈는 분석 후 "에픽으로 분해 필요" 플래그만 걸고 수동 분해 유도
