---
name: crm-ios-viewmodel-test
description: ViewModel 테스트 코드를 작성합니다. Input/Output Transform 패턴 또는 Direct Method 패턴을 지원합니다. ViewModel 테스트, 뷰모델 테스트 요청 시 사용.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# ViewModel Test

ViewModel 테스트 코드를 작성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-viewmodel-test] 스킬이 실행되었습니다."를 출력할 것

## 필수 문서 확인

테스트 작성 전 반드시 다음 문서를 확인:
- `.docs/conventions/TESTCODE.md` - 테스트 코드 작성 전 필수 체크리스트
- `.docs/conventions/VIEWMODEL_TEST_GUIDE.md` - ViewModel 테스트 가이드
- `.docs/conventions/CONVENTIONS.md` - 코딩 컨벤션

## 테스트 파일 위치

- ViewModel은 메인 앱 모듈 → `gongbiz-crm-b2bTests/ViewModelTests/` 에 생성

## 테스트 목적

- UseCase로부터 받은 데이터를 UI에 맞는 형태로 변환하는지 검증
- 사용자 인터랙션(Input)에 대한 적절한 반응(Output) 검증
- 상태 관리와 비즈니스 로직의 올바른 동작 확인

## 핵심 패턴

**실제 UseCase + MockService 조합**
- Mock UseCase 생성 금지
- MockService로 응답 제어
- Repository → UseCase → ViewModel 체인 전체 테스트

## ViewModel 패턴 종류

### 패턴 1: Input/Output Transform (권장)
```swift
final class SomeViewModel: ViewModelDescribing {
    func transform(_ input: Input) -> Output {
        // Observable 체이닝
    }
}
```

### 패턴 2: Direct Method
```swift
final class SomeViewModel {
    private let dataRelay = BehaviorRelay<[Item]>(value: [])

    func loadData() {
        // 직접 메서드 호출
    }
}
```

## 테스트 구조

### Input/Output Transform 패턴

```swift
final class SomeViewModelTests: XCTestCase {

    // MARK: - Constants
    private let timeInterval: TimeInterval = 10.0

    // MARK: - Properties
    private var mockService: MockService!
    private var repository: SomeV2Repository!
    private var useCase: SomeUseCase!
    private var viewModel: SomeViewModel!
    private var disposeBag: DisposeBag!

    // Input Subjects
    private var viewNeedLoadSubject: PublishSubject<Void>!
    private var buttonTouchedSubject: PublishSubject<Void>!

    // Output
    private var output: SomeViewModel.Output!

    override func setUp() {
        super.setUp()

        self.mockService = MockService()
        self.repository = SomeV2Repository(service: mockService)
        self.useCase = SomeUseCase(repository: repository)
        self.viewModel = SomeViewModel(useCase: useCase)
        self.disposeBag = DisposeBag()

        // Input subjects 초기화
        self.viewNeedLoadSubject = PublishSubject<Void>()
        self.buttonTouchedSubject = PublishSubject<Void>()

        // ViewModel transform
        let input = SomeViewModel.Input(
            viewNeedLoadObservable: viewNeedLoadSubject.asObservable(),
            buttonTouchedObservable: buttonTouchedSubject.asObservable()
        )

        self.output = viewModel.transform(input)
    }

    override func tearDown() {
        super.tearDown()

        mockService = nil
        repository = nil
        useCase = nil
        viewModel = nil
        disposeBag = nil
        viewNeedLoadSubject = nil
        buttonTouchedSubject = nil
        output = nil
    }
}
```

## 실행 프로세스

### 1단계: ViewModel 분석

- 패턴 확인 (Input/Output vs Direct Method)
- 의존하는 UseCase 확인
- Input/Output 구조 파악

**의존성 및 초기화 메서드 확인 (중요!)**:
- **DTO 초기화**: 실제 DTO 파일을 Read하여 정확한 이니셜라이저 파라미터 확인
- **의존성 타입**: 정확한 import와 타입명 확인
- **파라미터명 정확성**: 실제 사용되는 파라미터명 (dto vs data 등)

### 2단계: 테스트 코드 작성

**데이터 로드 테스트**:
```swift
func test_화면_로드_시_데이터_조회() {
    // Given
    mockService.setResponseType(.success(SomeMockJSONFile.getDataSuccess))

    let expectation = XCTestExpectation(description: "Load data")
    var receivedItems: [Item]?

    output.itemsObservable
        .skip(1)  // 초기값 스킵
        .subscribe(onNext: { items in
            receivedItems = items
            expectation.fulfill()
        })
        .disposed(by: disposeBag)

    // When
    viewNeedLoadSubject.onNext(())

    // Then
    wait(for: [expectation], timeout: timeInterval)

    XCTAssertNotNil(receivedItems)
    XCTAssertEqual(receivedItems?.count, 3)
}
```

**버튼 탭 테스트**:
```swift
func test_저장_버튼_탭_시_저장_성공() {
    // Given
    mockService.setResponseType(.success(SomeMockJSONFile.saveSuccess))

    let expectation = XCTestExpectation(description: "Save successfully")
    var saveResult: Bool?

    output.saveResultObservable
        .subscribe(onNext: { result in
            saveResult = result
            expectation.fulfill()
        })
        .disposed(by: disposeBag)

    // When
    saveButtonTouchedSubject.onNext(())

    // Then
    wait(for: [expectation], timeout: timeInterval)

    XCTAssertTrue(saveResult == true)
}
```

**상태 변경 테스트**:
```swift
func test_아이템_선택_시_상태_변경() {
    // Given
    mockService.setResponseType(.success(SomeMockJSONFile.getItemsSuccess))

    let loadExpectation = XCTestExpectation(description: "Load items")
    let selectExpectation = XCTestExpectation(description: "Select item")

    var selectedItem: Item?

    // 먼저 데이터 로드
    output.itemsObservable
        .skip(1)
        .take(1)
        .subscribe(onNext: { _ in
            loadExpectation.fulfill()
        })
        .disposed(by: disposeBag)

    viewNeedLoadSubject.onNext(())
    wait(for: [loadExpectation], timeout: timeInterval)

    // When - 아이템 선택
    output.selectedItemObservable
        .subscribe(onNext: { item in
            selectedItem = item
            selectExpectation.fulfill()
        })
        .disposed(by: disposeBag)

    itemSelectedSubject.onNext(0)

    // Then
    wait(for: [selectExpectation], timeout: timeInterval)

    XCTAssertNotNil(selectedItem)
}
```

### 3단계: 컴파일 검증 (필수!)

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

### 4단계: crm-ios-coverage-checker 스킬 호출

`crm-ios-coverage-checker` 스킬을 호출하여 테스트 실행 및 커버리지 분석을 수행합니다.

## 체크리스트

- [ ] ViewModel 패턴 확인 (Input/Output vs Direct)
- [ ] Input subjects 초기화
- [ ] Output transform 설정
- [ ] skip(1)로 초기값 처리
- [ ] Given-When-Then 패턴 사용
- [ ] 테스트 실행 및 통과 확인

## 주의사항

- 한 번에 하나씩 테스트 작성하여 검증
- Observable 스트림의 순서와 타이밍 주의
- skip, take 등 연산자 활용하여 정확한 시점 캡처

## 자주 놓치는 실수들 (반드시 확인!)

1. **DTO 초기화 파라미터 누락**
   - 실제 DTO 파일 Read하여 모든 파라미터 확인
   - Optional 파라미터도 명시적으로 nil 전달

2. **JSON 파일 한글 깨짐**
   - 생성 후 Read로 확인
   - UTF-8 인코딩 확인

3. **잘못된 파라미터명**
   - ViewModel/UseCase 메서드의 실제 파라미터명 확인
   - dto vs data 등 정확히 구분

4. **Input/Output 바인딩 누락**
   - setUp에서 transform 호출 확인
   - Input subjects 초기화 누락 주의

## 참조 문서

- ViewModel 테스트 가이드: `.docs/conventions/VIEWMODEL_TEST_GUIDE.md`
- UseCase 테스트 가이드: `.docs/conventions/USECASE_TEST_GUIDE.md`
- 호칭: `CLAUDE.local.md`
