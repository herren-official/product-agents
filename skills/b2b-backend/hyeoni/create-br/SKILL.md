---
name: b2b-backend-create-br
description: 작업 목록 MD 파일에서 GBIZ 번호와 제목을 추출하여 브랜치를 자동 생성한다. .claude/docs/ 하위 *tasks.md 파일을 입력으로 받음.
---

# 작업 목록 기반 브랜치 자동 생성 커맨드

작업 목록 MD 파일에서 특정 작업의 GBIZ 번호와 제목을 추출하여 브랜치를 자동으로 생성합니다.

## 사용 방법

### 명령어 형식
```
/b2b-backend-create-br [작업목록_파일경로] [작업번호]
```

또는 인터랙티브 방식:
```
/b2b-backend-create-br
```

### 파라미터
1. **작업목록_파일경로** (선택): `.claude/docs/` 기준 상대 경로
   - 예: `customer_visit_count_and_last_visit_date_add/backend_tasks.md`
   - 생략 시: 사용자에게 입력 요청

2. **작업번호** (선택): MD 파일의 작업 번호
   - 예: `7` (7번 작업)
   - 생략 시: 사용자에게 입력 요청

## 작업 목록 파일 형식

```markdown
## 1. GBIZ-20262: 데이터베이스 스키마 변경 및 초기 데이터 마이그레이션

## 2. GBIZ-20263 : 매출 등록 이벤트 핸들러 구현

## 7. GBIZ-20268 : 예약 목록 API 응답 확장
```

### 형식 규칙
- 헤딩: `## {번호}. GBIZ-{번호}: {제목}` 또는 `## {번호}. GBIZ-{번호} : {제목}`
- 콜론(`:`) 앞뒤 공백 허용
- 번호는 순차적이지 않아도 됨

## 브랜치 네이밍 규칙

```
{GBIZ-번호}-{영어-작업-설명}
```

### 작업 타입 키워드
- `feat-`, `add-`: 새로운 기능 추가
- `fix-`: 버그 수정
- `refactor-`: 코드 리팩토링
- `test-`: 테스트 코드
- `docs-`: 문서 작업
- `perf-`: 성능 개선
- `implement-`: 새로운 구현

## 실행 순서

### 1단계: 현재 브랜치 확인
```bash
git branch --show-current
```

### 2단계: 작업 목록 파일 경로 확인
파라미터로 전달되지 않은 경우 사용자에게 입력 요청.

```bash
find .claude/docs -name "*tasks.md" -type f
```

### 3단계: 작업 번호 입력
```bash
grep -E "^## [0-9]+\. GBIZ-[0-9]+" backend_tasks.md
```

### 4단계: GBIZ 번호 및 제목 추출
```bash
grep -E "^## 7\. GBIZ-[0-9]+" backend_tasks.md
```

### 5단계: 브랜치명 생성
1. 한글 제목을 영어로 번역
2. 소문자 변환
3. 공백을 하이픈으로 변환
4. 특수문자 제거

예시:
- `예약 목록 API 응답 확장` → `expand-booking-list-api-response`
- `매출 등록 이벤트 핸들러 구현` → `implement-sale-registered-event-handler`

### 6단계: 브랜치 생성 확인
```
현재 브랜치: GBIZ-20265-implement-sale-deleted-event-handler
새 브랜치: GBIZ-20268-expand-booking-list-api-response
작업: 예약 목록 API 응답 확장

이 브랜치를 생성하시겠습니까? (y/n)
```

### 7단계: 브랜치 생성
```bash
git checkout -b GBIZ-20268-expand-booking-list-api-response
```

## 영어 번역 가이드

| 한글 | 영어 |
|------|------|
| 추가 | add |
| 구현 | implement |
| 수정 | modify, update |
| 삭제 | delete, remove |
| 조회 | retrieve, query |
| 등록 | register, create |
| 확장 | expand, extend |
| 개선 | improve, enhance |
| 리팩토링 | refactor |
| 이벤트 핸들러 | event-handler |
| API 응답 | api-response |
| 데이터베이스 스키마 | database-schema |

## 주의사항

- 모든 작업 목록 파일은 `.claude/docs/` 디렉토리 하위에 있어야 합니다
- develop이나 main 브랜치에서는 경고 메시지 표시
- 이미 존재하는 브랜치명인 경우 에러 표시

## 에러 처리

### MD 파일 없음 / 작업 번호 없음 / GBIZ 번호 추출 실패 / 브랜치명 중복
각 케이스마다 명확한 에러 메시지를 출력하고 중단한다.
