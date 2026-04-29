# Extraction Heuristics

This file is the lookup table for "what does this Figma node mean for engineering output". Read it when the file you're working on doesn't fit the default Korean hand-off conventions, or when you're unsure how to classify a node.

## The three buckets

Every text node on the hand-off page falls into one of three buckets. Your job is to classify each one.

### Bucket A — Policy (must include verbatim)

These are explicit statements written by the planner about how the product should behave. **Copy them verbatim** into the requirements doc. Don't paraphrase, don't summarize, don't rewrite.

Signals (any one is enough):
- Immediate parent frame name is `Cell` or `cell`
- An ancestor is named `Summary`, `Spec`, `정책`, `Requirements`, or similar
- The text contains policy verbs: "Tap 시", "노출한다", "must", "should", "표기", "활성화", "비활성화", "기본 선택", "default to"
- The text contains conditional structure: "~할 경우", "~일 때", "if/when", "unless"
- The text length is > 30 chars and reads like a sentence (not a UI label)

When any one of those holds, treat it as policy. When two or more hold, definitely policy.

The text often uses ` / ` as a manual line break (the planner pressed shift+enter inside a single text node). Convert these to bullet points or sub-items in the markdown output:

```
Original Cell text:
"예약금 / %로 설정된 샵은 시술 메뉴 선택 시마다 실시간으로 변경 / 회원가 적용 X / 티켓일 경우 예약금 0원"

Output:
- 예약금
  - %로 설정된 샵은 시술 메뉴 선택 시마다 실시간으로 변경
  - 회원가 적용 X
  - 티켓일 경우 예약금 0원
```

### Bucket B — Case/state labels

These name a branch in the UI. Each one corresponds to one row in a case matrix.

Signals:
- The text is a noun phrase or short condition, not a sentence (e.g., "예약금 100%", "정액권 잔액 부족", "Coupon applied")
- It sits in a small framed box near a UI variant
- The parent INSTANCE is named `설명`, `Description`, `Note`, `Case`, `Variant`, `Tag`, or similar
- The same parent name repeats across a section (the planner stamped the same component to label N variants)
- The label sits visually next to or above a UI mockup that differs from neighboring mockups

When you find Bucket B labels, build a table:

```markdown
| Case | Condition | Notes |
|------|-----------|-------|
| 1    | 예약금 O + 100% | 시술금액 = 예약금 |
| 2    | 예약금 0원 | |
| ...  | ... | ... |
```

If the same component (e.g., `결제수단`) has 4 case labels, that component has 4 visual states the developer must implement.

### Bucket C — Sample data and chrome (mostly ignore)

UI labels, button text, status bar time ("11:11"), sample shop names, placeholder Lorem-ish text, mock review content. These are useful for understanding the screen but are not requirements.

Signals:
- Single short word: "확인", "취소", "선택", "OK", "Cancel"
- Looks like time, date, currency: "11:11", "₩18,000", "5.0", "(10년차)"
- Looks like a person's name, shop name, or address (no policy content)
- Path includes generic component names like `Status Bar`, `top_bar`, `Frame 1234567` with no semantic name nearby

You can include a few of these inline in the screen description for color, but don't put them in any policy table.

## Handling non-Korean files

The default conventions above are tuned for Korean B2C product files where planners use:
- `Cell` / `Header` table structure
- `설명` instance for case labels
- 🔥 emoji for "needs clarification"
- `[Web]` prefix for platform variants

For other team conventions, watch for these alternatives:

**English/Western teams:**
- Tables: `Cell`, `Header`, `Row`, `Spec Row`
- Case labels: `Note`, `State`, `Variant`, `Case`, `Tag`, `Annotation`
- Markers: 🚧, ⚠️, "TBD", "TODO", "FIXME", "@question"
- Platform: `[Mobile]`, `[Desktop]`, `[iOS]`, `[Android]`

**Japanese teams:**
- Markers: 「要確認」, 「未定」, ❓
- Case labels: `説明`, `状態`, `パターン`

**Chinese teams:**
- Markers: 「待定」, 「确认」
- Case labels: `说明`, `状态`

When the convention is unclear:
1. Run a quick scan of all text nodes in one active section
2. Group by parent name and count occurrences
3. The most common parent names that hold short noun-phrase text are usually Bucket B
4. The parents that hold long sentence text are usually Bucket A

## Detecting screen boundaries

A "screen" is usually a top-level FRAME inside a SECTION whose width matches a device width (typically 360, 390, 414 for mobile; 1440, 1920 for desktop) and whose height is reasonable (600–1200px). Frames much wider than these are documentation containers (Summary tables), not screens.

Mobile-app file canvas widths to watch for:
- 360 — Android default
- 390 — iPhone 14/15
- 393 — Pixel
- 414 — older iPhone Plus

Desktop:
- 1440 — Mac default
- 1920 — Full HD
- 2400 — common SECTION container width (this is documentation, not a screen)

## Reusable component detection

When the same INSTANCE name appears across many screens, it's a reusable component the developer should build once. Common ones:
- `top_bar`, `bottom_bar`, `tab_bar`
- `Status Bar`, `Android Status Bar`
- `Chip`, `Tag`, `Badge`
- `rectangle_button` (CTA)
- `bottom_sheet`, `bottom list`, `handle_up`
- `toast-message`, `confirm modal`, `system modal`

List these in the "디자인 / 기술 요구사항" section of the output as the component palette.

## Algorithm/flowchart frames

When you see frames named `algorithm`, `flow`, `decision`, with arrows (VECTOR children) connecting them, that's a logic flowchart. Convert it to ASCII or Mermaid in the output:

```
[예약 완료]
   ↓
디바이스 알림 ON?
   ├─ YES → 종료
   └─ NO  → 모달 노출
            ├─ 닫기 → 종료
            └─ 설정 → ...
```

## Self-check before finalizing

Before writing the output file, verify:

1. Did you cover **every active top-level frame** in the hand-off page? (No silent drops.)
2. Did you copy Cell text **verbatim**, not paraphrased?
3. Does the case matrix include **every label** found via Bucket B?
4. Did you list every 🔥/⚠️/TBD marker in section 6?
5. Did you note dimmed frames in section 7 (excluded scope)?
6. Did you mark all speculation as `(추정)` in the API/domain section?
7. Did you keep the language of the source file (don't translate Korean policy to English)?

If any answer is no, go back and fix before saving.
