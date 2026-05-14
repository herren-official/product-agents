---
name: b2c-android-create-backlog
description: "기능/구현/버그 설명을 노션 백로그 카드로 생성. 템플릿 페이지를 복제(duplicate-page)한 후 속성/제목/본문을 update. 단일/배치 모드 지원. Use when: 기능 추가 후 일감 만들어줘, 노션 카드 만들어 작업 시작, 일감부터 생성하고 진행, 백로그 카드 생성, 일감 생성"
argument-hint: "<설명>  [--epic <URL>] [--milestone <URL>]   |   --batch <JSON 배열>"
allowed-tools: ["bash", "read", "grep", "glob", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-duplicate-page", "mcp__notionMCP__notion-update-page", "mcp__notionMCP__notion-get-users"]
---

# create-backlog

노션 백로그 카드 생성 단일 진실 소스. **공비서팀 제품 백로그(NEW) DB 에 직접 생성 불가** → 항상 **템플릿 페이지를 복제** 후 속성/제목/본문 update.

| 모드 | 인자 | 트리거 |
|---|---|---|
| **단일** | `<설명> [--epic] [--milestone]` | 사용자 ad-hoc 호출 — 미리보기 컨펌 포함 |
| **배치** | `--batch <JSON 배열>` | `/b2c-android-flow-plan` 등 상위 스킬 위임 — 미리보기 컨펌 없음 (호출자가 이미 받음) |

인자: $ARGUMENTS

---

## 노션 카드 생성 명세 (양 모드 공통)

### 템플릿 페이지

- **템플릿 페이지 ID**: `35e48de8-e0ea-80c7-91aa-f74deaf429d8`
- **URL**: https://www.notion.so/0909/35e48de8e0ea80c791aaf74deaf429d8
- 이 페이지를 `notion-duplicate-page` 로 복제. 복제본은 같은 DB(공비서팀 제품 백로그 NEW) 의 일감으로 자동 등록됨

### 생성 절차

1. **`notion-duplicate-page`** — `page_id = <템플릿 ID>` 호출. 응답에서 새 페이지 ID 회수
2. **`notion-update-page`** — 새 페이지에 아래 속성 + 제목 + 본문 덮어쓰기

### 덮어쓸 속성

| 속성 | 값 | 비고 |
|---|---|---|
| `이름` (title) | `[B2C][Android] {영역} > {위치} > {동작}` | 프리픽스 + Breadcrumb `>` 통일 (`.docs/conventions/notion-convention.md`) |
| `에픽` (relation) | 지정 시 `"[\"<에픽 페이지 URL>\"]"` | 없으면 생략 |
| `마일스톤` (relation) | 지정 시 `"[\"<마일스톤 페이지 URL>\"]"` | 양방향 자동 연결, 마일스톤 페이지 별도 update 불필요 |
| `플랫폼` (multi_select) | `"[\"Android\"]"` | **고정** |
| `서비스` (multi_select) | `"[\"공비서-B2C\"]"` | **고정** |
| `유형` (select) | `"작업"` 또는 `"버그"` | 일감 성격에 따라 |
| `상태` (status) | `"백로그"` | **고정** |
| `스토리포인트` (number) | `0.1` ~ `1.0`, 소수점 가능 | 일감 분석 기반 추정 (아래 가이드) |
| `작업자` (people) | MCP 토큰 owner | `notion-get-users user_id="self"` 로 UUID 조회 후 `"[\"<UUID>\"]"` |

> `icon` 은 템플릿 페이지에 이미 설정되어 있어 복제 시 자동 상속됨 — 별도 update 불필요.

### 스토리포인트 추정 가이드

**최대 1.0, 소수점 가능.** 일감 본문/영향 범위 분석 기반:

| SP | 기준 |
|---|---|
| 0.1 | 텍스트/색상 1줄 변경, 30분 이내 |
| 0.25 | 단일 컴포넌트 마이너 수정, 2시간 이내 |
| 0.5 | API 1개 추가 / 단일 화면 로직 변경 / 단일 ViewModel 테스트, 반나절 |
| 0.75 | 여러 컴포넌트 손대거나 약간 복잡한 로직, 거의 1일 |
| 1.0 | 새 화면 1개 신규 구현 (Route + ViewModel + Screen + Contract), 1일 |

> 1SP 를 넘어가는 작업은 백로그 단일로 만들지 말고 쪼개기. 사용자에게 분할 제안.

### 본문

템플릿 페이지에 이미 기본 본문 구조가 들어있다고 가정 (Todo 체크리스트 등). 추가로 채울 내용은 `notion-update-page` 의 `content` 또는 별도 블록 추가로 처리:

```markdown
## 작업내용
### 내용
- {요구사항 1}
- {요구사항 2}
- 수정 범위
  - feature/{모듈}/.../{File}.kt:{라인} — {설명}
- {중요 영향 / 주의사항}

### 참고
- 코드: feature/{모듈}/...
- 화면 명세: 프로젝트 wiki (해당 시)
```

---

## 단일 모드 흐름

### Step 1. 요구사항 정리 + SP 추정

사용자 설명을 한 줄 제목 + 본문으로 구조화. **추측 금지**.

- 제목: `[B2C][Android] {영역} > {위치} > {동작}` — 프리픽스 + Breadcrumb `>` 통일. 화면 경로 없는 짧은 일감은 그냥 한 줄
- 영향 모듈/파일 추정은 코드 grep 으로 검증
- 작업 유형 판정: 작업 / 버그
- **SP 추정**: 위 가이드 표 기준. 최대 1.0
- 모호한 부분은 사용자에게 한 줄로 되묻기 (특히 SP 가 1.0 을 넘어보이면 분할 제안)

### Step 2. 미리보기 ✋컨펌

```
[백로그 카드 안]
- 제목: [B2C][Android] {영역} > {위치} > {동작}
- 에픽: {URL 또는 "없음"}
- 마일스톤: {URL 또는 "없음"}
- 유형: 작업 / 버그
- SP: {0.1 ~ 1.0}
- 플랫폼: Android (고정)
- 서비스: 공비서-B2C (고정)
- 작업자: self (MCP 토큰 owner)

[본문]
(요구사항 / 수정 범위 / 참고)

생성할까요? (y / 수정)
```

수정 요청 들어오면 즉시 반영 → 다시 미리보기. OK 받기 전까지 반복.

### Step 3. 복제 + update

1. `notion-duplicate-page page_id=35e48de8-e0ea-80c7-91aa-f74deaf429d8` → 새 페이지 ID 회수
2. `notion-get-users user_id="self"` → owner UUID 회수 (캐시 가능, 첫 호출 후 메모리 보관)
3. `notion-update-page` → 위 "덮어쓸 속성" + 제목 + 본문 한 번에 덮어쓰기

### Step 4. 결과 안내

```
## 백로그 생성 완료
- GBIZ-{번호}
- URL: {새 페이지 URL}

지금 바로 구현 시작할까요?
  → `/b2c-android-flow-impl --backlog <URL>`
```

**자동 진입 X**. 사용자가 직접 명령 주면 그때 flow-impl 호출.

---

## 배치 모드 흐름

상위 스킬(주로 `/b2c-android-flow-plan`)에서 미리 컨펌된 백로그 배열을 일괄 생성. **미리보기 단계 없음** — 호출자가 이미 사용자 컨펌을 받았다고 신뢰.

### 입력 스키마 (`--batch` JSON)

```json
[
  {
    "title": "[B2C][Android] 샵 상세 > 카드 > 별점 평균 표시 추가",
    "epic": "https://www.notion.so/0909/<에픽URL>",
    "milestone": "https://www.notion.so/0909/<마일스톤URL>",
    "type": "작업",
    "sp": 0.5,
    "body": "## 작업내용\n### 내용\n- ...\n\n### 참고\n- ...\n"
  }
]
```

| 키 | 필수 | 비고 |
|---|---|---|
| `title` | ✅ | `[B2C][Android]` 프리픽스 + Breadcrumb `>` 형식 |
| `epic` | 선택 | URL |
| `milestone` | 선택 | URL. 일감별로 다를 수 있음 |
| `type` | ✅ | `"작업"` / `"버그"` |
| `sp` | ✅ | 0.1 ~ 1.0, 소수점 |
| `body` | ✅ | 본문 마크다운 |

`플랫폼` / `서비스` / `상태` / `작업자` 는 모든 항목에 고정 적용 (입력 받지 않음).

### Step 1. owner UUID 1회 조회

`notion-get-users user_id="self"` → 배치 전체에 동일하게 사용.

### Step 2. 각 항목 복제 + update

배열의 각 항목마다:
1. `notion-duplicate-page page_id=35e48de8-...` → 새 페이지 ID
2. `notion-update-page` → 속성 + 제목 + 본문 덮어쓰기

> `notion-duplicate-page` 는 페이지당 1회 호출. 다중 페이지 일괄 복제 API 는 없음. 순차 또는 병렬 처리 (실패 시 재시도 가능하도록 항목별 상태 추적).

### Step 3. 결과 리포트 (호출자에게 반환)

```
## 배치 생성 완료
- 성공: N개
- 실패: M개 (있으면 URL/사유 나열)
- 생성된 백로그:
  - GBIZ-XXXXX https://...
  - GBIZ-XXXXX https://...
```

호출자(예: flow-plan)가 이 결과를 사용자에게 최종 보고.

---

## 사용 예시

```bash
# 단일 모드
/create-backlog 샵 카드에 별점 평균 표시 추가
/create-backlog 결제 실패 시 토스트 메시지가 안 뜨는 버그 --epic https://...

# 배치 모드 — flow-plan 등 상위 스킬에서 위임
/create-backlog --batch '[{"title":"...","epic":"...","milestone":"...","type":"작업","sp":0.5,"body":"..."}, ...]'
```

## 원칙

- **노션 카드 생성 메커닉의 단일 진실 소스**. 템플릿 ID / 고정 속성 / SP 가이드 / 작업자 처리는 이 파일 한 곳에서만 정의. 다른 스킬은 호출만 함
- **항상 템플릿 복제** — DB 직접 생성 불가. `notion-duplicate-page` → `notion-update-page` 순서 고정
- **고정 속성** — 플랫폼=`Android`, 서비스=`공비서-B2C`, 상태=`백로그`, 작업자=MCP 토큰 owner (`self`)
- **SP 최대 1.0** — 넘으면 분할 제안. 소수점 가능
- **단일 모드 컨펌 1회, 배치 모드 컨펌 없음** (호출자가 미리 받음)
- **추측 금지** (단일 모드) — 영향 모듈/파일은 코드 grep 으로 검증
- **자동 진입 X** (단일 모드) — 생성 후 URL 안내만. 구현은 사용자가 `/b2c-android-flow-impl` 호출
