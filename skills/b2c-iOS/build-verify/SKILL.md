---
name: b2c-ios-build-verify
description: "tuist generate, xcodebuild build, xcodebuild test를 순차 실행하여 빌드와 테스트를 검증합니다"
argument-hint: "[build | test | full]"
disable-model-invocation: false
allowed-tools: ["Bash", "Read"]
---

# /b2c-ios-build-verify - 빌드 및 테스트 검증

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[b2c-ios-build-verify] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 참조 문서

| Document | Path | Purpose |
|----------|------|---------|
| CLAUDE.md | [`CLAUDE.md`](CLAUDE.md) | 빌드/테스트 명령어 |
| TESTS.md | [`TESTS.md`](.docs/conventions/TESTS.md) | 테스트 실행 가이드, 스킴 구분 |

> 실행 명령어가 변경될 수 있으므로 반드시 위 문서를 먼저 읽고 최신 명령어를 사용할 것

## 실행 모드

| 모드 | 설명 | 실행 단계 |
|------|------|----------|
| `build` | 빌드만 검증 | 1 → 2 |
| `test` | 테스트만 실행 | 1 → 3 |
| `full` | 전체 검증 (기본값) | 1 → 2 → 3 |

## 실행 프로세스

### 1단계: 프로젝트 생성

파일 추가/삭제/이동이 있었을 때 필수:
```
CLAUDE.md에 정의된 tuist generate 명령어 실행
```
- 파일 변경이 없어도 안정성을 위해 생략하지 않는 것 권장
- 실패 시 tuist clean 후 재시도

### 2단계: 빌드 검증

```
CLAUDE.md에 정의된 xcodebuild build 명령어 실행
```
- **BUILD SUCCEEDED** 확인 필수
- 실패 시 에러 메시지 분석 후 보고

### 3단계: 테스트 실행

> 테스트 스킴 구분은 [TESTS.md](.docs/conventions/TESTS.md) 참조

```
CLAUDE.md에 정의된 xcodebuild test 명령어 실행
```

**규칙:**
- 기본: 전체 테스트 실행 (`-only-testing` 사용 금지)
- Unit Test와 UI Test 스킴이 분리되어 있음
- 사용자가 특정 테스트만 요청한 경우에만 `-only-testing` 허용

### 4단계: 결과 보고

```markdown
### 빌드/테스트 검증 결과

| 단계 | 결과 | 비고 |
|------|------|------|
| tuist generate | PASS/FAIL | (필요 시 메시지) |
| xcodebuild build | PASS/FAIL | (필요 시 메시지) |
| xcodebuild test | PASS/FAIL | (실패 테스트 목록) |
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| tuist generate 실패 | `tuist clean` 후 재시도 |
| 빌드 실패 | 에러 메시지 분석, 수정 필요 파일 안내 |
| 테스트 실패 | 실패한 테스트 목록 + 에러 내용 보고 |
| 시뮬레이터 문제 | TESTS.md의 시뮬레이터 안정성 섹션 참조 |

## 테스트 로그 정리

테스트 실행 후 로그 파일 정리:
```bash
rm -f *_test_output.log *_test_result.log
```
