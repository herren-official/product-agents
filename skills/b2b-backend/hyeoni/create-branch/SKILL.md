---
name: b2b-backend-create-branch
description: 현재 브랜치에서 새로운 하위 작업 브랜치를 자동 생성한다. GBIZ 번호 + 작업 설명 입력 → GBIZ-XXXXX-{description} 브랜치 생성.
---

# 브랜치 자동 생성 커맨드

현재 브랜치에서 새로운 하위 작업 브랜치를 자동으로 생성합니다.

## 사용 방법

이 커맨드를 실행하면 다음 정보를 입력받아 브랜치를 생성합니다:
- GBIZ 일감 번호
- 작업 설명

## 브랜치 네이밍 규칙

```
{GBIZ-일감번호}-{간략한-설명}
```

### 규칙
- GBIZ 번호는 필수
- 소문자와 하이픈(-) 사용
- 간결하고 명확한 설명
- 언더스코어(_) 사용 금지
- 대문자 사용 금지 (GBIZ 제외)

### 작업 타입 키워드
설명에 작업 타입을 자연스럽게 포함하세요:
- `feat-`, `add-`: 새로운 기능 추가
- `fix-`: 버그 수정
- `refactor-`: 코드 리팩토링
- `test-`: 테스트 코드
- `docs-`: 문서 작업
- `perf-`: 성능 개선

## 실행 순서

### 1단계: 현재 브랜치 확인
```bash
git branch --show-current
```

### 2단계: GBIZ 번호 입력받기
사용자로부터 다음 형식 중 하나로 입력받습니다:
- `GBIZ-20269`
- `https://www.notion.so/24148de8e0ea809d8182f5f78f33655d?pvs=4`
- `GBIZ-20269 예약 목록 API 확장`

GBIZ 번호를 추출합니다:
```bash
echo "GBIZ-20269 예약 목록 API 확장" | grep -oE 'GBIZ-[0-9]+'
# 출력: GBIZ-20269
```

### 3단계: 작업 설명 입력받기
사용자로부터 간략한 작업 설명을 입력받습니다.
- 공백은 하이픈(-)으로 변환
- 대문자는 소문자로 변환
- 특수문자 제거

예시 변환:
- `예약 목록 API 확장` → `expand-booking-list-api`
- `고객 방문 통계 추가` → `add-customer-visit-stats`

### 4단계: 브랜치명 생성
```
{GBIZ-번호}-{작업-설명}
```

예시:
- `GBIZ-20269-expand-booking-list-api`
- `GBIZ-20270-add-customer-visit-stats`

### 5단계: 브랜치 생성
```bash
git checkout -b {브랜치명}
```

### 6단계: 생성 완료 메시지
```
브랜치가 생성되었습니다!
브랜치명: GBIZ-20269-expand-booking-list-api
부모 브랜치: deploy-161
```

## 예시 시나리오

### 시나리오 1: GBIZ 번호만 제공
```
입력: GBIZ-20269
설명 입력 요청: 예약 목록 API에 고객 방문 통계 추가
생성된 브랜치: GBIZ-20269-add-customer-visit-stats-to-booking-list-api
```

### 시나리오 2: GBIZ 번호와 설명 함께 제공
```
입력: GBIZ-20270 인센티브 계산 로직 개선
생성된 브랜치: GBIZ-20270-improve-incentive-calculation-logic
```

### 시나리오 3: Notion URL 제공
```
입력: https://www.notion.so/24148de8e0ea809d8182f5f78f33655d
GBIZ 번호 추출: GBIZ-20271
설명 입력 요청: 매출 등록 이벤트 핸들러 구현
생성된 브랜치: GBIZ-20271-implement-sale-registered-event-handler
```

## 주의사항

- 항상 **현재 브랜치에서** 새 브랜치를 생성합니다
- develop이나 main 브랜치에서는 경고 메시지를 표시합니다
- 이미 존재하는 브랜치명인 경우 에러를 표시합니다
- GBIZ 번호가 없으면 브랜치 생성을 중단합니다

## 에러 처리

### 1. GBIZ 번호 없음
```
오류: GBIZ 번호를 찾을 수 없습니다.
형식: GBIZ-XXXXX (예: GBIZ-20269)
```

### 2. 브랜치명 중복
```
오류: 브랜치 'GBIZ-20269-expand-booking-list-api'가 이미 존재합니다.
```

### 3. develop/main 브랜치에서 생성 시도
```
경고: develop 브랜치에서 직접 분기하려고 합니다.
대부분의 경우 feature 브랜치에서 분기해야 합니다.
계속하시겠습니까? (y/n)
```

## 실행 프롬프트

1. 현재 브랜치 확인
2. 사용자에게 GBIZ 번호 또는 작업 정보 요청
3. GBIZ 번호 추출 및 검증
4. 작업 설명 입력 받기 (영어 권장)
5. 브랜치명 생성 및 유효성 검사
6. 사용자 확인 후 브랜치 생성
7. 생성 완료 메시지 표시
