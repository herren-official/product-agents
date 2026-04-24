---
name: b2c-ios-test-explore
description: "프로젝트의 기존 테스트 코드 패턴, 헬퍼, Mock 구조를 탐색하고 분석합니다"
argument-hint: "[Feature명 또는 테스트 유형]"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# /test-explore - 테스트 코드 탐색

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[test-explore] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 사전 준비

**반드시 테스트 가이드 문서를 먼저 확인할 것:**

| Document | Path | Purpose |
|----------|------|---------|
| TESTS.md | `.docs/conventions/TESTS.md` | 테스트 전체 구조, 공통 패턴 |
| FEATURE_TESTS.md | `.docs/conventions/FEATURE_TESTS.md` | TCA Feature 테스트 패턴 |
| NETWORK_TESTS.md | `.docs/conventions/NETWORK_TESTS.md` | Repository/UseCase 테스트 패턴 |
| UTILS_TESTS.md | `.docs/conventions/UTILS_TESTS.md` | Utils 모듈 테스트 패턴 |
| UI_TESTS.md | `.docs/conventions/UI_TESTS.md` | UI 테스트 패턴 |

> 테스트 디렉토리 구조, 네이밍 규칙, 프레임워크 선택 기준은 위 문서 참조

## 실행 프로세스

### 1단계: 탐색 목적 파악

| 키워드 유형 | 탐색 범위 | 예시 |
|------------|----------|------|
| Feature명 | 해당 Feature 테스트 | "Booking", "MyPage" |
| 테스트 유형 | 해당 유형 전체 | "Feature 테스트", "Repository 테스트" |
| 패턴 키워드 | 전체 테스트에서 검색 | "Mock", "TestStore", "FeatureTestable" |
| 전체 탐색 | 모든 테스트 디렉토리 | 키워드 없음 |

### 2단계: 테스트 파일 탐색

**2.1 Feature 테스트 탐색**
```
Glob: Projects/Features/*/Tests/**/*Tests.swift
```

실제 디렉토리 구조:
```
Projects/Features/{Module}/Tests/
    {ScreenName}/Feature/{ScreenName}FeatureTests.swift
    {ScreenName}/Domain/UseCase/{UseCaseName}Tests.swift
    Common/Domain/UseCase/{CommonUseCaseName}Tests.swift
```

- FeatureTestable 프로토콜 채택 패턴
- @Suite(.serialized) 사용 패턴
- TestStore 설정 방법
- exhaustivity 설정

**2.2 Network 테스트 탐색**
```
Glob: Projects/Core/NetworkSystem/Tests/**/*Tests.swift
```
- RepositoryTestable/NetworkTestable 상속 패턴
- MockService 설정 방법
- expectation/cancellables 패턴

**2.3 UseCase 테스트 탐색**
```
Grep: Projects/Features/*/Tests/**/*UseCaseTests.swift
```
- UseCase 테스트 구조
- Repository 주입 패턴

**2.4 Utils 테스트 탐색**
```
Glob: Projects/Core/Utils/Tests/**/*Tests.swift
```

### 3단계: 테스트 헬퍼/Mock 탐색

**3.1 테스트 베이스 클래스**
```
Glob: Projects/Core/NetworkSystem/Tests/Base/**/*.swift
```
- NetworkTestable, RepositoryTestable 구조

**3.2 Mock 구조 탐색**
```
Grep: "MockService" "MockRouter" "MockRoutable" - Projects/**/Tests/**/*.swift
```
- Mock 패턴 확인
- ServiceAccessManager.isMockSignIn 사용 패턴

**3.3 MockData (JSON) 탐색**
```
Glob: Projects/Core/NetworkSystem/Resources/MockData/**/*.json
```

### 4단계: 유사 테스트 패턴 수집

새로운 테스트 작성 시 참고할 기존 테스트 3개 이상 수집:
- 동일 유형 (Feature/Repository/UseCase) 테스트
- 비슷한 복잡도의 테스트
- Given-When-Then 패턴 활용 예시

## 출력 형식

```markdown
### 테스트 탐색 결과

#### 기존 테스트 현황: {ModuleName}

| 테스트 파일 | 유형 | 테스트 수 |
|------------|------|----------|
| {FeatureTests.swift} | Feature | {N}개 |
| {UseCaseTests.swift} | UseCase | {N}개 |

#### 테스트 패턴 분석

**사용된 프레임워크:** Swift Testing / XCTest
**베이스 클래스:** FeatureTestable / NetworkTestable / RepositoryTestable
**Mock 방식:** MockService / MockRouter

#### 유사 테스트 참고

| 참고 테스트 | 유사점 | 파일 경로 |
|------------|--------|----------|
| {Test1} | {패턴 설명} | {path} |
| {Test2} | {패턴 설명} | {path} |
| {Test3} | {패턴 설명} | {path} |
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| 테스트 파일 없음 | 신규 테스트 작성 필요 안내, 유사 모듈 테스트 제안 |
| 테스트 헬퍼 미발견 | TESTS.md 문서의 베이스 클래스 섹션 참조 권고 |
| MockData 없음 | NETWORK_TESTS.md의 MockData 관리 섹션 참조 권고 |
