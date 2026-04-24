---
name: crm-ios-test-runner
description: 테스트를 실행하고 결과를 분석합니다. 실패 시 원인을 파악하고 수정 방향을 제안합니다. 테스트 실행, 테스트 돌려줘 요청 시 사용.
allowed-tools: Read, Grep, Glob, Bash
---

# Test Runner

테스트를 실행하고 결과를 분석하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-test-runner] 스킬이 실행되었습니다."를 출력할 것

## 테스트 실행 명령어

### Repository/Router 테스트 (빠름, destination 불필요)

```bash
# 워크스페이스 방식 (권장) - destination 지정하면 안 됨
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme NetworkSystemTests

# 특정 클래스만
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme NetworkSystemTests \
  -only-testing:NetworkSystemTests/{테스트클래스명}

# 특정 메서드만
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme NetworkSystemTests \
  -only-testing:NetworkSystemTests/{테스트클래스명}/{테스트메서드명}
```

### UseCase/ViewModel 테스트 (느림, destination 필수)

```bash
# 시뮬레이터 필요
xcodebuild test -workspace gongbiz-crm-iOS.xcworkspace \
  -scheme gongbiz-crm-b2bTests \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -only-testing:gongbiz-crm-b2bTests/{테스트클래스명}
```

**주의**: 빌드 시간이 오래 걸림 (백그라운드 실행 권장)

## 실행 프로세스

### 1단계: 테스트 대상 확인

```bash
# 테스트 파일 위치 확인
# Repository/Router → NetworkSystemTests
# UseCase/ViewModel → gongbiz-crm-b2bTests
```

### 2단계: 테스트 실행

적절한 명령어로 테스트 실행

### 3단계: 결과 분석

**성공 시**:
```
"[호칭], 테스트가 성공했습니다.

✅ {테스트클래스명}
  - test_메서드1 ✅
  - test_메서드2 ✅"
```

**실패 시**:
```
"[호칭], 테스트가 실패했습니다.

❌ {테스트클래스명}
  - test_메서드1 ❌

실패 원인:
XCTAssertEqual failed: ("0") is not equal to ("6")

분석:
- JSON 데이터와 expected 값 불일치 가능성
- nil vs 빈 배열 구분 확인 필요

수정 제안:
1. Mock JSON 파일 확인
2. expected 값과 JSON 데이터 비교"
```

## 실패 원인별 대응

### 1. XCTAssertEqual 실패
```
XCTAssertEqual failed: ("A") is not equal to ("B")
```
→ JSON 데이터와 expected 값 비교

### 2. 타임아웃
```
Asynchronous wait failed: Exceeded timeout
```
→ Mock JSON 파일 또는 Router 매핑 확인

### 3. JSON 파일 찾을 수 없음
```
Failed to load mock JSON file
```
→ MockJSONFile fileName과 실제 파일명 일치 확인

### 4. 디코딩 실패
```
keyNotFound / typeMismatch
```
→ DTO 구조와 JSON 구조 비교

### 5. nil 반환
```
XCTAssertNotNil failed
```
→ Router successMockJSONFile 매핑 확인

## 디버깅 팁

### 에러 메시지 필터링
```bash
xcodebuild test ... 2>&1 | grep -E "XCTAssert|error:|failed" -A 5 -B 5
```

### 특정 테스트 상세 로그
```bash
xcodebuild test ... \
  -only-testing:NetworkSystemTests/{클래스}/{메서드} \
  -parallel-testing-enabled NO 2>&1 | grep -E "XCTAssert|error:" -A 5 -B 5
```

## 금지 사항

- ⛔ 로그 파일 생성 금지 (`> log.txt`)
- ⛔ `-resultBundlePath` 옵션 사용 금지
- ⛔ Repository/Router 테스트(워크스페이스 방식)에서 `-destination` 지정 금지

## 체크리스트

### 실패 시 확인 순서
1. [ ] 에러 메시지 정확히 확인
2. [ ] Mock JSON 파일 존재 및 내용 확인
3. [ ] MockJSONFile enum fileName 확인
4. [ ] Router successMockJSONFile 매핑 확인
5. [ ] expected 값과 JSON 데이터 비교
6. [ ] DTO Equatable 채택 여부 확인

## 커버리지 확인

테스트 실행 후 커버리지 확인이 필요하면 `crm-ios-coverage-checker` 스킬을 호출하세요.

## 참조 문서

- 테스트 가이드: `.docs/conventions/TESTCODE.md`
- 빌드 가이드: `.docs/BUILD_GUIDE.md`
- 호칭: `CLAUDE.local.md`
