---
name: b2c-android-create-feature
description: "프로젝트 컨벤션에 맞춰 새 기능 모듈의 Screen, ViewModel, Contract, Navigation 자동 생성. Use when: 새 기능 모듈 생성, feature 모듈 만들기, 스캐폴딩"
argument-hint: "<feature-name> (예: wishlist, notification-detail)"
---

# 새 기능 스캐폴딩

프로젝트 컨벤션(CLAUDE.md, project-convention.md)에 맞춰 새 feature 모듈을 생성합니다.

기능명: $ARGUMENTS

## 사전 확인

### 1. 기능명 검증
- kebab-case 영문만 허용
- 기존 feature 모듈과 중복 확인: `feature/$ARGUMENTS/` 존재 여부

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
- 사용자가 설명한 기능에 맞는 UiState 필드 추가
- 필요한 SideEffect 정의

#### ViewModel 파일
- `BaseIntentViewModel<BaseUiState>` 상속 확인
- 필요한 UseCase 주입 추가
- public 메서드 (UI 이벤트 핸들러) 스텁 생성

#### Screen 파일
- Route와 Screen 같은 파일에 정의
- 디자인 시스템 컴포넌트 사용 (`B2CText`, `RectangleButton` 등)

#### Navigation 파일
- `@Serializable` Route 정의
- NavGraphBuilder 확장 함수 생성

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
3. **PRD 문서**: `.docs/prd/{name}.md` 생성 권장

## 컨벤션 준수 사항
- `BaseIntentViewModel<BaseUiState>` 상속 (Contract 패턴 미사용)
- UI 이벤트는 ViewModel public 메서드로 처리
- `reduceSuccessState<T>` + `apiFlow` 패턴 사용
- 디자인 시스템 컴포넌트 우선 사용
