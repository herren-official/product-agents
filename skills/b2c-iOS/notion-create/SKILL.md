---
name: b2c-ios-notion-create
description: "Notion 공비서팀 제품 백로그 DB에 일감을 생성합니다. 일감 제목과 상세 내용을 기반으로 페이지를 생성하고 속성을 설정합니다."
argument-hint: "<일감 제목 또는 작업 설명> [옵션: 유형, 에픽, 마일스톤, 스토리포인트 등]"
disable-model-invocation: false
allowed-tools: ["mcp__notionMCP__notion-create-pages", "mcp__notionMCP__notion-duplicate-page", "mcp__notionMCP__notion-update-page", "mcp__notionMCP__notion-fetch", "mcp__notionMCP__notion-search", "Read", "Glob"]
---

# /b2c-ios-notion-create - Notion 일감 생성

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[b2c-ios-notion-create] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 상수 정의

| 항목 | 값 |
|------|-----|
| DB ID | `06181769bed6407e877d103bf6362c12` |
| 템플릿 페이지 ID | `24548de8e0ea805a936ef434b3d669c3` |
| 서비스 | `공비서-B2C` |
| 서비스 표기 | `[B2C]` |
| 기본 플랫폼 | `iOS` |
| 기본 작업자 (코리) | `56437b30-c924-4715-bac7-dfae061486e0` |

## 참고 문서

- [NOTION_TASK_GUIDE.md](.docs/NOTION_TASK_GUIDE.md) - 일감 생성 상세 규칙, 템플릿 구조, 속성 설정

## 실행 프로세스

### 1단계: 입력 분석 및 정보 수집

사용자 입력에서 다음을 추출:

| 항목 | 필수 | 기본값 | 비고 |
|------|------|--------|------|
| 작업 내용 | O | - | 일감 제목에 사용 |
| 플랫폼 | X | `iOS` | iOS, Android, WEB, API 등 |
| 서비스 | X | `공비서-B2C` | |
| 유형 | X | `작업` | 작업, 버그, 에픽, 데이터추출, 문서 |
| 에픽 | X | - | 에픽 페이지 ID 또는 URL |
| 마일스톤 | X | - | 마일스톤 페이지 ID 또는 URL |
| 스토리포인트 | X | - | 노션 수동 설정 권고 |
| 우선순위 | X | - | 상, 중, 하 |
| 작업 상세 내용 | X | - | 본문에 기술할 내용 |
| Todo 리스트 | X | - | 본문 Todo 섹션에 기술할 체크리스트 |
| 참고 자료 | X | - | Figma 링크, 유사 구현 경로, DS 컴포넌트 등 |
| Git 전략 | X | - | 브랜치명, 베이스, PR 타겟, 커밋 계획 |

**일감 이름 생성 규칙:**
```
{서비스 표기}[{플랫폼}] {작업 내용}
```
> `{서비스 표기}`는 상수 정의의 서비스 표기 값을 사용 (기본값: `[B2C]`)

예시: `[B2C][iOS] 후기 임시 저장 삭제 로직 구현`

### 1-1단계: 마일스톤 자동 조회 (에픽이 있고 마일스톤이 없을 때)

에픽 ID가 제공되었으나 마일스톤이 지정되지 않은 경우, 에픽의 마일스톤 목록을 자동 조회하여 적절한 마일스톤에 매핑한다.

**프로세스:**
1. `notion-fetch`로 에픽 페이지 조회
2. 에픽의 `마일스톤` 관계 속성에서 마일스톤 ID 목록 추출
3. 각 마일스톤을 `notion-fetch`로 조회하여 이름 확인
4. 일감 제목/작업 내용과 마일스톤 이름을 대조하여 가장 적합한 마일스톤 매핑

**매핑 규칙:**
- 마일스톤 이름의 키워드(화면명, 기능명)와 일감 제목을 비교
- 예: 일감 "콕예약 리스트뷰 - 회원가 표시" -> "B2C-콕예약-01-콕예약-리스트 뷰" 매핑
- 매핑 불확실 시 사용자에게 선택지 제시
- 매핑 불가 시 "00-기술부채" 마일스톤 사용 또는 미설정

> 대량 생성 시 에픽의 마일스톤 목록은 1회만 조회하고 캐싱하여 재사용한다.

### 2단계: 작업자 확인

1. `claude.local.md` 파일 존재 여부 확인 (Glob으로 탐색)
2. 파일이 있으면 작업자 정보 읽기
3. 파일이 없으면 **기본 작업자(코리) 고정 사용**: `56437b30-c924-4715-bac7-dfae061486e0`

> 현재 B2C 프로젝트에는 `claude.local.md`가 없으므로 항상 코리가 기본 작업자로 설정됨

### 3단계: 사용자 확인

생성 전 아래 형식으로 사용자에게 확인 요청:

```
다음 일감을 생성합니다:

| 항목 | 값 |
|------|-----|
| 이름 | [B2C][iOS] ... |
| 유형 | 작업 |
| 플랫폼 | iOS |
| 서비스 | 공비서-B2C |
| 작업자 | 코리 |
| 에픽 | (있으면 표시) |
| 마일스톤 | (있으면 표시) |
| 스토리포인트 | (있으면 표시, 수동 설정 필요 시 안내) |

진행할까요? [Y/N/E(수정)]
```

### 4단계: 페이지 생성 (2단계 전략)

#### 1차 시도: create-pages 직접 생성

```
Tool: mcp__notionMCP__notion-create-pages
Parameters:
  - database_id: "06181769bed6407e877d103bf6362c12"
  - properties: {
      "이름": "[B2C][iOS] 작업 제목"
    }
```

> 직접 생성 시 최소 속성(이름)만으로 생성. 나머지 속성은 5단계에서 개별 업데이트.
> JSON 배열 속성을 포함할 경우 문자열로 변환 필요: `["iOS"]` -> `"[\"iOS\"]"`

#### 1차 실패 시 Fallback: 템플릿 복사

```
Tool: mcp__notionMCP__notion-duplicate-page
Parameters:
  - page_id: "24548de8e0ea805a936ef434b3d669c3"
```

복사 후 반환된 페이지 ID를 기록하고 5단계로 진행.

### 5단계: 속성 설정 (개별 업데이트)

> 여러 속성을 한번에 업데이트하면 실패할 수 있으므로 **하나씩 개별 호출**한다.
> 단, 실패 가능성이 낮은 속성들(이름, 상태, 유형)은 묶어서 시도해볼 수 있다.

#### 업데이트 순서 및 성공률

| 순서 | 속성 | 성공률 | 값 형식 | 실패 시 대응 |
|------|------|--------|---------|-------------|
| 1 | 이름 | 높음 | 문자열: `"[B2C][iOS] ..."` | - |
| 2 | 상태 | 높음 | 문자열: `"백로그"` | - |
| 3 | 유형 | 높음 | 문자열: `"작업"` | - |
| 4 | 플랫폼 | 중간 | JSON 배열 문자열: `"[\"iOS\"]"` | prefix 변경 시도 |
| 5 | 서비스 | 중간 | JSON 배열 문자열: `"[\"공비서-B2C\"]"` | prefix 변경 시도 |
| 6 | 작업자 | 중간 | JSON 배열 문자열: `"[\"56437b30-...\"]"` | `user://` prefix 시도 |
| 7 | 에픽 | 중간 | JSON 배열 문자열: `"[\"https://www.notion.so/에픽ID\"]"` | URL 형식 확인 후 재시도 |
| 8 | 마일스톤 | 중간 | JSON 배열 문자열: `"[\"https://www.notion.so/마일스톤ID\"]"` | URL 형식 확인 후 재시도 |
| 9 | 우선순위 | 중간 | 문자열: `"중"` | - |
| 10 | 스토리포인트 | 낮음 | 숫자: `0.5` | 노션 수동 설정 안내 |

#### 속성 업데이트 호출 패턴

**기본 속성 묶음 (1차 시도):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "이름": "[B2C][iOS] 작업 제목",
      "상태": "백로그",
      "유형": "작업"
    }
```

**플랫폼 (개별):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "플랫폼": "[\"iOS\"]"
    }
```

**서비스 (개별):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "서비스": "[\"공비서-B2C\"]"
    }
```

**작업자 (개별):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "작업자": "[\"56437b30-c924-4715-bac7-dfae061486e0\"]"
    }
```

> 작업자 실패 시 `user://` prefix 추가하여 재시도:
> `"[\"user://56437b30-c924-4715-bac7-dfae061486e0\"]"`

**에픽/마일스톤 값 정규화:**
- 입력이 페이지 ID(예: `32f48de8e0ea805d8566d021c2083129`)이면 `https://www.notion.so/{ID}`로 변환
- 입력이 이미 URL(예: `https://www.notion.so/...`)이면 그대로 사용

**에픽 (개별, 값이 있을 때만):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "에픽": "[\"https://www.notion.so/에픽페이지ID\"]"
    }
```

**마일스톤 (개별, 값이 있을 때만):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "마일스톤": "[\"https://www.notion.so/마일스톤페이지ID\"]"
    }
```

> 에픽/마일스톤은 relation 속성이므로 반드시 **전체 Notion URL** 형식으로 전달해야 한다.
> 페이지 ID만 전달하면 "not a valid URL" 에러 발생.

**스토리포인트 (개별, 실패 허용):**
```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "update_properties"
  - properties: {
      "스토리포인트": 0.5
    }
```

> 스토리포인트 실패 시 에러로 처리하지 않고 사용자에게 수동 설정 안내

### 6단계: 본문 내용 작성

> 속성 업데이트와 내용 교체는 반드시 별도 호출로 수행

[NOTION_TASK_GUIDE.md](.docs/NOTION_TASK_GUIDE.md)의 템플릿 구조를 따라 본문 작성:

```
Tool: mcp__notionMCP__notion-update-page
Parameters:
  - page_id: (생성된 페이지 ID)
  - command: "replace_content"
  - new_str: (아래 템플릿 기반 마크다운)
```

#### 기본 템플릿
```markdown
## **작업내용** {color="blue_bg"}
### 내용
<callout icon="💡" color="gray_bg">
	작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다
</callout>

{작업 상세 내용}

### 참고
<callout icon="💡" color="gray_bg">
	설계/문서/피그마/슬랙 링크 등
</callout>

{참고 자료 링크}

---
## TT {color="orange_bg"}
### Todo
- [ ] {세부 작업 1}
- [ ] {세부 작업 2}

### Test Case
{테스트 케이스 관련 내용}
```

#### 템플릿 구조 보존 규칙 (절대 규칙)
- `{color="..."}` 색상 지정 유지
- `<callout>` 태그의 아이콘/색상 유지
- **callout 안의 힌트 텍스트 반드시 보존** (삭제 금지)
  - 내용 callout: `작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다`
  - 참고 callout: `설계/문서/피그마/슬랙 링크 등`
- 섹션 구조 (`##`, `###`) 유지
- 실제 내용은 callout 블록 **아래에** 작성 (안에 넣지 않음)
- `<synced_block_reference>` 절대 수정 금지

### 7단계: 생성 확인

```
Tool: mcp__notionMCP__notion-fetch
Parameters:
  - url: (생성된 페이지 ID)
```

생성된 페이지의 속성과 내용이 올바른지 확인.

## 출력 형식

### 성공 시
```markdown
### Notion 일감 생성 완료

| 항목 | 값 |
|------|-----|
| GBIZ | (자동 생성됨 - 확인 필요) |
| 이름 | [B2C][iOS] ... |
| 유형 | 작업 |
| 상태 | 백로그 |
| 플랫폼 | iOS |
| 서비스 | 공비서-B2C |
| 작업자 | 코리 |
| 에픽 | (설정된 경우) |
| 마일스톤 | (설정된 경우) |

**페이지 URL**: (Notion URL)

**수동 설정 필요 항목:**
- (스토리포인트 실패 시) 스토리포인트: 노션에서 직접 설정 필요
- (기타 실패 속성)
```

### 속성 설정 결과 요약
```markdown
| 속성 | 결과 |
|------|------|
| 이름 | 성공 |
| 상태 | 성공 |
| 유형 | 성공 |
| 플랫폼 | 성공 |
| 서비스 | 성공 |
| 작업자 | 성공 |
| 에픽 | 성공/미설정/실패 |
| 마일스톤 | 성공/미설정/실패 |
| 스토리포인트 | 성공/실패(수동 설정 필요) |
| 본문 내용 | 성공 |
```

## 에러 처리

### 생성 단계 에러

| 에러 | 원인 | 대응 |
|------|------|------|
| `create-pages` 실패 | DB 스키마 불일치, 권한 부족 | `duplicate-page` fallback 실행 |
| `duplicate-page` 실패 | 템플릿 삭제됨, 권한 부족 | 사용자에게 템플릿 페이지 확인 요청 |
| 양쪽 모두 실패 | API 장애 또는 권한 문제 | 사용자에게 수동 생성 안내 |

### 속성 업데이트 에러

| 에러 | 원인 | 대응 |
|------|------|------|
| "Property not found" | 속성명 변경/삭제됨 | 해당 속성 건너뛰고 수동 설정 안내 |
| "Invalid value" | 값 형식 불일치 | JSON 배열 문자열화 재시도 |
| 작업자 설정 실패 | ID 형식 불일치 | `user://` prefix 추가 후 재시도, 재실패 시 수동 안내 |
| 스토리포인트 실패 | API 제약 (숫자 타입) | 에러 무시, 수동 설정 안내 |
| 에픽/마일스톤 실패 | 페이지 ID 유효하지 않음 | ID 재확인 후 재시도, 실패 시 수동 안내 |

### 내용 작성 에러

| 에러 | 원인 | 대응 |
|------|------|------|
| `replace_content` 실패 | 마크다운 파싱 오류 | 단순화된 내용으로 재시도 |
| synced_block 충돌 | 템플릿 복사 시 잔여 블록 | 해당 블록 제외하고 재시도 |

## 대량 생성 가이드

여러 일감을 한번에 생성해야 할 때:

1. **배치 크기**: 5-8개씩 나누어 생성
2. **순차 처리**: 각 일감을 순서대로 생성 (병렬 생성 금지)
3. **중간 확인**: 각 배치 완료 후 생성 결과 확인
4. **누락 보완**: 실패한 일감은 개별 재시도
5. **스토리포인트**: 모든 생성 완료 후 노션에서 일괄 설정 안내

## 주의사항

1. GBIZ 번호는 자동 생성되므로 직접 입력하지 않음
2. JSON 배열 속성(플랫폼, 서비스, 작업자)은 문자열화하여 전달: `["iOS"]` -> `"[\"iOS\"]"`
3. 속성 업데이트는 개별 호출 원칙 (묶음 실패 방지)
4. 스토리포인트는 API 제약으로 실패 가능성 높음 - 수동 설정 권고
5. 템플릿 구조(색상, callout, 섹션)는 절대 변경 금지
6. synced_block은 절대 수정 금지 (다른 페이지에 영향)
