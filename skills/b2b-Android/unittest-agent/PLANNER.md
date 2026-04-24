---
name: unittest-agent-planner
description: ViewModel 함수 흐름 분석 및 병렬 테스트 그룹화
allowed-tools: Read, Grep, Glob
user-invocable: false
---

# Parallel Test Planner

ViewModel의 함수 흐름을 분석하고 병렬 가능한 테스트 그룹을 식별합니다.

---

## ⚡ 분석 전략 (기존 테스트 유무 + 파일 크기 기반 분기)

```
┌─────────────────────────────────────────────────────────────────┐
│  Step -1: 기존 테스트 존재 여부 확인                               │
│  Glob: **/test/**/{ViewModel명}*Test*.kt                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  기존 테스트 있음 → 📊 JaCoCo 커버리지 사전 분석 (Pass 0)         │
│                     → JaCoCo 실행 → HTML 파싱 → 미커버 메서드 식별 │
│                     → 미커버 영역 중심으로 Pass 1~2 진행            │
│                                                                  │
│  기존 테스트 없음 → 전체 분석 (Pass 1~2 또는 싱글)                  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  ViewModel 파일 크기 확인                                        │
│  wc -l {ViewModel}.kt                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  300줄 미만 → 싱글 분석 (전체 파일 1회 읽기)                       │
│                Step 0~5 순차 실행                                 │
│                                                                  │
│  300줄 이상 → 2-Pass 분석 (선택적 읽기)                           │
│                Pass 0: 커버리지 사전 분석 (기존 테스트 있을 때)     │
│                Pass 1: 구조 스캔 (코드 본문 읽지 않음)             │
│                Pass 2: 핵심 블록만 부분 읽기                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**왜 2-Pass인가?**

- 3000줄+ ViewModel을 통째로 읽으면 컨텍스트의 대부분을 코드가 차지
- 뒷부분 코드의 분석 품질이 떨어지고, 콜백 내부 호출을 놓침
- 2-Pass로 **10~15%만 선택적으로 읽어도** 100% 분석 가능
- Planner 분석 품질 향상 → Generator 코드 정확도 향상 → **Healer 반복 횟수 감소**

**왜 JaCoCo 사전 분석인가?**

- 기존 테스트가 이미 일부 메서드를 커버하고 있으면, **이미 커버된 영역은 계획에서 제외**
- 미커버 메서드만 집중 분석 → **Generator가 보충 테스트만 생성** → 효율 극대화
- 눈대중이 아닌 **정량적 데이터 기반 계획** → 목표 달성 확률 대폭 상승

---

## Pass 0: JaCoCo 커버리지 사전 분석 (기존 테스트 있을 때만)

⛔ **기존 테스트가 있을 때만 실행합니다. 없으면 Pass 1로 바로 진행합니다.**

### 0-A. JaCoCo 리포트 실행

```bash
./gradlew :app:testDevDebugUnitTest --tests '*{ViewModel명}*Test*' --rerun --no-configuration-cache
./gradlew :app:jacocoViewModelTestReport --no-configuration-cache
```

### 0-B. CSV에서 전체 커버리지 파악

```bash
grep "{ViewModel명}" app/build/reports/jacoco/viewmodel.csv
```

### 0-C. HTML에서 메서드별 커버리지 파싱 (메서드 요약)

```bash
Read: app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.html
```

HTML 테이블에서 각 메서드의 커버리지 퍼센트를 추출.

### 0-C-2. 소스 HTML에서 라인별 커버리지 파싱 (핵심!)

⛔ **메서드 요약만으로는 부족합니다. 소스 HTML에서 정확히 어떤 라인/분기가 미커버인지 파싱합니다.**

```bash
# 소스 코드 + 커버리지 하이라이팅이 포함된 HTML 파일
# 파일명: {ViewModel명}.kt.html (메서드 요약인 {ViewModel명}.html과 다름!)

# 1) 완전 미커버 라인 추출 (빨간색)
Grep: pattern='class="nc"'
      path="app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.kt.html"
      output_mode="content"

# 2) 부분 커버 분기 추출 (노란색 + 분기 미스 수 포함)
Grep: pattern='class="pc bpc"'
      path="app/build/reports/jacoco/viewmodel/{패키지경로}/{ViewModel명}.kt.html"
      output_mode="content"
```

#### JaCoCo HTML CSS 클래스 의미

| CSS 클래스 | 의미 | 색상 | 예시 |
|-----------|------|------|------|
| `fc` | fully covered | 초록 | 정상 실행된 라인 |
| `nc` | not covered | 빨강 | 한번도 실행 안 된 라인 |
| `pc bpc` | partially covered branch | 노랑 | 일부 분기만 실행됨 |
| `fc bfc` | fully covered branch | 초록 | 모든 분기 실행됨 |

#### HTML 파싱 결과 형식

```
id="L{라인번호}" → ViewModel 소스의 실제 라인 번호
title="{N} of {M} branches missed." → 정확한 미커버 분기 수
```

파싱 결과를 `uncoveredBlocks` 로 정리:

```json
{
  "uncoveredLines": [
    { "line": 228, "code": "fun onClickItemDelete(position: Int) = deleteCategory(position)", "type": "nc" },
    { "line": 245, "code": "PRODUCT -> uiState.saleRegisterModel.productSelectList.getOrNull(position)", "type": "nc" },
    { "line": 248, "code": "val update = {", "type": "nc" }
  ],
  "partialBranches": [
    { "line": 130, "branchesMissed": 2, "branchesTotal": 4, "code": "if (savedStateHandle.get<String>(SALE_NO)...)", "type": "pc" },
    { "line": 1999, "branchesMissed": 7, "branchesTotal": 10, "code": "if (uiState.searchCustomer?.pets?...)", "type": "pc" },
    { "line": 2308, "branchesMissed": 1, "branchesTotal": 2, "code": "val items = when (uiState.currentTab) {", "type": "pc" }
  ],
  "uncoveredBlocks": [
    {
      "function": "onClickItemCountChange",
      "lines": "L243-L265",
      "ncCount": 12,
      "pcCount": 1,
      "reason": "PRODUCT 탭 분기 미실행 + twoEmployees 로직 미도달",
      "requiredCondition": "currentTab=PRODUCT 상태에서 아이템 카운트 변경"
    },
    {
      "function": "showProcedureMedium",
      "lines": "L2060-L2090",
      "ncCount": 25,
      "pcCount": 3,
      "reason": "콜백 내부 함수 미트리거 + procedureList 데이터 부재",
      "requiredCondition": "procedureList mock 설정 + SelectModalHost.onClick 트리거"
    }
  ]
}
```

> **핵심**: `uncoveredBlocks`에서 `requiredCondition`이 Generator에게 "이 조건을 세팅하면 이 코드가 실행된다"를 알려줍니다.

### 0-C-3. 미커버 블록 → ViewModel 소스 매칭

```bash
# uncoveredBlocks의 각 블록에 대해, ViewModel 소스에서 해당 라인 읽기
# → 실제 코드 로직을 이해하고, 어떤 mock/상태가 필요한지 판단

Read: {ViewModel}.kt (offset={line-5}, limit=30)  # 미커버 블록 전후 컨텍스트
```

### 0-D. 커버리지 분석 보고 + 분석 범위 결정

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 기존 커버리지 분석: {ViewModel명}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
현재: LINE {X}% | BRANCH {Y}% | METHOD {Z}%
목표: LINE 50% | BRANCH 25% | METHOD 70%
갭:   LINE {gap}%p | BRANCH {gap}%p | METHOD {gap}%p

✅ 커버된 메서드 ({N}개): 추가 테스트 불필요
❌ 미커버 라인 (nc): {N}줄 → 함수 호출 자체가 안 됨
⚠️ 부분 분기 (pc bpc): {M}곳 → 일부 조건만 실행됨

🔴 미커버 블록 TOP 5 (줄수 많은 순):
  1. {함수명} (L{start}-L{end}): nc {N}줄 → {requiredCondition}
  2. {함수명} (L{start}-L{end}): nc {N}줄 → {requiredCondition}
  3. ...

🟡 부분 분기 TOP 5 (미스 분기 많은 순):
  1. L{line}: "{N} of {M} branches missed" → {코드 요약}
  2. L{line}: "{N} of {M} branches missed" → {코드 요약}
  3. ...

🎯 우선순위: nc 줄수 + pc 미스 분기 수 기준 내림차순
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

```
미커버 영역만 Pass 1~2 분석 대상에 포함:

| 메서드 | 상태 | nc줄 | pc분기 | 분석 대상? |
|--------|------|------|--------|----------|
| updateTab | fc (100%) | 0 | 0 | ❌ 스킵 |
| onClickCancel | fc bfc | 0 | 0 | ❌ 스킵 |
| onClickItemDelete | nc (0%) | 1 | 0 | ✅ 함수 미호출 |
| onClickItemCountChange | nc+pc | 12 | 1 | ✅ 분기+데이터 분석 |
| showProcedureMedium | nc+pc | 25 | 3 | ✅ 콜백+mock 분석 |
```

> **효과**: 100개 함수 중 미커버 30개만 분석 → 컨텍스트 70% 절약 + Generator 정확도 향상
> **추가 효과**: 라인레벨 분석으로 "왜 안 커버되는지" 원인까지 파악 → 보충 테스트 1회만에 적중률 극대화

---

## 분석 프로세스 (2-Pass)

```
┌─────────────────────────────────────────────────────────────────┐
│  (기존 테스트 있을 때)                                            │
│  Pass 0: JaCoCo 커버리지 사전 분석                                │
│  → 미커버 메서드 목록 확정 → 이후 분석 범위 축소                    │
└────────────────────────┬────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Pass 1: 구조 스캔 (grep/regex, 코드 본문 읽지 않음)             │
├─────────────────────────────────────────────────────────────────┤
│  1-A. 함수 시그니처 추출 (Grep: fun/private fun 패턴)            │
│  1-B. 의존성 + 상태 필드 추출 (Grep: @Inject, UiState)          │
│  1-C. 콜백 패턴 탐지 (Grep: SelectModalHost, ConfirmModalHost)  │
│  1-D. 비동기 패턴 탐지 (Grep: viewModelLaunch, apiFlow, response)│
│  1-E. 초벌 그룹 분류 → "구조 요약 시트" 생성                     │
│       ※ Pass 0 결과가 있으면 미커버 메서드에 ⚠️ 마킹              │
└────────────────────────┬────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Pass 2: 선택적 상세 분석 (필요한 블록만 부분 읽기)               │
├─────────────────────────────────────────────────────────────────┤
│  2-A. 콜백 트리거 상세 분석 (콜백 라인 ±30줄만 Read)             │
│  2-B. 분기 조건 분석 (when/if-else 있는 함수만 Read)             │
│  2-C. 상태 의존성 정밀 매핑 (reduceState 블록만 Read)            │
│  2-D. 최종 그룹화 + Plan JSON 생성                               │
│       ※ 미커버 메서드에 우선순위 부여 + 기존 커버 메서드는 최소화   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pass 1: 구조 스캔

⛔ **Pass 1에서는 파일 본문을 Read로 읽지 않습니다.** Grep/Glob만 사용합니다.

### 1-A. 함수 시그니처 추출

```bash
# Public + Private 함수 시그니처를 한 번에 추출
Grep: pattern="^\s+(fun |private fun |private suspend fun |override fun )"
      path="{ViewModel}.kt"
      output_mode="content"
```

결과에서 각 함수의 **라인 번호, 접근제어자, 이름, 파라미터**를 기록합니다.

### 1-B. 의존성 + 상태 필드 추출

```bash
# DI 의존성 확인
Grep: pattern="(@HiltViewModel|@Inject|class.*ViewModel)"
      path="{ViewModel}.kt"

# 상태 구조 확인 (Contract 파일)
Grep: pattern="(data class.*UiState|sealed.*SideEffect|enum class)"
      path="{패키지경로}/"

# Contract 파일은 전체 Read (보통 100줄 이내로 작음)
Read: {Contract}.kt
```

### 1-C. 콜백 패턴 탐지

```bash
# SelectModalHost, ConfirmModalHost 위치 확인
Grep: pattern="(SelectModalHost|ConfirmModalHost|onClick\s*=|onConfirm\s*=|onDismiss\s*=)"
      path="{ViewModel}.kt"
      output_mode="content"
```

결과에서 **콜백이 있는 라인 번호**를 기록 → Pass 2에서 해당 블록만 읽습니다.

### 1-D. 비동기 패턴 탐지 (핵심!)

⛔ **이 프로젝트의 모든 비즈니스 로직은 비동기 패턴 안에서 실행됩니다. 이를 인식하지 못하면 테스트에서 API 호출 후 상태 변경이 전혀 포착되지 않습니다.**

```bash
# 3가지 비동기 패턴 탐지
Grep: pattern="(viewModelLaunch|\.apiFlow\(|\.response\()"
      path="{ViewModel}.kt"
      output_mode="content"
```

#### 비동기 패턴 3종과 테스트 전략

| 패턴 | 소스 위치 | 내부 동작 | 테스트 필수 처리 |
|------|----------|----------|----------------|
| `viewModelLaunch { }` | BaseViewModel L54 | `launch { delay(300); showLoading() }; callFunc(); hideLoading()` | 3단계 스케줄러 제어 필수 |
| `.apiFlow()` | BaseViewModel L103 | `.onStart { launch { delay(300); showLoading() } }.onCompletion { hideLoading() }.catch { ... }` | 3단계 스케줄러 제어 필수 |
| `.response()` | BaseIntentViewModel L59 | `when(this) { Success→successCallFunc / ApiError→(custom or default) / NetworkError→transferError }` | 5종 분기별 테스트 필요 |

#### 3단계 스케줄러 제어 패턴 (convention.md 4-1절)

```kotlin
// viewModelLaunch 또는 apiFlow 사용 함수 테스트 시 필수!
testDispatcher.scheduler.runCurrent()      // 코루틴 시작
testDispatcher.scheduler.advanceTimeBy(301) // delay(300) 처리
testDispatcher.scheduler.advanceUntilIdle() // 나머지 작업 완료
```

> ⛔ `advanceUntilIdle()` 만으로는 내부 `delay(300)`을 넘기지 못함!
> 반드시 `runCurrent()` → `advanceTimeBy(301)` → `advanceUntilIdle()` 3단계 필수

#### NetworkResponse 5종 분기 (`.response()` 사용 함수)

```
.response()의 when 분기:
1. NetworkResponse.SuccessNoBody → successCallFunc(body)
2. NetworkResponse.Success → successCallFunc(body)
3. NetworkResponse.ApiError(isApiErrorCustom=true) → apiErrorCallFunc(body)
4. NetworkResponse.ApiError(isApiErrorCustom=false) → transferError(message) or transferError(R.string.toast_retry)
5. NetworkResponse.NetworkError / UnknownError → transferError(R.string.toast_retry)
```

각 `.response()` 사용 함수에 대해 **최소 3종 테스트** 필요:
- Success 경로 (1개)
- ApiError 경로 (1개)
- NetworkError 경로 (1개)

#### 함수별 비동기 유형 기록

```json
{
  "asyncPatterns": {
    "fetchData": { "type": "viewModelLaunch+apiFlow", "requiresSchedulerAdvance": true },
    "onClickPayment": { "type": "viewModelLaunch+response", "requiresSchedulerAdvance": true, "responseBranches": 5 },
    "updateTab": { "type": "direct", "requiresSchedulerAdvance": false },
    "onClickBack": { "type": "direct", "requiresSchedulerAdvance": false }
  }
}
```

### 1-E. 구조 요약 시트 생성

위 결과를 종합하여 다음 형태의 요약 시트를 만듭니다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 구조 요약 시트: {ViewModel명}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📏 파일 크기: {N}줄
📦 의존성: {Repository 목록}
📊 상태 필드: {필드 수}개
🔧 Public 함수: {N}개 (라인 범위별)
🔒 Private 함수: {M}개 (라인 범위별)
⚡ 콜백 패턴: {K}곳 (라인 번호 목록)
🔄 비동기 패턴: viewModelLaunch {A}곳, apiFlow {B}곳, response {C}곳

🗂️ 초벌 그룹 분류:
| 그룹 ID              | 함수 수 | 코드 범위       | 비동기 유형     | 핵심 상태       |
|----------------------|--------|----------------|----------------|----------------|
| init-fetch           | ~N     | L{start}-{end} | apiFlow        | {상태 필드들}   |
| {기능}-flow          | ~N     | L{start}-{end} | viewModelLaunch| {상태 필드들}   |
| ui-events            | ~N     | 분산            | direct         | 없음           |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Pass 2: 선택적 상세 분석

⛔ **Pass 2에서는 전체 파일을 읽지 않습니다.** 필요한 블록만 `Read(offset, limit)`으로 읽습니다.

### 2-A. 콜백 트리거 상세 분석

Pass 1에서 식별한 콜백 라인 번호를 기반으로 해당 블록만 읽습니다:

```bash
# 예: 콜백이 L2057, L2307, L2555에 있으면
Read: offset=2057, limit=60   # showProcedureMedium 블록
Read: offset=2307, limit=80   # showEmployees 블록
Read: offset=2555, limit=30   # showProductWarningDialog 블록
# 병렬로 동시 읽기 가능!
```

각 콜백에서 다음을 분석:
- **onClick 내부에서 호출되는 함수** (addCategory, updatePetItem 등)
- **콜백 체이닝** (showProcedureMedium → onClick → showProcedureSmall)
- **상태 변경** (reduceState 내 copy 필드)

### 2-B. 분기 조건 분석

함수 시그니처에서 복잡한 로직이 예상되는 함수만 선택적 읽기:

```bash
# when/if-else 분기가 있는 함수 탐지
Grep: pattern="(when\s*\{|when\s*\(|if\s*\(.*\)\s*\{)"
      path="{ViewModel}.kt"
      output_mode="content"

# 해당 함수 블록만 읽기
Read: offset={함수시작라인}, limit={함수길이}
```

### 2-C. 상태 의존성 정밀 매핑

```bash
# reduceState/copy 블록만 추출
Grep: pattern="(reduceState|\.copy\(|postSideEffect)"
      path="{ViewModel}.kt"
      output_mode="content"
      context=3  # 전후 3줄 포함
```

### 2-D. 최종 그룹화

Pass 1 구조 요약 시트 + Pass 2 상세 분석 결과를 합쳐서 최종 Plan JSON을 생성합니다.

---

## Step 0: API Endpoint + Mock 데이터 요구사항 분석

> **모든 분석에 앞서**, ViewModel이 의존하는 Repository/UseCase의 API endpoint와 응답 데이터를 분석합니다.
> MockWebServer + Real RepositoryImpl 패턴을 사용하므로 JSON fixture 파일이 필요합니다.

### 0.1 의존성 Repository 메서드 + API Endpoint 파싱

```bash
# ViewModel 생성자에서 주입받는 의존성 확인
Grep: pattern="(@Inject|constructor\()"
      path="{ViewModel}.kt"
      output_mode="content"
      context=20

# 각 Repository의 메서드 반환 타입 확인
Grep: pattern="(fun |suspend fun )"
      path="{Repository}.kt"
      output_mode="content"

# 각 Service의 Retrofit 어노테이션 + URL 패턴 확인 (JSON fixture 파일명 결정에 필수)
Grep: pattern="(@GET|@POST|@PUT|@PATCH|@DELETE)"
      path="{Service}.kt"
      output_mode="content"
      context=3
```

### 0.2 Entity/VO 구조 확인

```bash
# 반환되는 Entity의 필드 구조 확인 (JSON fixture 데이터 설계에 필요)
Read: {Entity}.kt
```

### 0.3 API Endpoint → JSON Fixture 매핑 생성

⛔ **MockWebServer auto-dispatch는 URL 경로를 기반으로 JSON fixture 파일을 자동 매칭합니다.**
⛔ **파일명 규칙**: `{method}_{path_segments}_{query}_{code}_{apiResult}_{account}.json`
⛔ **domain 폴더**: `MockWebServerExtension.getDomainFolder(path)` 에 따라 결정

```bash
# 기존 fixture 파일 확인 (이미 존재하면 새로 생성 불필요)
Glob: network/src/testFixtures/resources/**/*.json
```

분석 결과를 `apiEndpoints` + `mockDataRequirements` 로 정리:

```json
{
  "apiEndpoints": [
    {
      "service": "SaleService",
      "method": "GET",
      "url": "/api/v2/sales/payment-methods/{shopNo}",
      "resolvedUrl": "/api/v2/sales/payment-methods/test_shop_no",
      "domainFolder": "shop",
      "fixturePath": "shop/get_api_v2_sales_payment-methods_test_shop_no_200_success_herrenail.json",
      "fixtureExists": false,
      "responseEntity": "GetPaymentMethodEntity",
      "requiredData": "결제수단 목록 (현금, 카드 등)"
    },
    {
      "service": "EmployeeService",
      "method": "GET",
      "url": "/api/v2/employees?shopNo={shopNo}&isLoginEmployeeSortFirst=true",
      "resolvedUrl": "/api/v2/employees?shopNo=test_shop_no&isLoginEmployeeSortFirst=true&hasNoChargeEmployee=false&hasStateWaitingEmployee=false",
      "domainFolder": "employee",
      "fixturePath": "employee/get_api_v2_employees_shopNo=test_shop_no&isLoginEmployeeSortFirst=true&hasNoChargeEmployee=false&hasStateWaitingEmployee=false_200_success_herrenail.json",
      "fixtureExists": true,
      "responseEntity": "EmployeeEntity",
      "requiredData": "직원 2명 이상 (빈 리스트면 직원 선택 로직 미실행)"
    }
  ],
  "mockDataRequirements": {
    "saleRepository.getPaymentMethods": {
      "returnType": "Flow<ResponseBase<GetPaymentMethodEntity>>",
      "apiEndpoint": "GET /api/v2/sales/payment-methods/{shopNo}",
      "fixturePath": "shop/get_api_v2_sales_payment-methods_test_shop_no_200_success_herrenail.json",
      "requiredData": "결제수단 4종 (현금, 카드, 상품권, 이체) - JSON fixture로 제공"
    },
    "employeeRepository.getEmployeeList": {
      "returnType": "Flow<ResponseBase<List<EmployeeEntity>>>",
      "apiEndpoint": "GET /api/v2/employees",
      "fixturePath": "employee/get_api_v2_employees_..._200_success_herrenail.json",
      "requiredData": "직원 2명 이상 - JSON fixture로 제공"
    }
  }
}
```

> **핵심**: `apiEndpoints`에서 `fixtureExists == false`인 항목은 Phase 1.5에서 JSON fixture 파일을 생성해야 합니다.
> **데이터 흐름**: JSON fixture → MockWebServer auto-dispatch → HTTP 응답 → Retrofit+Gson 파싱 → Entity → Real RepositoryImpl → ViewModel

### 0.4 getDomainFolder() 매핑 확인

⛔ **fixture 파일이 올바른 폴더에 위치해야 auto-dispatch가 동작합니다.**

```bash
# MockWebServerExtension.kt의 getDomainFolder() 매핑 확인
Read: app/src/test/.../utils/MockWebServerExtension.kt
```

| URL 패턴 | 도메인 폴더 | 비고 |
|----------|-----------|------|
| `booking/payments` | booking_payments | |
| `shop-contacts` | shop-contacts | |
| `shop-point-settings` | shop | |
| `products` | shop | |
| `business-day` (employees 제외) | shop | |
| `sales` | shop | |
| `cosmetics` / `books/items` | shop | |
| `shop` | shop | |
| `employees` | employee | |
| `customer` | customer | |
| `login` | login | |
| 기타 | shop | 폴백 |

---

## 함수당 최소 테스트 수 규칙

```
⛔ 함수 1개 = 테스트 1개 금지

최소 테스트 수 = max(2, 분기 수)

| 함수 특성              | 최소 테스트 수 | 예시                                    |
|----------------------|--------------|----------------------------------------|
| 단순 setter (분기 없음) | 2개           | 정상값 + 경계값/특수값                     |
| if-else 1개          | 2개           | true 경로 + false 경로                    |
| when 3분기            | 3개           | 각 분기 1개씩                             |
| API 호출 함수         | 3개 이상       | 성공 + 실패 + 엣지케이스(null/빈값)        |
| 콜백 내부 함수         | 2개 이상       | 콜백 트리거 + 콜백 후 상태 검증              |
| 복합 분기 (when+if)    | 분기 수만큼     | 모든 분기 조합                             |
```

---

## 상세 분석 규칙 (Step 0~5)

---

## Step 1: 함수 추출

> **2-Pass 모드**: Pass 1-A에서 Grep으로 시그니처만 추출합니다. 파일 전체를 Read하지 않습니다.

### 1.1 코드 패턴 인식

```kotlin
// Public 함수 패턴
fun functionName(...)           // 기본 public
internal fun functionName(...)  // internal
override fun functionName(...)  // override

// Private 함수 패턴
private fun functionName(...)
private suspend fun functionName(...)
```

### 1.2 추출 결과 형식

```json
{
  "publicFunctions": [
    { "name": "handleEvent", "params": ["event: UiEvent"], "returnType": "Unit" },
    { "name": "updateAmount", "params": ["value: TextFieldValue"], "returnType": "Unit" },
    { "name": "onClickPayment", "params": [], "returnType": "Unit" }
  ],
  "privateFunctions": [
    { "name": "validateAmount", "params": [], "returnType": "Boolean" },
    { "name": "requestStorePayment", "params": ["type: String"], "returnType": "Job" },
    { "name": "showErrorModal", "params": ["case: ModalCase"], "returnType": "Unit" }
  ]
}
```

---

## Step 2: 호출 체인 추적

> **2-Pass 모드**: Pass 1-A 결과에서 1-depth 호출 관계를 파악하고, Pass 2-A에서 콜백 블록만 선택적으로 읽어 상세 체인을 추적합니다.

### 2.1 분석 방법

```
각 함수 본문에서:
1. 다른 함수 호출 탐지 (함수명( 패턴)
2. 호출 관계 그래프 구축
3. 진입점(Public) → 종단점(Leaf Private) 경로 추적
```

### 2.2 호출 그래프 예시

```
onClickPayment()
    ├── validateAmount()
    │       └── (분기 조건 분석)
    ├── requestStorePayment(type)
    │       ├── naverRepository.requestStorePayment()
    │       └── startPolling()
    │               └── getApprovalStatus()
    └── showErrorModal(case)

updateAmount(value)
    └── (직접 상태 업데이트)

onClickClose()
    └── (SideEffect 발생)
```

### 2.3 출력 형식

```json
{
  "callGraph": {
    "onClickPayment": {
      "calls": ["validateAmount", "requestStorePayment", "showErrorModal"],
      "depth": 3,
      "leaves": ["naverRepository.requestStorePayment", "getApprovalStatus"]
    },
    "validateAmount": {
      "calls": [],
      "depth": 0,
      "leaves": []
    }
  }
}
```

### 2.3 콜백 체인 분석

```
콜백을 통해 호출되는 Private 함수 식별:

showEmployeesModal()
    └── SelectModalHost(onClick = { addEmployeeItem(it) })
                                        └── (콜백 내부 호출)

confirmDelete()
    └── ConfirmModalHost(onConfirm = { deleteReservation() })
                                           └── (콜백 내부 호출)
```

#### 콜백 호출 패턴 인식

```kotlin
// 콜백 패턴 1: SelectModalHost
SelectModalHost(
    onClick = { item -> privateFunction(item) }  // ← 콜백 내 private 함수
)

// 콜백 패턴 2: ConfirmModalHost
ConfirmModalHost(
    onConfirm = { privateFunction() }  // ← 콜백 내 private 함수
)

// 콜백 패턴 3: lambda 파라미터
someFunction(
    onComplete = { result -> handleResult(result) }
)
```

이 패턴이 발견되면 테스트 케이스에 **callbackTrigger** 필드 추가:

```json
{
    "name": "직원_추가_테스트",
    "entryPoint": "showEmployeesModal",
    "callbackTrigger": {
        "host": "selectModalHost",
        "action": "onClick",
        "target": "addEmployeeItem"
    },
    "assertion": "selectEmployees 목록에 추가됨"
}
```

---

## Step 3: 상태 의존성 분석

> **2-Pass 모드**: Pass 1-B에서 상태 필드 목록을 추출하고, Pass 2-C에서 reduceState/copy 블록만 Grep+context로 읽어 매트릭스를 생성합니다.

### 3.1 상태 접근 패턴

```kotlin
// 상태 읽기 패턴
uiState.fieldName
container.uiState.value.fieldName
_uiState.value.fieldName

// 상태 쓰기 패턴
updateState { copy(fieldName = ...) }
_uiState.value = _uiState.value.copy(...)
_uiState.update { it.copy(...) }
```

### 3.2 상태 의존성 매트릭스

```
              │ screenState │ amount │ hairTags │ isLoading │
──────────────┼─────────────┼────────┼──────────┼───────────┤
onClickPayment│    R/W      │   R    │    -     │    W      │
updateAmount  │      -      │   W    │    -     │    -      │
validateAmount│      R      │   R    │    -     │    -      │
fetchHairTags │      -      │   -    │    W     │    W      │
onClickClose  │      -      │   -    │    -     │    -      │

R = Read, W = Write, R/W = Both, - = None
```

### 3.3 충돌 탐지

```json
{
  "conflicts": [
    {
      "functions": ["onClickPayment", "validateAmount"],
      "sharedState": ["screenState", "amount"],
      "type": "read-after-write",
      "parallel": false
    }
  ],
  "independent": [
    {
      "functions": ["onClickClose", "toggleBottomSheet"],
      "reason": "no shared state",
      "parallel": true
    }
  ]
}
```

---

## Step 4: 분기 조건 분석

> **2-Pass 모드**: Pass 2-B에서 when/if-else 패턴을 Grep으로 탐지한 후, 해당 함수 블록만 `Read(offset, limit)`으로 읽어 분기를 분석합니다.

### 4.1 분기 패턴 인식

```kotlin
// when 분기
private fun validateAmount(): Boolean {
    return when {
        amount < MIN_AMOUNT -> false      // 분기 1
        amount > maxAmount -> false       // 분기 2
        amount % 10 != 0 -> false         // 분기 3
        else -> true                      // 분기 4
    }
}

// if-else 분기
private fun processResult(success: Boolean) {
    if (success) {                        // 분기 1
        updateState { copy(status = OK) }
    } else {                              // 분기 2
        showError()
    }
}
```

### 4.2 분기 분석 결과

```json
{
  "privateBranches": {
    "validateAmount": {
      "type": "when",
      "branches": [
        { "id": 1, "condition": "amount < MIN_AMOUNT", "result": "false" },
        { "id": 2, "condition": "amount > maxAmount", "result": "false" },
        { "id": 3, "condition": "amount % 10 != 0", "result": "false" },
        { "id": 4, "condition": "else", "result": "true" }
      ],
      "testCasesNeeded": 4
    },
    "processResult": {
      "type": "if-else",
      "branches": [
        { "id": 1, "condition": "success == true", "result": "updateState" },
        { "id": 2, "condition": "success == false", "result": "showError" }
      ],
      "testCasesNeeded": 2
    }
  }
}
```

### 4.3 커버리지 테스트 케이스 매핑

```json
{
  "branchCoverage": {
    "validateAmount.branch1": {
      "testCase": "결제금액_50원_입력_시_최소금액_100원_미만_에러모달_표시",
      "setup": { "amount": 50 },
      "assertion": "confirmModalHost.message가 '최소 100원 이상' 포함"
    },
    "validateAmount.branch2": {
      "testCase": "결제금액_999999원_입력_시_최대금액_10000원_초과_에러모달_표시",
      "setup": { "amount": 999999, "maxAmount": 10000 },
      "assertion": "confirmModalHost.message가 '최대 10,000원' 포함"
    },
    "validateAmount.branch3": {
      "testCase": "결제금액_1005원_입력_시_10원단위_아님_에러모달_표시",
      "setup": { "amount": 1005 },
      "assertion": "confirmModalHost.message가 '10원 단위' 포함"
    },
    "validateAmount.branch4": {
      "testCase": "결제금액_5000원_입력_후_결제요청_시_API호출되고_성공모달_표시",
      "setup": { "amount": 5000, "apiResponse": "success" },
      "assertion": "screenState가_SUCCESS, coVerify_requestStorePayment_호출됨"
    }
  }
}
```

### 4.4 테스트명 작성 규칙

⛔ **추상적/모호한 테스트명 금지**

```
❌ 금지:
- "금액 변경 시 업데이트된다"
- "결제 요청 성공 시 처리된다"
- "에러 발생 시 모달 표시"
- "빈 리스트에서 호출 시 에러없이 실행"

✅ 필수 (구체적인 값과 결과 명시):
- "결제금액_50원_입력_시_최소금액_100원_미만_에러모달_표시"
- "결제금액_5000원_입력_후_결제요청_시_API호출되고_성공모달_표시"
- "직원목록_3번째_홍길동_선택_시_selectEmployees에_홍길동_추가"
```

**테스트명 공식:**
```
[대상]_[구체적입력값]_[동작]_시_[구체적결과]_[상태변화]
```
```

---

## Step 5: 그룹화

### 5.1 그룹화 알고리즘

```
1. 상태 공유 함수들을 하나의 그룹으로 묶음 (순차)
2. 호출 체인으로 연결된 함수들을 하나의 그룹으로 묶음 (순차)
3. 나머지 독립 함수들을 병렬 그룹으로 분류
4. 각 그룹에 테스트 케이스 할당
```

### 5.2 그룹화 결과

⛔ **각 그룹의 testCases에는 반드시 `mockSetup`을 포함해야 합니다.**
⛔ **함수당 테스트 수는 `max(2, 분기 수)` 이상이어야 합니다.**
⛔ **각 그룹에 `asyncType`을 명시하여 Generator가 올바른 스케줄러 제어를 생성하도록 합니다.**
⛔ **`.response()` 사용 함수는 최소 Success + ApiError + NetworkError 3종 테스트를 포함해야 합니다.**

```json
{
  "mockDataRequirements": {
    "(Step 0에서 분석한 전체 mock 데이터 요구사항)"
  },
  "groups": [
    {
      "id": "init-hairTags",
      "type": "sequential",
      "asyncType": "viewModelLaunch+apiFlow",
      "requiresSchedulerAdvance": true,
      "reason": "hairTags 상태 공유, 초기화 체인",
      "functions": ["init(isHairCategory)", "fetchHairTags", "getBookingHairTags", "updateSelectedGender", "selectTag"],
      "sharedState": ["hairTags", "selectedHairTags", "isShowStyleTagBottomSheet"],
      "callChain": "init → fetchHairTags → updateSelectedGender",
      "testCases": [
        {
          "name": "Hair_카테고리_true_초기화_시_hairTags가_3개_조회됨",
          "entryPoint": "init",
          "branches": [],
          "mockSetup": [
            "coEvery { hairTagRepository.getHairTags() } returns flowOf(ResponseBase(data = listOf(HairTagEntity(id=1, name=\"펌\"), HairTagEntity(id=2, name=\"커트\"), HairTagEntity(id=3, name=\"염색\"))))"
          ]
        },
        {
          "name": "Hair_카테고리_false_초기화_시_hairTags가_빈리스트",
          "entryPoint": "init",
          "branches": ["isHairCategory.false"],
          "mockSetup": []
        },
        { "name": "성별_MALE_선택_시_태그가_남성태그만_필터링됨", "entryPoint": "updateSelectedGender", "branches": [] },
        { "name": "성별_FEMALE_선택_시_태그가_여성태그만_필터링됨", "entryPoint": "updateSelectedGender", "branches": [] },
        { "name": "태그_1번_선택_시_selectedHairTags에_추가됨", "entryPoint": "selectTag", "branches": [] },
        { "name": "이미선택된_태그_재선택_시_selectedHairTags에서_제거됨", "entryPoint": "selectTag", "branches": ["toggle"] }
      ]
    },
    {
      "id": "payment-validation",
      "type": "sequential",
      "asyncType": "viewModelLaunch+response",
      "requiresSchedulerAdvance": true,
      "reason": "결제 금액 검증 → 요청 체인",
      "functions": ["updateStorePaymentAmount", "onClickPaymentRequest", "validateAmount", "requestStorePayment"],
      "sharedState": ["storePaymentAmount", "screenState", "confirmModalHost"],
      "callChain": "onClickPaymentRequest → validateAmount → requestStorePayment",
      "testCases": [
        {
          "name": "결제금액_50원_입력_시_최소금액_100원_미만_에러모달_표시",
          "entryPoint": "onClickPaymentRequest",
          "branches": ["validateAmount.1"],
          "precondition": {
            "requiredState": "storePaymentAmount가 50원으로 설정된 상태",
            "mockSetup": ["viewModel.updateStorePaymentAmount(TextFieldValue(\"50\"))"]
          },
          "assertion": "confirmModalHost.message가 '최소 100원 이상' 포함"
        },
        {
          "name": "결제금액_999999원_입력_시_최대금액_10000원_초과_에러모달_표시",
          "entryPoint": "onClickPaymentRequest",
          "branches": ["validateAmount.2"],
          "precondition": {
            "requiredState": "storePaymentAmount가 999999원, maxAmount가 10000원인 상태",
            "mockSetup": [
              "every { savedStateHandle.get<Long>(\"maxAmount\") } returns 10000L",
              "viewModel.updateStorePaymentAmount(TextFieldValue(\"999999\"))"
            ]
          },
          "assertion": "confirmModalHost.message가 '최대 10,000원' 포함"
        },
        {
          "name": "결제금액_5000원_입력_후_결제요청_시_API호출되고_screenState가_SUCCESS로_변경",
          "entryPoint": "onClickPaymentRequest",
          "branches": ["validateAmount.4", "requestStorePayment.success"],
          "precondition": {
            "requiredState": "storePaymentAmount가 5000원, API가 성공 응답 반환",
            "mockSetup": [
              "viewModel.updateStorePaymentAmount(TextFieldValue(\"5000\"))",
              "coEvery { repository.requestStorePayment(any()) } returns flowOf(ResponseBase(data = PaymentResultEntity(success = true)))"
            ]
          },
          "assertion": "screenState == ScreenState.SUCCESS, coVerify { repository.requestStorePayment(5000) }"
        },
        {
          "name": "결제금액_5000원_입력_후_결제요청_시_API실패하면_에러모달_표시",
          "entryPoint": "onClickPaymentRequest",
          "branches": ["validateAmount.4", "requestStorePayment.failure"],
          "precondition": {
            "requiredState": "storePaymentAmount가 5000원, API가 실패 응답 반환",
            "mockSetup": [
              "viewModel.updateStorePaymentAmount(TextFieldValue(\"5000\"))",
              "coEvery { repository.requestStorePayment(any()) } returns flowOf(ResponseBase(error = ErrorInfo(code = \"PAYMENT_FAILED\")))"
            ]
          },
          "assertion": "confirmModalHost가 에러 모달로 설정됨"
        }
      ]
    },
    {
      "id": "refund-flow",
      "type": "sequential",
      "reason": "환불 요청 체인",
      "functions": ["onClickPaymentRefund", "requestStorePaymentRefund"],
      "sharedState": ["screenState"],
      "testCases": [
        { "name": "환불요청_성공", "entryPoint": "onClickPaymentRefund", "branches": ["requestRefund.success"] },
        { "name": "환불요청_실패", "entryPoint": "onClickPaymentRefund", "branches": ["requestRefund.failure"] }
      ]
    },
    {
      "id": "ui-events",
      "type": "parallel",
      "asyncType": "direct",
      "requiresSchedulerAdvance": false,
      "reason": "독립적 UI 이벤트, 상태 간섭 없음",
      "functions": ["onClickClose", "onClickStyleTagBottomSheet", "onClickPaymentRequestComplete"],
      "sharedState": [],
      "testCases": [
        { "name": "닫기_클릭_시_화면_종료", "entryPoint": "onClickClose", "branches": [] },
        { "name": "스타일태그_바텀시트_토글", "entryPoint": "onClickStyleTagBottomSheet", "branches": [] },
        { "name": "결제완료_클릭", "entryPoint": "onClickPaymentRequestComplete", "branches": [] },
        {
          "name": "직원_추가_시_목록에_추가",
          "entryPoint": "showEmployeesModal",
          "callbackTrigger": {
            "host": "selectModalHost",
            "action": "onClick",
            "target": "addEmployeeItem"
          },
          "branches": [],
          "assertion": "selectEmployees 목록에 추가됨"
        }
      ]
    }
  ],
  "summary": {
    "totalGroups": 4,
    "parallelGroups": 1,
    "sequentialGroups": 3,
    "totalTestCases": 13,
    "privateBranchesCovered": 8,
    "callbackFunctions": 1
  },
  "coverageVerification": {
    "jacocoCommand": "./gradlew :app:testDevDebugUnitTest --tests '*{ViewModel명}Test*' && ./gradlew :app:jacocoViewModelTestReport",
    "csvPath": "app/build/reports/jacoco/viewmodel.csv",
    "htmlPath": "app/build/reports/jacoco/viewmodel/index.html",
    "callbackFunctions": ["addEmployeeItem"]
  }
}
```

---

## 출력 파일

계획을 JSON 파일로 저장:

```
.unittest-pipeline/plans/{ViewModel명}_parallel_plan.json
```

---

## 사용 예시

### 예시 1: 소형 ViewModel (싱글 분석)

```
입력: NaverPayStorePaymentViewModel.kt (250줄)

분석 전략: 싱글 (300줄 미만)
→ 전체 파일 1회 Read → Step 1~5 순차 실행

결과:
- Public 함수 12개, Private 함수 8개 (분기 조건 15개)
- 순차 그룹 3개, 병렬 그룹 1개
- 테스트 케이스 20개
- Private 분기 커버리지 100% (15/15)
```

### 예시 2: 대형 ViewModel (2-Pass 분석)

```
입력: SaleViewModel.kt (3805줄)

분석 전략: 2-Pass (300줄 이상)

Pass 1 (구조 스캔):
- Grep 4회로 함수 시그니처, 의존성, 콜백 패턴 추출
- 코드 본문 읽기: 0줄
- 결과: 구조 요약 시트 (Public 60개, Private 45개, 콜백 14곳)
- 초벌 그룹 11개 분류

Pass 2 (선택적 읽기):
- 콜백 블록 9곳 × 평균 40줄 = ~360줄 Read
- 분기 조건 함수 5곳 × 평균 30줄 = ~150줄 Read
- 총 읽은 줄: ~510줄 (전체의 13%)

결과:
- 순차 그룹 8개, 병렬 그룹 3개
- 테스트 케이스 50+개
- 콜백 트리거 9개 식별
- 컨텍스트 절약: 87%
```
