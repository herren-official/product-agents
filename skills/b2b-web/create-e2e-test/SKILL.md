---
name: b2b-web-create-e2e-test
description: "E2E 테스트 파일 자동 생성 (Given-When-Then 스타일)"
argument-hint: "[기능명]"
allowed-tools: ["read", "write", "grep", "bash", "edit"]
---

# E2E 테스트 자동 생성

대상 기능: {기능명}

## 테스트 명명 규칙 (스타일 C: Given-When-Then)

**[.docs/conventions/TEST_NAMING_CONVENTIONS.md 참조]**

E2E 테스트는 **스타일 C (Given-When-Then)** 패턴을 따릅니다:

```
describe('기능/시나리오명') → test('Given: [전제조건] / When: [액션] / Then: [기대결과]')
```

## 처리 단계

1. **기능 분석**
   - 테스트 대상 기능/시나리오 파악
   - 사용자 플로우 분석
   - 필요한 전제조건 식별
   - 기대 결과 정의

2. **테스트 파일 생성**
   - 파일명: `{기능명}.e2e.ts`
   - 위치: `e2e/` 또는 `tests/e2e/` 디렉토리

3. **시나리오 작성**
   - Given: 전제조건 (로그인 상태, 데이터 상태 등)
   - When: 사용자 액션 (클릭, 입력, 네비게이션 등)
   - Then: 기대 결과 (화면 변화, 데이터 변경 등)

4. **테스트 실행**
   - `yarn test:e2e` 명령으로 실행
   - 결과 검증 및 오류 수정

## E2E 테스트 템플릿

```typescript
import { test, expect } from '@playwright/test'

describe('예약메모 표시', () => {
  test('Given: 캘린더 설정 페이지 / When: 예약메모 토글 ON / Then: 캘린더에 메모 표시', async ({ page }) => {
    // Given: 캘린더 설정 페이지
    await page.goto('/settings/calendar')
    await expect(page.getByText('캘린더 설정')).toBeVisible()

    // When: 예약메모 토글 ON
    await page.getByRole('switch', { name: '예약메모' }).click()

    // Then: 캘린더에 메모 표시
    await page.goto('/calendar')
    await expect(page.getByTestId('booking-memo')).toBeVisible()
  })

  test('Given: 예약메모 활성화 상태 / When: 예약메모 토글 OFF / Then: 캘린더에서 메모 숨김', async ({ page }) => {
    // Given: 예약메모 활성화 상태
    await page.goto('/settings/calendar')
    const toggle = page.getByRole('switch', { name: '예약메모' })
    if (!(await toggle.isChecked())) {
      await toggle.click()
    }

    // When: 예약메모 토글 OFF
    await toggle.click()

    // Then: 캘린더에서 메모 숨김
    await page.goto('/calendar')
    await expect(page.getByTestId('booking-memo')).not.toBeVisible()
  })
})

describe('고객 예약', () => {
  test('Given: 로그인된 사용자 / When: 예약 생성 후 저장 / Then: 예약 목록에 추가됨', async ({ page }) => {
    // Given: 로그인된 사용자
    await page.goto('/login')
    await page.fill('[name="email"]', 'test@example.com')
    await page.fill('[name="password"]', 'password123')
    await page.click('button[type="submit"]')
    await expect(page).toHaveURL('/dashboard')

    // When: 예약 생성 후 저장
    await page.goto('/booking/new')
    await page.fill('[name="customerName"]', '홍길동')
    await page.fill('[name="phone"]', '010-1234-5678')
    await page.click('button:has-text("저장")')

    // Then: 예약 목록에 추가됨
    await page.goto('/booking/list')
    await expect(page.getByText('홍길동')).toBeVisible()
  })

  test('Given: 기존 예약 있음 / When: 예약 시간 변경 / Then: 변경된 시간으로 표시됨', async ({ page }) => {
    // Given: 기존 예약 있음
    await page.goto('/booking/list')
    await page.click('text=홍길동')

    // When: 예약 시간 변경
    await page.click('[data-testid="edit-time"]')
    await page.selectOption('[name="hour"]', '14')
    await page.click('button:has-text("저장")')

    // Then: 변경된 시간으로 표시됨
    await expect(page.getByText('14:00')).toBeVisible()
  })
})

describe('매출 통계', () => {
  test('Given: 이번 달 매출 데이터 있음 / When: 매출 페이지 접속 / Then: 월별 매출 차트 표시', async ({ page }) => {
    // Given: 이번 달 매출 데이터 있음 (테스트 데이터 시딩 필요시 API 호출)

    // When: 매출 페이지 접속
    await page.goto('/statistics/sales')

    // Then: 월별 매출 차트 표시
    await expect(page.getByTestId('sales-chart')).toBeVisible()
    await expect(page.getByText('월별 매출')).toBeVisible()
  })
})
```

## Given-When-Then 작성 가이드

### Given (전제조건)
- 로그인 상태
- 특정 페이지 위치
- 데이터 상태 (예: 기존 예약 있음)
- 설정 상태

### When (액션)
- 버튼 클릭
- 폼 입력
- 페이지 이동
- 토글/스위치 조작

### Then (기대결과)
- 화면에 특정 요소 표시
- URL 변경
- 데이터 변경 확인
- 에러 메시지 표시

## 사용 예시

```bash
/create-e2e-test 예약메모표시
/create-e2e-test 고객예약
/create-e2e-test 매출통계
/create-e2e-test 로그인플로우
```

## 주의사항

- 테스트 파일명: `*.e2e.ts`
- Given-When-Then 형식을 test 이름에 포함
- 각 단계를 주석으로 명확히 구분
- 비동기 동작은 적절한 대기 처리
- 테스트 간 독립성 유지 (상태 공유 X)
