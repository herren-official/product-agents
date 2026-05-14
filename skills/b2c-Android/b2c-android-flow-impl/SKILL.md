---
name: b2c-android-flow-impl
description: "백로그 노션 카드 1개를 브랜치 → 코드/테스트까지 처리하고 /ship 호출 지점에서 멈추는 Phase 2 구현 스킬. Use when: 백로그 단위 구현, GBIZ 백로그 → PR"
argument-hint: "--backlog <백로그 노션URL>"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-update-page"]
---

# b2c-android-flow-impl (Phase 2)

백로그 노션 카드 1개 → 브랜치 → 코드 → 테스트 작성까지. PR 까지 가는 마지막 단계는 사용자 명시 지시(`/ship`)로 트리거. **백로그 1개 = 브랜치 1개 = PR 1개**.

인자: $ARGUMENTS

> **🚨 직접 `git` / `gh` 금지.** 브랜치/커밋/PR 은 `/create-branch`, `/ship` 위임. 직접 명령 시 PR 템플릿·노션 연동·라벨이 다 빠짐.

---

## Step 1. 백로그 fetch

`notion-fetch` 로 백로그 페이지 가져와 정보 추출:
- 제목, 본문 (`### 내용` 영역)
- **`synced_block_reference`** 가 있으면 그 페이지도 추가 fetch (작업 본문이 다른 페이지에 동기화돼 있을 수 있음)
- GBIZ 번호
- 에픽/마일스톤 relation

**중요**: 본문이 채워져 있으면 **PDF 재분석하지 말 것**. 사용자가 채운 본문이 정답.

## Step 2. 브랜치 생성 (✅ 스킬 위임)

**`/create-branch GBIZ-{번호}` 호출**.

베이스 브랜치는 프로젝트별 다름 (`develop` / `prefix/main` 등). 결과 base 가 의도와 다르면 사용자에게 컨펌받고 올바른 인자로 `/create-branch` 재호출.

## Step 3. 작업 계획 ✋컨펌

백로그 본문 → 영향 분석을 `analyze-code` 에이전트(`mode=impact`)에 위임. 격리 컨텍스트에서 코드 grep + Read 후 영향 파일 list + 호출 후보 스킬 list 만 회수.

`Agent` 도구 1회:
- `subagent_type`: `analyze-code`
- `description`: `Impact analysis for GBIZ-{번호}`
- `prompt`: `mode=impact, target={Step 1 에서 받은 백로그 본문}, context=GBIZ-{번호}. 영향 모듈/파일/호출 후보 스킬 list 반환.`

에이전트 결과 + Step 2 의 브랜치 결과를 합쳐 사용자에게 한 번에 컨펌받음:

```
[작업 계획]
- 브랜치명 안: {type}/GBIZ-{번호}-{설명}
- 베이스 브랜치: {prefix/main 또는 develop} ← 사용자 컨펌 필수
- (analyze-code 결과)
  - 영향 모듈: feature/{name}, core:navigation, ...
  - 추가/수정 예정 파일 list
  - 호출 후보 스킬: /create-feature-module, /create-screen, /create-mock-data, ...
  - 의존성/순서

이대로 진행할까요? (y / 수정 / 베이스 변경)
```

## Step 4. 코드 작성 (스킬 위임 우선)

작업 계획에 따라:
- 새 feature 모듈 → `/create-feature-module`
- 한글 문자열 → `.docs/conventions/string-resource-convention.md` 따라 strings.xml 직접 추가 (SA-STR-001 detekt 강제)
- mock 데이터 → `/create-mock-data`
- **API 추가 → `.docs/conventions/api-convention.md` 보고 직접 Write/Edit** (Service / Entity / Vo / Body / Repository interface·impl / DI / UseCase 7 파일). detekt 가 SA-DATA-005 / SA-DATA-007 / SA-MOD-002 등 위반 차단
- 라우팅·로직 등 위 스킬에 안 맞는 작업 → 직접 Edit

CLAUDE.md, 컨벤션 문서 준수:
- MVI: `BaseIntentViewModel`, `reduceState`, `apiFlow`
- 디자인 시스템: `core:designsystem-v2`
- 네이밍/패키지: `.docs/conventions/project-convention.md`
- API 레이어: `.docs/conventions/api-convention.md`

## Step 5. 멈춤 — 사용자 명시 지시로 `/ship` 진입

코드 작성까지 완료 후 안내만 출력하고 멈춤:

```
## 코드 작성 완료
- 브랜치: {type}/GBIZ-{번호}-{설명}
- 변경 파일: {N개}

다음 단계 (사용자가 직접 트리거):
  /ship              # 테스트 코드 자동 작성 + 빌드 체크 + 커밋 + PR (+ 노션 3곳 업데이트)
  /ship --no-test    # 테스트 작성 스킵
  /ship develop      # base 명시 (epic 누적이면 epic-ai/main 등)
```

**자동 진입 X**. 사용자가 "ship 해줘" / "올려" / "PR까지 가자" 같이 명시할 때만 `/ship` 호출.

`/ship` 안에서 3 Step 순서대로 실행:
  1. `/create-commit` — simplify(코드 정리) + 커밋
  2. `unit-test` 에이전트 — 변경된 ViewModel/UseCase 테스트 생성/수정 + 커밋
  3. `/create-pr` — **Step 0 에 check-build 강제 호출** (컴파일 + 단위 테스트) → 통과 후 PR 미리보기 ✋ 컨펌 → 생성 + 노션 3곳 업데이트

---

## 사용 예시

```bash
/b2c-android-flow-impl --backlog https://www.notion.so/0909/...
# → Step 5 멈춤
# 사용자: "ship 해"
# → /ship 호출 → PR
```

## 원칙

- **컨펌 1단계 + ship 컨펌**: ① 작업 계획 (이 스킬) + ② PR 미리보기 (`/ship` 안)
- **백로그 1개 = 브랜치 1개 = PR 1개**
- **자동 진입 X** — Step 5 에서 멈추고 사용자 명시 지시로만 `/ship` 호출 (메모리: "ship/PR 은 명시적 지시 받고만 진행")
- **🚨 직접 `git`/`gh` 금지** — `/create-branch`, `/ship` 위임만
- 무거운 작업은 기존 스킬에 위임 (`/create-feature-module`, `/create-screen`, `/create-mock-data`). API 추가는 `api-convention.md`, 한글 문자열은 `string-resource-convention.md` 직접 참조
- **본문 우선** — 백로그 본문이 채워져 있으면 PDF 재분석 X. `synced_block_reference` 도 추가 fetch
