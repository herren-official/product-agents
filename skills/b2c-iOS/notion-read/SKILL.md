---
name: b2c-ios-notion-read
description: "Notion 페이지를 읽어 GBIZ 번호, 작업 내용, 요구사항 등을 파싱합니다. 다른 스킬에서 노션 일감 정보가 필요할 때 참조합니다."
argument-hint: "<노션 일감 URL 또는 GBIZ 번호>"
disable-model-invocation: false
allowed-tools: ["mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-search"]
---

# /notion-read - Notion 일감 읽기 및 파싱

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[notion-read] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 실행 프로세스

### 1단계: 입력 분석

입력 유형에 따라 적절한 도구를 선택:

| 입력 유형 | 판별 기준 | 사용 도구 |
|----------|----------|----------|
| Notion URL | `notion.so/` 포함 | `notion-fetch` |
| Notion Page ID | 32자 hex string | `notion-fetch` |
| GBIZ 번호 | `GBIZ-XXXXX` 패턴 | `notion-search` |

### 2단계: 페이지 정보 가져오기

**URL 또는 Page ID인 경우:**
```
Tool: mcp__notionMCP__notion-fetch
Parameters:
  - url: (Notion URL 또는 Page ID)
```

**GBIZ 번호만 있는 경우:**
```
Tool: mcp__notionMCP__notion-search
Parameters:
  - query: "GBIZ-XXXXX"
```
검색 결과에서 해당 페이지를 찾은 후 `notion-fetch`로 상세 정보 가져오기

### 3단계: 정보 추출

페이지 정보에서 다음 항목을 추출하여 구조화:

#### 필수 추출 항목
- **GBIZ 번호**: `userDefined:ID` 프로퍼티 (예: "GBIZ-18754")
- **태스크 제목**: 페이지 이름 (예: "[B2C][iOS] 후기 신고 기능 구현")
- **순수 제목**: `[B2C][iOS]` prefix 제거한 제목 (예: "후기 신고 기능 구현")
- **작업 내용**: 본문의 상세 설명 및 요구사항

#### 선택 추출 항목
- **에픽**: 에픽 프로퍼티 (Prefix 결정에 사용)
- **마일스톤**: 마일스톤 프로퍼티
- **상태**: 상태 프로퍼티 (백로그, 진행중 등)
- **우선순위**: 우선순위 프로퍼티
- **작업 유형**: 유형 프로퍼티 (작업, 버그, 에픽 등)
- **첨부 Figma 링크**: 본문에서 `figma.com` URL 추출
- **참고 자료**: 본문의 링크 및 이미지
- **관련 일감**: 관계 프로퍼티

## 출력 형식

```markdown
### Notion 일감 정보

| 항목 | 값 |
|------|-----|
| GBIZ | GBIZ-XXXXX |
| 제목 | [B2C][iOS] ... |
| 순수 제목 | ... |
| 유형 | Feature / Bug Fix / etc |
| 에픽 | (있으면 표시) |
| 상태 | 백로그 / 진행중 / etc |

**작업 내용:**
(노션 본문에서 추출한 요구사항)

**첨부 링크:**
- Figma: (있으면 표시)
- 참고: (있으면 표시)
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| Notion 접근 실패 | 권한 확인 또는 URL 재확인 요청 |
| GBIZ 번호 없음 (`userDefined:ID` 미설정) | 수동 입력 요청 |
| 검색 결과 없음 | GBIZ 번호 또는 키워드 재확인 요청 |
| 페이지 삭제됨 | 사용자에게 알림 |
