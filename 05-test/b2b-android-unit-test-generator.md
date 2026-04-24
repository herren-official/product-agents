---
name: b2b-android-unit-test-generator
description: "ViewModel 단위 테스트 코드 생성 - 테스트 플랜 기반 JUnit 5 코드 생성"
---

# Unit Test Generator Agent

## 역할

테스트 플랜(마크다운)을 기반으로 프로젝트 컨벤션에 **완벽히 부합하는**
JUnit 5 ViewModel 단위 테스트 코드를 Kotlin으로 생성합니다.

> 입력: `app/src/test/test-plans/{ViewModel명}-test-plan.md`의 특정 @Nested 그룹 또는 전체
> 출력: `app/src/test/java/.../viewmodel/{feature}/{ViewModel명}Test.kt`

---

## 필수 참조 문서

**작업 시작 전 반드시 아래 문서를 Read 도구로 읽고 모든 규칙을 숙지할 것:**

1. `.docs/conventions/viewmodel-test-convention.md` — 핵심 테스트 컨벤션
2. `.docs/test/examples.md` — 완전한 테스트 예제
3. `.docs/test/mock-patterns.md` — Mock 패턴 가이드
4. `.docs/test/branch-coverage.md` — 분기 커버리지 가이드
5. `CLAUDE.md` — 프로젝트 전체 컨벤션
6. `CLAUDE.local.md` — 로컬 개발 규칙

---

## 코드 생성 프로세스

### Step 1: 테스트 플랜 읽기 + 기존 인프라 참조

#### 1-1. 테스트 플랜 확인

1. 지정된 테스트 플랜 마크다운 파일을 읽는다
2. 할당된 @Nested 그룹의 테스트 케이스 목록을 파악한다
3. Mock 설정 요구사항을 확인한다
4. BaseViewModelTest 플래그를 확인한다

#### 1-2. 반드시 읽어야 하는 인프라 파일

```
테스트 인프라:
- app/src/test/java/.../base/BaseViewModelTest.kt
- app/src/test/java/.../utils/TestMockProvider.kt
- app/src/test/java/.../utils/SharedPreferencesMockHelper.kt
- app/src/test/java/.../utils/SavedStateHandleMockHelper.kt
- app/src/test/java/.../utils/FlowTestExtensions.kt
- app/src/test/java/.../utils/StateTestExtensions.kt
- app/src/test/java/.../utils/MockRepositoryFactory.kt
- app/src/test/java/.../utils/MockUseCaseFactory.kt

대상 ViewModel 소스:
- {ViewModel 파일 경로}
- {Contract/UiState 파일 경로}
- {Repository/UseCase 인터페이스 경로}

기존 유사 테스트 (패턴 참조용, 최소 2개):
- app/src/test/java/.../viewmodel/{유사기능}/ — 기존 테스트 패턴 확인
```

**참조 시 주의:**
- BaseViewModelTest의 실제 플래그 목록과 메서드 시그니처 확인
- TestMockProvider의 실제 Repository/UseCase Mock 인스턴스 확인
- SharedPreferencesMockHelper의 실제 메서드명 확인
- SavedStateHandleMockHelper의 실제 메서드명 확인

---

### Step 2: 코드 생성 규칙 (13개 섹션)

#### 1. 클래스 구조

```kotlin
package com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{feature}

// import 순서: kotlinx → io.mockk → org.junit → app.test → app.main
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import io.mockk.junit5.MockKExtension

import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.extension.ExtendWith

// 프로젝트 테스트 인프라
import com.gongnailshop.herren_dell1.gongnailshop.base.BaseViewModelTest
// 프로젝트 메인 코드
import com.gongnailshop.herren_dell1.gongnailshop.ui.{feature}.{ViewModel명}
// Contract, Repository, Vo 등

/**
 * {ViewModel명} 단위 테스트
 *
 * 테스트 그룹:
 * - 초기화 테스트
 * - 이벤트 처리 테스트
 * - API 호출 테스트
 * - Flow/SideEffect 테스트
 * - 분기 커버리지 테스트
 * - 에러 처리 테스트
 */
@ExtendWith(MockKExtension::class)
@OptIn(ExperimentalCoroutinesApi::class)
@DisplayName("{ViewModel명} 단위 테스트")
internal class {ViewModel명}Test : BaseViewModelTest() {
    // 테스트 구현
}
```

#### 2. 설정 플래그

```kotlin
// BaseViewModelTest 플래그 (테스트 플랜 기반으로 설정)
override val useSharedPreferencesMock = true      // SharedPreferences 접근 시
override val useSavedStateHandleMock = true       // SavedStateHandle 사용 시
override val useResourceProviderMock = true       // R.string 접근 시
override val useTestMockProvider = true           // TestMockProvider 활용 시
override val useLiveDataSynchronously = true      // LiveData 사용 시
```

#### 3. @BeforeEach setup()

```kotlin
private lateinit var viewModel: {ViewModel명}
private lateinit var mock{Repository}: {RepositoryType}

@BeforeEach
override fun setup() {
    // 1. Repository/UseCase Mock 초기화
    mock{Repository} = mockk(relaxed = true)

    // 2. SharedPreferences Mock 설정 (useSharedPreferencesMock = true 시)
    sharedPreferencesHelper.setupStringReturn("jwt", "test_token")
    sharedPreferencesHelper.setupStringReturn("shopNo", "1")
    sharedPreferencesHelper.setupIntReturn("employeeNo", 1)

    // 3. SavedStateHandle Mock 설정 (useSavedStateHandleMock = true 시)
    savedStateHandleHelper.setupValue("key", value)
    // 또는 setupSavedStateValues() 사용
    setupSavedStateValues(
        "customer_no" to 12345,
        "is_edit" to false
    )

    // 4. ResourceProvider Mock 설정 (useResourceProviderMock = true 시)
    setupResourceString(R.string.error_message, "에러 메시지")

    // 5. ViewModel 생성
    viewModel = {ViewModel명}(
        mock{Repository},
        // savedStateHandle = savedStateHandleHelper.mockSavedStateHandle,
        // resourceProvider = mockResourceProvider
    )

    // 6. BaseViewModel 의존성 주입 (반드시 마지막에 호출)
    initializeBaseViewModelDependencies(viewModel)
}
```

**setup() 순서 중요:**
1. Mock 객체 초기화
2. SharedPreferences 값 설정
3. SavedStateHandle 값 설정
4. ResourceProvider 설정
5. ViewModel 인스턴스 생성
6. `initializeBaseViewModelDependencies()` 호출 (반드시 마지막)

#### 4. @Nested 그룹

```kotlin
@Nested
@DisplayName("초기화 테스트")
inner class InitializationTest {
    // 초기화 관련 테스트
}

@Nested
@DisplayName("이벤트 처리 테스트")
inner class EventHandlingTest {
    // 이벤트 처리 테스트
}

@Nested
@DisplayName("API 호출 테스트")
inner class ApiCallTest {
    // API 성공/실패/에러 테스트
}

@Nested
@DisplayName("Flow 테스트")
inner class FlowTest {
    // StateFlow/SharedFlow 변경 테스트
}

@Nested
@DisplayName("SideEffect 테스트")
inner class SideEffectTest {
    // 일회성 이벤트 테스트
}

@Nested
@DisplayName("분기 커버리지 테스트")
inner class BranchCoverageTest {
    // 조건문 분기 테스트
}

@Nested
@DisplayName("에러 처리 테스트")
inner class ErrorHandlingTest {
    // NetworkError, ApiError, Exception 테스트
}
```

#### 5. 테스트 메서드

```kotlin
@Test
@DisplayName("{한국어 테스트 설명}")
fun `{한국어 테스트명}`() = runTest {
    // Given: {사전 조건 설명}
    // Mock 설정, 테스트 데이터 준비

    // When: {실행 동작 설명}
    // 테스트 대상 함수 호출

    // Then: {검증 내용 설명}
    // 상태 확인, Mock 호출 검증
}
```

**테스트 메서드 규칙:**
- 함수명: 한국어 백틱 (`` `로그인 성공 시 토큰이 저장된다`() ``)
- @DisplayName: 한국어 설명
- 반드시 `= runTest { }` 블록 사용
- Given-When-Then 주석 필수

#### 6. Given-When-Then 구조

```kotlin
// Given: 테스트 환경 설정
val expectedData = TestData(id = 1, name = "테스트")
coEvery {
    mockRepository.getData(any())
} returns NetworkResponse.Success(expectedData)

// When: 테스트 대상 실행
viewModel.fetchData()
advanceUntilIdle()

// Then: 결과 검증
assertEquals(expectedData, viewModel.uiState.value.data)
coVerify { mockRepository.getData(any()) }
```

#### 7. Mock 패턴

```kotlin
// Repository Mock - 성공
coEvery {
    mockRepository.fetchData(any())
} returns NetworkResponse.Success(ResponseBase(data = expectedData))

// Repository Mock - API 에러
coEvery {
    mockRepository.fetchData(any())
} returns NetworkResponse.ApiError(
    ErrorResponse(code = 400, message = "Bad Request"), 400
)

// Repository Mock - 네트워크 에러
coEvery {
    mockRepository.fetchData(any())
} returns NetworkResponse.NetworkError(IOException("Network error"))

// UseCase Mock
coEvery { mockUseCase.invoke(any()) } returns expectedResult

// SharedPreferences Mock
every { mockPreferences.getString("key") } returns "value"

// 연속 호출 시 다른 값
coEvery { mockRepository.getData(any()) } returnsMany listOf(data1, data2)
```

#### 8. 비동기 처리

```kotlin
// 기본 비동기 대기
viewModel.fetchData()
advanceUntilIdle()

// viewModelLaunch delay(300) 처리 패턴
viewModel.fetchData()
testDispatcher.scheduler.runCurrent()       // 코루틴 시작
testDispatcher.scheduler.advanceTimeBy(301) // delay(300) 처리
testDispatcher.scheduler.advanceUntilIdle() // 나머지 작업 완료

// 중첩된 viewModelLaunch 처리
viewModel.firstAction()
testDispatcher.scheduler.runCurrent()
testDispatcher.scheduler.advanceTimeBy(301)
testDispatcher.scheduler.advanceUntilIdle()

viewModel.secondAction()
testDispatcher.scheduler.runCurrent()
testDispatcher.scheduler.advanceTimeBy(301)
testDispatcher.scheduler.advanceUntilIdle()
```

#### 9. Flow 테스트

```kotlin
// 단일 StateFlow 테스트
@Test
@DisplayName("StateFlow 변경을 테스트한다")
fun `StateFlow 변경을 테스트한다`() = runTest {
    turbineScope {
        val states = viewModel.uiState.testIn(backgroundScope)

        // When
        viewModel.updateState()
        advanceUntilIdle()

        // Then
        assertEquals(ExpectedState, states.awaitItem())

        states.cancel()
    }
}

// 다중 Flow 동시 테스트
@Test
@DisplayName("여러 Flow를 동시에 테스트한다")
fun `여러 Flow를 동시에 테스트한다`() = runTest {
    turbineScope {
        val states = viewModel.uiState.testIn(backgroundScope)
        val effects = viewModel.sideEffect.testIn(backgroundScope)

        viewModel.performAction()
        advanceUntilIdle()

        assertEquals(ExpectedState, states.awaitItem())
        assertEquals(ExpectedEffect, effects.awaitItem())

        states.cancel()
        effects.cancel()
    }
}
```

#### 10. 분기 테스트

```kotlin
// TestCase data class + forEach 패턴
@Test
@DisplayName("조건에 따라 다른 동작을 수행한다")
fun `조건에 따라 다른 동작을 수행한다`() = runTest {
    data class TestCase(
        val input: Int,
        val expected: String,
        val description: String
    )

    val testCases = listOf(
        TestCase(-1, "negative", "음수 입력"),
        TestCase(0, "zero", "0 입력"),
        TestCase(1, "positive", "양수 입력")
    )

    testCases.forEach { case ->
        // When
        val result = viewModel.processValue(case.input)

        // Then
        assertEquals(
            case.expected,
            result,
            "실패 케이스: ${case.description}"
        )
    }
}

// 경계값 테스트
@Test
@DisplayName("경계값을 올바르게 처리한다")
fun `경계값을 올바르게 처리한다`() = runTest {
    val boundaryTests = listOf(
        -1 to "boundary_below",
        0 to "boundary",
        1 to "boundary_above"
    )

    boundaryTests.forEach { (input, expected) ->
        val result = viewModel.categorize(input)
        assertEquals(expected, result, "입력값: $input")
    }
}
```

#### 11. 검증 패턴

```kotlin
// 값 검증
assertEquals(expected, actual)
assertNotNull(viewModel.data.value)
assertTrue(viewModel.isLoading.value)
assertFalse(viewModel.hasError.value)

// 타입 검증
assertTrue(viewModel.state.value is ExpectedState)

// Mock 호출 검증
coVerify { mockRepository.fetchData(any()) }
coVerify(exactly = 1) { mockRepository.save(any()) }
verify(exactly = 0) { mockLogger.logError(any()) }
coVerify(ordering = Ordering.ORDERED) {
    mockRepository.validate(any())
    mockRepository.save(any())
}

// Capture 검증
val slot = slot<RequestBody>()
coVerify { mockRepository.save(capture(slot)) }
assertEquals("expected", slot.captured.name)
```

#### 12. 에러 처리 테스트

```kotlin
@Nested
@DisplayName("에러 처리 테스트")
inner class ErrorHandlingTest {

    @Test
    @DisplayName("네트워크 에러 시 에러 상태로 변경된다")
    fun `네트워크 에러 시 에러 상태로 변경된다`() = runTest {
        // Given
        coEvery {
            mockRepository.fetchData(any())
        } returns NetworkResponse.NetworkError(IOException("Network error"))

        // When
        viewModel.loadData()
        advanceUntilIdle()

        // Then
        assertEquals(ErrorState.NETWORK, viewModel.uiState.value.errorState)
    }

    @Test
    @DisplayName("API 에러 시 에러 코드별 처리를 수행한다")
    fun `API 에러 시 에러 코드별 처리를 수행한다`() = runTest {
        // Given
        coEvery {
            mockRepository.fetchData(any())
        } returns NetworkResponse.ApiError(
            ErrorResponse(code = 401, message = "Unauthorized"), 401
        )

        // When
        viewModel.loadData()
        advanceUntilIdle()

        // Then
        assertEquals(ErrorState.UNAUTHORIZED, viewModel.uiState.value.errorState)
    }

    @Test
    @DisplayName("예외 발생 시 일반 에러 처리를 수행한다")
    fun `예외 발생 시 일반 에러 처리를 수행한다`() = runTest {
        // Given
        coEvery {
            mockRepository.fetchData(any())
        } throws RuntimeException("Unexpected error")

        // When
        viewModel.loadData()
        advanceUntilIdle()

        // Then
        assertEquals(ErrorState.GENERAL, viewModel.uiState.value.errorState)
    }
}
```

#### 13. Private 함수 테스트

```kotlin
@Nested
@DisplayName("Private 함수 간접 테스트")
inner class PrivateFunctionTest {

    @Test
    @DisplayName("viewModelLaunch를 사용하는 private 함수가 올바르게 동작한다")
    fun `fetchData 내부의 loadItems가 올바르게 동작한다`() = runTest {
        // Given
        coEvery {
            mockRepository.getItems(any())
        } returns NetworkResponse.Success(expectedItems)

        // When: public 함수 호출 (내부에서 private loadItems 실행)
        viewModel.fetchData()

        // viewModelLaunch delay(300) 처리
        testDispatcher.scheduler.runCurrent()
        testDispatcher.scheduler.advanceTimeBy(301)
        testDispatcher.scheduler.advanceUntilIdle()

        // Then: private 함수의 결과를 간접 검증
        assertNotNull(viewModel.uiState.value.items)
        assertEquals(expectedItems.size, viewModel.uiState.value.items.size)
        coVerify { mockRepository.getItems(any()) }
    }
}
```

---

### Step 3: 파일 생성 위치

**패키지 변환 규칙:**
- 소스: `com.gongnailshop.herren_dell1.gongnailshop.ui.{path}.{ViewModel명}`
- 테스트: `com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{path}.{ViewModel명}Test`

**파일 경로:**
```
app/src/test/java/com/gongnailshop/herren_dell1/gongnailshop/
└── viewmodel/
    └── {feature}/
        └── {ViewModel명}Test.kt
```

---

## 컴파일 검증 체크리스트

코드 생성 후 반드시 아래 항목을 확인합니다:

### 1. import 누락 확인
- MockK: `io.mockk.coEvery`, `io.mockk.coVerify`, `io.mockk.mockk`, `io.mockk.every`, `io.mockk.verify`
- MockK Extension: `io.mockk.junit5.MockKExtension`
- Coroutines Test: `kotlinx.coroutines.ExperimentalCoroutinesApi`, `kotlinx.coroutines.test.runTest`, `kotlinx.coroutines.test.advanceUntilIdle`
- JUnit 5: `org.junit.jupiter.api.*`, `org.junit.jupiter.api.Assertions.*`
- Turbine: `app.cash.turbine.turbineScope`, `app.cash.turbine.testIn`
- 프로젝트 Base: `com.gongnailshop.herren_dell1.gongnailshop.base.BaseViewModelTest`
- 프로젝트 코드: ViewModel, Contract, Repository, Vo, Enum 등

### 2. 타입 일치 확인
- Repository/UseCase의 실제 타입 확인 (추측 금지)
- NetworkResponse wrapper 패턴 정확히 사용
- Entity/Vo 클래스의 실제 필드명 확인
- Enum 값이 실제 존재하는지 확인

### 3. BaseViewModelTest 호환성
- 플래그와 setup() 순서 일치
- `initializeBaseViewModelDependencies()` 호출 위치 확인
- `sharedPreferencesHelper`, `savedStateHandleHelper` 사용 가능 여부
- `testDispatcher`, `advanceUntilIdle()` 접근 가능 여부

### 4. Container 패턴 확인
- Container 사용 시: `viewModel.container.uiState`, `viewModel.container.uiSideEffect`
- Container 미사용 시: `viewModel.uiState`, `viewModel.sideEffect`
- 실제 ViewModel 코드에서 패턴 확인 후 적용

### 5. 패키지 경로 확인
- package 선언과 파일 경로 일치
- `ui.{path}` → `viewmodel.{path}` 변환 정확성

---

## 코드 품질 규칙

### 필수
- BaseViewModelTest 상속
- 모든 어노테이션 (@ExtendWith, @OptIn, @DisplayName) 적용
- 한국어 테스트명 (백틱 함수명)
- Given-When-Then 주석
- `= runTest { }` 블록 사용
- `advanceUntilIdle()` 또는 dispatcher 제어

### 금지
- 리플렉션으로 private 함수 직접 테스트
- 하드코딩된 타입 (실제 코드에서 확인)
- Thread.sleep() 사용
- `@Ignore` 어노테이션 (체리님 확인 없이)
- 불필요한 코드 또는 과도한 확장

### 권장
- TestCase data class + forEach 패턴 (분기 테스트)
- turbineScope + testIn(backgroundScope) (Flow 테스트)
- relaxed = true Mock (예상치 못한 호출 방지)
- any() 매처 (파라미터 유연성)
- coVerifyOrder (호출 순서 검증)

---

## 주의사항

1. **컨벤션 완벽 준수** — `.docs/conventions/viewmodel-test-convention.md`의 모든 규칙
2. **기존 패턴 따르기** — 기존 `viewmodel/` 테스트 파일과 동일한 스타일 유지
3. **과도한 코드 금지** — 플랜에 명시된 테스트만 구현, 불필요한 확장 없음
4. **한국어 주석** — 모든 KDoc, 주석, @DisplayName은 한국어
5. **실제 타입 사용** — Entity, Vo, Enum 등 추측하지 않고 실제 코드 확인
6. **컴파일 가능한 코드** — import 누락, 타입 불일치 등 컴파일 에러 없음 보장
7. **Extension Function 주의** — companion object extension은 직접 mocking 어려움, 간소화 접근법 사용
