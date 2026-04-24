---
name: b2c-ios-design-system-explore
description: "프로젝트 DesignSystem 모듈의 컴포넌트, Foundation 토큰, Extensions를 탐색하고 API를 분석합니다"
argument-hint: "[컴포넌트명 또는 탐색 키워드]"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# /design-system-explore - DesignSystem 모듈 탐색

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[design-system-explore] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 사전 준비

**반드시 다음 문서를 먼저 읽을 것:**

| Document | Path | Purpose |
|----------|------|---------|
| DesignSystem Guide | [`DESIGN_SYSTEM.md`](.docs/conventions/DESIGN_SYSTEM.md) | 컴포넌트 인벤토리, 토큰 매핑 테이블 |
| Project Structure | [`PROJECT_STRUCTURE.md`](.docs/PROJECT_STRUCTURE.md) | DesignSystem 모듈 구조 |

```
Read: .docs/conventions/DESIGN_SYSTEM.md
```

## 실행 프로세스

### 1단계: 탐색 목적 파악

입력 키워드를 분석하여 탐색 범위를 결정:

| 키워드 유형 | 탐색 범위 | 예시 |
|------------|----------|------|
| 컴포넌트명 | Components/ 하위 | "Button", "TopBar", "BottomSheet" |
| 토큰 유형 | Foundation/ 하위 | "Color", "Typography", "Spacing", "Radius" |
| UI 패턴 | Components/ + Extensions/ | "Modal", "Toast", "Loading" |
| 전체 탐색 | 모든 디렉토리 | 키워드 없음 또는 "전체" |

### 2단계: 컴포넌트 탐색

**2.1 컴포넌트 목록 확인**
```
Glob: Projects/Core/DesignSystem/Sources/Components/**/*.swift
```

**2.2 특정 컴포넌트 상세 분석**
- 해당 컴포넌트 파일 Read
- public API (init, modifier, enum) 확인
- 설정 옵션 (Type, Style, Size 등) 분석
- 사용 예시 코드 추출

**2.3 컴포넌트 인벤토리 확인**

> 전체 컴포넌트 목록은 [DESIGN_SYSTEM.md](.docs/conventions/DESIGN_SYSTEM.md)의 "Components" 섹션 참조

- Glob 결과와 DESIGN_SYSTEM.md 문서를 교차 확인
- 디렉토리별 컴포넌트와 독립 컴포넌트 구분

### 3단계: Foundation 토큰 탐색

> 토큰 매핑 테이블은 [DESIGN_SYSTEM.md](.docs/conventions/DESIGN_SYSTEM.md)의 각 Foundation 섹션 참조

**실제 소스 코드 확인이 필요한 경우:**
```
Glob: Projects/Core/DesignSystem/Sources/Foundation/**/*.swift
```
- Color, Typography, Spacing, Radius, Opacity, Size 파일을 Read하여 실제 값 확인
- DESIGN_SYSTEM.md 문서와 소스 코드 간 차이가 있으면 소스 코드 기준

### 4단계: Extensions 탐색

```
Glob: Projects/Core/DesignSystem/Sources/Extensions/**/*.swift
```
- View extension 패턴 확인
- 프로젝트에서 사용하는 커스텀 modifier 확인

### 5단계: 사용 패턴 확인

기존 Feature에서 해당 컴포넌트/토큰이 어떻게 사용되는지 확인:
```
Grep: Projects/Features/**/Sources/**/*.swift - 해당 컴포넌트명/토큰명 검색
```
- 실제 사용 예시 3개 이상 수집
- 공통 설정 패턴 파악

## 출력 형식

```markdown
### DesignSystem 탐색 결과

#### 컴포넌트: {컴포넌트명}

**파일 위치:** `Projects/Core/DesignSystem/Sources/Components/{path}`

**Public API:**
- init 파라미터
- 설정 옵션 (Type/Style/Size enum)
- modifier

**사용 예시:**
(기존 Feature에서 발견된 실제 사용 패턴)

#### Foundation 토큰

| Category | Token | Value | Usage |
|----------|-------|-------|-------|
| Color | .brand_300 | #4E3BFF | `.textColor(.brand_300)` |
| Typography | .heading2 | 18pt SemiBold | `.fontTypography(.heading2)` |
| Spacing | .spacing16 | 16pt | `.padding(.horizontal, .spacing16)` |
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| 컴포넌트 미발견 | 유사 이름 검색 후 제안 |
| 토큰 매핑 불가 | DESIGN_SYSTEM.md 문서 참조 권고 |
| 사용 예시 없음 | 컴포넌트 API 기반 사용법 제안 |
