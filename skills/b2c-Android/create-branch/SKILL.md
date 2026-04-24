---
name: b2c-android-create-branch
description: "GBIZ 번호로 Notion 작업 카드를 검색하여 브랜치 자동 생성. Use when: 브랜치 만들어줘, GBIZ 번호로 브랜치 생성, 작업 브랜치 생성, 프로젝트 브랜치 생성"
argument-hint: "[GBIZ-NNNNN | project-name]"
allowed-tools: ["bash", "mcp__notionMCP__search", "mcp__notionMCP__fetch"]
---

# 브랜치 자동 생성

GBIZ 번호로 Notion 작업 카드를 검색하여 `.docs/branch-convention.md` 규칙에 따라 브랜치를 자동으로 생성합니다.

!git branch --show-current
!git status --porcelain

## 모드 판별

| 인자 | 모드 | 동작 |
|------|------|------|
| GBIZ-NNNNN | **일감 브랜치** | Notion 검색 → 브랜치 타입 결정 → 생성 |
| 프로젝트명 (예: cok) | **프로젝트 메인** | `{project}/main` 브랜치 생성 |

## 프로젝트 메인 브랜치 생성

프로젝트명이 인자로 주어진 경우:

1. `develop`에서 `{project}/main` 브랜치 생성
2. 사용자 확인 후 `git checkout -b {project}/main`

```bash
/create-branch cok        # develop에서 cok/main 생성
/create-branch curation   # develop에서 curation/main 생성
```

## 일감 브랜치 생성

### 1. GBIZ 번호 검증 및 Notion 카드 검색
- `mcp__notionMCP__search`로 GBIZ 번호 검색
- `mcp__notionMCP__fetch`로 상세 정보 조회 (ID, 이름, 상태, 마일스톤, 유형)

### 2. 현재 브랜치 확인 및 base 결정

| 현재 브랜치 | base |
|------------|------|
| `{project}/main` (예: `cok/main`) | 현재 브랜치 (프로젝트 일감으로 생성) |
| `develop` | develop |
| 기타 | 사용자에게 확인 |

### 3. 브랜치 타입/접두사 결정

**프로젝트 브랜치 위에 있는 경우** (현재 브랜치가 `{project}/main`):
- 접두사: `{project}/` (프로젝트명 사용)
- 형식: `{project}/GBIZ-{번호}-{영문-설명}`

**develop 위에 있는 경우** (단독 작업):
| 조건 | 타입 |
|------|------|
| 마일스톤에 "기술부채" | `stability/` |
| 유형이 TEST / 제목에 "테스트" | `test/` |
| 유형이 BUG / 제목에 "버그/수정" | `fix/` |
| 제목에 "리팩토링" | `refactor/` |
| 제목에 "문서" | `docs/` |
| 기본값 | `feature/` |

### 4. 브랜치명 생성
- 한글 → 영문 변환, kebab-case
- 프로젝트 일감: `{project}/GBIZ-{번호}-{영문-설명}`
- 단독 작업: `{타입}/GBIZ-{번호}-{영문-설명}`

### 5. 브랜치 생성
- 사용자 확인 후 `git checkout -b {브랜치명}`

## 사용 예시
```bash
# 프로젝트 메인 브랜치 생성
/create-branch cok                   # develop → cok/main

# 프로젝트 일감 브랜치 (cok/main 위에서 실행)
/create-branch GBIZ-26100           # cok/main → cok/GBIZ-26100-task-name

# 단독 작업 브랜치 (develop 위에서 실행)
/create-branch GBIZ-26000           # develop → feature/GBIZ-26000-task-name
```

## 참고
- `.docs/branch-convention.md`, `.docs/notion-convention.md`
