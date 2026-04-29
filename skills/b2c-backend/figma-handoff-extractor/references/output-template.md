# Output Template

Use this skeleton when writing the final markdown. Fill in the sections from the extracted data; delete sections that don't apply (e.g., if there's no flow chart, drop the algorithm/Mermaid block).

The example values below are from the 공비서 B2C reservation file — replace them with whatever the current file actually contains. **Match the source file's language**: write the doc in Korean if the Figma is Korean, English if English. Do not translate verbatim policy text.

---

```markdown
# {Project Name} — {Hand-off Page Name}

**Figma 파일**: {file.name}
**대상 페이지**: {page.name}
**작성 기준일**: {today's date} (Figma 최종 수정 {file.lastModified})
**현재 프로젝트 식별 기준**: opacity 1.0 (그림자 처리 opacity {observed dim value} = 이전 프로젝트, 이 문서에서는 제외)

---

## 0. 전체 화면 구성

본 프로젝트는 다음 N개 화면 그룹으로 구성된다.

| # | 섹션 | 주요 화면 |
|---|------|-----------|
| 1 | {section_name} | {comma-separated active frame names} |
| 2 | ... | ... |

각 섹션마다 **앱 + [Web] 두 벌**이 함께 작업됐다 (반응형/플랫폼 분기 필요). *(이 줄은 [Web] 변형이 실제로 있을 때만 포함)*

---

## 1. 화면별 요구사항 및 정책

### 1.1 {Section Name}

[Optional: a short paragraph describing the section's purpose]

#### {Logical sub-area, e.g., 검색바 영역, 샵 카드 구성 요소}

- **{UI element name}**: {policy text from Bucket A, verbatim, ` / ` converted to bullet hierarchy}
- **{...}**: {...}

##### {Numbered policy table when the source has Header 1/2/3 numbering}

| # | 정책 |
|---|------|
| 1 | {Cell text 1, verbatim} |
| 2 | {Cell text 2, verbatim} |
| 2-1 | {sub-row Cell text} |

##### ⚠️ 확인 필요 (Figma 내 🔥 표시)
*(only include this subsection if there are markers in this section)*
- 🔥 {marker text 1}
- 🔥 {marker text 2}

### 1.2 {Next Section}
...

---

## 2. 공통 정책

*Cross-section rules that apply throughout the product. Pull these out so they're not duplicated. Common categories:*

### 2.1 거리 표기
- {distance formatting rules}

### 2.2 시간 슬롯
- 단위: {1시간 / 30분}
- 오늘 선택 시: {rule}
- 다른 날짜 선택 시: {rule}

### 2.3 통화/금액 단위
- {rounding rule, e.g., 100원 단위로만 설정 가능}

### 2.4 텍스트 글자수
- {field}: 최대 N자, M줄까지 노출, "..." 처리

### 2.5 플랫폼 분기
- 모든 화면에 **앱 (iOS/Android) + Web** 두 벌
- {OS-specific divergences}

---

## 3. 케이스/상태 전체 매트릭스

### 3.1 {Component Name with Cases} — N 케이스

| 케이스 | 조건 | 비고 |
|--------|------|------|
| 1 | {label from Bucket B} | {extra context if any} |
| 2 | {label} | |
| ... | ... | |

### 3.2 {Next branching component} — N 케이스

| 케이스 | 노출 항목 |
|--------|-----------|
| {label} | {what's shown in this case} |

### 3.X {Flowchart-style decision tree}

```
[Entry state]
   ↓
{Decision question}?
   ├─ YES → {next state}
   └─ NO  → {next state}
              ├─ {action 1} → {result}
              └─ {action 2} → {result}
```

---

## 4. API/도메인 추정 요구사항

> 디자인에서 직접 확인되지 않은 항목은 `(추정)` 표시

### 4.1 도메인 모델

- **{EntityName}**: {field1, field2, field3 with brief notes}
- **{EntityName}**: ...

### 4.2 주요 API 엔드포인트 (추정)

- `GET /resources/...` — {what it returns} (추정)
- `POST /resources/...` — {what it does} (추정)

### 4.3 클라이언트 상태/로컬 스토리지 (추정)

- {state field}: {why it's needed} (추정)

---

## 5. 디자인 / 기술 요구사항

### 5.1 화면 사이즈
- 모바일 앱 기준 **{width} x {height}**
- Web 별도 디자인 존재 (`[Web]` 프리픽스 프레임)

### 5.2 컴포넌트 (재사용)
*Components that appear as INSTANCEs across multiple screens — built once, used many times.*
- `{component_name_1}` — {brief description}
- `{component_name_2}` — {brief description}

### 5.3 좌표/맵 *(only if the product uses maps)*
- {map-related notes}

---

## 6. ⚠️ 확인 필요 / 미정 항목 (질문 리스트)

다음 항목은 디자인만으로 판단이 불가능하므로 기획자/디자이너 확인 필요:

1. **🔥 {marker text from file}** — {context: which screen/section}
2. **{ambiguous policy}** — {why it's ambiguous}
3. **{missing case}** — {which dimension isn't fully covered}
4. ...

*Number these so the user can answer "1번은 ~, 3번은 ~" without ambiguity.*

---

## 7. 그림자 처리 = 이전 프로젝트 (개발 범위 제외)

다음 화면들은 opacity {dim value}로 그림자 처리되어 있으므로 **이번 프로젝트에서 제외**:

| 섹션 | 제외 화면 |
|------|-----------|
| {section} | `{frame_name}`, `{frame_name}` |
| ... | ... |

> ⚠️ 경계가 애매한 항목은 "6. 확인 필요" {N}번 참고

---

**문서 끝.**
```

## Notes on filling in the template

- **Section 0 table**: count active frames per section, list them comma-separated. Skip dimmed ones.
- **Section 1 numbered tables**: when the source Summary has `Header` cells with numbers like `1`, `2`, `2-1`, preserve that exact numbering — it lets the user cross-reference back to the Figma.
- **Section 2 (공통 정책)**: only put a rule here if it appears in 2+ sections. Section-specific rules stay in section 1.
- **Section 3 case matrices**: one table per case-branching component, not one giant table. Title each table with the component name plus the count.
- **Section 4 (API)**: be explicit about speculation. Every endpoint should have `(추정)` unless you literally see it in a designer's note. Same for domain fields.
- **Section 6 (questions)**: this is the section the user will read most carefully. Include:
  - Every 🔥/⚠️/TBD marker from the file
  - Every ambiguous threshold ("최대 N자" without a number)
  - Every case-matrix dimension that isn't fully filled
  - Every "추후 ~" or "later ~" comment found in policy text
- **Section 7**: only top-level dimmed frames, not every dimmed text node. The user wants to know what screens are out of scope, not which sub-elements.

## Common section omissions

If the source has no flow charts, no maps, no platform variants, etc., **delete those subsections entirely** rather than leaving "N/A" placeholders. The doc should look written-for-this-project, not a generic template with empty slots.
