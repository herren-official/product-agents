---
name: unittest-agent-scaffold
description: 테스트 파일 기본 구조 생성 (Mock 선언, BaseViewModelTest 상속)
allowed-tools: Read, Write, Grep, Glob
user-invocable: false
---

# Test Scaffold Generator

테스트 파일이 없을 때 기본 구조를 생성합니다.

---

## 실행 조건

```
Plan의 hasExistingTest == false 일 때만 실행
```

---

## 생성 프로세스

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: 의존성 분석                                             │
├─────────────────────────────────────────────────────────────────┤
│  • ViewModel 생성자 파라미터 추출                                 │
│  • Repository, UseCase, Helper 등 식별                          │
│  • SavedStateHandle 사용 여부 확인                               │
└────────────────────────┬────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: Mock 선언 생성                                          │
├─────────────────────────────────────────────────────────────────┤
│  • 각 의존성에 대한 lateinit var 선언                             │
│  • mockk(relaxed = true) 기본 사용                               │
│  • coEvery 기본 설정 (필요시)                                     │
└────────────────────────┬────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: 테스트 클래스 생성                                       │
├─────────────────────────────────────────────────────────────────┤
│  • BaseViewModelTest 상속                                        │
│  • @ExperimentalCoroutinesApi 어노테이션                         │
│  • @ExtendWith(InstantTaskExecutorExtension::class)             │
│  • setup() 메서드 구현                                           │
└────────────────────────┬────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: Helper 메서드 생성                                       │
├─────────────────────────────────────────────────────────────────┤
│  • createViewModel() 또는 initializeViewModel()                  │
│  • createTest{Entity}() 테스트 데이터 팩토리 (실코드 생성!)        │
│  • setupDefaultMocks() 공통 Mock 설정 메서드 (실코드 생성!)       │
│  ⛔ 주석이 아닌 실제 함수를 생성해야 함!                           │
│  ⛔ PLANNER의 mockDataRequirements를 반드시 참조                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 1: 의존성 분석

### 1.1 생성자 파라미터 추출

```kotlin
// ViewModel 예시
class NaverPayStorePaymentViewModel(
    private val naverPayStorePaymentRepository: NaverPayStorePaymentRepository,  // Repository
    private val naverPayAuthCheckUseCase: NaverPayAuthCheckUseCase,              // UseCase
    private val savedStateHandle: SavedStateHandle                               // SavedStateHandle
) : BaseViewModel()
```

### 1.2 분석 결과

```json
{
  "dependencies": [
    {
      "name": "naverPayStorePaymentRepository",
      "type": "NaverPayStorePaymentRepository",
      "category": "repository",
      "mockType": "relaxed"
    },
    {
      "name": "naverPayAuthCheckUseCase",
      "type": "NaverPayAuthCheckUseCase",
      "category": "useCase",
      "mockType": "relaxed"
    }
  ],
  "useSavedStateHandle": true,
  "useSharedPreferences": true,
  "savedStateHandleArgs": [
    { "key": "bookNo", "type": "String", "defaultValue": "\"test_book_no\"" },
    { "key": "maxAmount", "type": "Long", "defaultValue": "100000L" }
  ]
}
```

---

## Step 2: MockWebServer + Real RepositoryImpl 설정

⛔ **Kotlin 코드에 Mock 데이터를 하드코딩하지 않습니다.**
⛔ **MockWebServer가 JSON fixture 파일로 HTTP 응답 → Retrofit+Gson 자동 파싱 → Real RepositoryImpl → ViewModel.**

### 2.1 MockWebServer 패턴 (권장, 기본)

```kotlin
// BaseViewModelTest의 MockWebServer 옵션 활성화
override val useMockWebServer: Boolean = true

// setup()에서 Real RepositoryImpl 생성
val saleRepository = SaleRepositoryImpl(MockWebServerService.saleService(mockWebServer))
val shopRepository = ShopRepositoryImpl(MockWebServerService.shopService(mockWebServer))
val employeeRepository = EmployeeRepositoryImpl(MockWebServerService.employeeService(mockWebServer))
// ... 모든 Repository를 real impl로 생성

// ViewModel에 real repository 전달
viewModel = SaleViewModel(
    saleRepository = saleRepository,
    shopRepository = shopRepository,
    employeeRepository = employeeRepository,
    savedStateHandle = mockSavedStateHandle,
    resourceProvider = mockResourceProvider
)
```

> **데이터 흐름**: JSON fixture → MockWebServer → HTTP → Retrofit+Gson → Entity → Real RepositoryImpl → ViewModel

### 2.2 Mock 패턴 (MockWebServer 미지원 시 폴백)

특정 Repository/UseCase가 MockWebServerService에 팩토리 메서드가 없거나,
MockWebServer로 시뮬레이션하기 어려운 경우에만 mock 사용:

```kotlin
// MockWebServer에 없는 서비스만 mock
private lateinit var specialUseCase: SpecialUseCase

// setup()에서
specialUseCase = mockk(relaxed = true)
```

### 2.3 하이브리드 패턴 (권장)

대부분의 Repository는 Real RepositoryImpl, 특수한 UseCase만 mock:

```kotlin
override val useMockWebServer: Boolean = true

override fun setup() {
    // Real RepositoryImpl (MockWebServer 기반)
    val saleRepository = SaleRepositoryImpl(MockWebServerService.saleService(mockWebServer))

    // Mock (특수한 경우만)
    val specialUseCase = mockk<SpecialUseCase>(relaxed = true)

    viewModel = ViewModel(
        saleRepository = saleRepository,       // real
        specialUseCase = specialUseCase         // mock
    )
}
```

---

## Step 3: 테스트 클래스 템플릿

### 3.1 기본 템플릿 (MockWebServer + Real RepositoryImpl)

```kotlin
package com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{패키지경로}

import app.cash.turbine.test
import com.gongnailshop.herren_dell1.gongnailshop.base.BaseViewModelTest
import com.gongnailshop.herren_dell1.gongnailshop.ui.{패키지경로}.{ViewModel명}
import com.gongnailshop.herren_dell1.gongnailshop.ui.{패키지경로}.{Contract명}.*
import com.gongnailshop.herren_dell1.gongnailshop.utils.MockWebServerService
import com.gongnailshop.herren_dell1.gongnailshop.utils.dispatchResponse
// Real RepositoryImpl imports
import com.gongbiz.network.api.{도메인}.repository.{Repository}Impl
// ... 필요한 RepositoryImpl import
import io.mockk.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExperimentalCoroutinesApi
@ExtendWith(InstantTaskExecutorExtension::class)
@DisplayName("{ViewModel명} 단위 테스트")
internal class {ViewModel명}Test : BaseViewModelTest() {

    // === BaseViewModelTest 설정 ===
    override val useSharedPreferencesMock: Boolean = true
    override val useSavedStateHandleMock: Boolean = true
    // MockWebServer 활성화 → JSON fixture 기반 real RepositoryImpl 사용
    override val useMockWebServer: Boolean = true

    // === ViewModel ===
    private lateinit var viewModel: {ViewModel명}

    @BeforeEach
    override fun setup() {
        super.setup()

        // SharedPreferences 기본 설정
        sharedPreferencesHelper.setupStringReturn("jwt", "test_jwt_token")
        sharedPreferencesHelper.setupStringReturn("shopNo", "test_shop_no")
        sharedPreferencesHelper.setupIntReturn("employeeNo", 100)

        // SavedStateHandle 기본 설정
        // setupSavedStateValues("bookNo" to "test_book_no")

        // Real RepositoryImpl 생성 (MockWebServer 기반)
        val repository1 = Repository1Impl(MockWebServerService.repository1Service(mockWebServer))
        val repository2 = Repository2Impl(MockWebServerService.repository2Service(mockWebServer))
        // ... PLANNER의 apiEndpoints에서 분석한 모든 Repository

        // ViewModel 생성 (모든 Repository가 실제 구현체)
        viewModel = {ViewModel명}(
            repository1 = repository1,
            repository2 = repository2,
            savedStateHandle = mockSavedStateHandle,
            resourceProvider = mockResourceProvider
        )
        initializeBaseViewModelDependencies(viewModel)

        // 3단계 스케줄러 (init에서 API 호출하는 경우)
        testDispatcher.scheduler.runCurrent()
        testDispatcher.scheduler.advanceTimeBy(301)
        testDispatcher.scheduler.advanceUntilIdle()
        Thread.sleep(500) // MockWebServer HTTP 응답 대기
        testDispatcher.scheduler.advanceUntilIdle()
    }

    // === 여기서부터 Generator가 채움 ===
    // @Nested inner class들이 추가됨
}
```

> **핵심 변경**: `testMockProvider` + `coEvery` 대신 `MockWebServerService.xxxService(mockWebServer)` + `XxxRepositoryImpl`을 사용합니다.
> **JSON fixture 데이터**: `network/src/testFixtures/resources/{domain}/` 에 위치한 JSON 파일이 MockWebServer auto-dispatch로 자동 응답합니다.
> **Thread.sleep(500)**: MockWebServer는 실제 HTTP 소켓 통신을 사용하므로, 스케줄러 advance 후 HTTP I/O 완료 대기가 필요합니다.

### 3.2 SavedStateHandle 설정 패턴

```kotlin
// 방법 1: setupSavedStateHandle 헬퍼 사용
override fun setup() {
    super.setup()
    setupSavedStateHandle(
        "bookNo" to "test_book_no",
        "maxAmount" to 100000L
    )
}

// 방법 2: 직접 설정
override fun setup() {
    super.setup()
    every { savedStateHandle.get<String>("bookNo") } returns "test_book_no"
    every { savedStateHandle.get<Long>("maxAmount") } returns 100000L
}
```

---

## Step 4: Helper 메서드 생성 (MockWebServer 패턴)

### 4.1 MockWebServer 응답 제어 헬퍼

MockWebServer auto-dispatch는 기본적으로 성공 응답(200)을 반환합니다.
에러 테스트나 특정 시나리오에서는 응답을 수동으로 제어해야 합니다.

```kotlin
// 에러 응답 설정 (특정 테스트에서만 사용)
private fun setupApiError() {
    // auto-dispatch를 apiError 모드로 변경
    mockWebServer.dispatchResponse(apiResult = "apiError")
}

// 특정 endpoint에 대한 수동 응답 큐잉
private fun enqueueCustomResponse(folder: String, fileName: String, code: Int = 200) {
    mockWebServer.enqueueResponse(folder, fileName, code)
}
```

### 4.2 별도 ViewModel 생성 (특수 테스트용)

특정 테스트에서 다른 JSON fixture나 mock 설정이 필요한 경우,
별도의 ViewModel을 생성하여 사용합니다.

```kotlin
// 특수 테스트용: 다른 MockWebServer 설정으로 ViewModel 재생성
private fun createViewModelWithErrorResponse(): {ViewModel명} {
    // 에러 응답 설정
    mockWebServer.dispatchResponse(apiResult = "apiError")

    val repository = RepositoryImpl(MockWebServerService.repositoryService(mockWebServer))
    return {ViewModel명}(
        repository = repository,
        savedStateHandle = mockSavedStateHandle
    ).also {
        initializeBaseViewModelDependencies(it)
    }
}
```

### 4.3 스케줄러 제어 헬퍼

```kotlin
// 3단계 스케줄러 + MockWebServer HTTP 대기
private fun advanceSchedulerWithHttpWait() {
    testDispatcher.scheduler.runCurrent()
    testDispatcher.scheduler.advanceTimeBy(301)
    testDispatcher.scheduler.advanceUntilIdle()
    Thread.sleep(500) // MockWebServer HTTP I/O 대기
    testDispatcher.scheduler.advanceUntilIdle()
}
```

> **핵심**: MockWebServer 패턴에서는 `coEvery` 하드코딩 대신 JSON fixture 파일이 테스트 데이터를 관리합니다.
> Entity 변경 시 JSON 파일만 수정하면 되므로 유지보수성이 크게 향상됩니다.

---

## 출력 파일

```
app/src/test/java/com/gongnailshop/herren_dell1/gongnailshop/viewmodel/{패키지경로}/{ViewModel명}Test.kt
```

---

## 예시: 생성된 Scaffold (MockWebServer 패턴)

```kotlin
@ExperimentalCoroutinesApi
@ExtendWith(InstantTaskExecutorExtension::class)
@DisplayName("NaverPayStorePaymentViewModel 단위 테스트")
internal class NaverPayStorePaymentViewModelTest : BaseViewModelTest() {

    override val useSharedPreferencesMock: Boolean = true
    override val useSavedStateHandleMock: Boolean = true
    override val useMockWebServer: Boolean = true

    private lateinit var viewModel: NaverPayStorePaymentViewModel

    @BeforeEach
    override fun setup() {
        super.setup()

        sharedPreferencesHelper.setupStringReturn("jwt", "test_jwt_token")
        sharedPreferencesHelper.setupStringReturn("shopNo", "test_shop_no")

        setupSavedStateValues(
            "bookNo" to "test_book_no",
            "maxAmount" to 100000L
        )

        // Real RepositoryImpl (MockWebServer 기반)
        val repository = NaverPayStorePaymentRepositoryImpl(
            MockWebServerService.naverPayStorePaymentService(mockWebServer)
        )
        val authCheckUseCase = NaverPayAuthCheckUseCase(repository, testDispatcher)

        viewModel = NaverPayStorePaymentViewModel(
            naverPayStorePaymentRepository = repository,
            naverPayAuthCheckUseCase = authCheckUseCase,
            savedStateHandle = mockSavedStateHandle
        )
        initializeBaseViewModelDependencies(viewModel)

        // 3단계 스케줄러 + HTTP 대기
        testDispatcher.scheduler.runCurrent()
        testDispatcher.scheduler.advanceTimeBy(301)
        testDispatcher.scheduler.advanceUntilIdle()
        Thread.sleep(500)
        testDispatcher.scheduler.advanceUntilIdle()
    }

    // === Generator가 여기에 @Nested 클래스들을 추가 ===
}
```

---

## 체크리스트

Scaffold 생성 시 확인할 사항:

- [ ] 패키지 경로가 ViewModel과 일치하는가?
- [ ] BaseViewModelTest 상속이 올바른가?
- [ ] `useMockWebServer = true` 설정이 되어 있는가?
- [ ] 모든 생성자 의존성에 대해 Real RepositoryImpl이 생성되었는가?
- [ ] MockWebServerService에 해당 Service 팩토리 메서드가 있는가?
- [ ] 필요한 JSON fixture 파일이 `network/src/testFixtures/resources/` 에 존재하는가?
- [ ] SavedStateHandle 인자가 모두 설정되었는가?
- [ ] SharedPreferences 기본값이 설정되었는가?
- [ ] `initializeBaseViewModelDependencies(viewModel)` 호출이 있는가?
- [ ] 3단계 스케줄러 + `Thread.sleep(500)` + 추가 `advanceUntilIdle()`이 setup에 있는가?
- [ ] import 문이 완전한가? (RepositoryImpl, MockWebServerService, dispatchResponse 등)
