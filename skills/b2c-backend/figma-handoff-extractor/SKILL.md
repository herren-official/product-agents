---
name: figma-handoff-extractor
description: Extract development requirements, policies, case branches, and screen specifications from a Figma hand-off file using Figma's REST API. Use this skill whenever the user provides a Figma URL or file key and asks for development requirements, policies, "요구사항", "정책", "스펙", "개발 인계", "hand-off", or anything that involves reading actual design content from Figma to produce engineering documentation. Especially use this when the file mixes current and previous project work via opacity-based dimming (the typical convention is opacity 1.0 = current, opacity 0.2 = previous/out-of-scope) — the skill automatically separates them. Also use when the user provides a Figma Personal Access Token, even if they don't yet say what they want done with it.
---

# Figma Hand-off Extractor

A skill for turning a Figma hand-off file into a structured development specification: per-screen requirements, policy tables, case/state matrices, API/domain estimates, and a list of "needs clarification" questions. Works with files that mix current and previous project work via opacity dimming.

## When this skill applies

Trigger this skill when **all** of these hold:
- The user provides (or has already provided) a Figma file URL or file key.
- The user wants engineering output — requirements, policies, screen specs, dev hand-off — not just a screenshot description.
- The file is a real product hand-off page (typically named "Hand off", "개발 인계", "🟢 Hand off 🟢", etc.) with Summary tables and case-branch frames.

If a Figma Personal Access Token is not yet available, ask for one before doing anything else. Without the token nothing else in this skill works. The token format is `figd_...`. Tell the user how to make one if they don't have it: Figma → Settings → Security → Personal access tokens → Generate new token → enable **File content: Read-only** scope.

## Why direct DOM/screenshot scraping won't work

Don't waste turns trying to scrape the Figma canvas via Chrome automation. The canvas is GPU-rendered so screenshots time out, and Figma's first-party `/file/{key}/file` endpoint returns content that gets masked by browser-side security policies as "cookie/query string data". The REST API with a Personal Access Token is the only reliable path. Skip straight to it.

## Workflow

Follow these phases in order. Each phase has a clear exit condition.

### Phase 1 — Map the file

1. Extract `fileKey` and `nodeId` from the URL. URLs look like `figma.com/design/{fileKey}/{name}?node-id={a}-{b}`. The node ID in the URL uses `-` but the API expects `:` (so `4231-13260` becomes `4231:13260`).
2. Get the page list with `depth=1`:
   ```
   GET https://api.figma.com/v1/files/{fileKey}?depth=1
   Header: X-Figma-Token: {token}
   ```
   This returns `document.children` — the pages. Identify the hand-off page by name (look for "Hand off", "개발", "인계", or the page the user linked to).
3. Get top-level frames/sections of the hand-off page with `nodes?ids={pageId}&depth=2`. Note each child's `id`, `name`, `type`, `opacity`.

Exit when you have a clean list of top-level SECTIONs/FRAMEs on the hand-off page, with their IDs and names.

### Phase 2 — Identify current vs previous project

The convention this skill is built for: previous-project work is dimmed (`opacity` < 1, typically 0.2 or 0.5). Current-project work is `opacity: 1.0`.

- Treat any node with `opacity < 0.99` as **out of scope** (previous project / reference only). Do not include it in the requirements doc except in a small "excluded" appendix.
- Walk every section's children and record which top-level frames are dimmed vs active.
- If a whole section has *no* active frames, note it and ask the user before excluding it entirely — sometimes a whole section is being deprecated and that itself is the requirement.

If the file uses a different convention (e.g., colored overlays, "[OLD]" prefixes, archived layers), ask the user to confirm the dimming rule before proceeding. Don't assume.

### Phase 3 — Extract content from active frames only

For each active section, fetch the full subtree (`nodes?ids={sectionId}` with no depth limit) and walk it with this filter: skip any node where `opacity < 0.99` or `visible === false`. The subtree responses can be megabytes — store them in a JS variable on `window` so you can re-query without re-fetching.

Three buckets matter:

**Bucket A — Policies (the gold)**: Hand-off pages typically have Summary tables with rows. The text nodes whose immediate parent frame is named `Cell` (or whose path contains `Rows > Rows > Cell`) are the explicit policy statements written by the planner. These are *the* requirements — copy them verbatim, don't paraphrase. Cell text often uses ` / ` as a line break for sub-bullets.

**Bucket B — Case/state labels**: Frames named `설명` (or "Description", "Note", "case label" — depends on the team's convention) used as instances are the planner's case-branch labels. Each "설명" instance contains text that names the case (e.g., "예약금 O + 예약금 100%", "정액권 사용", "쿠폰 적용 시"). Extract these as a flat list per parent section — they're your case matrix.

**Bucket C — Sample data and UI labels**: Other text (button labels, sample shop names, placeholder text). Use these to confirm UI structure but don't put them in the requirements doc as policy.

If the file uses different naming conventions, look for: tables with header cells + body cells, repeated tag-shaped frames near case-divergent UI, and sticky-note-shaped frames. Adapt the bucket-A and bucket-B selectors to whatever the file uses.

### Phase 4 — Discover case-branch frames

Look at top-level frames within each section that have a `name` matching a UI variant (e.g., `booking-payment (정액권 사용)`, `map (검색결과 없음)`, `[Web] booking-staff`). Each such frame is one case. Combine these with Bucket B labels to build a complete case matrix.

For frames named with bracketed prefixes like `[Web]`, `[App]`, `[iOS]`, `[Android]`, treat them as platform variants of the same screen, not separate screens.

### Phase 5 — Write the requirements document

Output a single markdown file. Use this exact top-level structure unless the user asks for something else:

```
# {Project Name} — {Hand-off Page Name}

**Figma 파일**: {file name}
**대상 페이지**: {page name}
**작성 기준일**: {today} (Figma 최종 수정 {updated_at})
**현재 프로젝트 식별 기준**: opacity 1.0 (그림자 처리 opacity {dim value} = 이전 프로젝트, 이 문서에서는 제외)

## 0. 전체 화면 구성
[Table: # | 섹션 | 주요 화면]

## 1. 화면별 요구사항 및 정책
### 1.1 {Section Name}
[Subsections per logical area, with policy tables built from Bucket A cells]

## 2. 공통 정책
[Cross-section rules — distance formatting, date ranges, currency rounding, etc.]

## 3. 케이스/상태 전체 매트릭스
[One table per case-branching component, built from Bucket B + Phase 4 frames]

## 4. API/도메인 추정 요구사항
[Domain models and endpoints inferred from the screens. Mark every speculative item with (추정).]

## 5. 디자인 / 기술 요구사항
[Canvas size, reusable components (top_bar, status_bar, etc.), platform variants]

## 6. ⚠️ 확인 필요 / 미정 항목 (질문 리스트)
[Every 🔥/⚠️/?? marker found in the file, every ambiguous policy, every gap. Number them so the user can answer "1, 3, 5".]

## 7. 그림자 처리 = 이전 프로젝트 (개발 범위 제외)
[Table of dimmed top-level frames per section]
```

Match the user's language — if the Figma file is in Korean, write the doc in Korean. If English, English. Don't translate policy text; copy verbatim.

### Phase 6 — Save and present

Save to `/mnt/user-data/outputs/{project_name}_요구사항_및_정책.md` (or English equivalent based on file language) and call `present_files` so the user can download it.

## Reference scripts

The actual Figma API calls and tree-walking logic are in `scripts/figma_extract.js`. This is a reference implementation written for execution inside Claude in Chrome's `javascript_tool` (since `api.figma.com` is typically not in the bash allowlist, but the browser session can hit it directly with the Authorization header). When the Chrome tool is available, run that script. When it isn't, adapt the same logic to whatever HTTP-capable tool is available — the algorithm is identical.

See `references/api-cheatsheet.md` for the exact endpoints, headers, and response shapes you'll deal with. See `references/heuristics.md` for the full list of patterns that mark policy text vs case labels vs sample data, including patterns for non-Korean files. See `references/output-template.md` for the exact markdown skeleton to fill in.

## Common pitfalls

- **Spending tokens on screenshots before getting the API working.** Don't. Get the token first, hit the REST API, work from the JSON. Screenshots are only useful at the very end if a specific layout question can't be answered from text.
- **Treating opacity-0.7 labels as out of scope.** Sticky-note labels are often `opacity: 0.7` even on active frames. Use `opacity < 0.99` as the cutoff but check what the dimming value actually is in this specific file (run a quick `Set` of all observed opacity values first).
- **Paraphrasing Cell text.** The planner wrote those words deliberately. Copy verbatim into the markdown. The ` / ` separators inside one cell are intentional sub-bullets — preserve them as bullet lists in the output.
- **Skipping the case matrix.** Engineering teams care about case branches more than copy. If you find 5 "설명" labels in one section, that's a 5-row table the developer needs.
- **Forgetting to ask about missing context.** Every 🔥 marker, every "TBD", every empty section, every ambiguous threshold — list it in section 6. The doc's value is partly that it surfaces what isn't decided yet.
