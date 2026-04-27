---
name: create-integration-test
description: Container/Page 레벨 통합 테스트 자동 생성
---

# 통합 테스트 자동 생성

Container/Page 컴포넌트를 분석하여 MSW 기반 통합 테스트를 자동 생성합니다.

## 사용법

```bash
/create-integration-test src/app/(pages)/coupon/containers/CouponContainer
/create-integration-test src/app/(pages)/shop/[shopId]/page.tsx
/create-integration-test src/app/(pages)/shop  # 폴더 전체
```

## 참조 컨벤션

- [테스트 전략 컨벤션](../../../.docs/conventions/testing-strategy.md) — 핵심 철학, 명명 규칙, 패턴
- [테스트 Mock 시스템 가이드](../../../.docs/conventions/testing-mock-system.md) — Mock Store, Factory, Handler, 네이밍 규칙

## 처리 단계

1. **대상 분석**
   - 파일/폴더 존재 확인
   - 컴포넌트 타입 판별 (Container / Page / Component)
   - 의존성 파악 (API 호출, 하위 컴포넌트, 상태 관리)
   - 사용하는 모든 API 엔드포인트 식별

2. **Mock API 확인 및 생성**
   - `src/__mocks__/mockApiV1/` 디렉토리에서 기존 Mock API 확인
   - **fixture 도메인(shop, cokProcedure)**: `fixtures/shops.ts`에 데이터가 있는지 확인
     - 없으면 `fixtures/shops.ts`에 해당 데이터 추가 (ShopFixture 확장)
     - `data.ts`에서 `ALL_SHOP_FIXTURES`로 store 생성
     - Handler 작성 (success, empty, error)
   - **비-fixture 도메인(coupon, user 등)**: [Mock 시스템 가이드](../../../.docs/conventions/testing-mock-system.md)에 따라 생성:
     - Factory 함수 작성 (API 타입 기반)
     - Data 파일 작성 (createMockStore 사용)
     - Handler 작성 (success, empty, error)
   - 도메인 `index.ts`에 핸들러 등록 (와일드카드 패턴은 구체적 패턴보다 뒤에)
   - `mockApiV1/index.ts`에 통합
   - **Mock 데이터 네이밍 규칙** 준수 (아래 상세)

3. **테스트 생성**
   - **진입점-상황-동작** 명명 패턴 적용 (아래 상세)
   - 위치: `components/__tests__/integration/[ComponentName].test.tsx`
   - MSW 서버 설정 및 Mock 핸들러 사용
   - `renderWithProviders` 사용

4. **테스트 실행 및 검증**
   - `yarn test [테스트파일경로] --watchAll=false`
   - 모든 테스트 케이스 통과 확인
   - 실패 시 오류 분석 및 수정
   - 최종 통과 여부 보고

## 명명 규칙 — 진입점-상황-동작

통합 테스트는 반드시 **진입점 → 상황 → 동작** 패턴으로 작성합니다.

```typescript
describe('진입점: [페이지/컨테이너명]', () => {
  describe('상황: [조건/액션]', () => {
    test('동작: [결과]', () => {});
  });
});
```

- 한글로 작성
- `test` 키워드 사용
- 사용자 관점의 결과 설명

## 테스트 템플릿

```typescript
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { renderWithProviders } from '@/__test-utils__/render/renderWithProviders';
import { server } from '@/__mocks__/server';
import { mockGetXxxHandler } from '@/__mocks__/mockApiV1/xxx/getXxx/getXxx.handler';
import { mockXxxStore } from '@/__mocks__/mockApiV1/xxx/getXxx/getXxx.data';
// fixture 도메인(shop, cokProcedure)은 케이스 샵에서 데이터를 가져옴
// import { STANDARD_SHOP, toCokShopInfo } from '@/__mocks__/mockApiUtils/fixtures';
import XxxContainer from '../XxxContainer';

describe('진입점: Xxx 페이지', () => {
  beforeAll(() => server.listen({ onUnhandledRequest: 'bypass' }));
  afterEach(() => {
    server.resetHandlers();
    mockXxxStore.reset();
  });
  afterAll(() => server.close());

  describe('상황: 데이터가 정상 로드되었을 때', () => {
    test('동작: 목록이 표시된다', async () => {
      renderWithProviders(<XxxContainer />);
      await waitFor(() => {
        expect(screen.getByText('기대하는 텍스트')).toBeInTheDocument();
      });
    });

    test('동작: 항목 개수가 표시된다', async () => {
      renderWithProviders(<XxxContainer />);
      await waitFor(() => {
        expect(screen.getAllByTestId('xxx-item')).toHaveLength(2);
      });
    });
  });

  describe('상황: 데이터가 비어있을 때', () => {
    test('동작: 빈 상태 안내가 표시된다', async () => {
      server.use(mockGetXxxHandler.empty);
      renderWithProviders(<XxxContainer />);
      await waitFor(() => {
        expect(screen.getByText('데이터가 없습니다')).toBeInTheDocument();
      });
    });
  });

  describe('상황: 서버 오류가 발생했을 때', () => {
    test('동작: 에러 메시지가 표시된다', async () => {
      server.use(mockGetXxxHandler.error);
      renderWithProviders(<XxxContainer />);
      await waitFor(() => {
        expect(screen.getByText('오류가 발생했습니다')).toBeInTheDocument();
      });
    });
  });

  describe('상황: 사용자가 항목을 클릭했을 때', () => {
    test('동작: 상세 정보가 표시된다', async () => {
      renderWithProviders(<XxxContainer />);
      await waitFor(() => {
        expect(screen.getByText('기대하는 텍스트')).toBeInTheDocument();
      });
      await userEvent.click(screen.getByText('기대하는 텍스트'));
      await waitFor(() => {
        expect(screen.getByText('상세 정보')).toBeInTheDocument();
      });
    });
  });
});
```

## Mock 데이터 네이밍 규칙

Mock API 생성 시 반드시 아래 네이밍 규칙을 따릅니다.

| 유형 | 패턴 | 예시 |
|---|---|---|
| **Builder (fixture)** | `build{도메인명}` | `buildZeroShop`, `buildEmployee` |
| **Factory (비-fixture)** | `createMock{도메인명}` | `createMockCoupon` |
| **Store** | `mock{도메인}{엔드포인트}Store` | `mockCouponsStore` |
| **Handler** | `mock{HTTP메서드}{엔드포인트}Handler` | `mockGetCouponsHandler` |
| **케이스 샵** | `{특징}_SHOP` | `PREMIUM_SHOP`, `STANDARD_SHOP` |
| **기본 데이터** | `mock{도메인명}` | `mockCoupon` |
| **변형 데이터** | `mock{특징}{도메인명}` | `mockExpiredCoupon` |

## 핵심 원칙

- **Container는 반드시 통합 테스트** — 단위 테스트 아님
- **MSW 기반 네트워크 레벨 Mock** — `jest.mock`으로 hook을 mock하지 않음
- **`any` 타입 사용 금지** — `as any`, `: any` 모두 금지 (빌드 에러 발생)
- **사용자 관점으로 작성** — 기술적 구현이 아닌 사용자 경험 검증
- **afterEach에서 반드시 초기화** — `server.resetHandlers()` + `store.reset()`
- **이미지 URL은 mockImage 유틸리티 사용** — 하드코딩 금지
- **개별 파일에서 직접 import** — 도메인 index가 아닌 개별 handler/data/factory

## 테스트해야 할 시나리오

- 정상 데이터 로드 및 표시
- 빈 데이터 상태
- 서버 오류 상태
- 사용자 인터랙션 (클릭, 입력, 스크롤)
- 조건부 렌더링 (권한, 상태에 따른 UI 변화)
- 페이지네이션/무한 스크롤 (해당되는 경우)
