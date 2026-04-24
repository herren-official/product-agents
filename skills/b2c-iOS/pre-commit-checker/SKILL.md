---
name: b2c-ios-pre-commit-checker
description: "커밋 전 코드 컨벤션을 검사합니다. commit 스킬에서 자동 호출되며, 컨벤션 검사/pre-commit 요청 시에도 사용"
argument-hint: "인자 없음 (commit 스킬에서 자동 호출되거나 단독 실행)"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Pre-Commit Checker

커밋 전 코드 컨벤션을 검사하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[pre-commit-checker] 스킬이 실행되었습니다."를 출력할 것

## 검사 대상 파일

변경된 Swift 파일 목록을 수집합니다.
- staged 파일: `git diff --cached --name-only --diff-filter=ACM` 에서 `.swift` 파일 필터링
- staged 파일이 없으면 unstaged 변경 파일 대상

## 검사 항목

### 에러 (수정 필요)

#### 1. Force Unwrapping (강제 언래핑)
IBOutlet 제외한 강제 언래핑 검사

검사 제외 대상:
- IBOutlet, IBAction
- 문자열 리터럴 내부
- 주석 내부
- 부등호 연산자 (`!=`)
- try!, as!는 품질 검사 섹션에서 별도 검출 (에러 항목과 중복 보고하지 않음)

#### 2. 120자 초과
한 줄이 120자를 초과하는 경우

#### 3. 민감한 정보 포함 여부
변경된 파일에 민감한 정보가 포함되어 있는지 확인:
- `.env` 파일
- credentials, API key, secret 등 하드코딩
- 비밀번호, 토큰 등 인증 정보

### 경고 (목록화)

#### 4. print문
디버깅용 print문 목록 (추후 제거 대상)

#### 5. TODO/FIXME
미완료 작업 목록

### 컨벤션 검사

#### 6. Import 순서

> [CONVENTIONS.md](.docs/conventions/CONVENTIONS.md)의 Import 순서 규칙 참조
> Read 도구로 해당 문서를 읽어 올바른 Import 순서 검사

- 그룹 순서 (빈 줄로 분리) 및 각 그룹 내 알파벳 순 정렬 확인
- 중복 import 검사

#### 7. MARK 섹션 존재 여부

> [CONVENTIONS.md](.docs/conventions/CONVENTIONS.md)의 MARK 주석 규칙 참조
> Read 도구로 해당 문서를 읽어 파일 유형별 필수 MARK 섹션 검사

- SwiftUI View, TCA Feature, 테스트 파일 등 유형별 필수 MARK 확인

#### 8. 줄바꿈/공백 검사
- 줄 끝 불필요한 공백 (trailing whitespace)
- 빈 줄에 공백만 있는 경우
- 주석 위 빈 줄 누락 (제어문 직후 제외)

### 품질 검사

#### 9. 네이밍 규칙 위반
- Swift 네이밍 규칙 위반: snake_case 변수, 소문자 시작 타입, 대문자 시작 변수/함수 등
- 의미 불명확한 변수명 단독 사용: `temp`, `data`, `result`, `value`, `info`, `item`, `obj` 등
  - 접두/접미사와 결합된 경우(`userData`, `resultList` 등)는 허용

#### 10. 오타 검사
- 주석/문자열에서 흔한 한글 오타 패턴 검사
  - 예: "완료됬" → "완료됐", "안됬" → "안됐", "됬" → "됐"

#### 11. 데드코드
- 주석 처리된 코드 블록 (3줄 이상 연속으로 코드가 주석 처리된 경우)
  - 설명 주석이나 문서 주석은 제외, `//` 뒤에 코드 패턴이 있는 경우만 검출

#### 12. 안전성 검사
- `try!` 사용 (Force unwrap 검사와 별도로 검출)
- `as!` 사용 (Force unwrap 검사와 별도로 검출)
- 빈 catch 블록: `catch { }`, `catch {}`, `catch {\n}` 패턴

> 품질 검사는 매 커밋마다 실행되므로 가볍게 유지한다.
> 변경된 파일 단위 정적 분석만 수행하며, 프로젝트 전체 탐색은 하지 않는다.

## 실행 프로세스

### 1단계: 변경 파일 수집
```bash
# staged Swift 파일
git diff --cached --name-only --diff-filter=ACM | grep '\.swift$'

# staged 없으면 unstaged
git diff --name-only --diff-filter=ACM | grep '\.swift$'
```

### 2단계: 각 파일 검사
Read 도구로 파일을 직접 읽고 위 항목들을 분석

### 3단계: 결과 보고

다음 형식으로 보고:

```
[pre-commit-checker] 검사 결과

--- 에러 (수정 필요) ---
- FileName.swift:42 - Force unwrapping 발견: let value = dict["key"]!
- FileName.swift:108 - 120자 초과 (135자)

--- 경고 (확인 필요) ---
- ViewModel.swift:55 - print문: print("debug: \(value)")
- Service.swift:23 - TODO: // TODO: 에러 처리 추가

--- 컨벤션 ---
- FeatureView.swift - Import 순서 불일치 (외부 라이브러리가 시스템 프레임워크 앞에 위치)
- NewFeature.swift - MARK 섹션 누락: // MARK: - Body

--- 품질 ---
- Service.swift:10 - 의미 불명확한 변수명: let data = ...
- Feature.swift:30-35 - 주석 처리된 코드 블록 (6줄)
- Repository.swift:22 - 빈 catch 블록

에러: N건 | 경고: N건 | 컨벤션: N건 | 품질: N건
```

### 4단계: 사용자 확인
- 에러가 있으면: 수정 후 재검사 또는 무시하고 커밋 진행 여부 확인
- 에러가 없으면: 커밋 진행 가능 안내

## 에러 처리

| 에러 | 대응 |
|------|------|
| 변경 파일 없음 | "검사 대상 파일이 없습니다" 안내 |
| 파일 읽기 실패 | 해당 파일을 "검사 불가"로 보고하고 계속 진행 |
| Git 상태 확인 불가 | git 저장소 여부 확인 요청 |

## 참조 문서

- 코딩 컨벤션: `.docs/conventions/CONVENTIONS.md`
