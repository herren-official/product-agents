---
name: b2b-backend-create-ticket
description: Notion 백로그 티켓 일괄 생성 (작업자, SP, 마일스톤 한 번에 설정)
argument-hint: <티켓명 SP [마일스톤:이름] [플랫폼]>
---

Notion 백로그 DB에 티켓을 일괄 생성한다. 모든 속성(작업자, 스토리포인트, 마일스톤, 에픽 등)을 한 번의 호출로 설정한다.

## 사전 정보

### DB IDs
- **백로그 DB**: `collection://afbb2565-672a-44cd-85f4-45ba566e3613`
- **스프린트 DB**: `collection://46bae361-b009-4ac3-b08e-db4dce33a941`
- **마일스톤 DB**: `collection://a9c463d8-5409-4e08-8791-529e49919cfb`
- **에픽 DB**: `collection://72e31d4f-e0c4-4d01-9727-fce0cd93b9e7`

### 사용자 정보
- **제로 user ID**: `30cd872b-594c-8129-ab53-0002190f0e7d`

### 기본값
- **작업자**: 제로 (`30cd872b-594c-8129-ab53-0002190f0e7d`)
- **서비스**: `["공비서-B2B"]`
- **유형**: 작업
- **상태**: 백로그
- **우선순위**: 중

## 실행 절차

1. `$ARGUMENTS`를 파싱하여 생성할 티켓 정보를 파악한다.
   - 인자가 없으면 사용자에게 다음을 질문:
     - 티켓 이름 (여러 개 가능)
     - 에픽 (Notion 페이지 ID 또는 검색어)
     - 마일스톤 (Notion 페이지 ID 또는 검색어)
     - 스토리포인트
     - 플랫폼 (API, JSP, BATCH, Admin, Database 등)
   - 인자에서 누락된 필드는 기본값 적용

2. **스프린트 선택**: 스프린트가 지정되지 않은 경우
   - 스프린트 DB (`collection://46bae361-b009-4ac3-b08e-db4dce33a941`)를 조회하여 "현재", "다음" 상태 스프린트를 찾는다
   - 사용자에게 선택지를 제시한다 (스프린트 이름, 상태, 기간 표시)

3. **마일스톤/에픽 확인**: 검색어가 주어진 경우
   - Notion MCP `notion-search` 도구로 워크스페이스 전역 검색을 시도하거나, 데이터 소스가 정해져 있으면 `notion-fetch`로 해당 DB를 직접 조회한다.
   - 검색 시 `query` 파라미터에 마일스톤/에픽 이름을 넣고, `filter`에서 페이지 type을 지정한다 (예: `{"property": "object", "value": "page"}`).
   - 응답에서 `results[].url` 또는 `results[].id`를 추출한다 (`url`이 있으면 그대로 사용, 없으면 `https://www.notion.so/{id}` 형식으로 구성).
   - 다중 매치 시 사용자에게 후보를 제시해 선택받는다 (이름 + 상태/기간 표기).
   - 예시 워크플로우:
     1. `notion-search`로 마일스톤 이름 검색 → 후보 N개
     2. 1개면 자동 채택, 2개 이상이면 사용자 선택
     3. 선택된 page URL을 properties의 `마일스톤` 필드(JSON array)에 주입
   - 에픽도 동일 절차.

4. `notion-create-pages`를 사용하여 모든 속성을 **한 번의 호출**로 설정한다.
   - parent: `{"data_source_id": "afbb2565-672a-44cd-85f4-45ba566e3613"}`
   - properties에 포함할 필드:
     - `이름`: 티켓 제목
     - `유형`: 작업 (기본)
     - `상태`: 백로그 (기본)
     - `서비스`: JSON array (예: `["공비서-B2B"]`)
     - `플랫폼`: JSON array (예: `["API"]`)
     - `우선순위`: 상/중/하
     - `작업자`: JSON array of user IDs (예: `["30cd872b-594c-8129-ab53-0002190f0e7d"]`)
     - `스토리포인트`: 숫자
     - `스프린트`: JSON array of page URLs (예: `["https://www.notion.so/{sprint-page-id}"]`)
     - `에픽`: JSON array of page URLs
     - `마일스톤`: JSON array of page URLs

5. 생성 결과를 테이블로 정리하여 보여준다.

## 필드 타입 참조

| 필드 | 타입 | 값 형식 | 비고 |
|-----|------|---------|------|
| `이름` | title | 문자열 | 필수 |
| `유형` | select | `"작업"`, `"버그"` 등 | 기본: 작업 |
| `상태` | status | `"백로그"`, `"진행 중"` 등 | 기본: 백로그 |
| `서비스` | multi_select | `["공비서-B2B"]` | 기본: 공비서-B2B |
| `플랫폼` | multi_select | `["API"]`, `["JSP"]` 등 | 선택 |
| `우선순위` | select | `"상"`, `"중"`, `"하"` | 기본: 중 |
| `작업자` | people | `["user-id"]` | 기본: 제로 |
| `스토리포인트` | number | 숫자 | 필수 |
| `스프린트` | relation (limit:1) | `["https://www.notion.so/{id}"]` | 사용자 선택 |
| `에픽` | relation | `["https://www.notion.so/{id}"]` | 선택 |
| `마일스톤` | relation | `["https://www.notion.so/{id}"]` | 선택 |

## 주의사항

- `작업자`는 person 타입이므로 반드시 Notion user ID를 사용한다.
- `에픽`, `마일스톤`, `스프린트`는 relation 타입이므로 `["https://www.notion.so/{page-id}"]` 형식으로 전달한다.
- `스프린트`는 relation limit:1이므로 배열에 URL 하나만 넣는다.
- `서비스`, `플랫폼`은 multi_select이므로 JSON array 형식으로 전달한다.
- 여러 티켓을 한 번에 생성할 때는 pages 배열에 모두 넣어 **단일 API 호출**로 처리한다.
- 티켓 삭제는 사용자가 직접 수동으로 처리한다 (API로 삭제하지 않는다).
- SP는 최대 1을 초과하지 않도록 잘게 쪼갠다 (1 티켓 = 1 브랜치 + 1 PR 원칙).

## 인자 처리

$ARGUMENTS가 제공된 경우 자연어로 파싱하여 티켓 정보를 추출한다.
예시:
- `/create-ticket API 약관 조회 개발 1sp 마일스톤:마케팅수신동의`
- `/create-ticket DB 스키마 변경 0.5sp, API 약관조회 1sp, API 회원가입 1sp`
- `/create-ticket 12개 티켓 목록 (테이블 형태로 입력)`
