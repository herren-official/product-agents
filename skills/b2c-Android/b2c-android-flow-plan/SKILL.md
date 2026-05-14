---
name: b2c-android-flow-plan
description: "에픽 노션 + 피그마 + PDF 를 받아 마일스톤/백로그 노션 카드까지 생성하는 Phase 1 기획 스킬. Use when: 에픽 착수, 마일스톤 분해, 백로그 카드 일괄 생성"
argument-hint: "--epic <노션URL> [--figma <피그마URL>] [--pdf <경로>]"
allowed-tools: ["bash", "read", "write", "edit", "grep", "glob", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-search", "mcp__notionMCP__notion-create-pages", "mcp__notionMCP__notion-update-page", "WebFetch"]
---

# b2c-android-flow-plan (Phase 1)

에픽 → 마일스톤 → 백로그 노션 카드 생성까지. 코드 작성은 하지 않는다. 구현은 `/b2c-android-flow-impl --backlog <URL>` 로 이어감.

인자: $ARGUMENTS

---

## Step 1. 분석 — 1턴 병렬 (최대 4 호출 동시)

**한 메시지 안에서 4 호출을 동시에 발사**. 모두 서로 의존성 없음 (1턴 절약).

1. **에픽 노션 fetch** — `mcp__notionMCP__notion-fetch` (에픽 URL/ID)
2. **PDF 분석** — `Bash` 로 `./.claude/scripts/analyze-pdf-for-backlog.sh <PDF경로>` (PDF 인자 있을 때만)
3. **피그마 UI 분석** — `Agent` 도구, `subagent_type=figma-ui-analyzer` (피그마 URL 있을 때만)
4. **피그마 정책 분석** — `Agent` 도구, `subagent_type=figma-policy-analyzer` (피그마 URL 있을 때만)

### 1턴 결과 회수 후 후처리

**노션 fetch 결과**:
- 에픽 코드 추출 (예: `26-Q2-P1`)
- 에픽 페이지 ID + 마일스톤 relation 목록 저장
- 본문에서 피그마 / 상위 기획 wiki 링크 회수

**PDF bash 결과 분기**:
- **exit 2** (거대 페이지 ≥ 10000 pts) → 출력된 분할 PDF 요청 메시지를 사용자에게 그대로 전달 + Step 1 중단. 사용자가 분할 PDF 주면 재시작
- **exit 1** (손상/암호화/도구 부재) → 에러 보고 + 사용자 결정 대기 (PDF 없이 진행 / 새 PDF / 중단)
- **정상** → 출력의 `TEXT:` 텍스트 파일 + `PNG_DIR:` 디렉토리 경로를 `Read` 로 확인
  - PDF 영역 색상 컨벤션 (B2C 도메인 룰):
    - **빨강 / 초록 / 파랑 / 회색 헤더** = 작업 범위 안
    - **분홍 / 흐린 헤더** = 딤 처리 = **범위 밖 (반드시 제외)**
  - 영역 식별 후 사용자에게 "딤 영역 맞나요?" 한 번 확인

**피그마 에이전트 결과**:
- 두 에이전트 모두 격리 컨텍스트 → 메인 대화에 raw 코드 노출 없이 정리된 결과만 회수
- 둘 다 "추측 금지" 룰 (UI 는 픽셀, 정책은 원문). 불확실하면 "확인 필요" 표기
- 토큰 한도 초과 등 실패 시 노드 URL 만 추출해 백로그 참고 섹션에 첨부 + PDF 만으로 진행

> **기본 패턴은 4 호출 1턴.** 사용자가 명시적으로 `--pdf-first` 같은 신호를 주거나 직전 호출에서 exit 2 가 발생했을 때만 PDF 호출 단독 선행으로 전환. 그 외엔 LLM 임의 판단으로 분기하지 말 것 (대부분 PDF 가 정상이라 4 호출 1턴이 ROI 우위).

## Step 2. 마일스톤 제안 ✋컨펌①

PDF/피그마 분석 결과를 큰 챕터 단위로 자동 분해해 제안. **에픽에 이미 마일스톤이 있으면 그것도 함께 표시**:

```
[기존 마일스톤 (에픽 relation)]
01. B2C-26Q2-P1-01-내주변 하프시트
02. B2C-26Q2-P1-02-샵 카드 정보 강화
...

[새 마일스톤 제안]
01. B2C-{에픽코드}-{NN}-{기능명}
    └ 출처: PDF {파일} 빨강 헤더, Figma node-id=...
    └ 요약: 한 줄 설명
...

진행 옵션:
  A) 새로 생성        — 위 제안대로 마일스톤 DB에 추가
  B) 기존 사용        — 에픽에 이미 있는 마일스톤 그대로 사용 (추가 생성 X)
  C) 컨벤션만 참고    — 기존 이름 컨벤션만 따라하고 새로 생성
  D) 수정/합치기/쪼개기 후 생성
```

사용자 답에 따라 분기. **B 인 경우 Step 3 스킵하고 Step 4로 직행**.

## Step 3. 마일스톤 생성 (옵션 B 인 경우 스킵)

`notion-create-pages` 로 **공비서팀 마일스톤 DB** 에 페이지 생성:
- DB: `collection://a9c463d8-5409-4e08-8791-529e49919cfb`
- 이름: `B2C-{에픽코드}-{NN}-{기능명}`
- `에픽` relation: Step 1 에서 받은 에픽 페이지
- `상태`: `시작 전`
- 본문: 비움

생성된 마일스톤 페이지 ID 들을 메모리에 저장.

## Step 4. 백로그 제안 ✋컨펌② (반복형)

각 마일스톤별로 세부 작업을 분해. **추측 금지 — PDF + 코드 둘 다 검증 후 제안**:

**작성 룰**:
1. **PDF 키워드 grep** (`grep -n "키워드" /tmp/{pdf}.txt`) — 라인 번호로 출처 명시
2. **코드 grep** — 영향 모듈/파일/라인 번호 검증 (예: `feature/around-me/component/FilterType.kt:1-7`). 신규 vs 기존 수정 구분
3. **이미 구현된 부분과 신규 작업 구분** — 예) "카테고리 셀렉터는 이미 구현됨, 표시 순서만 반영"
4. **SP 추정** — `/create-backlog` SKILL.md 의 "스토리포인트 추정 가이드" 표 (0.1 / 0.25 / 0.5 / 0.75 / 1.0) 그대로 사용. 1.0 초과 시 분할 제안. 사용자가 절반/통일 등 조정 요청 시 즉시 반영
5. **본문 ### 내용** 구조: PDF 근거 (라인 번호) → 수정 범위 (파일:라인) → 영향 주의사항

제안 형식:
```
■ 01. B2C-{에픽코드}-01-{기능명} (마일스톤 URL: ...)
  - [B2C][Android] {영역} > {위치} > {동작}  | SP 0.5
    PDF: {파일} 라인 X / 빨강 헤더 "X" 영역
    코드: feature/{모듈}/{파일}.kt:라인 (수정) / 신규 컴포넌트
    작업 유형: 퍼블 / API / 로직 / UI+로직
  - ...
```

**컨펌 단계 반복 처리**:
- "주소 빠짐", "딤 영역 제외", "X로 변경", "1, 2, 4번 SP 0.1로" 등 한 줄 지적이 들어오면
- 해당 항목 PDF + 코드 재확인 → 본문/SP/제목 즉시 수정 → 다시 미리보기
- 빠진 일감 추가 / 합치기 / 쪼개기 / 삭제 모두 가능. 최종 OK 받기 전까지 반복

## Step 5. 백로그 생성 (✅ create-backlog 위임)

Step 4 에서 컨펌받은 백로그 배열을 JSON 으로 정리해 **`/create-backlog --batch <JSON>` 한 번 호출**. 마일스톤 relation 은 Step 3 에서 받은 마일스톤 페이지 URL 사용.

JSON 입력 예시 (각 항목 키: `title` / `epic` / `milestone` / `type` / `sp` / `body` — 본문은 아래 PDF 근거 템플릿 따름):

```json
[
  {
    "title": "[B2C][Android] 샵 상세 > 카드 > 별점 평균 표시 추가",
    "epic": "<에픽 페이지 URL>",
    "milestone": "<해당 마일스톤 URL>",
    "type": "작업",
    "sp": 0.5,
    "body": "## 작업내용\n### 내용\n- PDF 근거 (.docs/{filename}.pdf 라인 X / \"X\" 영역)\n  - {요구사항}\n- 수정 범위\n  - feature/{모듈}/.../{File}.kt:{라인} — {설명}\n\n### 참고\n- PDF: .docs/{filename}.pdf 영역\n- 코드: feature/{모듈}/...\n- 화면 명세: 프로젝트 wiki (해당 시)\n\n---\n### Todo\n- [ ]\n"
  }
]
```

**DB ID / properties / 작업자 update / inline DB 한계** 등 노션 카드 생성 메커닉은 `/create-backlog` SKILL.md 가 단일 진실 소스. 여기서는 위 JSON 만 만들어 위임.

## Step 6. 결과 리포트

```
## Phase 1 완료
- 마일스톤 N개 생성
- 백로그 M개 생성
- 에픽 페이지: {URL}

다음: 구현 시작 — `/b2c-android-flow-impl --backlog <백로그URL>`
```

---

## 사용 예시

```bash
/b2c-android-flow-plan --epic https://www.notion.so/0909/26-Q2-P1-... \
                       --figma https://www.figma.com/design/... \
                       --pdf .docs/하프시트+후기...pdf
```

## 원칙

- **컨펌 2단계 필수**: ① 마일스톤 ② 백로그
- **추측 금지** — 백로그 본문은 PDF 키워드 grep + 코드 grep 둘 다 검증 후 작성. 이미 구현된 부분/신규 부분 명시
- **컨펌 반복** — 한 줄 지적이 들어오면 PDF/코드 재확인 후 즉시 반영 (생성 전까지 무한 반복)
- **노션 도메인 룰** — PDF 분홍 헤더 = 딤 = 범위 밖, 빨강/초록/파랑/회색 = 범위 안
- **Phase 1 은 코드 안 짬**. 구현은 `/b2c-android-flow-impl --backlog <URL>` 로 위임
