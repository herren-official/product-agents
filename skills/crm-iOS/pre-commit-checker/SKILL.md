---
name: crm-ios-pre-commit-checker
description: 커밋 전 코드 컨벤션을 검사합니다. crm-ios-commit 스킬에서 자동 호출되며, 컨벤션 검사, pre-commit 요청 시에도 사용.
allowed-tools: Read, Grep, Glob, Bash
---

# Pre-Commit Checker

커밋 전 코드 컨벤션을 검사하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-pre-commit-checker] 스킬이 실행되었습니다."를 출력할 것

## 검사 대상 파일

변경된 Swift 파일 목록을 수집합니다.
- staged 파일: git diff --cached --name-only --diff-filter=ACM 에서 .swift 파일 필터링
- staged 파일이 없으면 unstaged 변경 파일 대상

## 검사 항목

### 에러 (수정 필요)

#### 1. Force Unwrapping (느낌표 강제 언래핑)
IBOutlet 제외한 강제 언래핑 검사

검사 제외 대상:
- IBOutlet, IBAction
- 문자열 내부
- 주석 내부
- 부등호 연산자 (!=)

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
올바른 순서:
1. 시스템 프레임워크 (UIKit 또는 Foundation)
2. 내부 모듈 (Common, NetworkSystem 등) - 알파벳 순
3. 외부 라이브러리 (RxSwift, SnapKit 등) - 알파벳 순

주의:
- UIKit과 Foundation 동시 import 금지
- DesignSystem은 import하지 않음

#### 7. MARK 섹션 존재 여부
클래스/구조체에 필요한 MARK 섹션:
- // MARK: - Constants
- // MARK: - Properties
- // MARK: - UI
- // MARK: - init
- // MARK: - Life Cycle
- // MARK: - Set Layout
- // MARK: - Configure
- // MARK: - Set Binding
- // MARK: - Function

#### 8. 줄바꿈/공백 검사
- 줄 끝 불필요한 공백 (trailing whitespace)
- 빈 줄에 공백만 있는 경우
- 탭/스페이스 혼용

#### 9. 파라미터 줄바꿈
파라미터가 3개 이상이면 각 파라미터를 새 줄에 작성 권장

## 실행 프로세스

### 1단계: 변경 파일 수집
Grep, Glob 도구를 사용하여 변경된 Swift 파일을 수집

### 2단계: 각 파일 검사
Read 도구로 파일을 직접 읽고 위 항목들을 분석

### 3단계: 결과 보고

호칭을 사용하여 다음 형식으로 보고:

- 에러 (수정 필요): 파일명:줄번호와 함께 Force unwrapping, 120자 초과 등
- 경고 (확인 필요): 파일명:줄번호와 함께 print문, TODO 등
- 컨벤션: 파일명과 함께 Import 순서 불일치, MARK 섹션 누락 등

### 4단계: 사용자 확인
- 에러가 있으면: 수정 후 재검사 또는 무시하고 커밋
- 에러가 없으면: 커밋 진행

## 참조 문서

- 코딩 컨벤션: .docs/conventions/CONVENTIONS.md
- 호칭: CLAUDE.local.md
