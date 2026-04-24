---
name: crm-ios-usecase-test
description: UseCase 테스트 코드를 작성합니다. 실제 Repository + MockService 패턴으로 DTO → 도메인 모델 변환 로직을 검증합니다. UseCase 테스트, 유즈케이스 테스트 요청 시 사용.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# UseCase Test

UseCase 테스트 코드를 작성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-usecase-test] 스킬이 실행되었습니다."를 출력할 것

## 필수 문서 확인

테스트 작성 전 반드시 다음 문서를 확인:
- `.docs/conventions/TESTCODE.md` - 테스트 코드 작성 전 필수 체크리스트
- `.docs/conventions/USECASE_TEST_GUIDE.md` - UseCase 테스트 가이드
- `.docs/conventions/CONVENTIONS.md` - 코딩 컨벤션

## 테스트 파일 위치

- UseCase는 메인 앱 모듈 → `gongbiz-crm-b2bTests/UseCaseTests/` 에 생성

## 테스트 목적

- Repository에서 받은 DTO를 도메인 모델로 올바르게 변환하는지 검증
- 여러 Repository를 조합하는 비즈니스 로직 검증
- nil/에러 응답 처리 검증

## 핵심 패턴

**실제 Repository + MockService 조합**
- Mock Repository 생성 금지
- MockService로 응답 제어
- Repository 테스트와 동일한 Mock JSON 파일 활용

## 테스트 구조

```swift
final class SomeUseCaseTests: XCTestCase {

    // MARK: - Constants
    private let timeInterval: TimeInterval = 10.0

    // MARK: - Properties
    private var mockService: MockService!
    private var repository: SomeV2Repository!
    private var useCase: SomeUseCase!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        self.mockService = MockService()
        self.repository = SomeV2Repository(service: mockService)
        self.useCase = SomeUseCase(repository: repository)
        self.disposeBag = DisposeBag()
    }

    override func tearDown() {
        super.tearDown()

        mockService = nil
        repository = nil
        useCase = nil
        disposeBag = nil
    }
}
```

## 실행 프로세스

### 1단계: UseCase 분석

- 의존하는 Repository 확인
- 입력/출력 타입 확인
- DTO → 도메인 모델 변환 로직 파악

**의존성 및 초기화 메서드 확인 (중요!)**:
- **DTO 초기화**: 실제 DTO 파일을 Read하여 정확한 이니셜라이저 파라미터 확인
- **의존성 타입**: 정확한 import와 타입명 확인
- **파라미터명 정확성**: 실제 사용되는 파라미터명 (dto vs data 등)

### 2단계: Mock JSON 확인

기존 Repository 테스트용 Mock JSON 파일 활용
- 없으면 crm-ios-repository-test 스킬로 먼저 생성

### 3단계: 테스트 코드 작성

**성공 케이스**:
```swift
func test_직원_목록_조회_성공() {
    // Given
    mockService.setResponseType(.success(EmployeeV2MockJSONFile.getEmployeeListSuccess))

    let expectation = XCTestExpectation(description: "Get employee list")
    var receivedEmployees: [Employee]?

    // When
    useCase.getEmployeeList()
        .subscribe(
            onSuccess: { employees in
                receivedEmployees = employees
                expectation.fulfill()
            },
            onFailure: { _ in
                XCTFail("Request should not fail")
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)

    // Then
    wait(for: [expectation], timeout: timeInterval)

    XCTAssertNotNil(receivedEmployees)
    XCTAssertEqual(receivedEmployees?.count, 3)
    XCTAssertEqual(receivedEmployees?[0].name, "담당자없음")
}
```

**실패/nil 처리 케이스**:
```swift
func test_직원_목록_조회_nil_응답() {
    // Given
    mockService.setResponseType(.failure())

    let expectation = XCTestExpectation(description: "Handle nil response")
    var receivedEmployees: [Employee]?

    // When
    useCase.getEmployeeList()
        .subscribe(
            onSuccess: { employees in
                receivedEmployees = employees
                expectation.fulfill()
            },
            onFailure: { _ in
                XCTFail("UseCase should handle nil response")
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)

    // Then
    wait(for: [expectation], timeout: timeInterval)

    XCTAssertNil(receivedEmployees)
}
```

**Bool 반환 케이스**:
```swift
func test_업데이트_성공() {
    // Given
    mockService.setResponseType(.success(SomeMockJSONFile.updateSuccess))

    let expectation = XCTestExpectation(description: "Update successfully")
    var isSuccess = false

    // When
    useCase.update(data: someData)
        .subscribe(
            onSuccess: { success in
                isSuccess = success
                expectation.fulfill()
            },
            onFailure: { _ in
                XCTFail()
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)

    // Then
    wait(for: [expectation], timeout: timeInterval)

    XCTAssertTrue(isSuccess)
}
```

### 4단계: 컴파일 검증 (필수!)

```bash
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme gongbiz-crm-b2bTests \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -only-testing:gongbiz-crm-b2bTests/{TestClassName} 2>&1 | grep -E "error:|warning:"
```

컴파일 에러 발생 시:
1. DTO 구조 재확인 (Glob -> Read)
2. 초기화 파라미터 수정
3. 타입 및 import 수정
4. 재컴파일 -> 성공할 때까지 반복

### 5단계: crm-ios-coverage-checker 스킬 호출

`crm-ios-coverage-checker` 스킬을 호출하여 테스트 실행 및 커버리지 분석을 수행합니다.

## 체크리스트

- [ ] UseCase 의존성 (Repository) 확인
- [ ] Mock JSON 파일 존재 여부 확인
- [ ] Given-When-Then 패턴 사용
- [ ] 성공/실패 케이스 모두 작성
- [ ] 도메인 모델 변환 결과 검증
- [ ] 테스트 실행 및 통과 확인

## 자주 놓치는 실수들 (반드시 확인!)

1. **DTO 초기화 파라미터 누락**
   - 실제 DTO 파일 Read하여 모든 파라미터 확인
   - Optional 파라미터도 명시적으로 nil 전달

2. **JSON 파일 한글 깨짐**
   - 생성 후 Read로 확인
   - UTF-8 인코딩 확인

3. **잘못된 파라미터명**
   - Repository/UseCase 메서드의 실제 파라미터명 확인
   - dto vs data 등 정확히 구분

4. **Mock JSON 파일 누락**
   - UseCase 테스트는 Repository 테스트용 Mock JSON 파일을 공유
   - 없으면 crm-ios-repository-test 스킬로 먼저 생성

## 참조 문서

- UseCase 테스트 가이드: `.docs/conventions/USECASE_TEST_GUIDE.md`
- Repository 테스트 가이드: `.docs/conventions/TESTCODE.md`
- 호칭: `CLAUDE.local.md`
