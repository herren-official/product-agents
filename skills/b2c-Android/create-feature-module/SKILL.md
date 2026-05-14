---
name: b2c-android-create-feature-module
description: "**신규 도메인 feature 모듈** 생성 (새 Gradle 모듈 + settings.gradle.kts 등록 + 첫 화면 골격). Use when: 새 도메인 시작 (예: 위시리스트, 알림센터). **기존 모듈에 화면만 추가**할 때는 `/create-screen` 사용."
argument-hint: "<feature-name> (예: wishlist, notification-detail)"
---

# 신규 도메인 feature 모듈 스캐폴딩

**용도**: 새 도메인 영역을 시작할 때 **신규 Gradle 모듈** + 첫 화면 골격을 컨벤션 100% 정합으로 자동 생성.

> ⚠ **이 스킬은 새 모듈을 만든다**. 같은 도메인 안에 화면만 추가하려면 `/create-screen <module> <screen>` 사용 (모듈 분산 방지).

생성 결과:
- `feature/{name}/` 새 디렉토리 + `build.gradle.kts` + `AndroidManifest.xml`
- `{Name}Screen.kt`, `{Name}ViewModel.kt`, `{Name}Contract.kt`, `graph/{Name}Navigation.kt`
- 테스트 디렉토리 (`src/test/`, `src/androidTest/`)
- `settings.gradle.kts` 에 `:feature:{name}` 자동 등록

도메인명 (= 모듈명): $ARGUMENTS

## 사용 가이드 — 어떤 스킬이 맞는지

| 시나리오 | 사용 |
|---|---|
| 새 도메인 (위시리스트 / 알림센터 / 쿠폰함 같은 독립 기능) | ✅ 이 스킬 (`/create-feature-module`) |
| 기존 도메인 안 새 화면 (예: mypage 에 "결제 수단 관리" 추가) | ❌ → `/create-screen mypage payment-method-settings` |
| 기존 화면의 sub-component 추가 | ❌ → 그 모듈의 `component/` 에 수동 추가 |

## 사전 확인

### 1. 기능명 검증
- kebab-case 영문만 허용
- 기존 feature 모듈과 중복 확인: `feature/$ARGUMENTS/` 존재 여부
- **모듈인지 화면인지 재확인**: 위 표 참고. 같은 도메인이면 `/create-screen` 으로 안내

### 2. 사용자 확인 사항 질문
- **패키지명**: `com.herren.gongb2c.feature.{name}` (기본값) 또는 커스텀
- **ViewModel 수**: 몇 개의 화면/ViewModel이 필요한지
- **주요 기능**: 간단한 설명 (UiState 필드 결정에 활용)

## 생성 프로세스

### Step 1: Gradle 모듈 생성
```bash
./gradlew createFeatureModule --featureName=$ARGUMENTS
```

### Step 2: 생성된 파일 커스터마이징

#### Contract 파일
**정석: `feature/home/.../HomeContract.kt`** — Intent sealed interface 로 UI 이벤트 묶음.

```kotlin
// 1. UiState — 항상 정의
@Immutable
data class FeatureNameUiState(
    val 필드: 타입 = 기본값,
) : BaseUiState.Success<FeatureNameUiState>

// 2. Intent — ViewModel 입력. 모든 UI 이벤트를 sealed interface 로 묶음
sealed interface FeatureNameIntent {
    data object OnEnter : FeatureNameIntent
    data object OnRefresh : FeatureNameIntent
    data class OnItemClick(val id: String) : FeatureNameIntent
    // ...
}

// 3. SideEffect — 외부 효과 (Navigate*, LogEvent 등)
sealed interface FeatureNameSideEffect : UiSideEffect {
    data class NavigateXxx(...) : FeatureNameSideEffect
    data class LogEvent(val event: B2CEventType, val params: Map<String, Any>? = null) : FeatureNameSideEffect
}

// 상세 구조 가이드: .docs/conventions/contract-split-convention.md (4 레벨)
```

#### ViewModel 파일 — home 패턴
- **단일 화면**: `BaseIntentViewModel<FeatureNameUiState>` 상속
- **페이징 화면**: `BasePagingViewModel<ItemVo>` 상속 (목록 무한 스크롤)
- UseCase 또는 Repository 주입 (단순 조회는 Repository 직접도 OK — `api-convention.md` §8 참조)
- **공개 API 는 `onIntent(intent: Intent)` 단일 메서드** (home 정석):

  ```kotlin
  fun onIntent(intent: FeatureNameIntent) {
      when (intent) {
          FeatureNameIntent.OnEnter -> onEnter()
          FeatureNameIntent.OnRefresh -> fetchData()
          is FeatureNameIntent.OnItemClick ->
              postSideEffect { FeatureNameSideEffect.NavigateXxx(intent.id) }
      }
  }
  ```
- `reduceSuccessState<T>` + `apiFlow { }` 패턴 사용

#### Screen 파일 — home 패턴
- Route(상태/네비) + Screen(순수 UI) 두 컴포저블을 같은 파일에 정의
- **Screen 시그니처**: `state: FeatureNameUiState, onIntent: (FeatureNameIntent) -> Unit` (단일 람다)
- Route 에서: `viewModel.onIntent(FeatureNameIntent.OnEnter)` (LaunchedEffect), `onIntent = viewModel::onIntent` (Screen 전달)
- 디자인 시스템 컴포넌트 사용 (`B2CText`, `RectangleButton` 등 — `core:designsystem-v2`)
- SideEffect 수집: `viewModel.collectSideEffect { effect -> when(effect) { ... } }`

#### Navigation 파일
- `@Serializable` Route 정의 (`core:navigation/.../Route.kt`)
- NavGraphBuilder 확장 함수 생성 (`{feature}NavGraph()`)
- 딥링크: `gongshop://feature/path` 패턴

### Step 3: 테스트 파일 생성
```kotlin
@ExtendWith(MockKExtension::class)
@ExperimentalCoroutinesApi
internal class {Feature}ViewModelTest : MockWebServerTestViewModel() {
    // 기본 테스트 구조
}
```

## 생성 후 안내
1. **빌드 확인**: `./gradlew :feature:{name}:assembleDevDebug`
2. **NavGraph 연결**: `feature/main/`의 `MainNavHost`에 그래프 추가 필요
3. **화면 명세 (선택)**: 프로젝트 wiki 에 PRD 작성 권장

## 컨벤션 준수 사항
- **Contract 파일 필수** — UiState + Intent + SideEffect 3종 (contract-split-convention.md 참조)
- `BaseIntentViewModel<FeatureNameUiState>` 또는 `BasePagingViewModel<T>` 상속
- **UI 이벤트는 Intent sealed interface 로 묶어 `onIntent()` 단일 메서드로 처리** (home 정석)
- `reduceSuccessState<T>` + `apiFlow { }` 패턴 (상태 직접 할당 `uiState.value =` 금지 — SA-MVI-005 강제)
- 디자인 시스템 컴포넌트 우선 사용 (`core:designsystem-v2`)

## 참고 컨벤션
- 정석 패턴: `feature/home/.../HomeContract.kt`, `HomeViewModel.kt`
- Contract 4 레벨 가이드: [.docs/conventions/contract-split-convention.md](../../../.docs/conventions/contract-split-convention.md)
- API 레이어 (Repository / UseCase): [.docs/conventions/api-convention.md](../../../.docs/conventions/api-convention.md)
- 패키지 표준: [CLAUDE.md](../../../CLAUDE.md) "네이밍 컨벤션"
