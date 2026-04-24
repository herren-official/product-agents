---
name: crm-ios-repository-test
description: Repository 테스트 코드를 작성합니다. NetworkSystem 모듈의 API 응답 DTO 변환을 검증합니다. Repository 테스트, 레포지토리 테스트, 네트워크 테스트 시 사용.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Repository Test

Repository 테스트 코드를 작성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-repository-test] 스킬이 실행되었습니다."를 출력할 것

## 필수 문서 확인

테스트 작성 전 반드시 다음 문서를 확인:
- `.docs/conventions/TESTCODE.md` - 테스트 코드 작성 전 필수 체크리스트
- `.docs/conventions/CONVENTIONS.md` - 코딩 컨벤션

## 테스트 파일 위치

- Repository는 NetworkSystem 모듈 → `NetworkSystemTests/RepositoryTests/` 에 생성

## 테스트 목적

API 요청 시 response를 의도한대로 DTO로 변환하는지 검증

## 테스트 구조

```
Repository Test
    ↓ uses
MockService
    ↓ gets file from
Router.successMockJSONFile
    ↓ points to
MockJSONFile enum
    ↓ provides fileName
JSON file in bundle
    ↓ decoded to
ResponseData<DTO>
```

## 실행 프로세스

### 1단계: 대상 분석

테스트할 Repository 메서드 분석:
- 메서드 시그니처 (파라미터명, 타입)
- 반환 타입 (Single vs AnyPublisher)
- Request/Response DTO 구조

**의존성 및 초기화 메서드 확인 (중요!)**:
- **DTO 초기화**: 실제 DTO 파일을 Read하여 정확한 이니셜라이저 파라미터 확인
- **MockJSONFile 매핑**: enum case 이름과 fileName 메서드 확인
- **파라미터명 정확성**: dto가 아닌 data 등 실제 사용되는 파라미터명

### 2단계: Mock JSON 파일 생성

**위치**: `NetworkSystem/MockData/{Feature}/`
**파일명**: `Get{MethodName}_Success.json`

**V2 API JSON 구조**:
```json
{
    "data": {
        // 실제 응답 데이터
    },
    "errorResponse": {
        "timestamp": null,
        "status": 200,
        "message": null,
        "code": null,
        "errors": null
    }
}
```

**규칙**:
- 들여쓰기: 4칸 스페이스
- 한글 인코딩 확인 필수 (작성 후 Read로 검증)

### 3단계: MockJSONFile enum 업데이트

**위치**: `NetworkSystem/MockData/{Feature}/{Feature}MockJSONFile.swift`

```swift
public enum StatisticsV2MockJSONFile: MockJSONFile {
    case getTodayStatistics  // 추가

    public var fileName: String {
        switch self {
        case .getTodayStatistics:
            return "GetTodayStatistics_Success"
        }
    }
}
```

### 4단계: Router에 Mock 파일 매핑

**위치**: `NetworkSystem/Router/{Feature}Router.swift`

```swift
extension StatisticsV2Router {
    public var successMockJSONFile: MockJSONFile? {
        switch self {
        case .getTodayStatistics:
            return StatisticsV2MockJSONFile.getTodayStatistics
        default:
            return nil
        }
    }
}
```

### 5단계: 테스트 코드 작성

**RxSwift 패턴**:
```swift
func test_methodName_응답_성공() {
    let expectation = XCTestExpectation(description: testExpectationDescription)

    let expectedResponse = SomeDTO(/* JSON과 동일한 값 */)

    repository.someMethod(dto: requestDTO).subscribe(
        onSuccess: { response in
            XCTAssertEqual(response, expectedResponse)
            expectation.fulfill()
        },
        onFailure: { _ in
            XCTFail("Request should not fail")
            expectation.fulfill()
        }
    ).disposed(by: disposeBag)

    wait(for: [expectation], timeout: timeInterval)
}
```

**Combine 패턴**:
```swift
func test_methodName_응답_성공() {
    let expectation = XCTestExpectation(description: testExpectationDescription)

    repository.someMethod(dto: requestDTO).sink { response in
        switch response {
        case .success(let result):
            XCTAssertEqual(result, expectedResponse)
            expectation.fulfill()
        case .failure:
            XCTFail()
            expectation.fulfill()
        }
    }.store(in: &cancellables)

    wait(for: [expectation], timeout: timeInterval)
}
```

### 6단계: MockJSONFile enum case 비교 패턴

```swift
// ✅ 올바른 패턴 (enum case 비교 - as? 타입캐스팅 필수)
XCTAssertEqual(
    router.successMockJSONFile as? ShopV2MockJSONFile,
    ShopV2MockJSONFile.postShopAdd
)

// ❌ 잘못된 패턴 (fileName 비교)
XCTAssertEqual(router.successMockJSONFile?.fileName, "PostShopAdd")
```

### 7단계: 컴파일 검증 (필수!)

```bash
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme NetworkSystemTests \
  -only-testing:NetworkSystemTests/{TestClassName} 2>&1 | grep -E "error:|warning:"
```

컴파일 에러 발생 시:
1. DTO 구조 재확인 (Glob -> Read)
2. 초기화 파라미터 수정
3. 타입 및 import 수정
4. 재컴파일 -> 성공할 때까지 반복

### 8단계: crm-ios-coverage-checker 스킬 호출

`crm-ios-coverage-checker` 스킬을 호출하여 테스트 실행 및 커버리지 분석을 수행합니다.

## 체크리스트

### 작성 전
- [ ] Repository 메서드 시그니처 확인
- [ ] Request/Response DTO 구조 완전 분석
- [ ] Optional 여부 확인 (nil vs 빈 배열)

### 작성 중
- [ ] JSON 필드와 DTO 타입 일치
- [ ] MockJSONFile fileName = 실제 파일명
- [ ] Router successMockJSONFile 매핑

### 작성 후
- [ ] JSON 한글 인코딩 확인 (Read로 검증)
- [ ] 테스트 실행 및 통과 확인
- [ ] Equatable 필요 시 DTO에 추가

## Void 반환 타입 처리

```swift
// Router 설정
case .deleteItem:
    return InvalidJSONFile.empty

// 테스트 코드
func test_deleteItem_응답_성공() {
    repository.deleteItem(id: 123).subscribe(
        onSuccess: { _ in
            XCTAssertTrue(true)
            expectation.fulfill()
        },
        onFailure: { _ in
            XCTFail()
            expectation.fulfill()
        }
    ).disposed(by: disposeBag)
}
```

## 자주 놓치는 실수들 (반드시 확인!)

1. **DTO 초기화 파라미터 누락**
   - 실제 DTO 파일 Read하여 모든 파라미터 확인
   - Optional 파라미터도 명시적으로 nil 전달

2. **MockJSONFile 매핑 패턴 오류**
   - enum case 직접 비교 (as? 타입캐스팅 필수)
   - fileName 비교 사용 금지

3. **JSON 파일 한글 깨짐**
   - 생성 후 Read로 확인
   - UTF-8 인코딩 확인

4. **잘못된 파라미터명**
   - Repository 메서드의 실제 파라미터명 확인
   - dto vs data 등 정확히 구분

## 참조 문서

- 테스트 가이드: `.docs/conventions/TESTCODE.md`
- 호칭: `CLAUDE.local.md`
