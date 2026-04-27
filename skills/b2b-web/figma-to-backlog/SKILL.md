---
name: b2b-web-figma-to-backlog
description: "Figma 디자인 URL로부터 개발 백로그(backlog.md), 정책 누락 보고서(policy-gaps.md), 디자이너 요청 목록(design-requests.md)을 자동 생성하는 오케스트레이터. 'Figma에서 백로그 추출', '디자인 분석해서 백로그 만들어줘', 'Figma URL로 작업 분해', '백로그 다시 만들어줘', '정책 감사 다시', '디자인 요청 업데이트', '이전 백로그 개선', 'Figma 백로그 수정', '정책 누락 보완' 요청 시 반드시 이 스킬을 사용할 것."
---

# Figma-to-Backlog Orchestrator

Figma 디자인을 분석하여 개발 백로그, 정책 누락 보고서, 디자이너 요청 목록을 자동 생성하는 팀 오케스트레이터.

## 실행 모드: 에이전트 팀 (Fan-out/Fan-in + Producer-Reviewer)

## 아키텍처

```
Phase 1: [design-analyzer] -> 디자인 인벤토리 추출
                                    |
Phase 2: [backlog-writer] <-> [policy-auditor]  (Fan-out, 병렬 + 상호 공유)
                    |                  |
Phase 3:        [qa-reviewer]  (Producer-Reviewer, 교차 검증)
                    |
Phase 4: 리더가 최종 산출물 통합
```

## 에이전트 구성

| 팀원 | 에이전트 타입 | 역할 | 스킬 | 출력 |
|------|-------------|------|------|------|
| design-analyzer | design-analyzer | Figma 데이터 추출 | design-analyzer | inventory.md |
| backlog-writer | backlog-writer | Feature/Story/Task 분해 | backlog-writer | backlog.md |
| policy-auditor | policy-auditor | 정책 누락 감사 | policy-auditor | gaps.md, design-requests.md |
| qa-reviewer | qa-reviewer | 산출물 교차 검증 | qa-reviewer | report.md |

## 워크플로우

### Phase 0: 컨텍스트 확인

기존 산출물 존재 여부를 확인하여 실행 모드를 결정한다:

1. `.harness/` 디렉토리 존재 여부 확인
2. 실행 모드 결정:
   - **`.harness/` 미존재** -> 초기 실행. Phase 1로 진행
   - **`.harness/` 존재 + 사용자가 부분 수정 요청** -> 부분 재실행. 해당 에이전트만 재호출하고 기존 산출물 중 수정 대상만 덮어쓴다
   - **`.harness/` 존재 + 새 Figma URL 제공** -> 새 실행. 기존 `.harness/`를 `.harness_{YYYYMMDD_HHMMSS}/`로 이동한 뒤 Phase 1 진행
3. 부분 재실행 시: 이전 산출물 경로를 에이전트 프롬프트에 포함하여, 에이전트가 기존 결과를 읽고 피드백을 반영하도록 지시

### Phase 1: 디자인 추출 (순차)

**실행 모드:** 에이전트 팀 (design-analyzer 단독)

1. 사용자로부터 Figma URL을 받는다
2. `.harness/00_input/` 디렉토리에 URL과 메타데이터를 저장한다
3. 팀 생성 -- Phase 1은 design-analyzer만 필요:

```
TeamCreate(
  team_name: "figma-extract",
  members: [
    { name: "design-analyzer", agent_type: "design-analyzer", model: "opus",
      prompt: "Figma URL: {url}을 분석하여 화면/컴포넌트/인터랙션 인벤토리를 작성하라.
               산출물을 .harness/01_design-analyzer_inventory.md에 저장하라.
               완료 시 리더에게 알려라." }
  ]
)
```

4. 작업 등록:
```
TaskCreate(tasks: [
  { title: "Figma 노드 트리 추출", assignee: "design-analyzer" },
  { title: "화면 목록 작성", assignee: "design-analyzer" },
  { title: "컴포넌트 인벤토리 작성", assignee: "design-analyzer" },
  { title: "인터랙션 맵 작성", assignee: "design-analyzer" },
  { title: "디자인 토큰 요약", assignee: "design-analyzer" }
])
```

5. design-analyzer 완료 대기
6. `.harness/01_design-analyzer_inventory.md` 존재 확인
7. 팀 정리 (TeamDelete) -- Phase 2에서 새 팀 구성

### Phase 2: 백로그 분해 + 정책 감사 (Fan-out, 병렬)

**실행 모드:** 에이전트 팀 (backlog-writer + policy-auditor 병렬)

1. 새 팀 생성:

```
TeamCreate(
  team_name: "backlog-policy",
  members: [
    { name: "backlog-writer", agent_type: "backlog-writer", model: "opus",
      prompt: ".harness/01_design-analyzer_inventory.md를 읽고 Feature > Story > Task 계층으로 백로그를 작성하라.
               퍼블리싱/API/로직 Task를 반드시 분리하라.
               산출물을 .harness/02_backlog-writer_backlog.md에 저장하라.
               policy-auditor가 정책 누락 항목을 보내면 백로그 Task에 추가하라.
               완료 시 리더에게 알려라." },
    { name: "policy-auditor", agent_type: "policy-auditor", model: "opus",
      prompt: ".harness/01_design-analyzer_inventory.md를 읽고 화면별 정책 누락을 감사하라.
               Empty/Error/Loading state, 반응형, 접근성, 예외 흐름을 체크하라.
               정책 누락 보고서를 .harness/02_policy-auditor_gaps.md에 저장하라.
               디자이너 요청 목록을 .harness/02_policy-auditor_design-requests.md에 저장하라.
               Critical/Major 누락 항목은 backlog-writer에게 SendMessage로 전달하라.
               완료 시 리더에게 알려라." }
  ]
)
```

2. 작업 등록:
```
TaskCreate(tasks: [
  { title: "인벤토리 분석 및 Feature 정의", assignee: "backlog-writer" },
  { title: "Story/Task 분해", assignee: "backlog-writer" },
  { title: "의존 관계 및 우선순위 설정", assignee: "backlog-writer" },
  { title: "화면 상태 감사 (5 states)", assignee: "policy-auditor" },
  { title: "반응형/접근성/예외 흐름 감사", assignee: "policy-auditor" },
  { title: "디자이너 요청 목록 작성", assignee: "policy-auditor" },
  { title: "정책 누락 -> 백로그 반영", assignee: "backlog-writer", depends_on: ["화면 상태 감사 (5 states)"] }
])
```

3. 팀원 간 통신 규칙:
   - policy-auditor -> backlog-writer: Critical/Major 정책 누락 항목을 SendMessage로 전달
   - backlog-writer -> policy-auditor: 분해 중 발견된 모호한 인터랙션을 SendMessage로 공유
   - 양쪽 완료 대기

4. 팀 정리 (TeamDelete)

### Phase 3: QA 검증 (Producer-Reviewer)

**실행 모드:** 에이전트 팀 (qa-reviewer + 수정 대상 에이전트)

1. 새 팀 생성:

```
TeamCreate(
  team_name: "qa-review",
  members: [
    { name: "qa-reviewer", agent_type: "qa-reviewer", model: "opus",
      prompt: "모든 산출물을 교차 검증하라:
               - .harness/01_design-analyzer_inventory.md
               - .harness/02_backlog-writer_backlog.md
               - .harness/02_policy-auditor_gaps.md
               - .harness/02_policy-auditor_design-requests.md
               인벤토리 <-> 백로그 커버리지, 정책 Gap <-> 백로그 반영, 용어 일관성을 검증하라.
               리포트를 .harness/03_qa-reviewer_report.md에 저장하라.
               FAIL 항목이 있으면 해당 에이전트에게 수정 요청하라.
               완료 시 리더에게 전체 판정과 함께 알려라." },
    { name: "backlog-fixer", agent_type: "backlog-writer", model: "opus",
      prompt: "qa-reviewer의 수정 요청을 대기하라.
               수정 요청이 오면 .harness/02_backlog-writer_backlog.md를 읽고 수정하라.
               수정 완료 시 qa-reviewer에게 알려라." },
    { name: "policy-fixer", agent_type: "policy-auditor", model: "opus",
      prompt: "qa-reviewer의 수정 요청을 대기하라.
               수정 요청이 오면 해당 산출물을 읽고 수정하라.
               수정 완료 시 qa-reviewer에게 알려라." }
  ]
)
```

2. 작업 등록:
```
TaskCreate(tasks: [
  { title: "커버리지 교차 검증", assignee: "qa-reviewer" },
  { title: "정책 반영 교차 검증", assignee: "qa-reviewer" },
  { title: "용어 일관성 검증", assignee: "qa-reviewer" },
  { title: "구조 품질 검증", assignee: "qa-reviewer" },
  { title: "수정 요청 처리 (백로그)", assignee: "backlog-fixer" },
  { title: "수정 요청 처리 (정책)", assignee: "policy-fixer" }
])
```

3. qa-reviewer -> backlog-fixer/policy-fixer: FAIL 항목에 대해 수정 요청 SendMessage
4. 수정 후 qa-reviewer가 재검증 (최대 2회)
5. 팀 정리 (TeamDelete)

### Phase 4: 최종 산출물 통합

리더가 직접 수행:

1. `.harness/03_qa-reviewer_report.md`를 읽어 전체 판정 확인
2. PASS 또는 WARN이면 최종 산출물 생성:
   - `.harness/02_backlog-writer_backlog.md` -> `backlog.md`로 복사
   - `.harness/02_policy-auditor_gaps.md` -> `policy-gaps.md`로 복사
   - `.harness/02_policy-auditor_design-requests.md` -> `design-requests.md`로 복사
3. FAIL이면 사용자에게 QA 리포트를 공유하고 진행 여부 확인
4. `.harness/` 디렉토리 보존 (중간 산출물, 감사 추적용)
5. 사용자에게 결과 요약 보고:
   - 총 화면 수, Feature 수, Story 수, Task 수
   - 정책 누락 건수 (Critical/Major/Minor)
   - 디자이너 요청 건수
   - QA 판정 결과

## 데이터 흐름

```
[리더] -> Figma URL
    |
[design-analyzer] -> .harness/01_inventory.md
    |
[backlog-writer] <-SendMessage-> [policy-auditor]
    |                               |
.harness/02_backlog.md    .harness/02_gaps.md + design-requests.md
    |                               |
         [qa-reviewer] <- Read all
              |
         .harness/03_report.md
              | (FAIL 시)
    [backlog-fixer] / [policy-fixer] <- SendMessage 수정 요청
              |
         [qa-reviewer] 재검증
              |
    [리더] -> 최종 산출물 통합
              |
    backlog.md / policy-gaps.md / design-requests.md
```

## 에러 핸들링

| 상황 | 전략 |
|------|------|
| Figma MCP 연결 실패 | figma-dev-mode-mcp-server 우회 시도. 재실패 시 사용자에게 알림 |
| design-analyzer 실패 | 1회 재시도. 재실패 시 사용자에게 수동 인벤토리 요청 |
| backlog-writer 또는 policy-auditor 실패 | 1회 재시도. 재실패 시 가용 산출물로 Phase 3 진행, 누락 명시 |
| qa-reviewer FAIL 판정 | 수정 요청 -> 재검증 (최대 2회). 2회 후에도 FAIL이면 현 상태로 산출물 생성 + 주의사항 명시 |
| 팀원 간 데이터 충돌 | 출처 명시 후 병기, 삭제하지 않음 |
