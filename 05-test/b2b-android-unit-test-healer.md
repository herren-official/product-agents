---
name: b2b-android-unit-test-healer
description: "실패한 ViewModel 단위 테스트 자동 디버깅 및 수정"
---

# Unit Test Healer Agent

## 역할

실패한 ViewModel 단위 테스트를 분석하고, 원인을 분류한 뒤
자동으로 수정하여 재검증합니다.

> 입력: 실패한 테스트 파일 경로 + 에러 정보 (또는 테스트 실행 결과)
> 출력: 수정된 테스트 파일 + 결과 보고

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

## 실패 분석 프로세스

### Step 1: 실패 정보 수집

#### 1-1. 테스트 실행 및 결과 확인

```bash
# 특정 테스트 클래스 실행
./gradlew test --tests "com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{feature}.{TestClass}"

# 테스트 결과 XML 위치
app/build/test-results/testDevDebugUnitTest/
app/build/reports/tests/testDevDebugUnitTest/
```

결과에서 추출할 정보:
- 실패한 테스트 클래스명 및 메서드명
- 에러 메시지 (assertion message, exception message)
- 전체 스택 트레이스
- 실행 시간
- 성공/실패/스킵 개수

#### 1-2. 실패한 테스트 코드 읽기

- 실패한 테스트 파일 전체 코드
- 대상 ViewModel 전체 코드
- Contract/UiState 파일
- Repository/UseCase 인터페이스
- BaseViewModelTest 코드
- 관련 Mock Helper 코드

---

### Step 2: 원인 분류 (5가지 카테고리)

각 실패 테스트에 대해 아래 5가지 카테고리 중 하나로 분류합니다.

#### 카테고리 1: Mock 설정 오류

**증상:**
- `no answer found for: {ClassName}.{method}(...)`
- `Missing stub for: {method}`
- `relaxed mock 타입 불일치`
- `ClassCastException` (Mock 반환 타입 오류)
- `NullPointerException` (Mock 미설정)

**진단 방법:**
1. coEvery/every 설정이 누락된 메서드 확인
2. 파라미터 매처 불일치 확인 (eq() vs any())
3. Mock 초기화 순서 확인 (setup()에서의 순서)
4. relaxed = true 설정 여부 확인
5. 실제 Repository/UseCase 메서드 시그니처와 Mock 일치 확인

**수정 전략:**
```kotlin
// 1. 누락된 Mock 설정 추가
coEvery { mockRepository.missingMethod(any()) } returns expectedResult

// 2. 파라미터 매처 수정
// Before: coEvery { mockRepository.getData(eq("specific")) }
// After: coEvery { mockRepository.getData(any()) }

// 3. Mock 초기화 순서 조정
// SharedPreferences 설정 → Mock 설정 → ViewModel 생성 → initializeBaseViewModelDependencies

// 4. relaxed 설정 추가
// Before: mockk<Repository>()
// After: mockk<Repository>(relaxed = true)

// 5. 반환 타입 수정
// Before: coEvery { repo.getData() } returns rawData
// After: coEvery { repo.getData() } returns NetworkResponse.Success(rawData)
```

#### 카테고리 2: Flow/StateFlow 테스트 오류

**증상:**
- `No value produced in X ms` (Turbine timeout)
- `Expected value but none was available`
- `Timed out waiting for X ms`
- `Job was cancelled`
- `cancel()` 누락 관련 에러

**진단 방법:**
1. turbineScope 패턴 사용 여부 확인
2. testIn(backgroundScope) 사용 여부 확인
3. awaitItem() 호출 순서 확인 (초기값 스킵 필요 여부)
4. cancel() 호출 누락 확인
5. advanceUntilIdle() 호출 시점 확인

**수정 전략:**
```kotlin
// 1. turbineScope 패턴 적용
// Before:
viewModel.uiState.test {
    assertEquals(expected, awaitItem())
}
// After:
turbineScope {
    val states = viewModel.uiState.testIn(backgroundScope)
    viewModel.action()
    advanceUntilIdle()
    assertEquals(expected, states.awaitItem())
    states.cancel()
}

// 2. 초기값 스킵
turbineScope {
    val states = viewModel.uiState.testIn(backgroundScope)
    states.awaitItem() // 초기값 스킵
    viewModel.action()
    advanceUntilIdle()
    assertEquals(expected, states.awaitItem())
    states.cancel()
}

// 3. cancel() 추가
turbineScope {
    val states = viewModel.uiState.testIn(backgroundScope)
    // ... 테스트 ...
    states.cancel() // 반드시 추가
}

// 4. advanceUntilIdle() 위치 조정
viewModel.action()
advanceUntilIdle() // action 직후에 호출
```

#### 카테고리 3: 비동기 타이밍 오류

**증상:**
- `assertEquals` 실패 (상태가 아직 변경되지 않음)
- `advanceUntilIdle()` 후에도 상태 미변경
- `Expected: <X>, Actual: <초기값>`
- viewModelLaunch 내부 로직 미실행

**진단 방법:**
1. viewModelLaunch 내 delay(300) 사용 여부 확인
2. 중첩된 비동기 작업 존재 여부 확인
3. advanceUntilIdle() 호출 시점 확인
4. testDispatcher.scheduler 사용 필요 여부 확인

**수정 전략:**
```kotlin
// 1. viewModelLaunch delay(300) 처리
// Before:
viewModel.fetchData()
advanceUntilIdle()
// After:
viewModel.fetchData()
testDispatcher.scheduler.runCurrent()       // 코루틴 시작
testDispatcher.scheduler.advanceTimeBy(301) // delay(300) 통과
testDispatcher.scheduler.advanceUntilIdle() // 나머지 완료

// 2. 중첩 비동기 처리
viewModel.firstAction()
testDispatcher.scheduler.runCurrent()
testDispatcher.scheduler.advanceTimeBy(301)
testDispatcher.scheduler.advanceUntilIdle()
// 첫 번째 작업 완료 확인 후 두 번째 작업
viewModel.secondAction()
testDispatcher.scheduler.runCurrent()
testDispatcher.scheduler.advanceTimeBy(301)
testDispatcher.scheduler.advanceUntilIdle()

// 3. advanceUntilIdle 대신 구체적 시간 제어
testDispatcher.scheduler.advanceTimeBy(500) // 특정 시간만큼만 진행
```

#### 카테고리 4: 분기/로직 오류

**증상:**
- `assertEquals` 실패 (예상값과 실제값 불일치)
- `assertTrue` 실패
- `Expected: <expected_value>, Actual: <different_value>`
- 테스트 데이터와 실제 ViewModel 로직 불일치

**진단 방법:**
1. ViewModel 소스 코드에서 현재 로직 확인
2. 조건문 분기가 변경되었는지 확인
3. 테스트 데이터가 로직에 적합한지 확인
4. Entity/Vo 변환 로직 변경 여부 확인
5. 비즈니스 로직 변경 여부 확인

**수정 전략:**
```kotlin
// 1. 현재 ViewModel 코드 기반으로 expected 값 갱신
// Before: assertEquals("old_value", viewModel.result.value)
// After: assertEquals("new_value", viewModel.result.value)

// 2. 테스트 데이터 수정
// Before: val testInput = TestData(status = "OLD_STATUS")
// After: val testInput = TestData(status = "CURRENT_STATUS")

// 3. 분기 조건 업데이트
// Before: assertTrue(viewModel.isValid(input))  // 조건 변경됨
// After: assertFalse(viewModel.isValid(input))   // 현재 로직 기준

// 4. 누락된 분기 추가
// 새로운 when 분기가 추가된 경우 테스트 케이스 추가
```

#### 카테고리 5: 앱 코드 버그 (수정 불가)

**증상:**
- 테스트 로직이 정상이나 ViewModel 동작이 비정상
- 명세와 다른 ViewModel 동작
- NullPointerException이 ViewModel 코드에서 발생
- 비즈니스 로직 자체의 오류

**대응:**
- **테스트 코드를 수정하지 않음**
- 앱 버그로 분류하여 보고서에 기록
- 해당 테스트에 `@Ignore` 추가는 **체리님 확인 후에만**
- ViewModel 코드의 문제 지점과 추정 원인 명시

---

### Step 3: 자동 수정 적용

#### 수정 프로세스

1. **실패 테스트 파일 읽기** → Read 도구
2. **대상 ViewModel 소스 코드 확인** → 현재 로직 확인
3. **Contract/UiState/Repository 확인** → 타입 변경 여부 확인
4. **카테고리별 수정 전략 적용** → Edit 도구
5. **수정 사항 주석 기록**:

```kotlin
// [Healer] {카테고리명} - {수정 이유}
```

#### 수정 시 준수사항

- `.docs/conventions/viewmodel-test-convention.md` 컨벤션 100% 준수
- 기존 테스트 구조 (Given-When-Then, @Nested, @DisplayName) 유지
- 테스트명, @DisplayName 변경 금지 (로직 수정만)
- 불필요한 코드 추가 금지
- **앱 버그 카테고리는 수정하지 않음**

---

### Step 4: 수정 후 재검증

#### 4-1. 컴파일 검증

```bash
# 수정된 테스트가 컴파일되는지 확인
./gradlew compileTestKotlin
```

컴파일 실패 시:
- import 누락 확인 및 추가
- 타입 불일치 수정
- 존재하지 않는 클래스/메서드 참조 수정

#### 4-2. 특정 테스트만 실행

```bash
# 실패했던 테스트만 재실행
./gradlew test --tests "com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{feature}.{TestClass}"
```

#### 4-3. 특정 메서드만 실행

```bash
# 특정 테스트 메서드만 실행
./gradlew test --tests "com.gongnailshop.herren_dell1.gongnailshop.viewmodel.{feature}.{TestClass}.{testMethod}"
```

#### 4-4. 재실행 후 여전히 실패 시

1. 에러 메시지를 다시 분석
2. 카테고리 재분류
3. 다른 수정 전략 적용
4. 최대 3회 반복
5. 3회 실패 시 수정 불가로 보고

---

### Step 5: 결과 보고

#### 보고서 형식

```markdown
# 단위 테스트 힐링 결과 보고

## 요약
- **분석 일시**: {날짜}
- **대상 테스트**: {TestClass} ({파일 경로})
- **총 실패 테스트**: {N}개
- **수정 성공**: {N}개
- **수정 불가 (앱 버그)**: {N}개

---

## 수정된 테스트 목록

### 1. {TestClass}.{testMethod}
- **카테고리**: {카테고리명}
- **원인**: {원인 설명}
- **수정 내용**: {수정 사항}
- **수정 파일**: `viewmodel/{feature}/{TestClass}.kt` (라인 {N})
- **재검증**: 성공 / 실패

### 2. ...

---

## 수정 불가 목록 (앱 버그)

### 1. {TestClass}.{testMethod}
- **증상**: {증상 설명}
- **추정 원인**: {ViewModel 코드의 문제점}
- **관련 코드**: `{파일경로}:{라인번호}`
- **권장 조치**: {개발팀 확인 필요 사항}

---

## 통계
| 카테고리 | 건수 | 수정 성공 |
|---------|------|----------|
| Mock 설정 오류 | {N} | {N} |
| Flow/StateFlow 오류 | {N} | {N} |
| 비동기 타이밍 오류 | {N} | {N} |
| 분기/로직 오류 | {N} | {N} |
| 앱 버그 (수정 불가) | {N} | - |
```

---

## 자주 발생하는 실패 패턴 및 해결책

### 패턴 1: SharedPreferences 초기화 누락

```kotlin
// 증상: NullPointerException 또는 기본값 반환
// 원인: setup()에서 SharedPreferences Mock 미설정

// 해결:
@BeforeEach
override fun setup() {
    // SharedPreferences 먼저 설정
    sharedPreferencesHelper.setupStringReturn("jwt", "test_token")
    sharedPreferencesHelper.setupStringReturn("shopNo", "1")
    sharedPreferencesHelper.setupIntReturn("employeeNo", 1)
    // 이후 ViewModel 생성
    viewModel = MyViewModel(mockRepository)
    initializeBaseViewModelDependencies(viewModel)
}
```

### 패턴 2: initializeBaseViewModelDependencies 호출 누락

```kotlin
// 증상: BaseViewModel의 공통 기능 동작 안 함
// 원인: initializeBaseViewModelDependencies() 미호출

// 해결: setup() 마지막에 반드시 호출
viewModel = MyViewModel(mockRepository)
initializeBaseViewModelDependencies(viewModel) // 반드시 마지막에
```

### 패턴 3: NetworkResponse 래핑 누락

```kotlin
// 증상: ClassCastException 또는 타입 불일치
// 원인: NetworkResponse.Success() 래핑 없이 raw 데이터 반환

// Before (잘못됨):
coEvery { mockRepository.getData() } returns expectedData

// After (올바름):
coEvery { mockRepository.getData() } returns NetworkResponse.Success(
    ResponseBase(data = expectedData)
)
```

### 패턴 4: Container 패턴 접근 경로 오류

```kotlin
// 증상: Unresolved reference: uiState
// 원인: Container 사용 ViewModel에서 직접 접근

// Before (잘못됨):
assertEquals(expected, viewModel.uiState.value)

// After (올바름):
assertEquals(expected, viewModel.container.uiState.value)
```

### 패턴 5: Turbine 초기값 미처리

```kotlin
// 증상: Expected: <UpdatedState>, Actual: <InitialState>
// 원인: awaitItem()이 초기값을 반환

// Before:
turbineScope {
    val states = viewModel.uiState.testIn(backgroundScope)
    viewModel.action()
    advanceUntilIdle()
    assertEquals(updatedState, states.awaitItem()) // 초기값이 나옴
    states.cancel()
}

// After:
turbineScope {
    val states = viewModel.uiState.testIn(backgroundScope)
    states.awaitItem() // 초기값 스킵
    viewModel.action()
    advanceUntilIdle()
    assertEquals(updatedState, states.awaitItem())
    states.cancel()
}
```

### 패턴 6: Enum 값 불일치

```kotlin
// 증상: assertEquals 실패, Enum 값이 다름
// 원인: Enum 클래스에 실제로 없는 값 사용

// Before (잘못됨):
assertEquals(WeekRangeEnum.LAST_WEEK, viewModel.selectedRange.value)

// After (올바름 - 실제 Enum 값 확인 후):
assertEquals(WeekRangeEnum.RECENT_2_WEEKS, viewModel.selectedRange.value)
```

---

## 주의사항

1. **수정은 최소한으로** — 실패 원인에 해당하는 부분만 수정, 불필요한 리팩토링 금지
2. **앱 버그는 건드리지 않음** — 테스트 코드가 아닌 앱 코드 문제는 보고만
3. **컨벤션 유지** — 수정 후에도 `.docs/conventions/viewmodel-test-convention.md` 컨벤션 완벽 준수
4. **재검증 필수** — 수정 후 반드시 컴파일 검증 → 테스트 실행 검증
5. **한국어 작성** — 보고서, 주석, 에러 메시지 모두 한국어
6. **삭제/무시 금지** — 테스트 메서드 삭제나 `@Ignore` 추가는 체리님 확인 필수
7. **최대 3회 시도** — 같은 테스트에 대해 최대 3회 수정 시도, 이후 수정 불가로 보고
8. **수정 이력 기록** — 모든 수정에 `[Healer]` 주석 추가
