---
name: b2c-android-create-screen
description: "**기존 feature 모듈 안에 새 화면 추가** (Screen + ViewModel + Contract + Route). 새 Gradle 모듈은 만들지 않음 — 같은 도메인 안에서 화면만 추가. Use when: 기존 모듈에 화면 추가, 서브 화면 추가. **새 도메인 모듈 신설**은 `/create-feature-module` 사용."
argument-hint: "<feature-module> <screen-name> (예: mypage payment-method-settings)"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob", "AskUserQuestion"]
---

# 기존 모듈에 화면 추가

**용도**: 같은 도메인 안에 화면 1개를 추가. Gradle 모듈은 신설하지 않음 (같은 `feature/{module}/` 안에 파일만 추가).

> ⚠ **새 도메인 (모듈)** 을 시작하려면 `/create-feature-module <name>` 사용. 이 스킬은 **기존 모듈 안 화면 추가** 전용.

인자: `<feature-module> <screen-name>`

예시:
- `/create-screen mypage payment-method-settings` → `feature/mypage/` 안에 PaymentMethodSettings 화면 추가
- `/create-screen shop-detail menu-detail` → `feature/shop-detail/` 안에 MenuDetail 화면 추가

---

## 사용 가이드 — 어떤 스킬이 맞는지

| 시나리오 | 사용 |
|---|---|
| 새 도메인 (위시리스트 등) | ❌ → `/create-feature-module` |
| **기존 모듈에 새 화면** | ✅ 이 스킬 (`/create-screen`) |
| 기존 화면의 sub-component 추가 (UI 분리만) | ❌ → 그 모듈의 `component/` 에 수동 |

---

## 사전 확인

### 1. 인자 검증
- `feature-module`: 존재 여부 확인 (`feature/{module}/` 디렉토리). 없으면 → `/create-feature-module` 안내
- `screen-name`: kebab-case 영문, 모듈 내 중복 확인

### 2. 사용자 질문 (AskUserQuestion)
- **UiState 필드 (예상)**: 화면이 어떤 데이터를 표시?
- **Intent 케이스**: UI 이벤트 list (OnEnter / 클릭 / 입력 등)
- **API 호출 여부**: UseCase 주입 / Repository 직접 / 없음
- **SideEffect**: Navigate 이동 / Toast / LogEvent 등

---

## 생성 프로세스 — Claude 직접 Write (Gradle task 없음)

### Step 1: Contract 파일 — home 정석 참고

`feature/{module}/src/main/java/.../{ScreenName}Contract.kt`:

```kotlin
package com.herren.gongb2c.feature.{module_snake}.{screen_snake}

import androidx.compose.runtime.Immutable
import com.herren.gongb2c.core.architecture.BaseUiState
import com.herren.gongb2c.core.architecture.UiSideEffect

@Immutable
data class {ScreenName}UiState(
    val 필드: 타입 = 기본값,
    // ...
) : BaseUiState.Success<{ScreenName}UiState>

sealed interface {ScreenName}Intent {
    data object OnEnter : {ScreenName}Intent
    // 사용자 질문 결과 기반으로 케이스 추가
}

sealed interface {ScreenName}SideEffect : UiSideEffect {
    data class NavigateXxx(...) : {ScreenName}SideEffect
    // ...
}
```

### Step 2: ViewModel 파일

`feature/{module}/.../{ScreenName}ViewModel.kt`:

```kotlin
@HiltViewModel
class {ScreenName}ViewModel @Inject constructor(
    // 사용자가 명시한 UseCase / Repository 주입
) : BaseIntentViewModel<{ScreenName}UiState>() {
    override val initialState = {ScreenName}UiState()

    fun onIntent(intent: {ScreenName}Intent) {
        when (intent) {
            {ScreenName}Intent.OnEnter -> onEnter()
            // 사용자 케이스 분기
        }
    }

    private fun onEnter() = apiFlow {
        // API 호출 (있으면)
    }
}
```

### Step 3: Screen 파일 (Route + Screen)

`feature/{module}/.../{ScreenName}Screen.kt`:

```kotlin
@Composable
fun {ScreenName}Route(
    viewModel: {ScreenName}ViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {},
) {
    val state by viewModel.collectAsState()

    LaunchedEffect(Unit) { viewModel.onIntent({ScreenName}Intent.OnEnter) }

    viewModel.collectSideEffect { effect ->
        when (effect) {
            // SideEffect 처리 (navigate / toast 등)
        }
    }

    {ScreenName}Screen(state = state, onIntent = viewModel::onIntent)
}

@Composable
fun {ScreenName}Screen(
    state: {ScreenName}UiState,
    onIntent: ({ScreenName}Intent) -> Unit = {},
) {
    // 디자인시스템-v2 컴포넌트로 UI 작성
}
```

### Step 4: Navigation Route 추가

`core/navigation/src/main/java/.../{Module}Route.kt` (또는 통합 Route 파일):

```kotlin
@Serializable
data object {ScreenName}Route : Route  // 또는 data class (인자 있을 때)
```

### Step 5: NavGraph 등록

`feature/{module}/.../graph/{Module}Navigation.kt` 의 `NavGraphBuilder` 확장 함수 안에:

```kotlin
composable<{ScreenName}Route> {
    {ScreenName}Route(
        onNavigateBack = { navController.popBackStack() },
    )
}
```

### Step 6: 테스트 파일 (선택)

`feature/{module}/src/test/.../{ScreenName}ViewModelTest.kt`:

```kotlin
@ExtendWith(MockKExtension::class)
@ExperimentalCoroutinesApi
internal class {ScreenName}ViewModelTest : MockWebServerTestViewModel() {
    // 기본 테스트 구조
}
```

---

## 컨벤션 준수 사항
- **Contract 파일 필수** — UiState + Intent + SideEffect 3종 (home 정석, contract-split-convention.md 참조)
- `BaseIntentViewModel<{ScreenName}UiState>` 또는 `BasePagingViewModel<T>` 상속
- UI 이벤트는 `onIntent()` 단일 메서드 (home 정석)
- `reduceSuccessState<T>` + `apiFlow { }` 패턴 (상태 직접 할당 `uiState.value =` 금지 — SA-MVI-005 강제)
- 패키지: `com.herren.gongb2c.feature.{module_snake}.{screen_snake}` (서브 디렉토리 권장)
- 디자인 시스템 컴포넌트 우선 사용 (`core:designsystem-v2`)

## 생성 후 안내
1. **빌드 확인**: `./gradlew :feature:{module}:compileDevDebugKotlin`
2. **테스트 작성**: `unit-test` 에이전트 위임 또는 수동

## 참고 컨벤션
- 정석 패턴: `feature/home/.../HomeContract.kt`, `HomeViewModel.kt`
- Contract 4 레벨 가이드: [.docs/conventions/contract-split-convention.md](../../../.docs/conventions/contract-split-convention.md)
- API 레이어 (Repository / UseCase): [.docs/conventions/api-convention.md](../../../.docs/conventions/api-convention.md)
- 패키지 표준: [CLAUDE.md](../../../CLAUDE.md) "네이밍 컨벤션"

## 관련 스킬
- `/create-feature-module` — 새 도메인 (모듈) 신설
- 한글 문자열 추가: `.docs/conventions/string-resource-convention.md` 따라 직접 (SA-STR-001 detekt 강제)
- `/create-mock-data` — 테스트용 JSON fixture
