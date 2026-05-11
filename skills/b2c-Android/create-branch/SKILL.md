---
name: b2c-android-create-branch
description: "GBIZ 번호로 Notion 작업 카드를 검색하여 브랜치 자동 생성. Use when: 브랜치 만들어줘, GBIZ 번호로 브랜치 생성, 작업 브랜치 생성, epic 브랜치 생성, epic accumulator 브랜치"
argument-hint: "[GBIZ-NNNNN | epic-project-name]"
allowed-tools: ["bash", "mcp__notionMCP__search", "mcp__notionMCP__fetch"]
---

# 브랜치 자동 생성

GBIZ 번호로 Notion 작업 카드를 검색하여 `.docs/branch-convention.md` 규칙에 따라 브랜치를 자동으로 생성합니다.

!git branch --show-current
!git status --porcelain

## 모드 판별

| 인자 | 모드 | 동작 |
|------|------|------|
| GBIZ-NNNNN | **일감 브랜치** | Notion 검색 → 현재 브랜치 컨텍스트로 epic 일감 또는 단독 작업 자동 분기 |
| epic 프로젝트명 (예: `epic-cok`) | **Epic Accumulator 메인** | `epic-{project}/main` 브랜치 생성 |

## Epic Accumulator 메인 브랜치 생성

epic 프로젝트명이 인자로 주어진 경우 (`epic-` 프리픽스 권장):

1. `develop`에서 `epic-{project}/main` 브랜치 생성
2. 사용자 확인 후 `git checkout -b epic-{project}/main`

```bash
/create-branch epic-cok        # develop → epic-cok/main
/create-branch epic-curation   # develop → epic-curation/main
```

> 큰 작업 (일감 3개 이상, stack PR 운용) 만 epic accumulator 사용. 소규모는 단독 작업 브랜치.

## 일감 브랜치 생성

### 1. GBIZ 번호 검증 및 Notion 카드 검색
- `mcp__notionMCP__search`로 GBIZ 번호 검색
- `mcp__notionMCP__fetch`로 상세 정보 조회 (ID, 이름, 상태, 마일스톤, 유형)

### 2. 현재 브랜치 확인 및 base/모드 결정

| 현재 브랜치 | base | 모드 |
|------------|------|------|
| `epic-{project}/main` (예: `epic-cok/main`) | 현재 브랜치 | **epic 일감** (type prefix 필수) |
| `develop` | `develop` | **단독 작업** |
| 기타 | `develop` (경고) | **단독 작업** (확인 후 진행) |

### 3. type 결정 (epic 일감 / 단독 작업 공통)

Notion 메타데이터에서 type 을 결정. 우선순위 규칙:

| 우선순위 | 조건 | type |
|------|------|------|
| 1 | 마일스톤에 "기술부채" 또는 "stability" | `stability` |
| 2 | Notion 유형 = TEST 또는 제목에 "테스트" | `test` |
| 3 | Notion 유형 = BUG 또는 제목에 "버그/수정" | `fix` |
| 4 | 제목에 "리팩토링" 또는 "refactor" | `refactor` |
| 5 | 제목에 "문서" 또는 "docs" | `docs` |
| 6 | (기본값) | `feat` |

### 4. 브랜치명 생성 (모드별 템플릿)

| 모드 | 템플릿 | 예시 |
|------|------|------|
| epic 일감 | `epic-{project}/{type}-GBIZ-{번호}-{영문-설명}` | `epic-cok/fix-GBIZ-2222-bottom-sheet` |
| 단독 작업 | `{type}/GBIZ-{번호}-{영문-설명}` | `feat/GBIZ-26000-add-favorite-button` |

설명은 Notion 제목에서:
- 한글 → 영문 변환, kebab-case
- 5~6 단어 이내, 불필요한 어구("수정", "구현" 등) 생략 가능

### 5. 브랜치 생성
- 사용자 확인 후 `git checkout -b {브랜치명}`

## 사용 예시
```bash
# Epic accumulator 메인 브랜치 생성
/create-branch epic-cok              # develop → epic-cok/main

# Epic 일감 브랜치 (epic-cok/main 위에서 실행)
/create-branch GBIZ-27000            # epic-cok/main → epic-cok/{type}-GBIZ-27000-task-name

# 단독 작업 브랜치 (그 외 — base = develop)
/create-branch GBIZ-26000            # → feat/GBIZ-26000-task-name (또는 type 에 따라 fix/refactor/...)
```

> 기존 진행 중인 `feature/...`, `{project}/...` 브랜치는 rename 안 함 — 자연 소멸.

## 참고
- `.docs/branch-convention.md`, `.docs/notion-convention.md`
- 마이그레이션 일자: 2026-05-11 (`feature/` → `feat/` + Epic Accumulator 도입)