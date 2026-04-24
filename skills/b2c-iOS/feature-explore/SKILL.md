---
name: b2c-ios-feature-explore
description: "TCA Feature 모듈 구조를 탐색하고 유사 구현, 패턴, 네트워크 레이어를 분석합니다"
argument-hint: "[Feature명 또는 화면명 또는 탐색 키워드]"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# /feature-explore - Feature 모듈 탐색

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[feature-explore] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 사전 준비

**반드시 다음 문서를 먼저 확인할 것:**
```
Read: .docs/PROJECT_STRUCTURE.md (Feature 모듈 목록 및 내부 구조)
Read: .docs/conventions/CONVENTIONS.md (TCA Feature 구조 템플릿)
Read: .docs/conventions/NETWORK_SYSTEM.md (네트워크 레이어 구조 및 파일 위치)
```

> Feature 모듈 목록, 모듈 내부 구조는 [PROJECT_STRUCTURE.md](.docs/PROJECT_STRUCTURE.md) 참조
> TCA Feature 구조 템플릿은 [CONVENTIONS.md](.docs/conventions/CONVENTIONS.md) 참조
> 네트워크 레이어 (Router/Repository/DTO/MockData) 경로는 [NETWORK_SYSTEM.md](.docs/conventions/NETWORK_SYSTEM.md) 참조

## 실행 프로세스

### 1단계: 탐색 범위 결정

입력 키워드를 분석:

| 키워드 유형 | 탐색 범위 | 예시 |
|------------|----------|------|
| Feature 모듈명 | 해당 모듈 전체 | "Booking", "Review" |
| 화면명 | 해당 화면 하위 | "ShopDetail", "CokDetail" |
| 기능 키워드 | 전체 Feature에서 검색 | "예약", "리뷰", "결제" |
| 레이어 키워드 | 해당 레이어 탐색 | "UseCase", "Reducer", "Router" |
| 전체 탐색 | 모든 Feature 모듈 | 키워드 없음 |

### 2단계: Feature 구조 탐색

**2.1 모듈 내 화면 목록 확인**
```
Glob: Projects/Features/{ModuleName}/Sources/*/Feature/*.swift
```

**2.2 TCA Feature 분석**
해당 Feature 파일을 Read하여 분석:
- **State**: 화면 상태 프로퍼티
- **Action**: 사용자 액션 + 내부 액션
- **Reducer body**: 비즈니스 로직 흐름
- **Dependencies**: 주입된 의존성 (UseCase, Repository 등)

**2.3 View 구조 분석**
```
Glob: Projects/Features/{ModuleName}/Sources/*/View/*.swift
```
- View 계층 구조
- DesignSystem 컴포넌트 사용 패턴
- Navigation 구조

**2.4 Domain 분석**
```
Glob: Projects/Features/{ModuleName}/Sources/*/Domain/**/*.swift
```
- UseCase 인터페이스 및 구현
- Domain Model 정의

### 3단계: 유사 구현 검색

새로운 기능과 유사한 기존 구현을 찾기 위해:

**3.1 키워드 기반 검색**
```
Grep: Projects/Features/**/Sources/**/*.swift - 관련 키워드
```

**3.2 패턴 기반 검색**
작업 유형에 따라 유사 패턴 검색:

| 작업 유형 | 검색 패턴 |
|----------|----------|
| 목록 화면 | `List`, `ForEach`, `Pagination` |
| 상세 화면 | `Detail`, `ScrollView` |
| 폼/입력 | `TextField`, `TextArea`, `validate` |
| 바텀시트 | `BottomSheet`, `.bottomSheet` |
| 검색 | `Search`, `Filter` |
| 결제 | `Payment`, `WebView` |
| 탭 | `Tab`, `TabItem` |

> 실제 Feature 모듈 목록은 `PROJECT_STRUCTURE.md` 또는 `Glob: Projects/Features/*/`로 동적 확인

**3.3 최소 3개 유사 구현 수집**
- Feature 파일 (State/Action/Reducer 패턴)
- View 파일 (레이아웃 패턴)
- UseCase 파일 (데이터 흐름 패턴)

### 4단계: 네트워크 레이어 탐색

> 디렉토리 구조 및 파일 위치는 [NETWORK_SYSTEM.md](.docs/conventions/NETWORK_SYSTEM.md) 참조

NETWORK_SYSTEM.md에 정의된 경로를 기반으로:
- **Router**: 관련 API 엔드포인트 검색
- **Repository**: 기존 메서드 재사용 가능 여부 확인
- **DTO (Data)**: 요청/응답 모델 확인
- **MockData**: 테스트용 목데이터 존재 여부 확인

### 5단계: Navigation 패턴 확인

TCA Navigation은 flat Path + CoordinatorFeature 분리 구조를 사용합니다.

**Navigation 모델:**
- `ApplicationPath` (@Reducer enum): push 네비게이션 (NavigationStack)
- `ApplicationDestination` (@Reducer enum): present 네비게이션 (sheet/fullScreenCover)

**Coordinator 구조:**
- 도메인별 CoordinatorFeature (`CokCoordinatorFeature`, `BookingCoordinatorFeature` 등)가 `ApplicationCoordinatorReducer` protocol을 준수
- ApplicationCoordinatorFeature의 body에서 각 CoordinatorFeature를 조합

**탐색 방법:**
```
Read: Projects/Application/Sources/Screens/ApplicationCoordinator/Domain/Model/ApplicationPath.swift
Read: Projects/Application/Sources/Screens/ApplicationCoordinator/Domain/Model/ApplicationDestination.swift
Glob: Projects/Application/Sources/Screens/ApplicationCoordinator/Feature/Coordinators/*CoordinatorFeature.swift
```
- ApplicationPath/ApplicationDestination에서 해당 Feature의 case 확인
- 도메인별 CoordinatorFeature에서 `.path(.element(_, action:))` 패턴으로 화면 전환 로직 확인

## 출력 형식

```markdown
### Feature 탐색 결과

#### 모듈: {ModuleName}

**화면 목록:**
- {Screen1}: {설명}
- {Screen2}: {설명}

#### TCA Feature 분석: {FeatureName}

**State:**
- {property}: {type} - {설명}

**Action:**
- {action1}: {설명}
- {action2}: {설명}

**Dependencies:**
- {useCase}: {역할}

#### 유사 구현 참고

| 참고 Feature | 유사점 | 파일 경로 |
|-------------|--------|----------|
| {Feature1} | {패턴 설명} | {path} |
| {Feature2} | {패턴 설명} | {path} |
| {Feature3} | {패턴 설명} | {path} |

#### 네트워크 레이어

| Layer | 파일 | 관련 API |
|-------|------|---------|
| Router | {path} | {endpoint} |
| Repository | {path} | {method} |
| DTO | {path} | {model} |
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| Feature 모듈 미발견 | 전체 모듈 목록 제시 후 선택 요청 |
| 유사 구현 없음 | 가장 가까운 패턴 제안 |
| 네트워크 레이어 없음 | 신규 Router/Repository 생성 필요 안내 |
