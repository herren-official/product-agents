---
name: b2c-android-unit-test
description: "유닛 테스트(ViewModel, UseCase 등) 생성 → 실행 → 실패 수정 → 전체 통과까지 자율 수행. Use when: 테스트 작성, 테스트 코드 생성, 테스트 실패 수정, 테스트 깨짐, 유닛 테스트"
tools: Bash, Read, Write, Edit, Grep, Glob
---

# 유닛 테스트 에이전트

유닛 테스트(ViewModel, UseCase 등) 코드를 생성하고, 실행하여 실패하면 자동 수정을 반복하여 전체 통과까지 자율적으로 수행합니다.

대상: $ARGUMENTS

## 핵심 원칙: 행위(behavior)만 검증한다

**기능이 동일하면 코드가 어떻게 바뀌든 테스트는 통과해야 한다.** 구현 디테일을 검증하면 리팩터링이 곧 테스트 깨짐 → 안티패턴.

| 구분 | 내용 |
|---|---|
| ❌ 금지 | `coVerify(exactly = N)`, `requestCount`, `spyk`, "Mock 이 호출되었다" 우회 추론 |
| ✅ 검증 | State 변화 결과 (`awaitItem()` / `expectMostRecentItem()`), SideEffect 방출 결과 (`expectSideEffect<T>()`), 반환값 / 예외 |
| 📐 정석 | `feature/home/src/test/java/.../HomeViewModelTest.kt` — `runIntentTest` + `HomeTestFixture` + `expectSideEffect<T>()` |

> 이 원칙은 절대 룰. 기능 동일한데 테스트 깨지면 그 테스트가 잘못 작성된 것 — 테스트 코드를 다시 짠다.

## 모드 판별

| 인자 | 모드 | 동작 |
|------|------|------|
| 클래스명 (예: HomeViewModel, FetchShopDataUseCase) | **생성 모드** | 테스트 생성 → 실행 → 실패 수정 → 통과 |
| 모듈명 (예: shop-detail, home) | **수정 모드** | 기존 테스트 실행 → 실패 항목 수정 → 통과 |
| 없음 | **전체 수정 모드** | 전체 테스트 실행 → 실패 항목 수정 → 통과 |

---

## 필수 참조 문서 (반드시 먼저 읽을 것)
1. `.docs/conventions/test-convention.md` — 테스트 작성 규칙, Mock 패턴, Turbine 패턴, 행위 검증 철학
2. `.docs/test-workflow.md` — 테스트 구현 상세 가이드
3. `feature/home/src/test/java/com/herren/gongb2c/feature/home/HomeViewModelTest.kt` — **정석 레퍼런스 (새 ViewModel 테스트 작성 전 필수 읽기)**

## Phase 1: 테스트 생성 (생성 모드만)

### 1-1. 대상 클래스 분류

| 대상 | 테스트 베이스 클래스 | 주요 검증 항목 |
|------|-------------------|--------------|
| **ViewModel** | `MockWebServerTestViewModel` | init State, Intent → State 변화, Intent → SideEffect 방출, 에러 처리 |
| **UseCase** | JUnit 5 + MockK | invoke 반환값, 데이터 변환 결과, 에러 전파, Repository combine 결과 |

> **UseCase 테스트 현황 (2026-05-13)**: `core/domain` 의 UseCase 14+ 개 대비 실테스트 파일 거의 없음 (`ExampleUnitTest.kt` 스켈레톤만). ViewModel 테스트가 MockWebServer 로 통합 검증을 다 흡수하지만 **순수 변환/조합 로직이 들어간 UseCase 는 단위 테스트 권장**. 생성 모드 인자가 UseCase 클래스명이면 우선순위 높게 처리.

### 1-2. 사전 확인
- 대상 클래스 파일 위치 확인
- 기존 테스트 파일 존재 여부 (있으면 수정 모드로 전환)
- 의존성 파악 (UseCase, Repository, Service 등)
- Mock JSON 파일 확인 — 위치 2곳:
  - `core/data/src/testFixtures/resources/` (공용 mock, 약 120개)
  - `feature/{모듈}/src/test/resources/` (모듈 전용 mock, 약 77개)
  - 신규 추가 시 — 여러 모듈 공유면 testFixtures, 단일 모듈 전용이면 feature 모듈 안

### 1-3. 테스트 코드 생성

**ViewModel 테스트 (home 정석)**:
- `MockWebServerTestViewModel` 상속
- **Fixture 분리**: 모듈 전용 `XxxTestFixture` private object 로 mock 데이터 모음
- **Intent → 결과 검증**: `runIntentTest(intent=..., expected=...)` 헬퍼로 시나리오 그룹화
- **SideEffect 검증**: `sideEffects.expectSideEffect<T>()` (from `core/testing/.../SideEffectTestExtensions.kt`)
- 초기화 State / Intent → State 변화 / Intent → SideEffect 방출 / 에러 처리

```kotlin
// 행위 검증 예시 (HomeViewModelTest 패턴)
@Nested
inner class IntentTest {
    @Test
    fun `OnBannerClick 시 NavigateBanner SideEffect 가 발생한다`() = runIntentTest(
        intent = HomeIntent.OnBannerClick(url = HomeTestFixture.URL, title = "배너"),
        expected = HomeSideEffect.NavigateBanner(url = HomeTestFixture.URL, title = "배너"),
    )
}
```

**UseCase 테스트**:
- JUnit 5 + `@ExtendWith(MockKExtension::class)`
- `@MockK`로 Repository 모킹
- **반환값 검증** (호출 횟수가 아닌 결과). invoke 결과, 데이터 변환, 에러 전파

**공통**:
- 한글 백틱 테스트명: `` `초기 상태는 Loading이다` ``
- `@Nested` 클래스로 그룹화 (Intent / State / SideEffect / Error)

---

## Phase 2: 테스트 실행

```bash
# 특정 클래스 테스트
./gradlew :{module}:testDevDebugUnitTest --tests "*{ClassName}Test" --continue 2>&1

# 모듈 전체 테스트
./gradlew :{module}:testDevDebugUnitTest --continue 2>&1

# 전체 테스트
./gradlew testDevDebugUnitTest --continue 2>&1
```

- 전체 통과 시 → Phase 4(결과 보고)로 이동
- 실패 있으면 → Phase 3으로

---

## Phase 3: 실패 수정 루프 (최대 3회 반복)

### 3-1. 실패 원인 분석

실행 결과에서 실패 테스트 클래스/메서드, 에러 메시지, 스택트레이스 추출.

| 원인 유형 | 증상 | 수정 방법 |
|----------|------|----------|
| API 변경 | Entity/Vo 필드 불일치 | Mock 데이터/JSON 업데이트 |
| ViewModel 로직 변경 | assertion 실패 (expected != actual) | expected 값 수정 |
| 새 의존성 추가 | lateinit not initialized | `@MockK` + `coEvery` 추가 |
| SideEffect 변경 | 순서/개수 불일치 | `skipItems()` 조정 |
| 데이터 포맷 변경 | "expected:<9> but was:<잔여 9회>" | Entity mapper 결과에 맞게 수정 |
| MockWebServer 관련 | ConnectException, Turbine timeout | lifecycle 확인 |
| Coroutine 타이밍 | 비동기 미완료 | `advanceUntilIdle()`, `skipItems()` 추가 |

### 3-2. 소스 코드 변경 확인
```bash
git log --oneline -10 -- {소스파일경로}
git diff HEAD~5 -- {소스파일경로}
```

### 3-3. 테스트 코드 수정

**수정 시 필수 규칙**:
- Repository Mock: data class 직접 사용 금지, MockWebServer Service 필수
  ```kotlin
  // 금지
  coEvery { repository.getData() } returns flow { emit(DataVo()) }
  
  // 필수
  coEvery { repository.getData() } coAnswers {
      flow { service.getData().suspendOnResponseWithMessage(...) }
  }
  ```
- Turbine: ShowLoading SideEffect 처리
  - home 정석은 `runIntentTest` 헬퍼 내부에서 ShowLoading 흡수 (별도 `skipItems` 불필요)
  - 직접 Turbine 사용 시만 `sideEffects.skipItems(2)` (ShowLoading true/false 2건)
  - **호출 횟수 (`exactly = N`) / requestCount 로 검증 금지** — 행위 결과만 검증
- **SA-MVI 룰 위반 금지** (detekt 가 pre-commit 에서 차단):
  - `SA-MVI-003 ForbidUiStateMutableCast`: `uiState as MutableStateFlow` 금지 → `awaitItem()` / `expectMostRecentItem()`
  - `SA-MVI-004 ForbidUiSideEffectMutableCast`: `sideEffect as MutableSharedFlow` 금지 → `expectSideEffect<T>()`
  - `SA-MVI-007 ForbidDirectContainerUiStateAccess`: `viewModel.container.uiState` 직접 접근 금지 → `viewModel.uiState` 사용
  - SA-Rule Registry: `.b2cspec/sa-rule-registry.md`

### 3-4. 수정 후 재실행
```bash
./gradlew :{module}:testDevDebugUnitTest --tests "*{TestClassName}" --continue 2>&1
```

- 통과 → Phase 4로
- 실패 → 3-1부터 반복 (최대 3회)
- 3회 실패 시 → 수동 확인 필요 항목으로 보고

---

## Phase 4: 결과 보고

```
## 유닛 테스트 에이전트 결과

### 모드: {생성/수정/전체 수정}
### 대상: {클래스명 / 모듈명}

### 실행 결과
| 항목 | 값 |
|------|-----|
| 전체 테스트 | {N}개 |
| 성공 | {N}개 |
| 실패 | {N}개 |
| 수정 라운드 | {N}회 |

### 생성된 테스트 (생성 모드)
- 파일: {테스트 파일 경로}
- 테스트 메서드: {N}개

### 수정 내역 (수정 모드)
| 테스트 | 원인 | 수정 내용 |
|--------|------|----------|

### 수동 확인 필요 (있는 경우)
- {수정 실패한 테스트 목록 및 원인}

### 변경된 파일
- {파일 경로 목록}
```

### 테스트 현황 문서 업데이트
- `.docs/viewmodel-test-status.md` — ViewModel 테스트 상태 갱신
