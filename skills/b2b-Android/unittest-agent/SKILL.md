---
name: b2b-android-unittest-agent
description: 병렬 UnitTest 자동 생성 파이프라인 (Planner→Scaffold→Generator[병렬]→Healer). "병렬 테스트", "parallel unittest", "테스트 병렬 생성" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Task
user-invocable: true
---

# Parallel UnitTest Pipeline

ViewModel 단위 테스트를 **병렬로** 생성하는 파이프라인입니다.

## 📚 관련 문서

- [PLANNER.md](./PLANNER.md) - 함수 흐름 분석 + 그룹화
- [SCAFFOLD.md](./SCAFFOLD.md) - 테스트 파일 초기 세팅
- [GENERATOR.md](./GENERATOR.md) - 병렬 테스트 코드 생성
- [HEALER.md](./HEALER.md) - 랄프루프 기반 수정

---

## Phase Isolation 아키텍처 (컨텍스트 격리)

⛔ **각 Phase는 독립적인 Task 서브에이전트에서 실행됩니다.**
⛔ **메인 오케스트레이터는 체크포인트 파일만 읽고/판단/위임합니다.**
⛔ **이 패턴으로 컨텍스트 컴팩트 없이 전체 파이프라인을 완료할 수 있습니다.**

```
Main Orchestrator (경량 컨텍스트 ~2K tokens)
│
├── Step 0: 사전 확인 (기존 테스트 + 커버리지)
│   → 메인에서 직접 실행 (Glob + Bash 2줄)
│
├── Step 1: Task(Phase 1: Planner)         ← 독립 컨텍스트
│   → phase1-plan.json 저장
│   → 메인은 JSON 요약만 읽음
│
├── Step 2: Task(Phase 1.5: Scaffold)      ← 독립 컨텍스트
│   → 테스트 파일 + JSON fixture 생성
│   → 메인은 파일 존재만 확인
│
├── Step 3: Task(Phase 2: Workers)         ← 병렬 독립 컨텍스트
│   → 그룹별 테스트 코드 생성 + 머지
│   → 메인은 테스트 파일 완성만 확인
│
├── Step 4: Skill(Phase 3: RalphLoop)      ← 별도 스킬 세션
│   → BUILD SUCCESSFUL까지 반복
│
├── Step 5: Task(Phase 4: Coverage)        ← 독립 컨텍스트
│   → phase4-coverage.json 저장
│   → 메인은 목표 달성 여부만 읽음
│
└── Step 6: Task(Phase 5: Loop)            ← 독립 컨텍스트 (필요 시)
    → 보충 테스트 + RalphLoop + 재측정
    → 최대 3회 반복
```

> **핵심**: 각 서브에이전트의 heavy work (ViewModel 읽기, 코드 생성, 빌드 로그 파싱)는
> 해당 서브에이전트 컨텍스트에만 존재. 메인 오케스트레이터에는 체크포인트 JSON 요약만 남음.

---

## 체크포인트 시스템 (Phase 간 통신)

Phase Isolation에서 체크포인트 파일은 **Phase 간 유일한 통신 수단**입니다.

### 디렉토리 구조

```
.unittest-pipeline/{ViewModel명}/
├── pipeline-status.json    ← 파이프라인 전체 상태 (현재 Phase, 타임스탬프)
├── phase1-plan.json        ← 2-Pass 분석 결과 (그룹, 의존성, 콜백 체인)
├── phase2-progress.json    ← 그룹별 생성 완료 상태
├── phase3-healer.log       ← 에러 수정 이력 (참고용)
├── phase4-coverage.json    ← JaCoCo 결과
└── phase5-iterations.json  ← 보충 루프 이력
```

### pipeline-status.json 형식

```json
{
  "viewModel": "SaleViewModel",
  "testClassName": "SaleViewModelTest",
  "testFilePath": "app/src/test/java/.../SaleViewModelTest.kt",
  "startedAt": "2026-02-10T10:00:00",
  "currentPhase": "phase2",
  "completedPhases": ["phase1", "phase1.5"],
  "lastUpdatedAt": "2026-02-10T10:15:00"
}
```

### 체크포인트 저장 타이밍

| Phase | 저장 시점 | 저장 파일 |
|-------|----------|----------|
| Phase 1 완료 | 분석 결과 + 그룹 목록 | `phase1-plan.json` + `pipeline-status.json` |
| Phase 1.5 완료 | 스캐폴드 생성 확인 | `pipeline-status.json` 업데이트 |
| Phase 2 진행 중 | **각 그룹 완료마다** | `phase2-progress.json` (그룹별 상태) |
| Phase 3 완료 | 빌드 성공 확인 | `pipeline-status.json` 업데이트 |
| Phase 4 완료 | 커버리지 결과 | `phase4-coverage.json` + `pipeline-status.json` |
| Phase 5 반복 | 각 iteration 완료 | `phase5-iterations.json` 업데이트 |

---

## 커버리지 목표치

| 메트릭 | 최소 목표 | 이상적 목표 |
|--------|----------|-----------|
| LINE | 80% | 90%+ |
| BRANCH | 40% | 55%+ |
| METHOD | 85% | 92%+ |

⛔ **Phase 4에서 최소 목표 미달 시 Phase 5(보충 루프)가 자동 실행됩니다.**

---

## Main Orchestrator Flow

### Step 0: 초기화 + 사전 확인

```
⛔ 메인 오케스트레이터가 직접 실행 (서브에이전트 X)

1. 체크포인트 존재 확인
   → Glob: .unittest-pipeline/{ViewModel명}/pipeline-status.json
   → 존재하면: Read → completedPhases 확인 → 미완료 Phase부터 재개
   → 없으면: mkdir -p .unittest-pipeline/{ViewModel명}/

2. 기존 테스트 확인
   → Glob: **/test/**/{ViewModel명}*Test*.kt
   → 있으면: hasExistingTest = true
   → 없으면: hasExistingTest = false

3. 기존 커버리지 확인 (hasExistingTest == true일 때만)
   → Bash: ./gradlew :app:testDevDebugUnitTest --tests '*{ViewModel명}*Test*' --rerun --no-configuration-cache
   → Bash: ./gradlew :app:jacocoViewModelTestReport --no-configuration-cache
   → Grep: "{ViewModel명}" app/build/reports/jacoco/viewmodel.csv
   → currentCoverage 요약 생성

4. ViewModel 경로 확인
   → Glob: **/ui/**/{ViewModel명}.kt
   → viewModelPath 저장
```

### Step 1~6: Phase별 서브에이전트 실행

> 아래 각 Phase 섹션의 "Subagent Invocation" 참조

---

## Phase 1: Planning (Task Subagent)

### Subagent Invocation

```
Task(
  subagent_type="general-purpose",
  model="opus",
  prompt="""
  [역할] ViewModel 단위 테스트 Planner
  [지침 파일] .claude/skills/unittest-agent/PLANNER.md 를 읽고 모든 규칙을 따를 것
  [컨벤션 파일] .docs/conventions/viewmodel-test-convention.md 를 읽고 테스트 규칙을 따를 것

  [대상 ViewModel]: {ViewModel명}
  [ViewModel 경로]: {viewModelPath}
  [기존 테스트 존재]: {hasExistingTest}
  [기존 커버리지]: {currentCoverage 요약 또는 "없음"}

  [필수 출력]:
  1. .unittest-pipeline/{ViewModel명}/phase1-plan.json 에 분석 결과 저장
  2. .unittest-pipeline/{ViewModel명}/pipeline-status.json 에 파이프라인 상태 저장
     → currentPhase: "phase1.5", completedPhases: ["phase1"]
  """
)
```

### Orchestrator Readback

```
1. Read: .unittest-pipeline/{ViewModel명}/phase1-plan.json
   → groups 목록, testCases 수, apiEndpoints 확인
2. Read: .unittest-pipeline/{ViewModel명}/pipeline-status.json
   → currentPhase 확인

3. 다음 Phase 결정:
   → hasExistingTest == false → Phase 1.5
   → hasExistingTest == true → Phase 2
```

### 완료 보고

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Phase 1: Planning 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 분석 결과:
- ViewModel: {ViewModel명}
- 그룹 수: {N}개 (병렬: {X}개, 순차: {Y}개)
- 총 테스트 케이스: {Z}개
- API Endpoints: {E}개

💾 체크포인트: .unittest-pipeline/{ViewModel명}/phase1-plan.json
🔜 다음: Phase 1.5 (Scaffold) 또는 Phase 2 (Generator)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Phase 1.5: Scaffold + JSON Fixture (Task Subagent)

**조건**: `hasExistingTest == false`일 때만 실행

### Subagent Invocation

```
Task(
  subagent_type="general-purpose",
  model="opus",
  prompt="""
  [역할] 테스트 Scaffold + JSON Fixture 생성기
  [지침 파일] .claude/skills/unittest-agent/SCAFFOLD.md 를 읽고 모든 규칙을 따를 것
  [컨벤션 파일] .docs/conventions/viewmodel-test-convention.md 를 읽고 테스트 규칙을 따를 것

  [분석 결과] .unittest-pipeline/{ViewModel명}/phase1-plan.json 를 읽을 것
  [대상 ViewModel]: {ViewModel명}
  [ViewModel 경로]: {viewModelPath}

  [필수 작업]:
  1. PLANNER의 apiEndpoints 기반 JSON fixture 파일 생성
     → 위치: network/src/testFixtures/resources/{domain}/
     → 기존 fixture 중복 확인: Glob으로 먼저 검색
  2. 테스트 클래스 Scaffold 생성 (BaseViewModelTest 상속, MockWebServer 패턴)
     → 위치: app/src/test/java/com/gongnailshop/herren_dell1/gongnailshop/viewmodel/{패키지경로}/{ViewModel명}Test.kt

  [필수 출력]:
  1. 테스트 파일 생성 완료
  2. JSON fixture 파일 생성 완료 (필요한 것만)
  3. .unittest-pipeline/{ViewModel명}/pipeline-status.json 업데이트
     → currentPhase: "phase2", completedPhases: ["phase1", "phase1.5"]
  """
)
```

### Orchestrator Readback

```
1. Glob: **/test/**/{ViewModel명}*Test*.kt → 테스트 파일 존재 확인
2. Read: .unittest-pipeline/{ViewModel명}/pipeline-status.json
   → currentPhase == "phase2" 확인
3. → Phase 2로 진행
```

---

## Phase 2: Generator (병렬 Task Subagents)

### Subagent Invocation

phase1-plan.json에서 groups를 읽고, 각 그룹별로 병렬 Worker를 스폰합니다.

```
# 먼저 phase1-plan.json에서 groups 읽기
Read: .unittest-pipeline/{ViewModel명}/phase1-plan.json → groups 배열

# 각 그룹별 병렬 Worker 스폰 (하나의 메시지에서 동시 호출)
Task(
  subagent_type="general-purpose",
  model="opus",
  prompt="""
  [역할] 테스트 코드 생성 Worker
  [지침 파일] .claude/skills/unittest-agent/GENERATOR.md 를 읽고 모든 규칙을 따를 것
  [컨벤션 파일] .docs/conventions/viewmodel-test-convention.md 를 읽고 테스트 규칙을 따를 것

  [담당 그룹]: {그룹 ID}
  [그룹 정보]: {그룹 JSON - functions, testCases, sharedState, apiEndpoints}
  [ViewModel 경로]: {viewModelPath}
  [테스트 파일 경로]: {testFilePath}
  [분석 결과]: .unittest-pipeline/{ViewModel명}/phase1-plan.json 참조

  [필수 출력]:
  코드 블록으로 @Nested inner class 코드를 출력할 것.
  테스트 파일에 직접 쓰지 말고 코드만 반환.
  """
)
// ... 그룹 수만큼 병렬 호출
```

### Merge Process (오케스트레이터가 직접 실행)

```
1. 모든 Worker 결과 수집
2. 기존 테스트 파일 Read
3. 각 Worker의 @Nested 클래스를 테스트 파일에 순서대로 Edit으로 삽입
4. 중복 import 정리
5. phase2-progress.json 업데이트
   → { "totalGroups": N, "completedGroups": [...], "pendingGroups": [] }
6. pipeline-status.json 업데이트
   → currentPhase: "phase3", completedPhases: ["phase1", "phase1.5", "phase2"]
```

### Orchestrator Readback

```
1. 테스트 파일에 모든 @Nested 클래스가 삽입되었는지 확인
2. pipeline-status.json 업데이트 확인
3. → Phase 3로 진행
```

---

## Phase 3: Healer + RalphLoop (별도 스킬 세션)

⛔ **반드시 `/ralph-loop:ralph-loop` 스킬을 호출하여 실행합니다.**
⛔ **수동 빌드→에러수정→재빌드 반복 절대 금지.**

### RalphLoop Invocation

```
Skill(
  skill="ralph-loop:ralph-loop",
  args="테스트 파일 {ViewModel명}Test.kt 경로 {테스트파일경로} 작업 1단계 gradlew app testDevDebugUnitTest tests {ViewModel명}Test 실행 2단계 BUILD SUCCESSFUL이면 HEALER_COMPLETE 출력 3단계 BUILD FAILED이면 에러 분석 후 테스트 파일만 수정 4단계 수정 후 1단계 반복 수정가능 import추가 타입수정 파라미터추가 assertion값조정 Mock설정수정 수정금지 ViewModel소스코드 BaseViewModelTest 테스트케이스삭제 --max-iterations 30 --completion-promise HEALER_COMPLETE"
)
```

**주의**: args에 마크다운 특수문자(`##`, `*`, `\n`, 줄바꿈) 포함 금지 → 쉘 연산자로 해석됨.

### Orchestrator Readback

```
1. RalphLoop 완료 확인 (HEALER_COMPLETE 출력)
2. pipeline-status.json 업데이트
   → currentPhase: "phase4", completedPhases: [..., "phase3"]
3. → Phase 4로 진행
```

---

## Phase 4: Coverage Measurement (Task Subagent)

### Subagent Invocation

```
Task(
  subagent_type="general-purpose",
  model="sonnet",
  prompt="""
  [역할] JaCoCo 커버리지 측정 및 분석
  [대상 ViewModel]: {ViewModel명}
  [테스트 파일]: {testFilePath}

  [필수 작업]:
  1. 테스트 실행 + JaCoCo 리포트 생성
     → Bash: ./gradlew :app:testDevDebugUnitTest --tests '*{ViewModel명}Test*' --rerun --no-configuration-cache
     → Bash: ./gradlew :app:jacocoViewModelTestReport --no-configuration-cache

  2. 커버리지 CSV 파싱
     → Grep: "{ViewModel명}" app/build/reports/jacoco/viewmodel.csv
     → CSV: GROUP,PACKAGE,CLASS,INST_MISSED,INST_COVERED,BR_MISSED,BR_COVERED,LINE_MISSED,LINE_COVERED,CPLX_MISSED,CPLX_COVERED,METH_MISSED,METH_COVERED
     → 계산: covered / (missed + covered) * 100

  3. 목표 달성 여부 판단
     → LINE >= 80%, BRANCH >= 40%, METHOD >= 85%

  4. 미커버 메서드 분석 (목표 미달 시)
     → HTML 리포트: app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.html
     → 미커버 메서드 목록 + 원인 분류

  [필수 출력]:
  1. .unittest-pipeline/{ViewModel명}/phase4-coverage.json 에 결과 저장:
     {
       "line": { "covered": N, "missed": M, "percentage": X },
       "branch": { "covered": N, "missed": M, "percentage": Y },
       "method": { "covered": N, "missed": M, "percentage": Z },
       "meetsTarget": true/false,
       "uncoveredMethods": [ { "name": "...", "lineMissed": N, "reason": "..." } ]
     }
  2. .unittest-pipeline/{ViewModel명}/pipeline-status.json 업데이트
     → currentPhase: "phase5" 또는 "complete"
  """
)
```

### Orchestrator Readback + Decision

```
1. Read: .unittest-pipeline/{ViewModel명}/phase4-coverage.json
   → meetsTarget 확인

2. 판단:
   → meetsTarget == true → 파이프라인 완료! 최종 보고 출력
   → meetsTarget == false → Phase 5로 진행

3. 커버리지 보고:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Phase 4: Coverage Measurement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

JaCoCo 커버리지:
- LINE:   {X}% (목표 80%) {✅ or ❌}
- BRANCH: {Y}% (목표 40%) {✅ or ❌}
- METHOD: {Z}% (목표 85%) {✅ or ❌}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Phase 5: Coverage Improvement Loop (Task Subagent, 반복)

⛔ **Phase 4에서 커버리지 목표 미달 시 자동으로 진입합니다.**
⛔ **최대 3회 반복 후에도 미달이면 현재 상태로 완료합니다.**

### 반복 구조 (각 Iteration을 서브에이전트로 실행)

```
for iteration in 1..3:

  # 5-A + 5-B: 미커버 분석 + 보충 테스트 생성 (Task Subagent)
  Task(
    subagent_type="general-purpose",
    model="opus",
    prompt="""
    [역할] 커버리지 보충 테스트 생성기
    [지침 파일] .claude/skills/unittest-agent/GENERATOR.md 를 읽고 모든 규칙을 따를 것
    [컨벤션 파일] .docs/conventions/viewmodel-test-convention.md 를 읽고 테스트 규칙을 따를 것

    [Phase 5 Iteration]: {iteration}/3
    [대상 ViewModel]: {ViewModel명}
    [ViewModel 경로]: {viewModelPath}
    [테스트 파일]: {testFilePath}
    [커버리지 결과]: .unittest-pipeline/{ViewModel명}/phase4-coverage.json 읽을 것

    [필수 작업]:
    1. JaCoCo .kt.html에서 라인레벨 미커버 분석
       → Grep: class="nc" path="app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.kt.html"
       → Grep: class="pc bpc" path="app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.kt.html"
    2. 미커버 블록별 rootCause + fix 분석
    3. 보충 테스트 @Nested 클래스 생성 → 테스트 파일에 추가
    4. 컴파일 확인: ./gradlew :app:compileDevDebugUnitTestKotlin

    [보충 테스트 규칙]:
    - 각 미커버 함수에 대해 최소 2개 테스트 (정상 경로 + 엣지 케이스)
    - MockWebServer 기반 데이터 설정 필수
    - 분기 조건마다 별도 테스트 케이스
    """
  )

  # 5-C: Healer (RalphLoop)
  Skill(ralph-loop) → BUILD SUCCESSFUL까지

  # 5-D: 커버리지 재측정 (Task Subagent - Phase 4와 동일)
  Task(Phase 4 동일) → phase4-coverage.json 업데이트

  # Orchestrator Decision
  Read: phase4-coverage.json
  → meetsTarget == true → 완료!
  → LINE이 이전 대비 3%p 이상 개선 → 효과 있음, 다음 iteration
  → LINE이 이전 대비 3%p 미만 개선 → 정체 감지
     → 2회 연속 정체 → 조기 종료
  → iteration == 3 → 최대 반복 도달, 현재 상태로 완료
```

### 최종 완료 보고

**목표 달성 시:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 파이프라인 완료 - 커버리지 목표 달성
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 최종 커버리지:
- LINE:   {X}% (목표 80%) ✅
- BRANCH: {Y}% (목표 40%) ✅
- METHOD: {Z}% (목표 85%) ✅

📈 커버리지 변화: LINE {시작}% → {최종}% (+{delta}%p)
🔄 보충 반복: {N}회
🧪 총 테스트: {N}개
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**목표 미달 시 (최대 반복 도달 또는 정체):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ 파이프라인 완료 - 최선 노력 달성
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 최종 커버리지:
- LINE:   {X}% (목표 80%) {✅/❌}
- BRANCH: {Y}% (목표 40%) {✅/❌}
- METHOD: {Z}% (목표 85%) {✅/❌}

📈 커버리지 변화: LINE {시작}% → {최종}% (+{delta}%p)
🔄 보충 반복: {N}회 (종료 사유: {최대반복 도달 / 커버리지 정체})
🧪 총 테스트: {N}개

🔍 달성 불가 원인:
- {함수명1}: {원인}
- {함수명2}: {원인}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 핵심 규칙

### ✅ 필수
- **Phase Isolation**: 각 Phase는 반드시 Task 서브에이전트로 실행
- Phase 간 데이터는 **체크포인트 파일**로만 전달
- 서브에이전트 프롬프트에 **지침 파일 경로** 명시 (PLANNER.md 등)
- `.docs/conventions/viewmodel-test-convention.md` 컨벤션 준수

### ⛔ 금지
- 메인 오케스트레이터에서 ViewModel 소스 코드 직접 읽기
- 메인 오케스트레이터에서 테스트 코드 직접 생성
- 메인 오케스트레이터에서 빌드 로그 전체 파싱
- 서브에이전트 없이 Phase를 메인 컨텍스트에서 직접 실행

---

## 실행 예시

```
User: "NaverPayStorePaymentViewModel 병렬 테스트 생성해줘"

→ Step 0 (메인): 기존 테스트 없음 확인, ViewModel 경로 확인
→ Phase 1 (서브에이전트): Planner → 4개 그룹 식별 → phase1-plan.json
→ 메인: plan 요약 읽기 → Phase 1.5 필요
→ Phase 1.5 (서브에이전트): Scaffold + Fixture → 테스트 파일 생성
→ 메인: 파일 존재 확인 → Phase 2 진행
→ Phase 2 (4개 병렬 서브에이전트): 그룹별 테스트 코드 생성
→ 메인: 결과 머지 → 테스트 파일 완성
→ Phase 3 (RalphLoop): BUILD SUCCESSFUL
→ Phase 4 (서브에이전트): JaCoCo → LINE 35%, BRANCH 15%, METHOD 55% → 미달
→ 메인: phase4-coverage.json 읽기 → Phase 5 진입
→ Phase 5 Iteration 1 (서브에이전트): 미커버 분석 + 보충 24개
→ Phase 5 RalphLoop → BUILD SUCCESSFUL
→ Phase 5 재측정 (서브에이전트): LINE 52%, BRANCH 28%, METHOD 72% → 달성!
→ 완료 (메인 컨텍스트: ~3K tokens 사용)
```
