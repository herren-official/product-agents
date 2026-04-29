# Figma REST API Cheatsheet

All endpoints below require this header:

```
X-Figma-Token: {personal_access_token}
```

Token format: `figd_...` — the user generates one at Figma → Settings → Security → Personal access tokens. Required scope: **File content: Read-only**.

When using `Claude in Chrome:javascript_tool` from a tab on `figma.com`, `fetch()` to `api.figma.com` works because the token is sent in a header (no CORS preflight on simple GETs with custom headers will succeed via the API's CORS config). When using `bash_tool` with `curl`, `api.figma.com` may not be in the allowlist — the browser path is the reliable one in that environment.

## Endpoints

### List pages (depth=1)
```
GET /v1/files/{fileKey}?depth=1
```
Returns `{document: {children: [{id, name, type, ...}]}}` where each child is a CANVAS (page).

### Get a node + its children at limited depth
```
GET /v1/files/{fileKey}/nodes?ids={nodeId1},{nodeId2}&depth=2
```
Use this for orientation. `nodes` is a comma-separated list. Node IDs use `:` not `-` (the URL form `4231-13260` maps to API form `4231:13260`).

### Get a node's full subtree
```
GET /v1/files/{fileKey}/nodes?ids={nodeId}
```
No `depth` param = full tree. Single section can be 500KB–5MB JSON.

### Render a node as PNG/SVG
```
GET /v1/images/{fileKey}?ids={nodeId}&format=png&scale=1
```
Returns `{images: {nodeId: "https://figma-alpha-api.s3.us-west-2.amazonaws.com/..."}}`. The S3 URLs are public for ~30 days but Figma's render queue is slow — request one node at a time, not 8 in a single call, or you'll hit a 30-second timeout.

## Response shape essentials

Every node has:
- `id` — string, format `"123:456"` (or `"I123:456;789:012"` for instance descendants)
- `name` — string, what the designer typed in the layers panel
- `type` — `DOCUMENT | CANVAS | SECTION | FRAME | INSTANCE | COMPONENT | COMPONENT_SET | GROUP | TEXT | RECTANGLE | VECTOR | LINE | ELLIPSE | ...`
- `visible` — boolean (defaults to true if absent)
- `opacity` — number 0–1 (defaults to 1 if absent)
- `children` — array, present on container types
- `absoluteBoundingBox` — `{x, y, width, height}`
- `fills` — array (relevant for solid color overlays)

For text nodes:
- `characters` — the actual text content
- `style` — `{fontFamily, fontWeight, fontSize, ...}`

## Patterns to know

### Detecting "dimmed = out of scope"
A node is dimmed if any of:
- `node.opacity < 0.99`
- A child RECTANGLE with `fills[].opacity < 1` and a dark/gray solid color sits on top (visual dim overlay)
- An ancestor has `opacity < 0.99` (opacity inherits visually)

In practice, checking `node.opacity` directly on each top-level frame catches the vast majority. Only walk into the subtree when the top-level is active.

### Detecting policy text (Korean files)
Text nodes whose immediate parent frame is named exactly `Cell` are policy rows in a Summary table. The corresponding `Header` cells (parent name `Header`) are the row numbers/letters.

Path-based check: if any ancestor in the chain is named `Summary` and the immediate parent is `Cell`, this is policy text.

### Detecting case labels (Korean files)
Instances named `설명` typically wrap a small box with case-name text. Pattern:
- `node.type === 'INSTANCE' && node.name === '설명'`
- Walk its descendants and concatenate all TEXT nodes' `characters`.

For non-Korean files, common conventions include: `Note`, `Description`, `Case`, `Variant Label`, `Tag`. When the convention is unclear, dump the names of all small INSTANCE/FRAME nodes near case-divergent UI and look for repetition.

### Detecting platform variants
Frame names with bracketed prefixes: `[Web]`, `[App]`, `[iOS]`, `[Android]`, `[Mobile]`, `[Desktop]`. Group these with their non-prefixed counterparts as platform variants of the same logical screen.

### Detecting reserved markers
Designers use emoji to flag uncertainty: 🔥, ⚠️, ❓, ❗, 🚧, "TBD", "TODO", "확인필요", "정의필요". Search all active text for these and put each match in the "확인 필요" section of the output.
