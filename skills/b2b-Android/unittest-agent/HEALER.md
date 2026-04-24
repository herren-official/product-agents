---
name: unittest-agent-healer
description: 랄프루프 플러그인 기반 테스트 에러 자동 수정
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
user-invocable: false
---

# Test Healer (RalphLoop Plugin)

생성된 테스트의 컴파일 에러 및 테스트 실패를 **공식 ralph-loop 플러그인**으로 자동 수정합니다.

---

## ⛔ 필수 실행 규칙

**이 Phase는 반드시 `/ralph-loop:ralph-loop` 스킬 호출로만 실행됩니다.**

```
❌ 금지: 수동으로 빌드 실행 → 에러 확인 → 코드 수정 → 재빌드 반복
✅ 유일한 방법: /ralph-loop:ralph-loop 스킬 호출
```

수동 반복은 다음 문제를 야기합니다:
- 컨텍스트 윈도우 낭비 (에러 로그가 매 반복마다 쌓임)
- 에이전트가 반복 횟수를 임의로 줄여 포기할 수 있음
- 완료 보고의 신뢰성 저하

---

## 랄프루프 핵심 원리

```
┌─────────────────────────────────────────────────────────────────┐
│  /ralph-loop 실행                                               │
│  → Claude가 작업 수행                                            │
│  → 종료 시도                                                     │
│  → Stop 훅이 종료 차단                                           │
│  → 동일한 프롬프트 재삽입                                         │
│  → BUILD SUCCESSFUL 또는 HEALER_COMPLETE 출력까지 반복           │
└─────────────────────────────────────────────────────────────────┘
```

**핵심**: 외부 스크립트가 아닌 **Stop 훅**이 세션 내에서 자동 반복 실행

---

## Phase 3 실행 방법

### 랄프루프 명령어

**주의**: args에 마크다운 특수문자(##, *, 줄바꿈 등)를 포함하면 쉘 연산자로 해석되어 권한 에러 발생.
반드시 **특수문자 없는 한 줄 평문**으로 작성할 것.

```
Skill(
  skill="ralph-loop:ralph-loop",
  args="테스트 파일 {ViewModel명}Test.kt 경로 {테스트파일경로} 작업 1단계 gradlew app testDevDebugUnitTest tests {ViewModel명}Test 실행 2단계 BUILD SUCCESSFUL이면 HEALER_COMPLETE 출력 3단계 BUILD FAILED이면 에러 분석 후 테스트 파일만 수정 4단계 수정 후 1단계 반복 수정가능 import추가 타입수정 파라미터추가 assertion값조정 Mock설정수정 수정금지 ViewModel소스코드 BaseViewModelTest 테스트케이스삭제 --max-iterations 30 --completion-promise HEALER_COMPLETE"
)
```

**금지 패턴 (쉘 에러 유발)**:
- `##` → 쉘 주석 연산자
- `*` → 글로브 와일드카드
- `\n` → 이스케이프 시퀀스
- 줄바꿈 → 다중 명령 해석

---

## 에러 유형별 수정 전략

### 1. 컴파일 에러

#### 1.1 Unresolved reference

```
e: {파일경로}:(라인,컬럼): Unresolved reference: {심볼명}
```

**수정**:
```kotlin
// import 추가
import androidx.compose.ui.text.input.TextFieldValue
import kotlinx.coroutines.flow.flowOf
import com.gongnailshop.herren_dell1.gongnailshop.data.vo.{VoClass}
```

#### 1.2 Type mismatch

```
e: Type mismatch: inferred type is {A} but {B} was expected
```

**수정**:
```kotlin
// coEvery returns 타입 수정
coEvery { repository.fetch() } returns flowOf(ResponseBase(data = CorrectType()))
```

#### 1.3 Missing constructor parameter

```
e: No value passed for parameter '{파라미터명}'
```

**수정**:
```kotlin
// 누락된 파라미터 추가
SomeEntity(
    existingParam = value,
    missingParam = defaultValue  // 추가
)
```

#### 1.4 Cannot access private member

```
e: Cannot access '{메서드명}': it is private
```

**수정**:
```kotlin
// ❌ private 직접 호출 불가
viewModel.privateMethod()

// ✅ public 메서드를 통해 테스트
viewModel.publicMethod()  // 내부적으로 privateMethod 호출
```

---

### 2. 테스트 실패

#### 2.1 Assertion Failed

**수정**:
```kotlin
// advanceUntilIdle() 추가
viewModel.onClickSomething()
advanceUntilIdle()  // ← 누락된 경우 추가
assertEquals(expected, viewModel.uiState.value.field)
```

#### 2.2 NullPointerException

**수정**:
```kotlin
// Mock 응답 설정 추가
coEvery { repository.fetch() } returns flowOf(
    ResponseBase(data = NonNullData())  // null이 아닌 값 반환
)
```

#### 2.3 Timeout / No events

**수정**:
```kotlin
// Turbine test 블록 사용
viewModel.container.uiSideEffect.test {
    viewModel.onClickBack()
    advanceUntilIdle()

    val effect = awaitItem()
    assertTrue(effect is BaseUiSideEffect.OnClickBack)
}
```

---

## 수정 우선순위

```
Priority 1: 컴파일 에러 (빌드 자체가 안 됨)
├── Unresolved reference
├── Type mismatch
└── Missing parameter

Priority 2: 런타임 에러 (테스트 실행 중 크래시)
├── NullPointerException
├── IllegalStateException
└── ClassCastException

Priority 3: Assertion 실패 (로직 검증 실패)
├── assertEquals 실패
├── assertTrue/assertFalse 실패
└── assertNotNull 실패

Priority 4: Timeout/Flow 문제
├── Turbine timeout
└── No events received
```

---

## 자주 발생하는 패턴

### 패턴 1: TextFieldValue import

```kotlin
// 에러: Unresolved reference: TextFieldValue
// 수정:
import androidx.compose.ui.text.input.TextFieldValue
```

### 패턴 2: Flow import

```kotlin
// 에러: Unresolved reference: flowOf
// 수정:
import kotlinx.coroutines.flow.flowOf
```

### 패턴 3: advanceUntilIdle 누락

```kotlin
// 에러: assertion 실패 (상태 미업데이트)
// 수정:
viewModel.onClickSomething()
advanceUntilIdle()  // ← 추가
```

### 패턴 4: coEvery 사용

```kotlin
// 에러: every 대신 coEvery 필요
// 수정:
coEvery { repository.suspendFunction() } returns result
```

### 패턴 5: viewModelLaunch/apiFlow 내 delay(300) 미처리

```kotlin
// 에러: Assertion 실패 - API 호출 후 상태가 여전히 초기값
// 원인: viewModelLaunch 또는 apiFlow 내부에 delay(300)이 있어
//       advanceUntilIdle()만으로는 코루틴이 완료되지 않음

// ❌ 잘못된 코드:
viewModel.onClickPaymentRequest()
advanceUntilIdle()  // delay(300) 안의 코루틴이 실행되지 않음!
assertEquals(ScreenState.SUCCESS, state.screenState)  // 실패!

// ✅ 수정:
viewModel.onClickPaymentRequest()
testDispatcher.scheduler.runCurrent()      // 코루틴 시작
testDispatcher.scheduler.advanceTimeBy(301) // delay(300) 처리
testDispatcher.scheduler.advanceUntilIdle() // 나머지 작업 완료
assertEquals(ScreenState.SUCCESS, state.screenState)  // 성공!
```

> **식별 방법**: Assertion 실패인데 Mock 설정이 올바른 경우 → viewModelLaunch/apiFlow 함수인지 확인 → 3단계 스케줄러 적용

### 패턴 6: savedStateHandle 타입 캐스팅 에러

```kotlin
// 에러: Type mismatch - inferred type is String? but Int was expected
// 원인: savedStateHandle.get<>()의 타입 파라미터 불일치

// ❌ 잘못된 코드:
every { savedStateHandle.get<String>("saleNo") } returns 12345

// ✅ 수정 (타입 일치시키기):
every { savedStateHandle.get<String>("saleNo") } returns "12345"
// 또는
every { savedStateHandle.get<Int>("saleNo") } returns 12345
```

---

## 완료 조건

```
BUILD SUCCESSFUL 달성 시:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<promise>HEALER_COMPLETE</promise>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 결과:
- 테스트 파일: {ViewModel명}Test.kt
- 전체 테스트: {N}개
- 성공: {N}개

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 실패/막힘 시

```
max-iterations 도달 또는 해결 불가 시:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ HEALER_BLOCKED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 상태:
- 남은 에러: {에러 목록}

🔧 시도한 수정:
- {수정 1}
- {수정 2}

💡 대안:
- {제안 1}
- {제안 2}

<promise>HEALER_BLOCKED</promise>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 수정 가능/불가 범위

### ✅ 수정 가능

- Import 문 추가/수정
- 타입 불일치 수정
- Mock 설정 추가/수정
- 테스트 assertion 값 조정
- advanceUntilIdle() 추가
- 파라미터 추가
- 테스트 데이터 팩토리 수정

### ⛔ 수정 금지

- **ViewModel 소스 코드**: 테스트 대상 수정 금지
- **테스트 케이스 삭제**: 분기 커버리지 유지
- **BaseViewModelTest**: 기반 클래스 수정 금지
- **TestMockProvider**: 공유 인프라 수정 금지
- **utils/defaults/*.kt**: 공유 기본값 파일 수정 금지
- **Contract 파일**: UiState, SideEffect 정의 수정 금지

---

## 참고: 랄프루프 취소

```bash
/ralph-loop:cancel-ralph
```
