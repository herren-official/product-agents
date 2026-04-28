---
name: b2b-backend-spec-orchestrator
description: 기획서 분석 파이프라인을 조율하는 오케스트레이터. "기획서 분석해줘", "기획 분석", "구현 가능성 확인", "정책 누락 검토", "스펙 분석", "기획 검토" 요청 시 트리거. 이전 결과 보완, 재분석, 다시 실행 요청에도 반응한다.
---

# 기획 분석 오케스트레이터 (Spec Orchestrator)

## 파이프라인 개요

```
Phase 0: 컨텍스트 확인 + 작업 디렉토리 생성
Phase 1: 루나(정책 대표) → [선택] 올빼미(리서치)
Phase 2: 코드체커(코드베이스 대표)
Phase 3: 가디언(통합 검증 + QA 루프 판단)
  ├── PASS → Phase 3.5로 진행
  └── FAIL → Phase 3-R(재실행 + 가디언 재검증)
Phase 3.5: 정책 엣지케이스 분석 (가디언 + edge-case-policy)
  → 루나/코드체커 재확인 → 가디언 판단 → Critical이면 Phase 3-R
Phase 4: Woody님 확인 질문 (누락건만)
Phase 5: 빌더(최종 기획서 종합)
Phase 5.5: 자체 검증 모드 (Verification Pass)
Phase 6: 리뷰 & 피드백
```

## 공통 규칙

### 프로젝트 루트
모든 에이전트 spawn 시 프로젝트 루트 절대 경로를 반드시 전달한다:
```
프로젝트 루트: /Users/woody/IdeaProjects/gongbiz/gongbiz-crm-b2b-backend
```

### 에이전트 spawn 설정
모든 에이전트 호출 시 다음을 적용한다:
- `model: "opus"`
- 산출물 경로는 **절대 경로**로 전달
- 에이전트 정의/스킬 파일 경로도 **절대 경로**로 전달

### 에이전트 spawn 권한 설정
모든 에이전트 호출 시 다음을 적용한다:
- `model: "opus"`
- `mode: "bypassPermissions"` — Write/Bash 권한 부여 (에이전트가 산출물 직접 저장)
- `subagent_type: "oh-my-claudecode:executor"` — **커스텀 에이전트 타입(spec-analyst, policy-reviewer 등)은 mode가 동작하지 않을 수 있음**. 안정적으로 `oh-my-claudecode:executor`를 사용하고, 에이전트 정의 파일은 prompt에 경로로 전달하여 역할을 지시한다.
- 산출물 경로는 **절대 경로**로 전달
- 분석 브랜치, module_context.md 경로를 prompt에 반드시 포함
- **기존 파일 덮어쓰기 시**: 에이전트 prompt에 "기존 파일이 존재하므로 Read로 먼저 읽은 후 Write하라"고 명시 (Write 도구 제약: 기존 파일을 Read 없이 Write하면 거부됨)

### 실행 순서 규칙 (절대 원칙)

| Phase | 에이전트 | run_in_background | 선행 조건 |
|-------|---------|------------------|----------|
| 1 | 루나 | **false** (완료 대기) | Phase 0 완료 + raw_spec.md 검증 통과 |
| 1-1 (자동) | 올빼미 | **false** (완료 대기) | 루나 완료 + 외부 연동 항목 1건 이상 → **자동 호출 (건너뛰지 않음)** |
| 2 | 코드체커 | **false** (완료 대기) | 루나 산출물 파일 존재 확인 |
| 3 | 가디언 | **false** (완료 대기) | 코드체커 산출물 파일 존재 확인 |
| 3-R (조건부) | 루나/코드체커 재실행 | **false** | 가디언 FAIL 판단 + 재실행 1회차 |
| 3-R2 | 가디언 재검증 | **false** | 재실행 에이전트 완료 |
| 4 | Woody님 확인 | - | 가디언 PASS |
| 5 | 빌더 | **false** (완료 대기) | 가디언 완료 + Woody님 답변 저장 |
| 5.5 | 자체 검증 | **true** (3개 병렬) | 빌더 완료 |
| 6 | 리뷰 & 피드백 | - | 검증 완료 |

**핵심**: 루나 → 코드체커는 반드시 순차. 코드체커 결과 없이 가디언 실행 금지. 가디언은 이제 **false**(완료 대기) — QA 루프 판단 결과를 읽어야 하므로.

### 산출물 검증 (각 Phase 완료 후)

에이전트 완료 후, 다음 Phase로 넘어가기 전에 산출물을 검증한다:

1. **파일 존재 확인**: Read로 첫 10줄 확인
2. **줄바꿈 검증**: 파일이 5줄 미만이면 `\\n` 리터럴 의심
   - `\\n`이 발견되면 Python으로 실제 줄바꿈 변환 (Bash 사용)
3. **HTML entity 변환**: `&gt;`, `&lt;`, `&amp;` → `>`, `<`, `&`
4. **구조 검증**: `##` heading이 3개 이상 존재하는지 확인
5. **검증 실패 시**: 오케스트레이터가 직접 정리하거나 에이전트 1회 재시도

```python
# 산출물 정리 스크립트 (필요 시)
content = content.replace('\\\\n', '\\n').replace('\\n', '\n')
content = content.replace('&gt;', '>').replace('&lt;', '<').replace('&amp;', '&')
```

## Phase 0: 컨텍스트 확인

### 입력 수집

사용자에게 확인한다 (이미 제공된 항목은 건너뜀):
1. **필수**: 기획서 소스 (아래 형태 모두 지원, 복수 가능)
   - 노션 URL (`https://www.notion.so/...`)
   - 로컬 디렉토리 (`ai/claude/woody/task/GBIZ-XXXXX/`)
   - 로컬 파일 경로
   - 텍스트 직접 입력
2. **선택**: 에픽/티켓 번호 (GBIZ-XXXXX), 담당 범위

### 작업 디렉토리 자동 생성

현재 날짜 기반으로 분기를 계산하여 디렉토리를 자동 생성한다:

```
1~3월  → 1Q
4~6월  → 2Q
7~9월  → 3Q
10~12월 → 4Q

경로: ai/claude/woody/_workspace/{년도}/{분기}/{에픽번호 또는 제목}/
```

**예시:**
- 에픽 번호 있음 (4월): `ai/claude/woody/_workspace/2026/2Q/GBIZ-24899/`
- 에픽 번호 없음 (4월): `ai/claude/woody/_workspace/2026/2Q/첫예약할인쿠폰/`

디렉토리명에 사용할 식별자 우선순위:
1. 에픽/티켓 번호 (GBIZ-XXXXX)
2. 기획서 제목에서 핵심 키워드 추출 (kebab-case)

### 실행 모드 판단

작업 디렉토리 존재 여부로 실행 모드를 결정한다:
- 디렉토리 없음 → **초기 실행** (전체 파이프라인)
- 디렉토리 있음 + 새 기획서 → **새 실행** (기존을 `{dir}_prev/`로 이동)
- 디렉토리 있음 + 부분 수정 요청 → **부분 재실행** (해당 Phase만)

### Step 0-0: 브랜치 확인 (신규)

1. `git branch --show-current`로 현재 브랜치 확인
2. 사용자에게 분석 대상 브랜치를 확인한다 (기본: develop)
   - 이미 제공된 경우 건너뜀
3. 현재 브랜치가 대상과 다르면:
   - "현재 브랜치는 {현재}입니다. develop 기준으로 분석할까요?" 확인
   - 승인 시 `git checkout {대상}` 실행
4. 에이전트 spawn 시 모든 prompt에 `분석 브랜치: {branch}` 포함

#### analysis_root 확정

브랜치 확인 후, 코드 분석 경로를 확정한다:
- 현재 브랜치 == 분석 대상 브랜치: `analysis_root = {프로젝트 루트}`
- 현재 브랜치 != 분석 대상: worktree 생성 후 `analysis_root = {worktree 경로}`

이후 **모든 에이전트 spawn prompt에 자동 포함**:
```
코드 분석 경로 (analysis_root): {analysis_root}
분석 브랜치: {브랜치명}
```

에이전트가 코드를 읽을 때는 반드시 `analysis_root` 경로를 사용한다.
산출물 저장은 기존 `{작업디렉토리}` 경로를 사용한다 (analysis_root와 다를 수 있음).

### 기획서/디자인 수집

노션 URL이 주어진 경우, **notion-collector 스킬**의 워크플로우를 따라 수집한다:
1. `mcp__plugin_Notion_notion__notion-fetch`로 페이지 조회
2. JSON 응답에서 text 필드 추출
3. 줄바꿈 변환 (`\\n` → 실제 줄바꿈) + HTML entity 디코딩
4. `{작업디렉토리}/raw_spec.md`에 저장

피그마 URL이 주어진 경우, **figma-collector 스킬**의 워크플로우를 따라 수집한다:
1. URL에서 nodeId 파싱 (`-` → `:`)
2. `mcp__figma-desktop__get_design_context`로 메타데이터 수집
3. 섹션 트리 추출 + 핵심 화면 스크린샷 수집
4. `{작업디렉토리}/figma_context.md`에 저장

#### 수집 실행 방식

오케스트레이터가 직접 수집하지 않고, **수집 에이전트를 spawn**하여 위임한다:

```
Agent(
  name: "수집기",
  subagent_type: "oh-my-claudecode:executor",
  model: "sonnet",
  mode: "bypassPermissions",
  prompt: "notion-collector 스킬과 figma-collector 스킬의 워크플로우를 따라
           기획서와 디자인을 수집하라.
           notion-collector 스킬: {절대경로}/.claude/skills/notion-collector/SKILL.md
           figma-collector 스킬: {절대경로}/.claude/skills/figma-collector/SKILL.md
           노션 URL: {URL}
           피그마 URL: {URL}
           저장 경로: {작업디렉토리}
           프로젝트 루트: {절대경로}"
)
```

수집 에이전트 완료 후, 오케스트레이터가 Step 0-1 (수집 결과 검증)을 직접 수행한다.

### Step 0-1: 수집 결과 검증 (신규)

수집 완료 후 반드시 검증한다:
1. `raw_spec.md` 파일 줄 수 확인 — **5줄 미만이면 수집 실패**로 판단, 재수집
2. 첫 줄이 `{` 또는 `[`로 시작하면 JSON 미파싱 → 재수집
3. `##` heading이 2개 이상 존재하는지 확인
4. `figma_context.md` 존재 시 섹션 수 확인 (0이면 경고)
5. 검증 실패 시 1회 재시도, 재실패 시 사용자에게 수동 확인 요청

### Step 0-2: 모듈 컨텍스트 수집 (신규)

분석 대상 모듈의 기술 스택을 **module-scanner 스킬**의 워크플로우를 따라 확인한다:
1. 기획서에서 언급된 대상 모듈 키워드 추출 (또는 사용자 지정)
   - 기본 대상: `gongbiz-crm-b2b-backend`, `gongbiz-notification`, `gongbiz-notification-orchestrator`, `gongbiz-notification-batch`, `gongbiz-notification-common`, `gongbiz-notification-client`
2. 각 모듈의 `build.gradle.kts`에서 Spring Boot 버전 직접 확인
3. javax vs jakarta import Grep count
4. CLAUDE.md 테이블과 교차 검증, 불일치 시 경고
5. `{작업디렉토리}/module_context.md` 생성
6. 이 파일을 **모든 후속 에이전트에 입력으로 전달**

## Phase 1: 기획 분석

**루나(spec-analyst)** 에이전트를 spawn한다.

```
Agent(
  name: "루나",
  agent: "spec-analyst",
  model: "opus",
  prompt: "기획서를 분석하여 요구사항을 구조화하라.
           에이전트 정의: {절대경로}/.claude/agents/spec-analyst.md
           스킬: {절대경로}/.claude/skills/spec-analysis/SKILL.md
           기획서: {작업디렉토리}/raw_spec.md
           module_context.md: {작업디렉토리}/module_context.md
           분석 브랜치: {브랜치명}
           산출물 경로: {작업디렉토리}/01_luna_requirements.md
           프로젝트 루트: {절대경로}"
)
```

루나 완료 후, 산출물의 "외부 연동 필요 항목"을 확인한다.

### 올빼미 자동 호출 (외부 연동 항목 존재 시 필수)

루나 산출물의 "외부 연동 필요 항목" 섹션을 확인한다.
- 외부 연동 항목이 **1건 이상이면 올빼미를 반드시 호출**한다. 오케스트레이터가 "불필요"로 판단하여 건너뛰지 않는다.
- 올빼미 완료 후에만 Phase 2(코드체커)로 진행한다.
- 외부 연동 항목이 0건이면 올빼미를 건너뛴다.

**외부 연동 있음 → 올빼미(researcher) 호출:**

```
Agent(
  name: "올빼미",
  agent: "researcher",
  model: "opus",
  prompt: "루나의 분석 결과에서 외부 연동 필요 항목을 조사하라.
           에이전트 정의: {절대경로}/.claude/agents/researcher.md
           스킬: {절대경로}/.claude/skills/research/SKILL.md
           입력: {작업디렉토리}/01_luna_requirements.md
           산출물 경로: {작업디렉토리}/01-1_owl_research.md
           프로젝트 루트: {절대경로}"
)
```

## Phase 2: 코드 실현성 분석

**코드체커(code-feasibility-checker)** 에이전트를 spawn한다. 완료 대기 (순차 실행).

```
Agent(
  name: "코드체커",
  agent: "code-feasibility-checker",
  model: "opus",
  run_in_background: false,
  prompt: "루나의 요구사항을 코드베이스와 매핑하여 실현성을 분석하라.
           에이전트 정의: {절대경로}/.claude/agents/code-feasibility-checker.md
           스킬: {절대경로}/.claude/skills/code-feasibility/SKILL.md
           입력: {작업디렉토리}/01_luna_requirements.md
                 {작업디렉토리}/01-1_owl_research.md (있는 경우)
           module_context.md: {작업디렉토리}/module_context.md
           분석 브랜치: {브랜치명}
           산출물 경로: {작업디렉토리}/02_codechecker_feasibility.md
           프로젝트 루트: {절대경로}"
)
```

### 구현 완료 비율 확인

코드체커 완료 후, 구현 완료 비율이 50% 이상이면 **잔여 작업 집중 모드**로 전환한다:
- 가디언에게 "이미 구현된 기능은 건너뛰고, 미구현/부분 구현 기능의 정책 갭에 집중하라"고 지시
- 빌더에게 "잔여 작업 중심으로 기획서를 구성하라"고 지시

## Phase 3: 통합 검증 + QA 루프

**가디언(policy-reviewer)** 에이전트를 spawn한다. **완료 대기** (QA 루프 판단 결과를 읽어야 하므로).

```
Agent(
  name: "가디언",
  agent: "policy-reviewer",
  model: "opus",
  run_in_background: false,
  prompt: "기획서 정책과 코드 동작을 대조하여 누락/불일치/엣지케이스를 검출하고,
           루나와 코드체커 산출물의 품질을 평가하여 재실행 필요 여부를 판단하라.
           에이전트 정의: {절대경로}/.claude/agents/policy-reviewer.md
           스킬: {절대경로}/.claude/skills/policy-review/SKILL.md
           입력: {작업디렉토리}/01_luna_requirements.md
                 {작업디렉토리}/02_codechecker_feasibility.md
                 {작업디렉토리}/01-1_owl_research.md (있는 경우)
           module_context.md: {작업디렉토리}/module_context.md
           분석 브랜치: {브랜치명}
           산출물 경로: {작업디렉토리}/03_guardian_policy_gaps.md
           프로젝트 루트: {절대경로}"
)
```

### Phase 3.5: 정책 엣지케이스 분석

> 가디언이 정책 검증 후, edge-case-policy 스킬로 정책 엣지케이스를 도출한다.
> 도출된 엣지케이스를 루나/코드체커가 재확인하고, 가디언이 최종 판단한다.

```
Agent(
  name: "가디언-엣지",
  description: "정책 엣지케이스 분석",
  model: "opus",
  mode: "bypassPermissions",
  run_in_background: false,
  prompt: "정책 엣지케이스를 도출하라.
           스킬: {절대경로}/.claude/skills/edge-case-policy/SKILL.md
           입력: {작업디렉토리}/05_builder_final_spec.md (또는 진행 중 기획서)
                 {작업디렉토리}/03_guardian_policy_gaps.md
                 {작업디렉토리}/10_architect_design.md (있는 경우)
           산출물 경로: {작업디렉토리}/03-1_edge_case_policy.md
           프로젝트 루트: {절대경로}"
)
```

#### 엣지케이스 후속 처리
1. 루나/코드체커에게 엣지케이스 목록 전달 → 대안/보강 확인
2. 가디언이 최종 판단:
   - Critical 엣지케이스 → 기획서 반영 필요 → Phase 3-R (QA Loop)
   - Woody님 확인 필요 → Phase 4 QnA 목록에 추가
   - Minor → 기록만 (디테일러가 테스트 시나리오에 반영)

### Phase 3-R: QA 루프 (가디언 재실행 판단 시)

가디언 산출물의 "QA 루프 판단" 섹션을 읽고 판단 결과를 확인한다.

#### PASS인 경우
Phase 4로 즉시 진행한다.

#### FAIL인 경우 (재실행 필요)

1. 가디언의 "보완 요청" 내용을 추출한다
2. 재실행 대상 에이전트를 호출한다 (피드백을 prompt에 포함):

**루나 재실행 (필요 시):**
```
Agent(
  name: "루나 (재실행)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: false,
  prompt: "이전 분석 결과를 보완하라. 가디언의 피드백을 반영하여 누락된 영역을 추가 분석하라.
           에이전트 정의: {절대경로}/.claude/agents/spec-analyst.md
           스킬: {절대경로}/.claude/skills/spec-analysis/SKILL.md
           기획서: {작업디렉토리}/raw_spec.md
           이전 산출물: {작업디렉토리}/01_luna_requirements.md
           가디언 피드백: {가디언의 루나 보완 요청 내용}
           지시: 이전 산출물을 Read로 읽은 후, 가디언 피드백 영역만 보완하여 동일 파일에 Write하라.
           산출물 경로: {작업디렉토리}/01_luna_requirements.md
           프로젝트 루트: {절대경로}"
)
```

**코드체커 재실행 (필요 시):**
```
Agent(
  name: "코드체커 (재실행)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: false,
  prompt: "이전 분석 결과를 보완하라. 가디언의 피드백을 반영하여 누락된 영역을 추가 분석하라.
           에이전트 정의: {절대경로}/.claude/agents/code-feasibility-checker.md
           스킬: {절대경로}/.claude/skills/code-feasibility/SKILL.md
           입력: {작업디렉토리}/01_luna_requirements.md
           이전 산출물: {작업디렉토리}/02_codechecker_feasibility.md
           가디언 피드백: {가디언의 코드체커 보완 요청 내용}
           module_context.md: {작업디렉토리}/module_context.md
           지시: 이전 산출물을 Read로 읽은 후, 가디언 피드백 영역만 보완하여 동일 파일에 Write하라.
           산출물 경로: {작업디렉토리}/02_codechecker_feasibility.md
           프로젝트 루트: {절대경로}"
)
```

3. 재실행 완료 후, **가디언을 재호출**한다 (재검증):

```
Agent(
  name: "가디언 (재검증)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: false,
  prompt: "이전 검증에서 FAIL 판단한 항목을 재검증하라.
           에이전트 정의: {절대경로}/.claude/agents/policy-reviewer.md
           스킬: {절대경로}/.claude/skills/policy-review/SKILL.md
           입력: {작업디렉토리}/01_luna_requirements.md
                 {작업디렉토리}/02_codechecker_feasibility.md
           이전 가디언 산출물: {작업디렉토리}/03_guardian_policy_gaps.md
           module_context.md: {작업디렉토리}/module_context.md
           지시: 이전 산출물을 Read로 읽은 후, 보완된 부분을 재평가하여 동일 파일에 Write.
                 재실행 횟수가 2회차이므로 FAIL이더라도 PASS 처리하고 미비 사항만 명시.
           산출물 경로: {작업디렉토리}/03_guardian_policy_gaps.md
           프로젝트 루트: {절대경로}"
)
```

4. 재검증 후 Phase 4로 진행한다 (최대 1회 재실행).

## Phase 4: Woody님 확인 질문

가디언의 산출물에서 확인 질문(Q-01, Q-02, ...)을 추출하여 Woody님에게 제시한다.

**제시 형식:**
```
가디언이 다음 항목에 대해 확인을 요청합니다:

[Critical] Q-01: {질문 내용}
  코드 근거: {파일:라인}
  기획 근거: {기획서 위치}

[Major] Q-02: {질문 내용}
  ...

답변해주시면 최종 기획서에 반영합니다.
놓친 부분이나 추가할 정책이 있으면 함께 알려주세요.
```

Woody님 답변을 `{작업디렉토리}/04_woody_answers.md`에 저장한다.

## Phase 5: 최종 기획서 종합

**빌더(spec-synthesizer)** 에이전트를 spawn한다.

```
Agent(
  name: "빌더",
  agent: "spec-synthesizer",
  model: "opus",
  prompt: "모든 산출물과 Woody님 답변을 종합하여 구현 가능한 기획서를 산출하라.
           에이전트 정의: {절대경로}/.claude/agents/spec-synthesizer.md
           입력: {작업디렉토리}/01_luna_requirements.md
                 {작업디렉토리}/01-1_owl_research.md (있는 경우)
                 {작업디렉토리}/02_codechecker_feasibility.md
                 {작업디렉토리}/03_guardian_policy_gaps.md
                 {작업디렉토리}/04_woody_answers.md
           module_context.md: {작업디렉토리}/module_context.md
           분석 브랜치: {브랜치명}
           산출물 경로: {작업디렉토리}/05_builder_final_spec.md
           프로젝트 루트: {절대경로}"
)
```

## Phase 5.5: 자체 검증 모드 (Verification Pass)

빌더 완료 후, 각 에이전트가 자신의 산출물을 원본 소스와 대조하여 누락을 자체 점검한다.
**가디언의 교차 검증과 다름**: 여기서는 각 에이전트가 자기 산출물만 자기 원본과 대조한다.

### 검증 에이전트 병렬 실행

3개 검증을 **병렬(run_in_background: true)**로 실행한다:

**루나 자체 검증:**
```
Agent(
  name: "루나 (검증)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: true,
  prompt: "자체 검증 모드. 자신의 산출물을 원본 기획서와 대조하여 누락을 점검하라.
           에이전트 정의: {절대경로}/.claude/agents/spec-analyst.md

           원본 소스: {작업디렉토리}/raw_spec.md
                     {작업디렉토리}/figma_context.md (있는 경우)
           자신의 산출물: {작업디렉토리}/01_luna_requirements.md

           검증 절차:
           1. raw_spec.md를 전체 읽기 (offset/limit 사용)
           2. 기획서의 모든 ## 섹션, 비즈니스 룰, 조건문, 예외사항을 목록화
           3. 01_luna_requirements.md를 읽기
           4. 원본 목록 vs 산출물 매핑 — 누락된 항목 식별
           5. 결과를 아래 형식으로 저장

           산출물 경로: {작업디렉토리}/06_verification_luna.md
           프로젝트 루트: {절대경로}"
)
```

**코드체커 자체 검증:**
```
Agent(
  name: "코드체커 (검증)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: true,
  prompt: "자체 검증 모드. 자신의 산출물을 코드베이스와 대조하여 누락을 점검하라.
           에이전트 정의: {절대경로}/.claude/agents/code-feasibility-checker.md

           입력: {작업디렉토리}/01_luna_requirements.md
           자신의 산출물: {작업디렉토리}/02_codechecker_feasibility.md
           코드 분석 경로: {analysis_root}

           검증 절차:
           1. 루나 산출물에서 전체 기능 목록(F-XX) 추출
           2. 02_codechecker_feasibility.md를 읽기
           3. 각 기능의 코드 매핑이 실제로 존재하는지 Grep으로 spot-check (최소 5건)
           4. 영향 범위 주장의 모듈 수를 실제 Grep으로 재검증 (핵심 2건)
           5. 누락된 매핑, 잘못된 경로 식별

           산출물 경로: {작업디렉토리}/06_verification_codechecker.md
           프로젝트 루트: {절대경로}"
)
```

**가디언 자체 검증:**
```
Agent(
  name: "가디언 (검증)",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "oh-my-claudecode:executor",
  run_in_background: true,
  prompt: "자체 검증 모드. 자신의 산출물을 루나/코드체커 산출물과 대조하여 누락을 점검하라.
           에이전트 정의: {절대경로}/.claude/agents/policy-reviewer.md

           입력: {작업디렉토리}/01_luna_requirements.md
                 {작업디렉토리}/02_codechecker_feasibility.md
           자신의 산출물: {작업디렉토리}/03_guardian_policy_gaps.md

           검증 절차:
           1. 루나의 정책 목록 전체 추출
           2. 코드체커의 기능별 리스크 전체 추출
           3. 03_guardian_policy_gaps.md를 읽기
           4. 엣지케이스 체크리스트 7개 관점을 각 기능에 적용 — 누락된 점검 식별
           5. 루나의 [불명확] 항목 중 가디언이 다루지 않은 것 식별

           산출물 경로: {작업디렉토리}/06_verification_guardian.md
           프로젝트 루트: {절대경로}"
)
```

### 검증 산출물 형식

각 `06_verification_*.md`는 다음 형식을 따른다:

```markdown
# 자체 검증 결과: {에이전트명}

## 검증 요약
| 지표 | 값 |
|------|-----|
| 원본 총 항목 수 | N |
| 산출물 반영 항목 수 | M |
| 누락 발견 수 | K |
| 오류율 | K/N × 100 = X% |
| 목표 대비 | PASS (< 2%) / FAIL (>= 2%) |

## 발견된 누락
### VG-01: {누락 항목}
- **원본 위치**: {raw_spec.md 섹션/라인 또는 코드 경로}
- **산출물 상태**: 미반영 / 부분 반영
- **심각도**: Critical / Major / Minor

## 학습 후보
| # | 패턴 | 빈도 | 학습 후보 여부 |
|---|------|------|--------------|
```

### 검증 결과 통합

3개 검증 완료 후, 오케스트레이터가 결과를 통합한다:

1. 각 `06_verification_*.md` 파일을 Read
2. 오류율 계산: `(발견된 갭 수 / 원본 총 항목 수) × 100`
3. 결과 요약을 Woody님에게 보고:

```
자체 검증 결과:
- 루나: {발견 갭}/{총 항목} = {X}% (목표 < 2%)
- 코드체커: {발견 갭}/{총 항목} = {X}% (목표 < 2%)
- 가디언: {발견 갭}/{총 항목} = {X}% (목표 < 2%)
```

4. Critical 갭 발견 시 → 빌더를 재호출하여 최종 스펙에 반영
5. 검증 결과를 학습 저장소에 기록 (Phase 5.5 후처리)

### Phase 5.5 후처리: 학습 기록

검증 결과에서 발견된 누락 패턴을 학습 파일에 기록한다.

1. 각 `06_verification_*.md`의 "학습 후보" 섹션을 읽는다
2. 학습 후보가 있으면:
   a. 해당 에이전트의 `.claude/agents/learnings/{agent}_learnings.md` 파일을 Read
   b. 기존 학습 항목과 중복 확인 (패턴명 기반)
   c. 중복이면 빈도 카운터 +1, 마지막 날짜 갱신
   d. 신규면 새 L-XXX 항목 추가
   e. 빈도 3회 이상이면 "활성 체크리스트"에 추가
   f. Write로 갱신된 파일 저장
3. 학습 파일이 없으면 초기 템플릿으로 생성
4. 빈도 3회 이상 + 범용 패턴이면 해당 Skill MD에 체크리스트 승격 고려 (Woody님 확인)

## Phase 6: 리뷰 & 피드백

최종 기획서 요약을 Woody님에게 제시하고 피드백을 요청한다.

```
기획 분석이 완료되었습니다.

[산출물 요약]
- 기능 N개, Critical N건, Major N건 해소
- 잔여 리스크 N건
- 산출물 경로: {작업디렉토리}/

놓친 부분이나 수정할 점이 있으세요?
```

- 피드백 있음 → 해당 Phase 에이전트 재호출하여 반영
- 피드백 없음 → 완료

### 올빼미 후행 실행 시 빌더 재실행

올빼미가 Phase 5(빌더) 완료 후에 실행된 경우:
1. 올빼미 산출물(`01-1_owl_research.md`)이 최종 기획서(`05_builder_final_spec.md`)보다 최신이면
2. 빌더를 **자동 재실행**하여 올빼미 결과를 최종 기획서에 반영한다
3. 재실행 시 Woody님 답변(04)은 유지하고, 올빼미 결과만 추가 입력으로 전달

### worktree 정리

분석에 worktree를 사용한 경우, 파이프라인 완료 후 정리한다:
1. `git worktree list`로 분석용 worktree 확인
2. `git worktree remove {worktree 경로}`로 제거
3. 제거 실패 시 `--force` 옵션 사용
4. Woody님에게 정리 완료 보고

## 에러 핸들링

| 상황 | 대응 |
|------|------|
| 에이전트 실패 | 1회 재시도 → 재실패 시 해당 영역 "미분석" 표시 후 진행 |
| 에이전트 파일 저장 실패 | 오케스트레이터가 에이전트 결과를 직접 저장 |
| 기획서 접근 불가 | 사용자에게 URL/내용 재요청 |
| 산출물 형식 불일치 | 핵심 내용 추출하여 다음 Phase에 전달 |

## 산출물 디렉토리

```
ai/claude/woody/_workspace/{년도}/{분기}/{에픽번호}/
├── raw_spec.md                      # Phase 0: notion-collector 산출물
├── raw_spec/                        # Phase 0: 대용량 시 분할
│   ├── raw_spec_index.md
│   └── 01_section.md ...
├── figma_context.md                 # Phase 0: figma-collector 산출물
├── module_context.md                # Phase 0: module-scanner 산출물
├── 01_luna_requirements.md          # Phase 1: 기획 분석 (정책 대표)
├── 01-1_owl_research.md             # Phase 1: 외부 리서치 (선택)
├── 02_codechecker_feasibility.md    # Phase 2: 코드베이스 대표
├── 03_guardian_policy_gaps.md       # Phase 3: 통합 검증 + QA 루프
├── 04_woody_answers.md              # Phase 4: 확인 답변
├── 05_builder_final_spec.md         # Phase 5: 최종 기획서
├── 06_verification_luna.md          # Phase 5.5: 루나 자체 검증
├── 06_verification_codechecker.md   # Phase 5.5: 코드체커 자체 검증
└── 06_verification_guardian.md      # Phase 5.5: 가디언 자체 검증
```
