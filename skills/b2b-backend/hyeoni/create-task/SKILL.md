---
name: b2b-backend-create-task
description: 작업 목록 MD 파일에서 정보를 추출하여 Notion 작업 카드를 자동 생성한다. 공비서팀 제품 백로그(NEW) DB에 [CRM][Backend] 카드 생성.
---

# Notion 작업 카드 자동 생성 커맨드

작업 목록 MD 파일에서 작업 정보를 추출하여 Notion "공비서팀 제품 백로그(NEW) DB"에 작업 카드를 자동으로 생성합니다.

## 사용 방법

### 명령어 형식
```
/b2b-backend-create-task [작업목록_파일경로] [작업번호]
```

또는 전체 작업 생성:
```
/b2b-backend-create-task [작업목록_파일경로] all
```

또는 인터랙티브 방식:
```
/b2b-backend-create-task
```

### 파라미터
1. **작업목록_파일경로** (선택): `.claude/docs/` 기준 상대 경로
2. **작업번호** (선택): MD 파일의 작업 번호 또는 "all"

**참고**: 스토리포인트는 항상 **1**로 자동 설정됩니다.

## 작업 목록 파일 형식

```markdown
## 1. 데이터베이스 스키마 변경 및 초기 데이터 마이그레이션

### 작업 목록
1. **customer 테이블 컬럼 추가**
   - `visit_count` (INT): 방문 수
   - `last_visit_date` (DATE): 최근 방문일

---

## 7. 예약 목록 API 응답 확장

### 작업 목록
1. **예약 목록 조회 API 응답 수정**
   - GET `/api/v2/{shopNo}/books`
   - 응답에 `customer.visitCount` 추가
```

### 형식 규칙
- 작업 헤딩: `## {번호}. {제목}` (GBIZ 번호는 자동 생성)
- 작업 내용: `### 작업 목록` 또는 `### 작업내용` 하위 내용
- 작업은 `---`로 구분

## Notion 카드 생성 규칙

### 자동 설정 필드
- **아이콘**: 파란색 사각형
- **작업자**: 혀니 (user://3172c742-e332-457d-8e7c-a6958fbcccae)
- **상태**: 백로그
- **유형**: 작업
- **서비스**: 공비서-B2B
- **플랫폼**: API
- **스토리포인트**: 1 (고정)
- **정제완료**: false

### 사용자 입력 필드
- **이름** (title): [CRM][Backend] {작업 제목}
- **userDefined:ID**: GBIZ-{자동 생성된 번호}

### 작업 내용 (content)

```markdown
## **작업내용** {color="blue_bg"}
### 내용
<callout icon="..." color="gray_bg">
	작업 상세 내용으로 해야할 작업을 세분화하여 정리하여 작성한다
</callout>

{MD 파일에서 추출한 작업 목록 내용}

### 참고
<callout icon="..." color="gray_bg">
	설계/문서/피그마/슬랙 링크 등
</callout>

---

### Todo
- [ ]
- [ ]
```

## 실행 순서

### 1단계: 작업 목록 파일 확인
```bash
find .claude/docs -name "*tasks*.md" -type f
```

### 2단계: 작업 모드 선택
- **단일 작업 모드**: 특정 작업 번호 입력
- **전체 작업 모드**: "all" 입력

### 3단계: MD 파일 파싱
```bash
grep -E "^## [0-9]+\." backend_tasks2.md
```

### 4단계: 작업 정보 추출
- **번호**: 헤딩의 번호 부분
- **제목**: 헤딩의 제목 부분
- **작업 내용**: `### 작업 목록` 또는 `### 작업내용` 하위 내용
- **관련 파일**: `### 관련 파일` 또는 `### 관련 패키지` 내용 (선택)

### 5단계: GBIZ 번호 확인
Notion 카드 생성 시 "userDefined:ID" 속성(auto_increment_id)이 자동으로 GBIZ 번호를 생성합니다.

### 6단계: Notion 카드 생성 확인
사용자에게 생성할 카드 정보를 표시하고 확인을 받습니다.

### 7단계: Notion API 호출

**템플릿 카드 ID**: `287ff6255dd041cb96f8c97e22e3693b`

**단일 작업 모드**:
1. 템플릿 카드 복제: `mcp__notionMCP__notion-duplicate-page`
2. 제목 수정: `mcp__notionMCP__notion-update-page` (properties 업데이트)
3. 내용 수정: `mcp__notionMCP__notion-update-page` (content 교체)

**전체 작업 모드**:
1. 첫 번째 작업: 템플릿 카드 복제 후 수정
2. 두 번째 이후 작업: 첫 번째 작업 카드 복제 후 수정 (더 빠름)

### 8단계: MD 파일 업데이트
Notion 카드가 생성되면 할당된 GBIZ 번호를 MD 파일에 업데이트합니다.

**업데이트 전**:
```markdown
## 7. 예약 목록 API 응답 확장
```

**업데이트 후**:
```markdown
## 7. GBIZ-20268: 예약 목록 API 응답 확장
```

### 9단계: 생성 완료 메시지
```
Notion 카드가 생성되었습니다!
- 제목: [CRM][Backend] 예약 목록 API 응답 확장
- GBIZ: GBIZ-20268
- URL: https://www.notion.so/...

MD 파일이 업데이트되었습니다!
- 파일: backend_tasks2.md
- 작업 7번에 GBIZ-20268 추가
```

## 주의사항

### 1. 작업 목록 파일 위치
- 모든 작업 목록 파일은 `.claude/docs/` 디렉토리 하위에 있어야 합니다

### 2. MD 파일 형식 검증
- 작업 헤딩 형식이 올바른지 확인
- 작업 내용이 존재하는지 확인

### 3. Notion 카드 중복 방지
- 이미 생성된 작업인지 확인 (GBIZ 번호로 검색)

### 4. API 호출 제한
- 전체 작업 생성 시 최대 20개
- 20개 이상인 경우 배치로 나누어 생성

### 5. 작업자 고정
- 모든 카드의 작업자는 자동으로 "혀니"로 설정됩니다
- 변경이 필요한 경우 Notion에서 수동으로 수정
