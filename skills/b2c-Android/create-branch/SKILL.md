---
name: b2c-android-create-branch
description: "GBIZ 번호로 Notion 작업 카드를 검색하여 브랜치 자동 생성. Use when: 브랜치 만들어줘, GBIZ 번호로 브랜치 생성, 작업 브랜치 생성, epic 브랜치 생성, epic accumulator 브랜치"
argument-hint: "[GBIZ-NNNNN | project-name]"
allowed-tools: ["bash", "mcp__notionMCP__notion-search", "mcp__notionMCP__notion-fetch"]
---

# 브랜치 자동 생성

GBIZ 번호로 Notion 작업 카드를 검색한 뒤, 결정적 규칙에 따라 브랜치를 생성합니다.

## 모드 판별

| 인자 | 모드 |
|------|------|
| `GBIZ-NNNNN` | 일감 브랜치 (현재 브랜치에 따라 epic 일감 또는 단독 작업으로 자동 분기) |
| epic 프로젝트명 (예: `epic-cok`) | epic accumulator 메인 브랜치 |

## Epic Accumulator 메인 브랜치

```bash
.claude/scripts/branch-resolve.sh --project <epic-프로젝트명>
```
출력의 실행 블록을 사용자 확인 후 그대로 실행. 결과는 `epic-cok/main` 형태.

## 일감 브랜치

### 1. Notion 카드 조회
`mcp__notionMCP__notion-search` + `mcp__notionMCP__notion-fetch` 로 GBIZ 번호 조회. 필요한 필드: **제목 / 마일스톤 / 유형**.

### 2. 결정적 해석 (스크립트 호출)

```bash
.claude/scripts/branch-resolve.sh \
  --gbiz GBIZ-NNNNN \
  --title "<Notion 제목>" \
  --milestone "<마일스톤>" \
  --type "<Notion 유형>"
```

스크립트 출력에 `Base`, `Type`, 브랜치명 템플릿(`{slug}` 포함)이 결정적으로 나옵니다. **LLM이 type 또는 template 을 바꾸지 말 것** — 규칙 수정이 필요하면 `branch-resolve.sh` 를 수정해야 함.

### 3. Slug 생성 (LLM)
- title 을 영문 kebab-case 로 변환
- 5~6 단어 이내, 불필요한 어구(수정/구현/추가 등) 제거

### 4. 사용자 확인 후 실행
스크립트 출력의 실행 블록에서 `{slug}` 만 치환해 실행.

## 사용 예시
```bash
/create-branch epic-cok              # develop → epic-cok/main
/create-branch GBIZ-27000            # epic-cok/main 위에 있을 때 → epic-cok/{type}-GBIZ-27000-<slug>
/create-branch GBIZ-26000            # 그 외 → feat/GBIZ-26000-<slug> 등 (base = develop)
```

`{type}` 은 Notion 메타데이터(milestone/유형/title 키워드) 기반으로 자동 결정 — 단독 작업과 동일 로직.

## 참고
- `.docs/conventions/branch-convention.md`, `.docs/conventions/notion-convention.md`
- 규칙 변경 시 `.claude/scripts/branch-resolve.sh` 를 수정
