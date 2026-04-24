---
name: crm-ios-doc-manager
description: .docs/ 문서 생성/수정 시 연관 문서를 자동으로 업데이트합니다. 문서 추가, 문서 수정, 문서 동기화, doc sync 요청 시 사용.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Doc Manager

`.docs/` 문서 또는 `.claude/skills/` 스킬이 생성/수정될 때, 연관 문서(체크리스트, 스킬, CLAUDE.md 등)를 함께 업데이트하는 스킬입니다.

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[crm-ios-doc-manager] 스킬이 실행되었습니다."를 출력할 것

## 실행 프로세스

### 1단계: 변경 감지

다음 명령어로 `.docs/`, `.claude/skills/` 하위의 변경/생성 파일을 식별합니다:

```bash
# 커밋되지 않은 변경 파일 확인
git diff --name-only
git diff --name-only --cached
git status --short
```

- `.docs/` 또는 `.claude/skills/` 하위 파일만 필터링
- 변경된 파일의 내용을 Read로 확인

### 2단계: 영향 범위 분석

변경된 문서의 내용을 읽고, 아래 3가지 영역을 분석합니다.

#### A. CLAUDE_DOCUMENT_CHECKLIST.md 확인

**"현재 문서 목록" 섹션 확인:**
- `.docs/CLAUDE_DOCUMENT_CHECKLIST.md`를 Read로 읽기
- "현재 문서 목록" 섹션에 해당 파일이 이미 등록되어 있는지 확인
- 없으면 추가 필요로 기록

**"작업별 필수 확인 문서" 테이블 확인:**
- 변경된 문서 내용의 키워드로 작업 카테고리를 자동 분류:

| 키워드 | 카테고리 |
|--------|----------|
| XCTest, Mock, Repository, Router, UseCase, ViewModel | 테스트 관련 작업 |
| UIKit, SnapKit, UIView, Layout | UI/View 작업 |
| git, branch, crm-ios-commit, PR | Git/브랜치 작업 |
| API, DTO, Endpoint, Router | API 구현 작업 |
| UITest, accessibility | UITest 작업 |
| RxSwift, Observable, MVVM | RxSwift/MVVM 구현 |
| 빌드, xcodebuild, scheme | 빌드/실행 작업 |

- 해당 카테고리 테이블에 행이 있는지 확인
- 없으면 추가 필요로 기록

#### B. 관련 스킬 확인

- `Grep`으로 `.claude/skills/` 내에서 변경된 문서 경로를 참조하는 스킬 검색
- 새 문서가 특정 스킬의 "참조 문서" 섹션에 추가되어야 하는지 판단

#### C. 관련 문서 간 상호 참조 확인

- `Grep`으로 `.docs/` 내에서 변경된 문서를 참조하는 다른 문서 검색
- `CLAUDE.md`에서 해당 문서의 링크 존재 여부 확인

### 3단계: 수정 제안

분석 결과를 사용자에게 표시합니다:

```
[crm-ios-doc-manager] 영향 분석 결과:

1. CLAUDE_DOCUMENT_CHECKLIST.md
   - "현재 문서 목록"에 {파일명} 추가 필요
   - "{카테고리}" 테이블에 행 추가 필요: | {파일경로} | {설명} | {관련 스킬} |

2. .claude/skills/{스킬명}/SKILL.md
   - "참조 문서" 섹션에 {파일경로} 추가 필요

3. CLAUDE.md
   - {섹션}에 {파일경로} 링크 추가 필요 (해당 시)

변경 사항이 없는 항목은 "✅ 업데이트 불필요"로 표시

수정을 진행할까요?
```

- 변경이 필요 없는 경우: `[crm-ios-doc-manager] 모든 연관 문서가 최신 상태입니다. 업데이트가 필요하지 않습니다.`

### 4단계: 수정 반영

사용자 승인 후 `Edit`으로 각 파일을 수정합니다.

## 시나리오별 체크리스트

### 시나리오 A: 새 .docs 문서 생성

- [ ] CLAUDE_DOCUMENT_CHECKLIST.md "현재 문서 목록"에 추가
- [ ] 작업 카테고리에 맞는 테이블에 행 추가
- [ ] 관련 스킬의 "참조 문서" 섹션에 추가 (해당 시)
- [ ] CLAUDE.md에 링크 추가 필요 여부 판단 (주요 가이드인 경우)

### 시나리오 B: 기존 .docs 문서 수정

- [ ] 해당 문서를 참조하는 다른 문서/스킬의 설명이 여전히 정확한지 확인
- [ ] CLAUDE_DOCUMENT_CHECKLIST.md의 설명 컬럼 업데이트 (해당 시)

### 시나리오 C: 스킬 생성/수정

- [ ] CLAUDE_DOCUMENT_CHECKLIST.md "관련 스킬" 컬럼 업데이트
- [ ] description에 트리거 키워드 포함 여부 확인

## 금지 사항

- 사용자 승인 없이 문서 수정 금지
- 문서 내용을 읽지 않고 추측으로 카테고리 분류 금지

## 참조 문서

- 문서 체크리스트: `.docs/CLAUDE_DOCUMENT_CHECKLIST.md`
- 파일 관리: `.docs/FILE_MANAGEMENT.md`
- 호칭: `CLAUDE.local.md`
