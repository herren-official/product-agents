---
name: b2b-web-workflow-harness
description: 워크플로우 Full-Auto 하네스. 전 Phase 권한 프리셋, 자동 체인, 퍼블리싱 검증 루프. `/workflow start --auto` 시 활성화.
user-invocable: false
---

# 워크플로우 하네스 (Full-Auto)

**목적**: `/workflow start --auto` 실행 시 활성화. 전 6 Phase를 **권한 팝업 없이, 멈춤 없이** 자동 실행한다.
**핵심 원칙**: 사람이 개입하는 지점은 0개. 피그마 URL 입력 → 코드 + PR 산출까지 완전 자동.

---

## 1. 활성화 프로토콜

### `/workflow start --auto {name}` 실행 시

리더가 순서대로 수행:

1. state.json에 harness 섹션 추가
2. settings.local.json에 권한 프리셋 머지
3. "하네스 활성화됨: Full-Auto" 출력
4. Phase 1 즉시 시작

### state.json 확장

```json
{
  "harness": {
    "active": true,
    "mode": "full-auto",
    "activatedAt": "ISO 8601",
    "permissionsApplied": true,
    "publishingVerification": true,
    "originalPermissions": []
  }
}
```

`originalPermissions`에 활성화 전 `settings.local.json`의 `permissions.allow`를 백업한다. 해제 시 복원용.

---

## 2. 권한 프리셋 (Permission Preset)

하네스 활성화 시 `settings.local.json`의 `permissions.allow`에 아래를 **머지**한다 (기존 항목 유지 + 추가).

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(git worktree:*)",
      "Bash(git stash:*)",
      "Bash(git merge:*)",
      "Bash(git reset --soft:*)",
      "Bash(git pull:*)",
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(git status)",
      "Bash(gh pr:*)",
      "Bash(gh api:*)",
      "Bash(yarn test:*)",
      "Bash(yarn lint:*)",
      "Bash(yarn tsc:*)",
      "Bash(yarn dev:*)",
      "Bash(yarn storybook:*)",
      "Bash(npx tsc:*)",
      "Bash(base64:*)",
      "Bash(shasum:*)",
      "Bash(mkdir:*)",
      "Bash(cp:*)",
      "Bash(cat:*)",
      "Bash(wc:*)",
      "Bash(terminal-notifier:*)",
      "mcp__Figma_Dev_Mode_MCP__get_figma_data",
      "mcp__figma-dev-mode-mcp-server__get_screenshot",
      "mcp__figma-dev-mode-mcp-server__get_metadata",
      "mcp__figma-dev-mode-mcp-server__get_design_context",
      "mcp__figma-dev-mode-mcp-server__get_code_connect_suggestions",
      "mcp__claude_ai_Notion__notion-create-pages",
      "mcp__claude_ai_Notion__notion-update-page",
      "mcp__claude_ai_Notion__notion-search",
      "mcp__claude_ai_Notion__notion-fetch",
      "mcp__claude_ai_Notion__notion-get-comments",
      "mcp__playwright__browser_navigate",
      "mcp__playwright__browser_snapshot",
      "mcp__playwright__browser_take_screenshot",
      "mcp__playwright__browser_click",
      "mcp__playwright__browser_evaluate",
      "mcp__playwright__browser_wait_for",
      "mcp__playwright__browser_close"
    ]
  }
}
```

### Phase별 권한 매핑

| Phase | 필요 권한 그룹 |
|-------|--------------|
| 1 (수집) | Figma MCP, base64, shasum, mkdir |
| 2 (시각화) | base64, shasum (Excalidraw 이미지) |
| 3 (TC) | 추가 권한 없음 (Read/Write만) |
| 4 (백로그) | 추가 권한 없음 |
| 5 (노션) | Notion MCP |
| 6 (개발) | git, gh, yarn, Playwright (검증) |

---

## 3. Auto-Chain Rules

**Phase 완료 시 리더가 즉시 다음 Phase를 시작한다. 멈추지 않는다.**

### 리뷰 게이트 자동 승인

| 게이트 | 원래 동작 | 하네스 동작 |
|--------|----------|------------|
| Phase 1→2 | "이해하신 뒤 /workflow visualize" 대기 | 즉시 Phase 2 시작 |
| Phase 2→3 | `policyReviewApproved` 기획자 확인 대기 | 자동 `true` 설정 → 즉시 Phase 3 |
| Phase 3→4 | `tcReviewApproved` QA 확인 대기 | 자동 `true` 설정 → 즉시 Phase 4 |
| Phase 4→5 | 개발자 검토 대기 | 즉시 Phase 5 |
| Phase 5→6 | 팀 리뷰 대기 | 즉시 Phase 6 |
| Phase 6 브리핑 | 사용자 "ㅇㅇ" 입력 대기 | 브리핑 출력 후 즉시 TDD 시작 |

### 체인 실행 의사코드

```
for phase in [1, 2, 3, 4, 5, 6]:
    execute_phase(phase)
    auto_approve_gate(phase)
    update_state(phase, "completed")
    notify(f"Phase {phase} 완료 → Phase {phase+1} 시작")
    # 멈추지 않고 바로 다음 Phase
```

### Phase 전환 시 리더 체크리스트

매 전환 시 리더가 자동 수행:
1. 이전 Phase 산출물 존재 확인
2. state.json 업데이트 (status, currentPhase)
3. 다음 Phase 전제 조건 자동 충족 (게이트 승인)
4. 알림: `"Phase {N} 완료 → Phase {N+1} 시작"`
5. 다음 Phase 즉시 실행

---

## 4. Phase 5 → 6 전환: 사전 질문 자동 처리

Phase 5(노션 변환)는 에픽 URL, 스프린트 URL 등을 질문한다.
하네스 모드에서는 state.json에서 자동 추출:

```
에픽 URL → state.json.notionEpicUrl (start 시 입력받음)
스프린트 URL → state.json.notionSprintUrl (start 시 입력받음)
작업자 → 기본값 (현재 사용자)
```

`/workflow start --auto` 시 피그마 URL과 함께 이 값들도 한 번에 받는다:
```
/workflow start --auto {name}
  피그마 URL: ...
  에픽 URL: ...
  스프린트 URL: ...
```

---

## 5. 퍼블리싱 검증 루프 (Publishing Verification Loop)

### 문제

UI Agent가 피그마 디자인을 코드로 변환할 때 발생하는 품질 문제:
- 공통 컴포넌트를 안 쓰고 새로 만듦
- 디자인 토큰 대신 하드코딩된 값 사용
- 상태별 variant (hover, disabled, selected) 누락
- 레이아웃 구조 불일치 (gap, padding, flex 방향)
- 반응형 처리 누락

### 해결: 3단 검증

Phase 6의 TDD 흐름에 검증 라운드를 삽입한다:

```
Round 1: RED (Test Writer)
Round 2: GREEN (UI Agent + Backend Agent)
  ↓
Round 2.5: VERIFY (Publishing Verification)  ← 신규
  ↓
Round 3: REFACTOR (Reviewer)
```

### Round 2.5 상세

#### Step 1: Pre-check (UI Agent 시작 전)

UI Agent 프롬프트에 **필수 체크리스트**를 주입한다:

```markdown
## 퍼블리싱 필수 규칙

1. **공통 컴포넌트 우선**: Phase 1 design.md의 "공통 컴포넌트 매칭" 테이블을 반드시 읽고,
   ✅ 동일 → 그대로 import
   ⚠️ 유사 → 기존 컴포넌트에 props 추가 검토 (불가 시에만 신규)
   🆕 신규 → 새로 생성

2. **디자인 토큰 사용**: design.md Pass 1의 토큰 사용. 하드코딩 금지.
   색상 → theme 변수 또는 프로젝트 상수
   타이포 → 기존 텍스트 스타일 재사용
   스페이싱 → 기존 gap/padding 패턴 참조

3. **상태별 구현**: design.md Pass 1의 variant 목록 전부 구현.
   Default, Hover, Disabled, Selected, Error, Loading, Empty

4. **레이아웃 정확도**: design.md의 Flex 방향, gap, padding 값을 정확히 반영.
   "대충 비슷하게"가 아닌 정확한 값 사용.

5. **styled-components 최소화**: 
   간단한 속성 1-2개만 다르면 Flex 등 공통 컴포넌트 직접 사용.
   styled-component 분리 금지. (feedback: 공통 컴포넌트 우선 사용)
```

#### Step 2: Visual Verification (UI Agent 완료 후)

리더가 CDP 에이전트를 스폰하여 검증:

```
Agent(subagent_type: "cdp-browser")
```

검증 프로세스:
1. `yarn dev` 실행 확인 (또는 Storybook)
2. 구현된 화면/컴포넌트로 네비게이트
3. 스크린샷 캡처
4. Phase 1 `pipeline/assets/` 스크린샷과 비교
5. 불일치 리포트 생성

#### Step 3: 불일치 리포트 → 자동 수정

```markdown
## 불일치 리포트

| # | 영역 | 피그마 | 구현 | 심각도 | 자동 수정 가능 |
|---|------|--------|------|--------|--------------|
| 1 | 헤더 gap | 16px | 24px | 높음 | ✅ |
| 2 | 버튼 색상 | #4A9EED | #3B82F6 | 높음 | ✅ |
| 3 | 호버 상태 | 존재 | 누락 | 중간 | ✅ |
| 4 | 테이블 컬럼 순서 | A,B,C | A,C,B | 높음 | ⚠️ 수동 확인 |
```

수정 루프:
- 자동 수정 가능(✅) → UI Agent에게 SendMessage로 수정 지시
- **최대 3회 반복**
- 3회 초과 또는 수동 확인(⚠️) → 불일치 리포트를 Reviewer에게 전달, 계속 진행

#### 검증 항목 체크리스트

| # | 항목 | 검증 방법 | 심각도 |
|---|------|----------|--------|
| 1 | 공통 컴포넌트 사용 | import 문 분석 vs 매칭 테이블 | 높음 |
| 2 | 레이아웃 구조 | CDP 스냅샷의 DOM 트리 분석 | 높음 |
| 3 | 색상 토큰 | styled-components에서 하드코딩 grep | 높음 |
| 4 | 타이포그래피 | font-size/weight 값 확인 | 중간 |
| 5 | 상태별 variant | Storybook stories 존재 확인 | 중간 |
| 6 | gap/padding | computed style 비교 | 중간 |
| 7 | 반응형 | viewport 리사이즈 후 재확인 | 낮음 |

### Storybook 활용

UI Agent가 Storybook stories를 작성하면, 검증 에이전트가 Storybook에서 각 variant를 순회하며 검증한다:
- Default → 기본 레이아웃 확인
- WithData → 데이터 바인딩 확인
- Empty → 빈 상태 UI 확인
- Loading → 로딩 상태 확인
- Error → 에러 상태 확인

---

## 6. Hooks

### PreCommit Lint Auto-fix (Phase 6)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit:*)",
        "hooks": [
          {
            "type": "command",
            "command": "cd $PROJECT_ROOT && yarn lint --fix --quiet 2>&1 | tail -5"
          }
        ]
      }
    ]
  }
}
```

### Phase 완료 알림

각 Phase 완료 시 리더가 실행:
```bash
terminal-notifier -message 'Phase {N} 완료 → Phase {N+1} 시작' -title 'Workflow Harness' -sound default
```

### 전체 완료 알림

```bash
terminal-notifier -message '워크플로우 완료! PR #{numbers}' -title 'Workflow Harness' -sound Glass
```

---

## 7. 에러 복구

### Phase 실패 시

```
if phase fails:
    1. 에러 로그를 state.json에 기록
    2. 1회 자동 재시도 (같은 Phase)
    3. 재시도도 실패 → 알림 + 멈춤
       terminal-notifier -message 'Phase {N} 실패. 수동 개입 필요.' -title 'Harness ERROR'
    4. state.json에 harness.lastError 기록
    5. 사용자가 수정 후 `/workflow {phase}` 로 해당 Phase부터 재개
```

### Agent Teams 실패 시

팀원 에러/타임아웃:
1. 해당 태스크 재시도 (1회)
2. 실패 시 다른 팀원에게 위임
3. 위임도 실패 → 에러 리포트 + 계속 진행 (해당 부분 스킵 기록)

---

## 8. 해제 프로토콜

### 정상 해제 (전체 완료 시)

1. settings.local.json 복원: `harness.originalPermissions`로 되돌림
2. PreCommit lint hook 제거
3. state.json: `harness.active = false`
4. 완료 알림

### 수동 해제 (`/workflow stop`)

1. 현재 진행 중인 Phase 완료 대기 (또는 즉시 중단)
2. 위와 동일한 복원 절차
3. "하네스 해제됨. Phase {N}에서 중단." 출력

### 복원 시 주의

- `originalPermissions`가 비어 있으면 기본 allow 목록으로 복원
- hooks는 하네스가 추가한 것만 제거 (기존 Notification/Stop hooks 보존)
