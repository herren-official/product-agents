---
name: unittest-agent-generator
description: 그룹별 병렬 테스트 코드 생성 Worker
allowed-tools: Read, Write, Edit
user-invocable: false
---

# Parallel Test Generator

Plan에서 분석한 그룹별로 테스트 코드를 병렬 생성합니다.

---

## 병렬 실행 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│  Orchestrator (Main Agent)                                      │
│  • Plan JSON 로드                                               │
│  • 그룹별 Worker 병렬 호출                                        │
│  • 결과 머지                                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┬───────────────┐
         ▼               ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Worker A   │ │  Worker B   │ │  Worker C   │ │  Worker D   │
│  그룹: init │ │ 그룹: pay   │ │ 그룹: refund│ │ 그룹: ui    │
│  테스트 3개  │ │ 테스트 4개  │ │ 테스트 2개  │ │ 테스트 3개  │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │               │
       └───────────────┴───────────────┴───────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Merge: 모든 @Nested 클래스를 하나의 파일로 합침                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Worker 호출 방식

### Task 병렬 호출

```
// Orchestrator가 Plan의 각 그룹에 대해 Task 병렬 호출
Task(
  subagent_type="general-purpose",
  prompt="그룹 테스트 생성: {그룹 정보 JSON}",
  model="opus"  // 테스트 품질 최우선
)
// 여러 Task를 단일 메시지에서 동시 호출
```

### Worker에게 전달되는 정보

```json
{
  "groupId": "payment-validation",
  "groupType": "sequential",
  "asyncType": "viewModelLaunch+response",
  "requiresSchedulerAdvance": true,
  "viewModel": "NaverPayStorePaymentViewModel",
  "viewModelPath": "ui/tab/menu/naverPayStorePayment/NaverPayStorePaymentViewModel.kt",
  "functions": [
    {
      "name": "updateStorePaymentAmount",
      "type": "public",
      "params": ["value: TextFieldValue"],
      "returnType": "Unit",
      "calls": [],
      "reads": [],
      "writes": ["storePaymentAmount"]
    },
    {
      "name": "onClickPaymentRequest",
      "type": "public",
      "params": [],
      "returnType": "Unit",
      "calls": ["validateAmount", "requestStorePayment"],
      "reads": ["storePaymentAmount", "bookNo"],
      "writes": ["screenState", "confirmModalHost"]
    },
    {
      "name": "validateAmount",
      "type": "private",
      "branches": [
        { "id": 1, "condition": "amount < MIN_STORE_PAYMENT_AMOUNT", "result": "showErrorModal" },
        { "id": 2, "condition": "amount > maxAmount", "result": "showErrorModal" },
        { "id": 3, "condition": "else", "result": "continue" }
      ]
    },
    {
      "name": "requestStorePayment",
      "type": "private",
      "branches": [
        { "id": 1, "condition": "response.isSuccess", "result": "showSuccessModal" },
        { "id": 2, "condition": "response.isError", "result": "showErrorModal" }
      ]
    }
  ],
  "testCases": [
    {
      "name": "최소금액_미만_에러모달",
      "entryPoint": "onClickPaymentRequest",
      "setup": { "storePaymentAmount": 50 },
      "branches": ["validateAmount.1"],
      "assertion": "confirmModalHost가 에러 모달로 설정됨"
    },
    {
      "name": "최대금액_초과_에러모달",
      "entryPoint": "onClickPaymentRequest",
      "setup": { "storePaymentAmount": 999999 },
      "branches": ["validateAmount.2"],
      "assertion": "confirmModalHost가 에러 모달로 설정됨"
    },
    {
      "name": "정상금액_결제요청_성공",
      "entryPoint": "onClickPaymentRequest",
      "setup": { "storePaymentAmount": 5000, "apiResponse": "success" },
      "branches": ["validateAmount.3", "requestStorePayment.1"],
      "assertion": "성공 모달 표시, screenState 변경"
    },
    {
      "name": "정상금액_결제요청_실패",
      "entryPoint": "onClickPaymentRequest",
      "setup": { "storePaymentAmount": 5000, "apiResponse": "error" },
      "branches": ["validateAmount.3", "requestStorePayment.2"],
      "assertion": "에러 모달 표시"
    }
  ],
  "sharedState": ["storePaymentAmount", "screenState", "confirmModalHost"]
}
```

---

## ⛔ 핵심 규칙: MockWebServer 기반 데이터 + 함수당 다중 테스트

### 규칙 1: MockWebServer + JSON fixture 기반 테스트 (권장)

```
✅ 기본: MockWebServer auto-dispatch가 JSON fixture로 자동 응답
   → Real RepositoryImpl → Retrofit+Gson 파싱 → Entity → ViewModel
   → setup()에서 이미 설정됨, 대부분의 테스트에서 추가 설정 불필요

✅ 에러 테스트: mockWebServer.dispatchResponse(apiResult = "apiError")
   → 500 에러 응답 시뮬레이션

✅ 특정 응답: mockWebServer.enqueueResponse("domain", "custom.json", 200)
   → 특정 endpoint만 다른 응답 필요할 때

⛔ 금지: Kotlin 코드에 Entity 하드코딩 (coEvery { ... } returns 하드코딩Entity)
   이유: Entity 변경 시 컴파일 에러, 재사용 불가, 가독성 저하
```

### 규칙 2: 함수당 최소 테스트 수

```
최소 테스트 수 = max(2, 분기 수)

| 함수 특성              | 최소 테스트 수 |
|----------------------|--------------|
| 단순 setter (분기 없음) | 2개 (정상값 + 경계값) |
| if-else 1개          | 2개 (true + false)   |
| when 3분기            | 3개 (각 분기)         |
| API 호출 함수         | 3개+ (성공+실패+엣지) |
| 콜백 내부 함수         | 2개+ (트리거+상태검증) |
```

---

## MockWebServer 기반 데이터 패턴

### 기본 패턴: JSON fixture → auto-dispatch (대부분의 테스트)

setup()에서 `useMockWebServer = true` + Real RepositoryImpl을 설정하면,
MockWebServer가 URL 패턴에 따라 JSON fixture 파일을 자동 매칭하여 응답합니다.

```
데이터 흐름:
JSON fixture (network/src/testFixtures/resources/{domain}/{filename}.json)
  → MockWebServer auto-dispatch (URL → 파일명 매칭)
  → HTTP 200 + JSON body
  → Retrofit + Gson (자동 파싱)
  → Entity
  → Real RepositoryImpl
  → ViewModel (비즈니스 로직 실행)
  → UiState/SideEffect (테스트에서 검증)
```

### 테스트에서 MockWebServer 활용

```kotlin
@Test
@DisplayName("시술_중분류에서_커트_선택_후_onClick콜백_실행_시_소분류_모달이_표시된다")
fun `시술_중분류에서_커트_선택_후_onClick콜백_실행_시_소분류_모달이_표시된다`() = runTest {
    // Given: setup()에서 이미 MockWebServer + Real RepositoryImpl이 설정됨
    // JSON fixture가 시술 카테고리 데이터를 자동 응답

    // When: 중분류 모달 → 커트 선택
    viewModel.onClickCategoryMedium()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()
    Thread.sleep(500)
    testDispatcher.scheduler.advanceUntilIdle()

    val modalHost = viewModel.container.uiState.value.selectModalHost
    modalHost.onClick(SelectModalVo(id = "1", content = "커트"))
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()
    Thread.sleep(500)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then: 소분류 모달이 표시됨
    val updatedModal = viewModel.container.uiState.value.selectModalHost
    assertTrue(updatedModal.isShowSelectModal)
}
```

### 에러 테스트: dispatchResponse 활용

```kotlin
@Test
@DisplayName("API_에러_발생_시_에러모달_표시")
fun `API_에러_발생_시_에러모달_표시`() = runTest {
    // Given: 에러 응답으로 MockWebServer 설정
    mockWebServer.dispatchResponse(apiResult = "apiError")

    // 별도 ViewModel 생성 (에러 응답 설정된 MockWebServer 사용)
    val errorRepository = RepositoryImpl(MockWebServerService.repositoryService(mockWebServer))
    val errorViewModel = ViewModel(repository = errorRepository, ...)

    // When
    errorViewModel.fetchData()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then
    assertNotNull(errorViewModel.container.uiState.value.confirmModalHost)
}
```

---

## Worker 테스트 생성 규칙

### 1. @Nested 클래스 구조

```kotlin
@Nested
@DisplayName("{그룹 한글명} 테스트")
inner class {GroupId}Test {

    @Test
    @DisplayName("{테스트케이스 한글명}")
    fun `{테스트케이스 한글명}`() = runTest {
        // Given
        // When
        // Then
    }
}
```

### 2. Given-When-Then 패턴

```kotlin
@Test
@DisplayName("최소 금액 미만 시 에러 모달이 표시된다")
fun `최소 금액 미만 시 에러 모달이 표시된다`() = runTest {
    // Given: 초기 상태 설정
    initializeViewModel()
    viewModel.updateStorePaymentAmount(TextFieldValue("50"))
    advanceUntilIdle()

    // When: 테스트 대상 함수 호출
    viewModel.onClickPaymentRequest()
    advanceUntilIdle()

    // Then: 결과 검증
    val state = viewModel.container.uiState.value
    assertNotNull(state.confirmModalHost)
    assertTrue(state.confirmModalHost is ConfirmModalHost.Error)
}
```

### 3. Private 분기 커버리지

Private 함수의 분기는 **Public 진입점을 통해** 테스트:

```kotlin
// ❌ 잘못된 방법: Private 함수 직접 호출 (불가능)
viewModel.validateAmount()

// ✅ 올바른 방법: Public 함수를 통해 분기 커버리지
// 분기 1: amount < MIN_AMOUNT
viewModel.updateStorePaymentAmount(TextFieldValue("50"))
viewModel.onClickPaymentRequest()  // validateAmount() 내부적으로 호출됨

// 분기 2: amount > maxAmount
viewModel.updateStorePaymentAmount(TextFieldValue("999999"))
viewModel.onClickPaymentRequest()

// 분기 3: 정상 금액
viewModel.updateStorePaymentAmount(TextFieldValue("5000"))
viewModel.onClickPaymentRequest()
```

### 4. 콜백 기반 Private 함수 테스트

Private 함수가 **콜백(onClick, onDismiss 등) 내부에서 호출**되는 경우,
설정(모달 표시)만으로는 커버되지 않습니다. **반드시 콜백을 트리거**해야 합니다.

#### ❌ 잘못된 방법: 설정만 하고 콜백 미트리거

```kotlin
@Test
fun `직원 추가 테스트`() = runTest {
    initializeViewModel()
    viewModel.showEmployeesModal()  // 모달 설정만 함
    advanceUntilIdle()
    // addEmployeeItem은 onClick 콜백 안에 있어 실행되지 않음!
}
```

#### ✅ 올바른 방법: 콜백을 캡처하여 직접 트리거

```kotlin
@Test
fun `직원 추가 시 목록에 추가된다`() = runTest {
    initializeViewModel()
    advanceUntilIdle()

    // Given: 모달의 onClick 콜백 캡처
    viewModel.showEmployeesModal()
    advanceUntilIdle()

    val modalHost = viewModel.container.uiState.value.selectModalHost
    assertNotNull(modalHost)

    // When: 콜백을 직접 트리거 (onClick 실행 = addEmployeeItem 호출)
    val employee = SelectModalVo(id = "emp_1", content = "홍길동")
    modalHost!!.onClick(employee)
    advanceUntilIdle()

    // Then: 직원이 목록에 추가됨
    assertTrue(viewModel.container.uiState.value.selectEmployees.any { it.id == "emp_1" })
}
```

#### 콜백 패턴 식별 기준

Plan에서 다음 패턴이 발견되면 콜백 트리거 테스트 필요:
- `onClick = { privateFunction(it) }`
- `onConfirm = { ... }`
- `onDismiss = { ... }`
- `SelectModalHost(onClick = { addEmployeeItem(it) })`
- `ConfirmModalHost(onConfirm = { deleteItem() })`

### 5. API 응답 분기 처리 (MockWebServer 패턴)

```kotlin
@Test
@DisplayName("결제_요청_성공_시_screenState가_SUCCESS로_변경된다")
fun `결제_요청_성공_시_screenState가_SUCCESS로_변경된다`() = runTest {
    // Given: setup()에서 이미 MockWebServer가 성공 JSON fixture로 응답
    viewModel.updateStorePaymentAmount(TextFieldValue("5000"))
    advanceUntilIdle()

    // When
    viewModel.onClickPaymentRequest()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()
    Thread.sleep(500)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then
    val state = viewModel.container.uiState.value
    assertEquals(ScreenState.SUCCESS, state.screenState)
}

@Test
@DisplayName("결제_요청_API에러_시_에러모달이_표시된다")
fun `결제_요청_API에러_시_에러모달이_표시된다`() = runTest {
    // Given: MockWebServer를 에러 응답 모드로 변경
    mockWebServer.dispatchResponse(apiResult = "apiError")
    // 에러 응답으로 별도 ViewModel 생성
    val errorRepository = RepositoryImpl(MockWebServerService.repositoryService(mockWebServer))
    val errorViewModel = ViewModel(repository = errorRepository, savedStateHandle = mockSavedStateHandle)

    errorViewModel.updateStorePaymentAmount(TextFieldValue("5000"))
    advanceUntilIdle()

    // When
    errorViewModel.onClickPaymentRequest()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()
    Thread.sleep(500)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then
    val state = errorViewModel.container.uiState.value
    assertNotNull(state.confirmModalHost)
}
```

> **참고**: MockWebServer의 `dispatchResponse(apiResult)` 옵션:
> - `"success"` (기본) → 200 + JSON fixture
> - `"apiError"` → 500 + `called_api_error.json`
> - `"apiSuccess"` → 200 + `called_api_success.json`
> - `"apiNotSuccess"` → 200 + `called_api_not_success.json`
> - `"apiFailAuth"` → 200 + `called_api_fail_auth.json`
> - `"emptyData"` → 200 + `called_empty_data.json`

### 6. 비동기 패턴별 스케줄러 제어 (필수!)

⛔ **`viewModelLaunch` 또는 `apiFlow()`를 사용하는 함수는 내부에 `delay(300)`이 존재하여 `advanceUntilIdle()`만으로는 상태 변경이 반영되지 않습니다.**

#### Plan의 asyncType에 따른 스케줄러 제어

| asyncType | advanceUntilIdle()만? | 3단계 스케줄러? | 이유 |
|-----------|----------------------|----------------|------|
| `direct` | ✅ 충분 | 불필요 | delay 없음 |
| `viewModelLaunch` | ❌ 부족 | ✅ 필수 | BaseViewModel.viewModelLaunch 내 delay(300) |
| `viewModelLaunch+apiFlow` | ❌ 부족 | ✅ 필수 | apiFlow의 onStart에도 delay(300) |
| `viewModelLaunch+response` | ❌ 부족 | ✅ 필수 | viewModelLaunch 내 delay(300) |

#### ❌ 잘못된 방법: advanceUntilIdle()만 사용

```kotlin
@Test
fun `데이터_조회_테스트`() = runTest {
    coEvery { repository.fetchData() } returns flowOf(ResponseBase(data = testData))
    initializeViewModel()
    advanceUntilIdle()  // ← delay(300) 안의 코루틴이 실행되지 않음!

    // 상태가 비어있음 (테스트 실패 또는 무의미한 assertion)
    val state = viewModel.container.uiState.value
    assertEquals(emptyList(), state.dataList)  // 항상 빈 리스트!
}
```

#### ✅ 올바른 방법: 3단계 스케줄러 제어

```kotlin
@Test
fun `초기화_시_직원목록_3명이_조회된다`() = runTest {
    // Given
    coEvery { shopRepository.getEmployeeList(any()) } returns flowOf(
        ResponseBase(data = listOf(
            EmployeeEntity(no = 1, name = "직원A"),
            EmployeeEntity(no = 2, name = "직원B"),
            EmployeeEntity(no = 3, name = "직원C")
        ))
    )

    // When
    initializeViewModel()
    testDispatcher.scheduler.runCurrent()      // 코루틴 시작
    testDispatcher.scheduler.advanceTimeBy(301) // delay(300) 처리
    testDispatcher.scheduler.advanceUntilIdle() // 나머지 작업 완료

    // Then: API 응답이 반영됨
    val employees = viewModel.container.uiState.value.employeeList
    assertEquals(3, employees.size)
    assertEquals("직원A", employees[0].name)
}
```

#### 스케줄러 제어 적용 규칙

```
Plan에서 그룹의 asyncType을 확인:
1. asyncType == "direct" → advanceUntilIdle() 사용
2. asyncType에 "viewModelLaunch" 또는 "apiFlow" 포함 → 3단계 스케줄러 사용
3. 확실하지 않으면 → 3단계 스케줄러 사용 (안전)

적용 위치:
- initializeViewModel() 직후 (init에서 API 호출하는 경우)
- viewModel.{비동기함수}() 호출 직후
```

### 7. NetworkResponse 5종 분기 테스트 (.response() 사용 함수)

⛔ **`.response()` 를 사용하는 함수는 내부적으로 NetworkResponse의 5개 sealed class로 분기됩니다.**
⛔ **최소 3종(Success + ApiError + NetworkError) 테스트가 필수입니다.**

#### NetworkResponse 5종 sealed class

```kotlin
// network 모듈의 NetworkResponse.kt
sealed class NetworkResponse<out T, out U> {
    data class Success<T>(val body: T) : NetworkResponse<T, Nothing>()
    data class SuccessNoBody<T>(val body: T) : NetworkResponse<T, Nothing>()
    data class ApiError<U>(val body: U, val isApiErrorCustom: Boolean) : NetworkResponse<Nothing, U>()
    data class NetworkError(val error: IOException) : NetworkResponse<Nothing, Nothing>()
    data class UnknownError(val error: Throwable?) : NetworkResponse<Nothing, Nothing>()
}
```

#### .response() 내부 분기 처리

```
.response(
    successCallFunc = { body -> /* Success, SuccessNoBody */ },
    apiErrorCallFunc = { body -> /* ApiError(isCustom=true) */ }
)
// ApiError(isCustom=false) → transferError(message)
// NetworkError, UnknownError → transferError(R.string.toast_retry)
```

#### 테스트 예시: .response() 함수의 3종 분기

```kotlin
// ✅ Success 경로
@Test
@DisplayName("결제요청_5000원_성공_시_screenState가_SUCCESS로_변경된다")
fun `결제요청_5000원_성공_시_screenState가_SUCCESS`() = runTest {
    // Given
    coEvery { repository.requestPayment(any()) } returns NetworkResponse.Success(
        PaymentResultEntity(success = true, transactionId = "TXN_001")
    )
    initializeViewModel()
    viewModel.updateAmount(TextFieldValue("5000"))
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // When
    viewModel.onClickPaymentRequest()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then
    assertEquals(ScreenState.SUCCESS, viewModel.container.uiState.value.screenState)
}

// ✅ ApiError 경로
@Test
@DisplayName("결제요청_API에러_코드_PAYMENT_FAILED_시_에러모달_표시")
fun `결제요청_API에러_시_에러모달_표시`() = runTest {
    // Given
    coEvery { repository.requestPayment(any()) } returns NetworkResponse.ApiError(
        body = ErrorResponse(code = "PAYMENT_FAILED", message = "결제 실패"),
        isApiErrorCustom = true
    )
    initializeViewModel()
    viewModel.updateAmount(TextFieldValue("5000"))
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // When
    viewModel.onClickPaymentRequest()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then
    assertNotNull(viewModel.container.uiState.value.confirmModalHost)
}

// ✅ NetworkError 경로
@Test
@DisplayName("결제요청_네트워크에러_시_재시도_토스트_표시")
fun `결제요청_네트워크에러_시_토스트_표시`() = runTest {
    // Given
    coEvery { repository.requestPayment(any()) } returns NetworkResponse.NetworkError(
        IOException("Network unreachable")
    )
    initializeViewModel()
    viewModel.updateAmount(TextFieldValue("5000"))
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // When
    viewModel.onClickPaymentRequest()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then: transferError가 호출되어 SideEffect 발생
    viewModel.container.uiSideEffect.test {
        val effect = awaitItem()
        assertTrue(effect is BaseUiSideEffect.ShowToast)
    }
}
```

### 8. ConfirmModalHost 콜백 트리거 (구체적 예시)

ConfirmModalHost는 SelectModalHost와 달리 **confirmBtnCallback/cancelBtnCallback** 두 가지 콜백을 가집니다.

#### ConfirmModalHost 구조

```kotlin
// ConfirmModalHost의 주요 콜백 필드
ConfirmModalHost(
    message = "삭제하시겠습니까?",
    confirmBtnCallback = { deleteItem() },     // 확인 버튼 콜백
    cancelBtnCallback = { cancelDelete() }     // 취소 버튼 콜백 (선택)
)
```

#### ✅ 올바른 테스트: 확인/취소 각각 트리거

```kotlin
// 확인 콜백 트리거
@Test
@DisplayName("삭제_확인모달에서_확인_클릭_시_아이템이_삭제된다")
fun `삭제_확인모달에서_확인_클릭_시_아이템이_삭제된다`() = runTest {
    // Given: 삭제 대상 아이템이 있는 상태
    setupMocksWithData()
    initializeViewModel()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // 삭제 모달 표시
    viewModel.onClickDelete(position = 0)
    advanceUntilIdle()

    val confirmModal = viewModel.container.uiState.value.confirmModalHost
    assertNotNull(confirmModal)

    // When: 확인 버튼 콜백 직접 트리거
    confirmModal!!.confirmBtnCallback?.invoke()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    // Then: 아이템이 삭제됨
    val items = viewModel.container.uiState.value.itemList
    assertTrue(items.none { it.position == 0 })
}

// 취소 콜백 트리거
@Test
@DisplayName("삭제_확인모달에서_취소_클릭_시_모달이_닫히고_아이템_유지")
fun `삭제_확인모달에서_취소_클릭_시_모달이_닫힌다`() = runTest {
    // Given
    setupMocksWithData()
    initializeViewModel()
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()

    viewModel.onClickDelete(position = 0)
    advanceUntilIdle()

    val confirmModal = viewModel.container.uiState.value.confirmModalHost
    assertNotNull(confirmModal)
    val itemCountBefore = viewModel.container.uiState.value.itemList.size

    // When: 취소 버튼 콜백 직접 트리거
    confirmModal!!.cancelBtnCallback?.invoke()
    advanceUntilIdle()

    // Then: 모달 닫히고 아이템 유지
    assertNull(viewModel.container.uiState.value.confirmModalHost)
    assertEquals(itemCountBefore, viewModel.container.uiState.value.itemList.size)
}
```

---

## Worker 출력 형식

### 단일 Worker 출력 (MockWebServer 패턴)

```kotlin
// === Worker Output: payment-validation ===

@Nested
@DisplayName("결제 검증 테스트")
inner class PaymentValidationTest {

    @Test
    @DisplayName("결제금액_50원_입력_시_최소금액_미만_에러모달_표시")
    fun `결제금액_50원_입력_시_최소금액_미만_에러모달_표시`() = runTest {
        // Given: setup()에서 MockWebServer + Real RepositoryImpl 이미 설정됨
        viewModel.updateStorePaymentAmount(TextFieldValue("50"))
        advanceUntilIdle()

        // When
        viewModel.onClickPaymentRequest()
        advanceUntilIdle()

        // Then
        val state = viewModel.container.uiState.value
        assertNotNull(state.confirmModalHost)
    }

    @Test
    @DisplayName("결제금액_99999원_입력_시_최대금액_10000원_초과_에러모달_표시")
    fun `결제금액_99999원_입력_시_최대금액_10000원_초과_에러모달_표시`() = runTest {
        // Given
        viewModel.updateStorePaymentAmount(TextFieldValue("99999"))
        advanceUntilIdle()

        // When
        viewModel.onClickPaymentRequest()
        advanceUntilIdle()

        // Then
        val state = viewModel.container.uiState.value
        assertNotNull(state.confirmModalHost)
    }

    @Test
    @DisplayName("결제금액_5000원_입력_후_결제요청_시_성공모달_표시")
    fun `결제금액_5000원_입력_후_결제요청_시_성공모달_표시`() = runTest {
        // Given: MockWebServer가 성공 JSON fixture로 자동 응답
        viewModel.updateStorePaymentAmount(TextFieldValue("5000"))
        advanceUntilIdle()

        // When
        viewModel.onClickPaymentRequest()
        testDispatcher.scheduler.runCurrent()
        testDispatcher.scheduler.advanceTimeBy(301)
        testDispatcher.scheduler.advanceUntilIdle()
        Thread.sleep(500)
        testDispatcher.scheduler.advanceUntilIdle()

        // Then
        val state = viewModel.container.uiState.value
        assertEquals(ScreenState.SUCCESS, state.screenState)
    }
}

// === End Worker Output ===
```

---

## 머지 프로세스

### 1. 모든 Worker 결과 수집

```
Worker A 출력 → InitializationTest @Nested
Worker B 출력 → PaymentValidationTest @Nested
Worker C 출력 → RefundFlowTest @Nested
Worker D 출력 → UIEventsTest @Nested
```

### 2. Scaffold 파일에 삽입

```kotlin
// Scaffold에서 생성된 기본 구조 (MockWebServer 패턴)
@ExperimentalCoroutinesApi
internal class NaverPayStorePaymentViewModelTest : BaseViewModelTest() {
    override val useMockWebServer = true
    // ... Real RepositoryImpl setup ...

    // === Worker A 결과 삽입 ===
    @Nested
    @DisplayName("초기화 테스트")
    inner class InitializationTest { ... }

    // === Worker B 결과 삽입 ===
    @Nested
    @DisplayName("결제 검증 테스트")
    inner class PaymentValidationTest { ... }

    // === Worker C 결과 삽입 ===
    @Nested
    @DisplayName("환불 흐름 테스트")
    inner class RefundFlowTest { ... }

    // === Worker D 결과 삽입 ===
    @Nested
    @DisplayName("UI 이벤트 테스트")
    inner class UIEventsTest { ... }
}
```

### 3. Import 문 병합

각 Worker가 사용한 import 문을 수집하여 중복 제거 후 파일 상단에 추가

---

## 테스트 네이밍 규칙

### ⛔ 금지: 추상적/모호한 테스트명

```kotlin
// ❌ 금지 - 추상적, 무엇을 테스트하는지 불명확
@DisplayName("최소 금액 미만 시 에러 모달이 표시된다")
@DisplayName("결제 요청 성공 시 처리된다")
@DisplayName("데이터 로드 시 상태가 변경된다")
@DisplayName("빈 리스트에서 호출 시 에러없이 실행")
```

### ✅ 필수: 구체적인 값과 결과를 명시

테스트명에는 반드시 **구체적인 입력값**과 **구체적인 결과**를 포함해야 합니다.

```kotlin
// ✅ 올바름 - 구체적인 값과 결과 명시
@DisplayName("결제금액을 50원으로 입력하면 최소금액_100원_미만_에러_모달이_표시된다")
@DisplayName("결제금액_5000원_입력_후_결제요청_시_API호출되고_성공모달_표시된다")
@DisplayName("카드결제_50000원_선택_시_paymentList의_0번째_amount가_50000으로_설정된다")
@DisplayName("시술탭에서_커트_카테고리_선택_시_procedureSelectList에_커트_아이템이_추가된다")
```

### 테스트명 작성 공식

```
[대상]_[구체적입력값]_[동작]_시_[구체적결과]_[상태변화]
```

**예시:**
| 추상적 (금지) | 구체적 (필수) |
|-------------|--------------|
| 금액 변경 시 업데이트된다 | 결제금액을_50000원으로_변경하면_paymentAmount가_50000으로_표시된다 |
| 직원 선택 시 추가된다 | 직원목록에서_홍길동_선택_시_selectEmployees에_홍길동이_추가된다 |
| 에러 발생 시 모달 표시 | API응답_code가_PAYMENT_FAILED일때_에러메시지_결제실패_모달이_표시된다 |
| 탭 변경 시 상태 변경 | PRODUCT탭_클릭_시_currentTab이_SaleTab.PRODUCT로_변경된다 |
| 취소 버튼 클릭 시 처리 | PAGE_FIRST에서_취소클릭_시_OnClickBack_SideEffect가_발생한다 |

### 함수명 (백틱 한글)

```kotlin
fun `결제금액을_50원으로_입력하면_최소금액_100원_미만_에러_모달이_표시된다`()
fun `결제금액_5000원_입력_후_결제요청_시_API호출되고_성공모달_표시된다`()
fun `시술탭에서_커트_중분류_선택_후_onClick콜백_실행_시_커트_소분류_모달이_표시된다`()
```

---

## 에러 방지 규칙

### ✅ 필수

1. **runTest 사용**: 모든 테스트는 `= runTest { }` 블록 내에서
2. **advanceUntilIdle()**: 비동기 작업 후 반드시 호출
3. **3단계 스케줄러**: `viewModelLaunch`/`apiFlow` 사용 함수는 `runCurrent()` → `advanceTimeBy(301)` → `advanceUntilIdle()` 필수
4. **MockWebServer 기반 테스트**: `useMockWebServer = true` + Real RepositoryImpl 사용. JSON fixture가 API 응답 데이터를 관리
5. **Thread.sleep(500)**: MockWebServer HTTP 응답 후 추가 대기. 스케줄러 advance만으로는 HTTP I/O 완료 보장 불가
6. **Turbine test**: SideEffect 테스트 시 `.test { }` 블록 사용
7. **콜백 트리거**: 모달/다이얼로그의 onClick/confirmBtnCallback 콜백 내 private 함수는 반드시 콜백을 직접 실행하여 테스트
8. **사전 상태 구축**: setup()에서 JSON fixture 데이터가 로드된 상태에서 테스트 시작
9. **구체적 assertion**: `assertNotNull(state)`가 아닌 구체적인 값 비교 (`assertEquals(50000, state.amount)`)
10. **구체적 테스트명**: 추상적 표현 금지, 입력값과 결과를 명시
11. **함수당 다중 테스트**: 함수 1개에 테스트 1개만 쓰지 말 것. 분기당 1개 이상, 최소 2개
12. **NetworkResponse 분기**: `.response()` 사용 함수는 최소 Success + ApiError + NetworkError 3종 테스트 필수
13. **에러 테스트**: `mockWebServer.dispatchResponse(apiResult = "apiError")` 활용

### ⛔ 금지 (절대 생성 금지)

1. **Private 함수 직접 호출**: 컴파일 에러 발생
2. **Entity 하드코딩**: `coEvery { repo.method() } returns 하드코딩Entity` 금지. JSON fixture 사용
3. **sleep/delay 직접 사용**: advanceTimeBy() 사용 (단, MockWebServer HTTP 대기용 Thread.sleep(500)은 예외)
4. **verify 순서 강제**: 불필요한 verifyOrder 지양
5. **콜백 미트리거 테스트**: 모달 설정만 하고 onClick/confirmBtnCallback 호출하지 않는 "가짜" 테스트 작성 금지
6. **"에러없이 실행" 테스트**: `assertNotNull(state)` 같은 무의미한 assertion 금지
7. **빈 상태 테스트**: 빈 리스트에서 함수 호출 후 "아무 일도 안 일어남"을 검증하는 테스트 금지
8. **추상적 테스트명**: "~시 처리된다", "~시 동작한다" 같은 모호한 표현 금지
9. **Mock Repository에 coEvery 설정**: Real RepositoryImpl + MockWebServer를 사용하므로 coEvery 불필요
10. **함수당 테스트 1개만**: 분기가 있는 함수에 테스트 1개만 작성하는 것 금지
11. **advanceUntilIdle()만으로 viewModelLaunch 테스트**: delay(300)을 넘기지 못하므로 3단계 스케줄러 필수
12. **.response() 함수에 Success만 테스트**: ApiError, NetworkError 경로 누락 금지

---

## ⛔ 안티패턴 상세 (절대 생성 금지)

### 안티패턴 1: "에러없이 실행" 테스트

```kotlin
// ❌ 절대 금지 - 이런 테스트를 생성하면 안 됨
@Test
@DisplayName("빈 리스트에서 호출 시 에러없이 실행")
fun `빈리스트에서_호출_시_에러없이_실행`() = runTest {
    initializeViewModel()
    advanceUntilIdle()

    viewModel.onClickItemEmployee(0)  // 빈 리스트 → early return
    advanceUntilIdle()

    assertNotNull(viewModel.container.uiState.value)  // 무의미한 assertion
}
```

**문제점:**
- 빈 리스트에서 호출하면 early return으로 실제 로직이 실행되지 않음
- `assertNotNull(state)`는 항상 true (UiState는 항상 존재)
- 라인/분기 커버리지 0%

**올바른 대체:**
```kotlin
// ✅ 올바름 - 데이터가 있는 상태에서 실제 로직 검증
@Test
@DisplayName("직원목록_3번째_홍길동_선택_시_selectEmployees에_홍길동이_추가된다")
fun `직원목록_3번째_홍길동_선택_시_selectEmployees에_홍길동이_추가된다`() = runTest {
    // Given: 직원 목록이 있는 상태
    coEvery { employeeListUseCase.execute(any()) } returns flowOf(
        Result.Success(listOf(
            EmployeeEntity(no = 1, name = "김철수"),
            EmployeeEntity(no = 2, name = "이영희"),
            EmployeeEntity(no = 3, name = "홍길동")
        ))
    )
    initializeViewModel()
    advanceUntilIdle()

    // When: 3번째 직원(홍길동) 선택
    viewModel.onClickItemEmployee(2)
    advanceUntilIdle()

    // Then: 홍길동이 선택된 직원 목록에 추가됨
    val selectedEmployees = viewModel.container.uiState.value.selectEmployees
    assertTrue(selectedEmployees.any { it.name == "홍길동" })
    assertEquals(3, selectedEmployees.find { it.name == "홍길동" }?.no)
}
```

### 안티패턴 2: 콜백 미트리거

```kotlin
// ❌ 절대 금지 - 모달 표시만 확인하고 끝
@Test
@DisplayName("시술 중분류 모달 표시")
fun `시술_중분류_모달_표시`() = runTest {
    initializeViewModel()
    viewModel.showProcedureMedium()
    advanceUntilIdle()

    assertTrue(viewModel.container.uiState.value.selectModalHost.isShowSelectModal)
    // onClick 콜백 미실행 → showProcedureSmall, addCategory 미커버!
}
```

**올바른 대체:**
```kotlin
// ✅ 올바름 - 콜백까지 실행하여 내부 로직 검증
@Test
@DisplayName("시술_중분류에서_커트_선택_후_onClick콜백_실행_시_커트_소분류_목록이_표시된다")
fun `시술_중분류에서_커트_선택_후_onClick콜백_실행_시_커트_소분류_목록이_표시된다`() = runTest {
    // Given: 중분류 목록이 있는 상태
    coEvery { cosmeticRepository.getCategoriesMedium(any()) } returns flowOf(
        ResponseBase(data = listOf(
            CosmeticCategoryEntity(id = 1, name = "커트"),
            CosmeticCategoryEntity(id = 2, name = "펌")
        ))
    )
    initializeViewModel()
    advanceUntilIdle()

    viewModel.showProcedureMedium()
    advanceUntilIdle()

    // When: 커트 중분류 선택 콜백 트리거
    val modalHost = viewModel.container.uiState.value.selectModalHost
    val cutCategory = SelectModalVo(id = "1", content = "커트")
    modalHost.onClick?.invoke(cutCategory)
    advanceUntilIdle()

    // Then: 커트 소분류 모달이 표시됨 (showProcedureSmall 호출됨)
    val updatedModal = viewModel.container.uiState.value.selectModalHost
    assertTrue(updatedModal.isShowSelectModal)
    // 소분류 API 호출 검증
    coVerify { cosmeticRepository.getCategoriesSmall(1, any()) }
}
```

### 안티패턴 3: 추상적 테스트명

```kotlin
// ❌ 금지 - 무엇을 테스트하는지 불명확
@DisplayName("금액 변경 시 상태가 업데이트된다")
@DisplayName("결제 처리가 성공한다")
@DisplayName("데이터 로드 후 표시된다")
```

**올바른 대체:**
```kotlin
// ✅ 올바름 - 구체적인 입력값과 결과
@DisplayName("결제금액을_50000원으로_변경하면_salePaymentModel의_totalAmount가_50000으로_설정된다")
@DisplayName("카드결제_10000원_현금결제_5000원_선택_시_총결제금액이_15000원으로_계산된다")
@DisplayName("고객번호_CUST001로_조회_시_고객명이_홍길동으로_표시된다")
```

---

## Worker 완료 시 출력

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Worker [{groupId}] 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 생성 결과:
- @Nested 클래스: {클래스명}Test
- 테스트 케이스: {N}개
- Private 분기 커버리지: {M}개

📝 코드:
```kotlin
{생성된 @Nested 클래스 코드}
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Phase 5: 보충 테스트 생성 포맷 (라인레벨 커버리지 기반)

Phase 5에서는 JaCoCo 소스 HTML(`.kt.html`)에서 파싱한 **라인별 미커버 데이터**를 활용하여 정밀한 보충 테스트를 생성합니다.

### 입력: uncoveredBlocks (5-A에서 생성)

```json
{
  "uncoveredBlocks": [
    {
      "function": "onClickItemCountChange",
      "lines": "L243-L265",
      "ncLines": [245, 248, 249, 250, 251, 253, 256, 257, 259, 260, 261, 263],
      "pcLines": [{"line": 243, "missed": 2, "total": 4, "code": "when (uiState.currentTab)"}],
      "rootCause": "PRODUCT 탭 분기 미실행",
      "fix": "currentTab=PRODUCT 상태 설정 + productSelectList mock 데이터 필요"
    }
  ]
}
```

### 라인레벨 데이터 → 테스트 설계 매핑

| JaCoCo 데이터 | 테스트 설계 방향 |
|--------------|----------------|
| `nc` 라인이 함수 전체 | 함수 자체를 호출하는 테스트 추가 |
| `nc` 라인이 특정 분기 내부만 | 해당 분기 조건을 만족시키는 테스트 추가 |
| `pc bpc "2 of 4 branches missed"` | 미커버 2개 분기에 대해 각각 테스트 추가 |
| `pc bpc "1 of 2 branches missed"` | when/if의 다른 경로(else/false) 테스트 추가 |
| `nc` 라인이 콜백 람다 내부 | onClick/onConfirm을 직접 invoke하는 테스트 추가 |
| `nc` 라인이 API 응답 처리 블록 | coEvery로 해당 API 응답 mock 설정 후 호출 |

### 보충 테스트 구조

```kotlin
// === Phase 5 보충 테스트 (Iteration {N}) ===
@Nested
@DisplayName("보충{N}: {미커버 영역} 커버리지 개선")
inner class SupplementaryCoverage{N}Test {

    /**
     * 타겟: {함수명} (L{시작}-L{끝})
     * 미커버: nc {N}줄, pc {M}곳
     * 원인: {rootCause}
     * 수정: {fix}
     */
    @Test
    @DisplayName("{구체적 테스트명 - 라인번호 기반}")
    fun `PRODUCT탭_아이템카운트_변경_시_productSelectList_getOrNull_실행`() = runTest {
        // Given: uncoveredBlocks.fix에서 요구하는 조건 설정
        // L243: when(uiState.currentTab) → PRODUCT 분기를 타려면 currentTab = PRODUCT
        coEvery { productRepository.getProducts(any()) } returns flowOf(
            ResponseBase(data = listOf(ProductEntity(no = 1, name = "샴푸", price = 15000)))
        )
        initializeViewModel()
        viewModel.updateTab(SaleTab.PRODUCT)
        advanceUntilIdle()

        // When: L245-L265 미커버 블록으로 진입
        viewModel.onClickItemCountChange(position = 0, textFieldValue = TextFieldValue("3"))
        advanceUntilIdle()

        // Then: L249-L251 실행 확인 (updateItemCountChange 호출됨)
        val products = viewModel.container.uiState.value.saleRegisterModel.productSelectList
        assertEquals(3, products[0].count)
    }

    /**
     * 타겟: L130 "2 of 4 branches missed"
     * 미커버 분기: savedStateHandle에 SALE_NO가 있을 때 (MODIFY 경로)
     */
    @Test
    @DisplayName("SALE_NO_존재_시_SaleType이_MODIFY로_설정된다")
    fun `SALE_NO_존재_시_SaleType이_MODIFY`() = runTest {
        // Given: L130의 미커버 분기 조건 설정
        every { savedStateHandle.get<String>(SALE_NO) } returns "12345"

        // When
        initializeViewModel()
        advanceUntilIdle()

        // Then: L130의 SaleType.MODIFY 분기 실행
        assertEquals(SaleType.MODIFY, viewModel.container.uiState.value.saleType)
    }
}
```

### 보충 테스트 필수 규칙

1. **라인번호 기반 설계**: 각 테스트의 주석에 타겟 라인(L{번호})과 미커버 원인 명시
2. **uncoveredBlocks.fix 반영**: 5-A에서 분석한 fix 전략을 그대로 코드로 구현
3. **분기별 개별 테스트**: `pc bpc "N of M branches missed"` → 미커버 N개 분기에 대해 각각 1개 테스트
4. **Mock 데이터 필수**: 모든 보충 테스트는 `coEvery`로 실제 데이터 반환 설정
5. **기존 테스트와 중복 금지**: 이미 `fc`인 라인/분기를 다시 테스트하지 않음
6. **각 미커버 블록에 최소 2개 테스트**: 정상 경로 + 엣지 케이스
7. **우선순위**: ncLines가 많은 블록 → pcLines의 missed가 높은 블록 순서로 작성
