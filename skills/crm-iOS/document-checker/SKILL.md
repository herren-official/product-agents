---
name: crm-ios-document-checker
description: 작업 시작 전 필수 문서를 확인합니다. 테스트, UI, Git, API, 노션 등 모든 작업 전에 관련 문서를 먼저 읽고 시작합니다. 문서 확인, 문서 체크 요청 시 사용.
allowed-tools: Read, Grep, Glob
---

# Document Checker

모든 작업 시작 전 필수 문서를 확인하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-document-checker] 스킬이 실행되었습니다."를 출력할 것

## 핵심 원칙

- **"코드 먼저" 금지** → **"문서 먼저" 원칙**
- **추측 금지** → **문서 확인 필수**

## 코드 작성 수반 작업 분류

다음 작업 유형은 **코드 작성을 수반**하므로 CONVENTIONS.md를 반드시 읽어야 합니다:

| 작업 유형 | 코드 작성 수반 |
|----------|:---:|
| 테스트 | O |
| API 구현 | O |
| UI/View | O |
| RxSwift/MVVM | O |
| 파일 관리 | O |
| UITest | O |
| Git/브랜치 | X |
| 노션 | X |
| 빌드/실행 | X |

## 실행 프로세스

### 1단계: 작업 유형 파악

사용자 요청에서 키워드를 확인하여 작업 유형 결정:

| 키워드 | 작업 유형 |
|--------|----------|
| 테스트, test, Repository, Router | 테스트 |
| API, DTO, 네트워크 | API 구현 |
| UI, View, 화면, SnapKit | UI/View |
| 브랜치, 커밋, PR, push | Git/브랜치 |
| 노션, GBIZ, 일감 | 노션 |
| UITest, E2E | UITest |
| RxSwift, MVVM, ViewModel | RxSwift/MVVM |
| 파일 생성, 새 파일 | 파일 관리 |
| 빌드, build, xcodebuild | 빌드/실행 |

### 2단계: 체크리스트 문서 참조

`.docs/CLAUDE_DOCUMENT_CHECKLIST.md` 파일을 읽고 해당 작업 유형의 **필수 확인 문서** 목록을 확인합니다.

### 2.5단계: 코드 작성 수반 작업인 경우 CONVENTIONS.md 필수 읽기

**코드 작성을 수반하는 작업 유형이면 반드시 `.docs/conventions/CONVENTIONS.md`를 읽습니다.**

- 체크리스트에 CONVENTIONS.md가 이미 포함되어 있더라도 이 단계에서 반드시 확인
- 읽은 후 현재 작업에 관련된 핵심 컨벤션을 간단히 정리하여 작업 시작 선언 시 함께 명시

### 3단계: 필수 문서 읽기

체크리스트에 명시된 문서들을 읽습니다.

### 4단계: 작업 시작 선언

```
"[호칭], [문서명]을 참고하여 [작업내용]을 진행하겠습니다.
적용할 주요 컨벤션: [현재 작업에 관련된 컨벤션 항목 나열]"
```

- 호칭은 `CLAUDE.local.md`에서 확인
- 참고한 문서를 명시하고 작업을 시작
- **코드 작성 수반 작업이면 적용할 주요 컨벤션을 함께 명시**

## 참조 문서

- 문서 체크리스트: `.docs/CLAUDE_DOCUMENT_CHECKLIST.md`
- 호칭 및 개인 설정: `CLAUDE.local.md`
