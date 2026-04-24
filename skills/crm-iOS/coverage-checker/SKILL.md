---
name: crm-ios-coverage-checker
description: 테스트 실행 후 코드 커버리지를 분석합니다. 파일별 커버리지 비율을 확인하고 개선 방향을 제안합니다. 커버리지, coverage 요청 시 사용.
allowed-tools: Read, Grep, Glob, Bash
---

# Coverage Checker

테스트 실행 후 코드 커버리지를 분석하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-coverage-checker] 스킬이 실행되었습니다."를 출력할 것

## 실행 시점

- "커버리지", "coverage", "커버리지 확인" 키워드 감지 시
- 테스트 작성 스킬 완료 후 커버리지 확인이 필요할 때

## 실행 프로세스

### 1단계: 대상 확인

사용자가 지정한 파일/모듈 또는 변경된 파일 기반으로 대상 결정:
- NetworkSystem 모듈 → `NetworkSystemTests` 스킴
- 메인 앱 모듈 → `gongbiz-crm-b2bTests` 스킴

### 2단계: crm-ios-test-runner 스킬 호출

`crm-ios-test-runner` 스킬을 호출하여 테스트를 실행합니다.
**단, 테스트 실행 명령어에 `-enableCodeCoverage YES` 옵션을 반드시 추가합니다.**

- 테스트 실패 시 → crm-ios-test-runner의 실패 분석 결과를 따르고, 커버리지 분석은 중단
- 테스트 성공 시 → 3단계로 진행

### 3단계: xcresult 경로 탐색

```bash
# DerivedData에서 최신 xcresult 찾기
LATEST_XCRESULT=$(find ~/Library/Developer/Xcode/DerivedData/gongbiz-crm-iOS-*/Logs/Test \
  -name "*.xcresult" -maxdepth 1 2>/dev/null | sort -r | head -1)
echo "$LATEST_XCRESULT"
```

xcresult를 찾지 못한 경우:
- DerivedData 경로 확인
- 테스트가 `-enableCodeCoverage YES`로 실행되었는지 확인

### 4단계: 커버리지 리포트 추출

```bash
# 전체 리포트
xcrun xccov view --report "$LATEST_XCRESULT"

# 특정 키워드로 필터 (예: V2 파일만)
xcrun xccov view --report "$LATEST_XCRESULT" | grep "V2"

# 특정 파일 상세 (함수별 커버리지)
xcrun xccov view --file {파일경로} --report "$LATEST_XCRESULT"
```

### 5단계: 결과 분석 및 보고

**보고 형식**:
```
"[호칭], 커버리지 분석 결과입니다.

## 전체 요약
- 대상 파일: {N}개
- 100% 달성: {N}개
- 100% 미달: {N}개

## 100% 미달 파일
| 파일 | 커버리지 | 원인 |
|------|----------|------|
| SomeDTO.swift | 0% | Mock JSON에서 null 필드 |
| SomeRouter.swift | 85% | 미매핑 Router case |

## 개선 방향
1. {구체적 제안}
2. {구체적 제안}"
```

### 6단계: 100% 미달 파일 원인 분류

커버리지 100% 미달 파일은 다음 기준으로 원인을 분류:

| 분류 | 원인 | 개선 가능 |
|------|------|----------|
| Response DTO 0% | Mock JSON에서 null로 설정된 필드 | O - JSON에 데이터 채움 |
| Request DTO 0% | MockService가 요청 본문을 인코딩하지 않음 | X - 구조적 한계 |
| Router 미달 | successMockJSONFile에 미매핑된 case | O - MockJSONFile + Router 매핑 추가 |
| Repository 미달 | 테스트가 작성되지 않은 메서드 | O - 테스트 코드 추가 |
| Dead code | MockService가 고정 반환값 사용 (예: 항상 201) | X - 구조적 한계 |
| MockJSONFile 미달 | failure/alternative case가 Router에 미매핑 | X - 실패 케이스는 Router에서 매핑하지 않음 |

**개선 불가(X) 항목은 보고에 포함하되, "구조적 한계"로 명시합니다.**

## 금지 사항

- `-resultBundlePath` 옵션 사용 금지 (DerivedData 자동 생성 xcresult만 사용)
- 로그 파일 생성 금지 (`> log.txt`)

## 참조 문서

- 테스트 가이드: `.docs/conventions/TESTCODE.md`
- 빌드 가이드: CLAUDE.md의 빌드 및 개발 환경 섹션
- 호칭: `CLAUDE.local.md`
