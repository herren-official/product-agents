---
name: b2c-ios-notion-update
description: "Notion 페이지의 속성 또는 내용을 업데이트합니다. 작업 계획, 상태 변경 등을 노션에 반영할 때 사용합니다."
argument-hint: "<노션 페이지 URL 또는 ID> <업데이트 내용>"
disable-model-invocation: false
allowed-tools: ["mcp__notionMCP__notion-update-page", "mcp__notionMCP__notion-fetch"]
---

# /notion-update - Notion 페이지 업데이트

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[notion-update] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 실행 프로세스

### 1단계: 대상 페이지 확인

업데이트 전 현재 페이지 상태를 확인:
```
Tool: mcp__notionMCP__notion-fetch
Parameters:
  - url: (Notion URL 또는 Page ID)
```

### 2단계: 업데이트 유형 판단

| 업데이트 유형 | command | 설명 |
|-------------|---------|------|
| 속성 변경 | `update_properties` | 상태, 작업자, 에픽 등 프로퍼티 변경 |
| 내용 교체 | `replace_content` | 페이지 본문 전체 교체 |
| 부분 교체 | `replace_content_range` | 페이지 본문 특정 부분만 교체 |

### 3단계: 업데이트 실행

#### 속성 업데이트
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (페이지 ID)
  - command: "update_properties"
  - properties: {
      "속성명": 값,
      ...
    }
```

#### 내용 교체
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (페이지 ID)
  - command: "replace_content"
  - new_str: "마크다운 형식의 전체 내용"
```

#### 부분 교체
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (페이지 ID)
  - command: "replace_content_range"
  - old_str: "교체 대상 텍스트"
  - new_str: "새로운 텍스트"
```

> **두 번의 호출이 필요한 경우**: 속성 업데이트와 내용 교체를 동시에 해야 하면 반드시 별도 호출로 수행

## 템플릿 구조 보존 규칙 (절대 규칙)

> 상세 템플릿과 속성 규칙은 [NOTION_TASK_GUIDE.md](.docs/NOTION_TASK_GUIDE.md) 참조

### 절대 변경 금지 항목
- `{color="..."}` 색상 지정
- `<callout>` 태그의 아이콘/색상
- 섹션 구조 (`##`, `###`)
- `<synced_block_reference>` (다른 페이지에 영향)

### Callout 블록 규칙
```markdown
<callout icon="..." color="gray_bg">
</callout>

실제 내용은 callout 아래에 작성
```
callout 블록 **안에** 내용을 넣지 않고, **아래에** 작성

## 에러 처리

| 에러 | 대응 |
|------|------|
| "Property not found" | 속성명 오타 확인, 데이터베이스 스키마 변경 확인 |
| "Invalid value" | 속성 타입 확인 (JSON 배열 형식 등) |
| 권한 없음 | 페이지 접근 권한 확인 |
| synced_block 수정 시도 | 절대 금지 - 일반 콘텐츠만 수정 |
