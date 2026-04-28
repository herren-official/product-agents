---
name: b2b-backend-notion-collector
description: Notion URL을 받아 clean markdown으로 변환하여 파일로 저장하는 수집 스킬. 오케스트레이터(spec-orchestrator)의 Phase 0에서 호출된다.
---

# Notion 기획서 수집 (notion-collector)

## 역할

Notion 페이지 URL을 입력받아, 페이지 내용을 clean markdown으로 변환하여 지정 경로에 저장한다.

## 입력

- **노션 URL**: `https://www.notion.so/...` 형태 (복수 가능)
- **저장 경로**: 절대 경로 (예: `/path/to/_workspace/raw_spec.md`)

## 출력

- `{저장경로}/raw_spec.md` — clean markdown 파일

## 워크플로우

### Step 1: 페이지 조회

1. `mcp__plugin_Notion_notion__notion-fetch` 도구 호출 (id 파라미터에 URL 전달)
2. 결과가 tool-results 파일로 저장될 수 있음:
   - 에러 메시지에 파일 경로가 포함되면 해당 파일에서 읽기
   - 정상 반환되면 직접 사용

### Step 2: 콘텐츠 추출

1. 결과가 JSON 배열이면 파싱:
   ```python
   import json
   data = json.load(f)  # [{type: "text", text: "..."}]
   for item in data:
       if item.get('type') == 'text':
           content += item['text']
   ```
2. `content`에서 줄바꿈 변환:
   - `\\n` (이스케이프된 리터럴) → 실제 줄바꿈 `\n`
3. HTML entity 디코딩:
   - `&gt;` → `>`
   - `&lt;` → `<`
   - `&amp;` → `&`
   - `&#39;` → `'`
   - `&quot;` → `"`

#### Notion MCP 응답 구조 (이중 래핑 주의)

Notion MCP 응답은 이중 래핑 구조이다:
1. **외부 래핑**: tool-results 파일에 JSON 배열 `[{type: "text", text: "..."}]`
2. **내부 래핑**: text 필드 값이 `{"metadata":{...},"title":"...","text":"<page>...<content>...</content></page>"}` JSON 객체

따라서 추출 순서:
1. 외부 JSON 배열 파싱 → text 필드 추출
2. text가 `{`로 시작하면 → 내부 JSON 파싱 시도 (제어문자로 실패할 수 있음)
   - 성공 시: data["text"] 에서 `<content>...</content>` 내부 추출
   - 실패 시: 문자열 검색으로 `<content>` ~ `</content>` 사이 추출
3. `\\n` 리터럴 → 실제 줄바꿈 변환 (**반드시 content 추출 후 수행**)
4. `\\t` 리터럴 → 실제 탭 변환
5. HTML entity 디코딩

### Step 3: 파일 저장

1. Write 도구로 `{저장경로}/raw_spec.md`에 저장
2. 100KB 초과 시 `##` heading 기준으로 분할:
   - `{저장경로}/raw_spec/01_{섹션명}.md`
   - `{저장경로}/raw_spec/02_{섹션명}.md`
   - `{저장경로}/raw_spec_index.md` — 목차

### 자동 수정 스크립트 (후처리)

저장 후 형식 검증에서 실패하면 아래 Python 스크립트로 자동 수정한다:

```python
import json, re

# 1. 파일 읽기
with open(filepath) as f:
    content = f.read()

# 2. 첫 줄이 { 이면 내부 JSON에서 content 추출
if content.strip().startswith('{'):
    try:
        data = json.loads(content)
        text = data.get('text', content)
    except json.JSONDecodeError:
        # 제어문자 포함 시 문자열 검색
        match = re.search(r'<content>(.*)</content>', content, re.DOTALL)
        text = match.group(1) if match else content
    content = text

# 3. 줄바꿈/탭/entity 변환
content = content.replace('\\n', '\n').replace('\\t', '\t')
content = content.replace('&gt;', '>').replace('&lt;', '<').replace('&amp;', '&')

# 4. 저장
with open(filepath, 'w') as f:
    f.write(content)
```

이 스크립트는 notion-collector가 자동으로 실행하거나, 오케스트레이터가 검증 실패 시 fallback으로 실행한다.

### Step 4: 검증

1. 저장 후 파일 줄 수 확인 (Bash `wc -l`)
   - **5줄 미만이면 실패** → Step 2 재시도
2. 첫 줄이 `{` 또는 `[`로 시작하면 → JSON 미파싱 경고, Step 2 재시도
3. `##` heading이 2개 이상 존재하는지 Grep 확인
4. 검증 통과 시 완료 보고

## 에러 처리

| 상황 | 대응 |
|------|------|
| Notion MCP 미응답 | 1회 재시도 → 재실패 시 에러 보고 |
| JSON 파싱 실패 | 원본 텍스트 그대로 저장 + 경고 |
| 파일 저장 실패 | Write 도구 대신 Bash echo 시도 |
| 100KB 초과 분할 실패 | 단일 파일로 저장 + 경고 |

## 복수 URL 처리

여러 노션 URL이 주어지면:
1. 각 URL을 순차적으로 조회
2. 결과를 하나의 raw_spec.md에 `---` 구분자로 병합
3. 또는 `raw_spec/01_page1.md`, `raw_spec/02_page2.md`로 분할
