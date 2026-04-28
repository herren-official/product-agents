---
name: b2b-backend-design-orchestrator
description: 개발 설계 파이프라인을 조율하는 오케스트레이터. "설계해줘", "TASK 분해", "구현 설계", "작업 설계" 요청 시 트리거. 1차 하네스(기획 분석) 완료 후 실행한다.
---

# 개발 설계 오케스트레이터 (Design Orchestrator)

## 파이프라인 개요

```
Phase D-0:   컨텍스트 확인 (1차 하네스 산출물 존재 검증)
Phase D-1:   아키(아키텍처 설계) → 10_architect_design.md
             └ design-validation 자동 검증
Phase D-1.5: Woody님 중간 피드백 (아키 산출물)
Phase D-1.6: 센티넬(시스템 엣지케이스) → 10-1_edge_case_system.md
             └ LOOP: 아키 재실행 가능
Phase D-1.7: Decision Gate (R-XX 처리 표준 검증) ← v3 신설
             └ 차단 R-XX 잔존 시 D-2 진입 거부 (decision-gate.md 참조)
Phase D-2:   태스커(TASK 분해 골격) → 11_tasker_tasks.md + task/TASK-XX.md
Phase D-2.5: Woody님 TASK 골격 리뷰 → 12_woody_review.md
Phase D-3:   디테일러 병렬 실행 (마일스톤 단위, 구현 명세 고도화)
Phase D-3.5: 검증 루프 (코드체커 팩트 + 위버 메타 정합 병렬)
             └ 반복 승격·자동 에스컬레이션, 최대 10회
Phase D-4:   Woody님 최종 승인
Phase D-5:   TASK 패키지 확정
```

**2차 하네스 검증자 매트릭스**:
- **설계 검증**: 센티넬 (아키 산출물 + 시스템 엣지케이스)
- **디테일 검증**: **코드체커 + 위버 병렬** (팩트 + 메타 정합)

## 공통 규칙

- 에이전트 spawn 설정: `model: "opus"`, `mode: "bypassPermissions"`
- 모든 경로는 절대경로 사용
- 산출물 Write 전 반드시 Read (Write 도구 제약)

### 실행 순서 규칙

| Phase | 에이전트 | run_in_background | 선행 조건 |
|-------|---------|------------------|----------|
| D-1 | 아키 | **false** | Phase D-0 완료 |
| D-2 | 태스커 | **false** | 아키 산출물 존재 확인 |
| D-3 | Woody 승인 | - | 태스커 산출물 존재 확인 |
| D-4 | (오케스트레이터) | - | Woody 승인 |

## Phase D-0: 컨텍스트 확인

### 선행 산출물 검증
1. 작업 디렉토리에서 1차 하네스 산출물 존재 확인:
   - `05_builder_final_spec.md` — **필수** (없으면 중단, 1차 하네스 먼저 실행 안내)
   - `02_codechecker_feasibility.md` — **필수**
   - `module_context.md` — **필수**
   - `06_verification_*.md` — 선택
2. 각 파일을 Read로 첫 10줄 읽어 유효성 확인 (5줄 이상, ## 헤딩 존재)

### 브랜치 확인
`05_builder_final_spec.md`에서 분석 브랜치를 추출하여 현재 브랜치와 일치하는지 확인.

### 작업 디렉토리 결정
1차 하네스와 동일한 `_workspace/{year}/{quarter}/{epic}/` 디렉토리를 사용한다.

## Phase D-1: 아키텍처 설계

```
Agent(
  name: "아키",
  description: "아키텍처 설계",
  model: "opus",
  mode: "bypassPermissions",
  subagent_type: "architect",
  run_in_background: false,
  prompt: "최종 스펙을 기반으로 아키텍처를 설계하라.
           에이전트 정의: {절대경로}/.claude/agents/architect.md
           스킬: {절대경로}/.claude/skills/architecture-design/SKILL.md
           입력: {작업디렉토리}/05_builder_final_spec.md
                 {작업디렉토리}/02_codechecker_feasibility.md
                 {작업디렉토리}/01-1_owl_research.md (있는 경우)
           module_context.md: {작업디렉토리}/module_context.md
           이전 설계 문서: {이전 설계 경로} (사용자 제공 시)
           분석 브랜치: {브랜치명}
           산출물 경로: {작업디렉토리}/10_architect_design.md
           프로젝트 루트: {절대경로}"
)
```

### 산출물 검증
1. `10_architect_design.md` 파일 존재 확인
2. 5줄 이상, `##` 헤딩 3개 이상
3. `\\n` 리터럴 → 실제 줄바꿈 치환
4. **design-validation 스킬 실행** — DB 네이밍 + 설계 정합성 통합 검증:
   ```
   Agent(
     name: "설계 검증",
     description: "설계 산출물 검증",
     model: "opus",
     mode: "bypassPermissions",
     run_in_background: false,
     prompt: "설계 산출물을 검증하라.
              스킬: {절대경로}/.claude/skills/design-validation/SKILL.md
              입력: {산출물 경로}"
   )
   ```
   - Critical/Major 발견 시 아키에게 수정 요청 후 재검증
   - Minor만 있으면 Phase D-1.5로 진행 (Woody님 판단)

## Phase D-1.5: Woody님 중간 피드백 (아키 → 태스커 전)

> 아키 산출물이 완성되면 태스커 실행 전에 Woody님 피드백을 받는다.
> 설계 3번 반복(V1→V2→V3)을 방지하기 위한 중간 검증 단계.

아키 산출물을 Woody님에게 제시:

```
아키텍처 설계가 완료되었습니다.

[설계 요약]
- 모듈 구성: {목록}
- 신규 테이블: {N}종
- 핵심 결정: {top 5}

확인 포인트:
1. 모듈별 책임 분리가 적절한가?
2. DB 구조가 기존 테이블과 정합한가?
3. 외부 연동 스펙이 누락 없는가?

승인하시면 태스커(TASK 분해)를 실행합니다.
수정이 필요하면 말씀해주세요.
```

**피드백 처리:**
- 승인 → Phase D-1.6
- 부분 수정 → 아키에게 수정 사항 전달 후 재실행
- 전면 재설계 → Phase D-1부터 재실행

## Phase D-1.6: 시스템 엣지케이스 분석 (센티넬)

> 아키 산출물에 대해 시스템 엣지케이스를 도출하고, 설계 보강이 필요한지 판단한다.
> 가디언이 1차 하네스에서 정책 엣지케이스를 잡는 것과 대칭 구조.

```
Agent(
  name: "센티넬",
  description: "시스템 엣지케이스 분석 + 설계 검증",
  model: "opus",
  mode: "bypassPermissions",
  run_in_background: false,
  prompt: "시스템 엣지케이스를 도출하고 설계를 검증하라.
           에이전트 정의: {절대경로}/.claude/agents/sentinel.md
           스킬: {절대경로}/.claude/skills/edge-case-system/SKILL.md
                 {절대경로}/.claude/skills/design-validation/SKILL.md
           입력: {작업디렉토리}/10_architect_design.md
                 {작업디렉토리}/03-1_edge_case_policy.md (있는 경우)
           산출물: {작업디렉토리}/10-1_edge_case_system.md
           프로젝트 루트: {절대경로}"
)
```

### 센티넬 판단 처리

```
센티넬 결과 수신
  ├── PASS → Phase D-1.7 (Decision Gate)로 진행
  │   (엣지케이스 목록은 디테일러 입력으로 전달)
  ├── LOOP → 아키에게 수정 사항 전달 후 Phase D-1 재실행
  │   → 아키 재실행 후 센티넬 재검증 (Loop)
  └── ESCALATE → Woody님 QnA
      → 답변 반영 후 센티넬 재검증
```

## Phase D-1.7: Decision Gate (v3 신설 — 2026-04-26)

> 센티넬이 식별한 R-XX(잔여 리스크)가 **모두 처리 표준을 통과했는지** 검증.
> 차단 항목 1건 이상 → **D-2(태스커) 진입 금지**.
>
> 본 Phase는 `.claude/docs/decision-gate.md` 표준에 정의된 3단계(차단 여부·해결 액션·결정 양식)를 강제한다.
> 도입 배경: 2026-04-26 R-08(이미지 업로드) 사례 — "리서치 필요"로만 명시된 Critical 리스크가 차단 처리되지 않은 채 디테일러 진입 직전까지 묵살된 사례 발생.

### 검증 항목 (자동화)

```python
# 의사코드
def decision_gate_phase_d_1_7(architect_design_md):
    risks = parse_risks_from_section_10(architect_design_md)  # R-01 ~ R-XX
    
    # 1. R-XX 표준 포맷 검증
    for r in risks:
        assert r.blocking is not None, f"R-{r.id} 차단 여부 미명시"
        assert r.action and is_specific(r.action), f"R-{r.id} 해결 액션 모호"
        assert r.owner is not None, f"R-{r.id} 담당자 미명시"
        assert r.deadline is not None, f"R-{r.id} 기한 미명시"
        assert r.severity in ["Critical", "Major", "Minor"]
        assert r.status in ["OPEN", "IN_PROGRESS", "RESOLVED", "DEFERRED"]

    # 2. 운영 전제 매트릭스(9.X) 등록 검증
    matrix_entries = parse_section_9x_operational_premise(architect_design_md)
    for entry in matrix_entries:
        if entry.has_unknowns():  # ❓ 항목
            assert any(r.references(entry) for r in risks), \
                f"매트릭스 ❓ '{entry.system}'이 R-XX로 등록 안 됨"

    # 3. 차단 미해결 검증
    blocking_open = [r for r in risks 
                     if r.blocking and r.status not in ["RESOLVED", "DEFERRED"]]
    if blocking_open:
        return REJECT(f"차단 R-XX {len(blocking_open)}건 미해결")
    
    return PASS
```

### 처리 결과

```
Decision Gate 결과
  ├── PASS → Phase D-2(태스커) 진입
  │   (RESOLVED 항목의 DECISION-XX.md 산출물은 디테일러 입력으로 함께 전달)
  ├── REJECT (차단 R-XX 미해결) →
  │   ├─ 해결 액션이 외부 의존(영업·기획)이면 → Woody님 ESCALATE
  │   ├─ 해결 액션이 내부 작업이면 → 해당 에이전트(올빼미·코드체커 등) 실행 후 재검증
  │   └─ 해결 양식 누락이면 → 메인이 직접 DECISION-XX.md 작성 유도
  └── REJECT (포맷 미준수) → 아키에게 R-XX 표준 포맷 재작성 지시 → 센티넬 재검증
```

### 외부 의존 별도 강조

설계서 섹션 9.X **외부 의존 운영 전제 매트릭스**의 ❓ 항목은 **자동으로 R-XX 차단 사유**로 간주.
- 인포뱅크 dev 계정 ❓ → 차단
- LG CNS 톡드림 MMS API 가이드 ❓ → 차단 (V2 시점까지 DEFERRED 가능)

### 참조

- 표준 문서: `.claude/docs/decision-gate.md`
- 센티넬 스킬: `.claude/skills/edge-case-system/SKILL.md` (Step 4 Decision Gate 검증)
- 위버 스킬: `.claude/skills/detail-weaver-validation/SKILL.md` (룰 R7 — 차단 R-XX 영향 범위 LOOP)

## Phase D-2: TASK 분해 (태스커 — 골격 생성)

> 태스커는 **골격만** 작성. 구현 코드/테스트 코드는 D-3에서 디테일러가 담당.

```
Agent(
  name: "태스커",
  description: "TASK 분해 (골격)",
  model: "opus",
  mode: "bypassPermissions",
  run_in_background: false,
  prompt: "아키텍처 설계를 독립적 TASK로 분해하라. 골격만 작성.
           에이전트 정의: {절대경로}/.claude/agents/task-decomposer.md
           스킬: {절대경로}/.claude/skills/task-decomposition/SKILL.md
           입력: {작업디렉토리}/10_architect_design.md
                 {작업디렉토리}/05_builder_final_spec.md
                 {작업디렉토리}/02_codechecker_feasibility.md (있는 경우)
           컨벤션: {절대경로}/.docs/conventions/developer-guide/
           산출물: {작업디렉토리}/11_tasker_tasks.md (요약)
                   {작업디렉토리}/task/TASK-XX-키워드.md (골격 문서)
           에픽 브랜치명: {에픽 브랜치}
           프로젝트 루트: {절대경로}"
)
```

### 산출물 검증
1. `11_tasker_tasks.md` 파일 존재 확인
2. `task/` 디렉토리 내 TASK-01 이상 존재 확인
3. 마일스톤 순서 준수 확인 (설계서 M1→M2→... 순서와 일치)
4. 각 TASK 문서에 목적/구현 범위/관련 정책/완료 조건 포함 확인

## Phase D-2.5: Woody님 TASK 골격 리뷰

태스커 산출물을 Woody님에게 제시:

```
TASK 분해가 완료되었습니다 (골격 수준).

[TASK 분해 결과]
- 총 TASK: N개
- 마일스톤 순서: M1 → M2 → ... → MN

TASK 목록:
{TASK 요약 테이블}

의존 관계:
{다이어그램}

리뷰 파일: {작업디렉토리}/task/12_woody_review.md
수정 사항을 작성해주시면 반영 후 TASK 고도화(디테일러)를 진행합니다.
```

**피드백 처리:**
- 승인 → Phase D-3 (전체 또는 마일스톤 단위)
- TASK 수정 요청 → 태스커 부분 재실행
- 골격 구조 변경 → Phase D-2 재실행

## Phase D-3: TASK 고도화 (디테일러 — 병렬 실행)

> TASK별 디테일러를 **마일스톤 단위로 병렬 spawn**.
> 각 디테일러는 TASK 1개에 집중하여 코드베이스 심층 탐색 + 구현 코드 + 테스트 코드 작성.

### 마일스톤 단위 병렬 실행

```python
# 마일스톤별로 TASK를 그룹핑하여 순차 실행
for milestone in milestones:
    # 같은 마일스톤 내 TASK는 병렬 실행
    tasks_in_milestone = get_tasks(milestone)
    
    for task in tasks_in_milestone:
        Agent(
          name: f"디테일러-{task.id}",
          description: f"TASK {task.id} 고도화",
          model: "opus",
          mode: "bypassPermissions",
          run_in_background: true,  # 병렬
          prompt: f"TASK 골격을 구현 명세서 수준으로 고도화하라.
                    에이전트 정의: {{절대경로}}/.claude/agents/task-detailer.md
                    스킬: {{절대경로}}/.claude/skills/task-detail/SKILL.md
                    TASK 골격: {{작업디렉토리}}/task/{task.file}
                    설계서: {{작업디렉토리}}/10_architect_design.md
                    기획서: {{작업디렉토리}}/05_builder_final_spec.md
                    컨벤션: {{절대경로}}/.docs/conventions/developer-guide/
                    프로젝트 루트: {{절대경로}}"
        )
    
    # 마일스톤 내 모든 디테일러 완료 대기
    wait_all(tasks_in_milestone)
    
    # 산출물 검증
    validate_milestone(milestone)
    
    # Woody님 마일스톤 검수 (선택)
    # 다음 마일스톤으로 진행하거나, 수정 요청 시 해당 TASK 디테일러 재실행
```

### 산출물 기본 검증 (마일스톤별, Phase D-3.5 진입 전)
1. 각 TASK 문서에 구현 코드 (복붙 수준) 포함 확인
2. 테스트 코드 (정상 2개 + 엣지 2개 + 유저 시나리오 1개) 포함 확인
3. 기존 코드 참조 경로 (절대경로) 명시 확인
4. DB 네이밍 자동 Grep 검증 (regdate, shopno, _datetime)
5. 설계서 교차 검증 결과 포함 확인

## Phase D-3.5: 검증 루프 (코드체커 + 위버 병렬 + 반복 승격)

> 디테일러 산출물의 **팩트 정확성(코드체커)**과 **메타 정합성(위버)**을 병렬로 교차 검증.
> 둘 다 PASS해야 해당 TASK 확정. 한 쪽이라도 Critical/Major 발견 시 디테일러 재실행.

### 루프 정책 (v2)

- **종료 조건**: `Critical == 0 && Major == 0` (Minor는 메인 패치로 흡수)
- **상한**: **최대 10회** (느슨). 상한 도달 전이라도 아래 조기 종료 조건 적용
- **동일 이슈 3회 이상 반복 지적** → **Woody님 QnA 에스컬레이션** (구조적 문제로 판단, 디테일러가 해결 불가)
- **반복 지적 승격**: 같은 항목이 루프 2회 지적되면 심각도 1단계 상향 (Minor → Major → Critical)
- **Minor만 남은 경우** → 오케스트레이터가 직접 Edit 패치로 수렴 (재실행 불필요)

### 병렬 실행 구조

```python
for task in tasks_in_milestone:  # 마일스톤 내 TASK 각자
    loop_count = 0
    repeated_issues = {}  # 이슈 ID → 지적 횟수

    while loop_count < 10:
        loop_count += 1

        # 병렬 spawn: 코드체커 + 위버
        code_check_result = Agent(
          name: f"코드체커-{task.id}-loop{loop_count}",
          subagent_type: "code-feasibility-checker",
          model: "opus",
          run_in_background: true,
          prompt: f"TASK-{task.id} 문서가 실제 코드베이스와 정합하는지 검증.
                    팩트: 경로·숫자·hallucination·컨벤션.
                    대상: {task.file}
                    참조: 설계서, 선행 TASK 산출물, 실제 모듈 경로"
        )

        weaver_result = Agent(
          name: f"위버-{task.id}-loop{loop_count}",
          subagent_type: "detail-weaver",
          model: "opus",
          run_in_background: true,
          prompt: f"TASK-{task.id} 구현 명세의 교차 TASK 정합성 검증.
                    메타: 선행/후속/형제 TASK 간 심볼·범위·설계서 섹션 매핑.
                    스킬: {{절대경로}}/.claude/skills/detail-weaver-validation/SKILL.md
                    대상: {task.file}
                    참조: 설계서, 선행 TASK, 후속 TASK, 11_tasker_tasks.md"
        )

        wait_all([code_check_result, weaver_result])

        # 두 결과 통합
        critical = code_check_result.critical + weaver_result.critical
        major = code_check_result.major + weaver_result.major
        minor = code_check_result.minor + weaver_result.minor

        # 반복 지적 승격 규칙 적용
        for issue in all_issues:
            repeated_issues[issue.id] = repeated_issues.get(issue.id, 0) + 1
            if repeated_issues[issue.id] >= 3:
                # 구조적 문제 → Woody님 에스컬레이션
                return ESCALATE(issue)
            if repeated_issues[issue.id] >= 2:
                issue.severity = escalate_severity(issue.severity)

        if critical == 0 and major == 0:
            # Minor만 남은 경우 → 오케스트레이터 직접 패치
            orchestrator_patch_minor_issues(minor)
            return PASS

        # Critical/Major 존재 → 디테일러 재실행 (코드체커+위버 피드백 주입)
        Agent(
          name: f"디테일러-{task.id}-loop{loop_count + 1}",
          subagent_type: "task-detailer",
          prompt: f"피드백 반영 재작성.
                    이전 산출물: {task.file}
                    코드체커 피드백: {code_check_result}
                    위버 피드백: {weaver_result}"
        )

    # 10회 도달 시 강제 종료 + 잔여 이슈 기록
    return ESCALATE_MAX_LOOPS
```

### 에스컬레이션 처리

- **ESCALATE(issue)**: Woody님에게 구체적 이슈 + 디테일러가 해결 못한 이유 제시 → 수동 판단
- **ESCALATE_MAX_LOOPS**: 10회 도달 → 잔여 이슈 "이후 체크 항목" 파일로 기록하고 다음 TASK/마일스톤으로 진행

### 왜 코드체커 + 위버 둘 다?

| 관점 | 코드체커 | 위버 |
|------|:-------:|:----:|
| 팩트(경로/숫자/존재) | ✅ 전문 | 보조 |
| 메타 정합(교차 TASK/범위/설계서 매핑) | 사각지대 | ✅ 전문 |

**상보적 관계**. 한 쪽만 돌리면 다른 쪽 영역의 결함을 놓친다.

## Phase D-4: Woody님 최종 승인

고도화 완료된 TASK 문서를 Woody님에게 제시:

```
TASK 고도화가 완료되었습니다.

[결과]
- 고도화 완료: N개 TASK
- 구현 코드: 전체 작성 (복붙 가능)
- 테스트 코드: TASK당 5개 이상
- 설계서 교차 검증: 완료

리뷰 파일: {작업디렉토리}/task/12_woody_review.md
수정 사항을 작성해주시면 반영합니다.
```

**피드백 처리:**
- 승인 → Phase D-5
- TASK 수정 요청 → 해당 TASK 디테일러 재실행
- 전면 재설계 요청 → Phase D-1부터 재실행

## Phase D-5: TASK 패키지 확정

1. `{작업디렉토리}/12_woody_approval.md`에 승인 내용 저장
2. 최종 안내:

```
설계 파이프라인 완료.

산출물:
- 아키텍처 설계: {작업디렉토리}/10_architect_design.md
- TASK 요약: {작업디렉토리}/11_tasker_tasks.md
- TASK 구현 명세: {작업디렉토리}/task/TASK-XX-키워드.md (고도화 완료)
- 승인 기록: {작업디렉토리}/12_woody_approval.md

다음 단계:
- 개별 TASK 구현: "TASK-01 구현해줘" (dev-execute 스킬)
- 전체 병렬 구현: "전체 구현 시작" (OMC team 활용)
```

## 산출물 디렉토리 (2차 하네스 추가분)

```
{작업디렉토리}/
├── (1차 하네스 산출물 — 기존)
├── 10_architect_design.md       # Phase D-1
├── 11_tasker_tasks.md           # Phase D-2
└── 12_woody_approval.md         # Phase D-3
```
