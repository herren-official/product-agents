---
name: crm-ios-router-test
description: Router 테스트 코드를 작성합니다. NetworkSystem 모듈의 API 엔드포인트 path, method, parameters, encoding, mockFile 매핑을 검증합니다. Router 테스트, 라우터 테스트, 네트워크 테스트 시 사용.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Router Test

Router 테스트 코드를 작성하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-router-test] 스킬이 실행되었습니다."를 출력할 것

## 테스트 목적

Router의 각 case에 대해 다음을 검증:
- path (API 엔드포인트 경로)
- method (HTTP 메서드)
- parameters (요청 파라미터)
- encoding (인코딩 방식)
- successMockJSONFile (Mock 파일 매핑)

## 필수 문서 확인

테스트 작성 전 반드시 다음 문서를 확인:
- `.docs/conventions/TESTCODE.md` - 테스트 코드 작성 전 필수 체크리스트
- `.docs/conventions/CONVENTIONS.md` - 코딩 컨벤션

## 테스트 파일 위치

- Router는 NetworkSystem 모듈 → `NetworkSystemTests/RouterTests/` 에 생성

## 실행 프로세스

### 1단계: 대상 Router 분석

- Router enum의 모든 case 확인
- 각 case의 path, method, parameters, encoding, successMockJSONFile 분석
- delegate 사용 여부 확인 (RouterConnectable 프로토콜)

### 2단계: 의존성 및 초기화 메서드 확인

- **DTO 초기화**: 실제 DTO 파일을 Read하여 정확한 이니셜라이저 파라미터 확인
- **MockJSONFile 매핑**: enum case 이름과 fileName 메서드 확인
- **파라미터명 정확성**: 실제 사용되는 파라미터명 (dto vs data 등)

### 3단계: MockRouterConnectDelegate 확인

```swift
// Router가 RouterConnectable을 채택한 경우
// MockRouterConnectDelegate를 사용하여 shopNumber, employeeNumber 등 제공

final class MockRouterConnectDelegate: RouterConnectDelegate {
    var shopNumber: Int { return 1 }
    var employeeNumber: Int { return 1 }
}
```

### 4단계: 테스트 코드 작성

```swift
import XCTest
@testable import NetworkSystem

final class SomeV2RouterTests: XCTestCase {

    // MARK: - Properties
    private var delegate: MockRouterConnectDelegate!

    // MARK: - Life Cycle
    override func setUp() {
        super.setUp()
        delegate = MockRouterConnectDelegate()
    }

    override func tearDown() {
        delegate = nil
        super.tearDown()
    }

    // MARK: - Tests
    func test_getSomeList_path() {
        let router = SomeV2Router.getSomeList
        router.delegate = delegate

        XCTAssertEqual(router.path, "/api/v2/some/list")
    }

    func test_getSomeList_method() {
        let router = SomeV2Router.getSomeList
        XCTAssertEqual(router.method, .get)
    }

    func test_getSomeList_successMockJSONFile() {
        let router = SomeV2Router.getSomeList

        // ✅ 올바른 패턴 (enum case 비교)
        XCTAssertEqual(
            router.successMockJSONFile as? SomeV2MockJSONFile,
            SomeV2MockJSONFile.getSomeList
        )

        // ❌ 잘못된 패턴 (fileName 비교) - 사용 금지
        // XCTAssertEqual(router.successMockJSONFile?.fileName, "GetSomeList")
    }

    func test_postSomeData_parameters() {
        let dto = SomeRequestDTO(id: 1, name: "test")
        let router = SomeV2Router.postSomeData(dto: dto)
        router.delegate = delegate

        let parameters = router.parameters
        XCTAssertEqual(parameters?["id"] as? Int, 1)
        XCTAssertEqual(parameters?["name"] as? String, "test")
    }

    func test_delegate_nil_처리() {
        let router = SomeV2Router.getSomeList
        // delegate 미설정 시 동작 확인
        XCTAssertNotNil(router.path)
    }
}
```

### 5단계: MockJSONFile enum case 비교 패턴

```swift
// ✅ 올바른 패턴 (enum case 비교 - as? 타입캐스팅 필수)
XCTAssertEqual(
    router.successMockJSONFile as? ShopV2MockJSONFile,
    ShopV2MockJSONFile.postShopAdd
)

// ❌ 잘못된 패턴 (fileName 비교)
XCTAssertEqual(router.successMockJSONFile?.fileName, "PostShopAdd")
```

### 6단계: crm-ios-coverage-checker 스킬 호출

`crm-ios-coverage-checker` 스킬을 호출하여 테스트 실행 및 커버리지 분석을 수행합니다.

## 체크리스트

### Router 테스트 체크리스트
- [ ] MockRouterConnectDelegate 생성 및 설정
- [ ] 모든 router case에 대한 테스트 메서드
- [ ] path, method, parameters, encoding 검증
- [ ] MockJSONFile enum case 비교 (타입 캐스팅 후)
- [ ] delegate nil 처리 테스트
- [ ] 정확한 DTO 초기화 파라미터

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
   - Router/Repository 메서드의 실제 파라미터명 확인
   - dto vs data 등 정확히 구분

## 참조 문서

- 테스트 가이드: `.docs/conventions/TESTCODE.md`
- 호칭: `CLAUDE.local.md`
