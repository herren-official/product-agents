---
name: b2b-web-create-integration-test
description: "프로젝트 맞춤형 통합 테스트 파일 자동 생성 (INTEGRATION_TESTING_RULES.md 기반)"
argument-hint: "[컴포넌트경로]"
allowed-tools: ["read", "write", "grep", "bash", "edit", "multi-edit"]
---

# 통합 테스트 자동 생성

대상 컴포넌트 경로: {컴포넌트경로}

## 처리 단계

1. **컴포넌트 검증 및 분석**
   - 디렉토리 존재 확인
   - index.tsx 파일 존재 확인
   - 컴포넌트 타입 판별 (모달/페이지/복합컴포넌트)
   - 의존성 분석 (hooks, providers, external libraries)
   - 기존 테스트 파일 존재 여부 확인

2. **의존성 Mock 준비**
   - **필수 Provider 설정**:
     - `ThemeProvider` (styled-components)
     - `RecoilRoot` (상태 관리)
     - `QueryClientProvider` (데이터 페칭)
   - **전역 설정 Mock** (파일 최상단):
     - `next/config` - publicRuntimeConfig 설정
     - `next/head` - 빈 컴포넌트로 모킹
   - **Hook Mock 설정** (describe 블록 외부에 변수 선언):
     - `useCommonModal` - show, hide 함수 반환
     - `useShopInfo` (샵 정보)
     - 컴포넌트별 커스텀 훅
   - **Window 객체 Mock**:
     - window.opener, window.close, window.alert 등
     - Object.defineProperty 사용
   - **컴포넌트 Mock**:
     - Icon 컴포넌트 (button으로 렌더링)
     - SVG 아이콘 컴포넌트
     - 동적 상호작용이 필요한 컴포넌트 (DateButton 등)
   - **Mock 데이터 생성/임포트**:
     - 필요한 mock 데이터 파일 확인
     - 없으면 `src/__mocks__/data/` 경로에 생성

3. **테스트 시나리오 생성**
   - [통합 테스트 작성 룰](/.docs/conventions/INTEGRATION_TESTING_RULES.md) 적용
   - [테스트 명명 규칙](/.docs/conventions/TEST_NAMING_CONVENTIONS.md) 적용
   - **명명 규칙 (스타일 D: 작업 단위)**:
     - 최상위 describe: `진입점: [페이지/모달명]`
     - 중첩 describe: `상황: [조건/액션]`
     - test: `동작: [결과]`
   - **기본 구조**:
     - 렌더링 테스트 그룹
     - 사용자 인터랙션 테스트 그룹
     - 상태 관리 테스트 그룹
     - 에러 처리 테스트 그룹
   - **컴포넌트 타입별 시나리오**:
     - **모달**: 열기/닫기, 확인/취소, 변경사항 감지
     - **리스트**: 아이템 렌더링, 필터링, 페이지네이션
     - **폼**: 입력 검증, 제출 처리, 에러 표시
     - **페이지**: 레이아웃 구조, 컴포넌트 통합 (자식 컴포넌트 mock)
   - **컴포넌트/페이지 분리 전략**:
     - 페이지 테스트: 자식 컴포넌트를 mock하여 중복 방지
     - 컴포넌트 테스트: 비즈니스 로직에 집중

4. **파일 저장** (FOLDER_STRUCTURE_CONVENTIONS.md 적용)
   - 파일명: `{ComponentName}.test.tsx`
   - 위치: 컴포넌트와 동일 디렉토리
   - **도메인 구조 기준 저장 위치**:
     ```
     src/domains/{domain}/{feature}/
     ├── index.tsx
     ├── index.test.tsx           # 페이지 통합 테스트 (1depth)
     ├── ui/
     │   ├── Header.tsx
     │   └── Header.test.tsx      # UI 컴포넌트 테스트 (2depth)
     └── modals/
         ├── SettingModal/
         │   ├── index.tsx
         │   └── SettingModal.test.tsx  # 모달 통합 테스트
     ```
   - **기존 구조 예시**:
     ```
     src/components/Shop/ShopEmployeeIncentives/
     └── modals/
         └── ShopEmployeeSettingIncentiveModal/
             ├── index.tsx
             └── ShopEmployeeSettingIncentiveModal.test.tsx
     ```

5. **테스트 실행 및 검증**
   - 생성된 테스트 파일 실행: `yarn test {ComponentName}.test.tsx`
   - 모든 테스트 케이스 통과 확인
   - console.error 처리 (jsdom 경고는 무시)
   - 테스트 실패 시 오류 분석 및 수정
   - 최종 통과 여부 보고

6. **커밋 안내**
   - 테스트 작성 완료 후 커밋 규칙 안내
   - 예시: `test(GBIZ-XXXX): {ComponentName} 통합 테스트 추가`
   - 컴포넌트/페이지 테스트는 별도 커밋으로 분리 권장

## 통합 테스트 템플릿

### 모달 컴포넌트
```typescript
import React from 'react'
import { screen, fireEvent, waitFor } from '@testing-library/dom'
import { render as rtlRender } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RecoilRoot } from 'recoil'
import { ThemeProvider } from 'styled-components'
import { common as theme } from '@/styles/theme'
import ComponentName from '.'
import { ModalProps } from '@/recoil/common'

// Mock next/config
jest.mock('next/config', () => () => ({
  publicRuntimeConfig: {
    apiDomain: 'http://localhost:3000',
  },
}))

// Mock dependencies
const mockShow = jest.fn()
const mockHide = jest.fn()

jest.mock('@/hooks/common/useCommonModal', () => ({
  __esModule: true,
  default: () => ({
    show: mockShow,
    hide: mockHide,
  }),
}))

jest.mock('@/hooks/common', () => ({
  useShopInfo: jest.fn(),
}))

// Icon component Mock
jest.mock('@/components/common/Icon', () => ({
  __esModule: true,
  default: ({ icon, onClick, ...props }: any) => (
    <button data-testid={icon} onClick={onClick} {...props}>
      {icon}
    </button>
  ),
}))

// 스타일 D (작업 단위) 명명 규칙 적용
describe('진입점: 직원 인센티브 설정 모달', () => {
  const createWrapper = () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
        mutations: { retry: false },
      },
    })

    return ({ children }: { children: React.ReactNode }) => (
      <RecoilRoot>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider theme={theme}>{children}</ThemeProvider>
        </QueryClientProvider>
      </RecoilRoot>
    )
  }

  const render = (ui: React.ReactElement) => {
    return rtlRender(ui, { wrapper: createWrapper() })
  }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('상황: 인센티브 조건을 변경하면', () => {
    test('동작: 저장 버튼이 활성화된다', async () => {
      // 구현
    })

    test('동작: 변경 내역이 폼에 반영된다', async () => {
      // 구현
    })
  })

  describe('상황: 저장 버튼을 클릭하면', () => {
    test('동작: API 호출이 실행된다', async () => {
      // 구현
    })

    test('동작: 성공 시 모달이 닫힌다', async () => {
      // 구현
    })
  })

  describe('상황: 닫기 버튼을 클릭하면', () => {
    test('동작: 변경사항이 있을 때 확인 모달이 표시된다', async () => {
      // 구현
    })
  })
})
```

### 페이지 컴포넌트 (자식 컴포넌트 mock)
```typescript
import React from 'react'
import { screen } from '@testing-library/dom'
import { render as rtlRender } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RecoilRoot } from 'recoil'
import { ThemeProvider } from 'styled-components'
import { common as theme } from '@/styles/theme'
import PageComponent from '.'

// Mock next/config
jest.mock('next/config', () => () => ({
  publicRuntimeConfig: {
    apiDomain: 'http://localhost:3000',
  },
}))

// Mock next/head
jest.mock('next/head', () => ({
  __esModule: true,
  default: ({ children }: { children: React.ReactNode }) => {
    return <>{children}</>
  },
}))

// Mock child components to avoid duplicate testing
jest.mock('@/components/ChildComponent', () => ({
  __esModule: true,
  default: () => <div data-testid="child-component">ChildComponent</div>,
}))

// 스타일 D (작업 단위) 명명 규칙 적용
describe('진입점: 고객 목록 페이지', () => {
  const createWrapper = () => {
    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
        mutations: { retry: false },
      },
    })

    return ({ children }: { children: React.ReactNode }) => (
      <RecoilRoot>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider theme={theme}>{children}</ThemeProvider>
        </QueryClientProvider>
      </RecoilRoot>
    )
  }

  const render = (ui: React.ReactElement) => {
    return rtlRender(ui, { wrapper: createWrapper() })
  }

  describe('상황: 페이지 진입 시', () => {
    test('동작: 레이아웃이 올바르게 렌더링된다', () => {
      render(<PageComponent />)
      expect(screen.getByTestId('child-component')).toBeInTheDocument()
    })

    test('동작: 헤더와 필터가 표시된다', () => {
      // 구현
    })
  })

  describe('상황: 검색 필터를 변경하면', () => {
    test('동작: 필터링된 결과가 표시된다', () => {
      // 구현
    })
  })
})
```

## Mock 데이터 템플릿

### API Response Mock
```typescript
export const mockEmployeeIncentiveDetailWithRates = {
  chargeEmployee: {
    employeeNo: 1,
    name: '김직원',
  },
  isActive: true,
  minimumPaymentCondition: {
    type: 'TOTAL_SALES' as const,
    amount: 100000,
  },
  incentiveRate: {
    type: 'BULK_SETTING' as const,
    incentiveRates: [
      {
        saleItemType: 'COSMETIC_PROCEDURE' as const,
        actualPayment: 15,
        deductedPayment: 10,
      },
    ],
    incentiveRateDetails: [
      {
        saleItemType: 'COSMETIC_PROCEDURE' as const,
        paymentMethods: [
          { id: 1, name: '현금', rate: 15 },
          { id: 2, name: '카드', rate: 12 },
        ],
      },
    ],
  },
}
```

## 사용 예시

```bash
/create-integration-test src/components/Shop/ShopEmployeeIncentives/modals/ShopEmployeeSettingIncentiveModal
/create-integration-test src/components/Order/OrderDetailModal
/create-integration-test src/components/Customer/CustomerListPage
```

## 주의사항

1. **Provider 설정 필수**
   - 모든 테스트는 Provider wrapper 사용
   - theme undefined 에러 시 ThemeProvider 확인

2. **Mock 설정 위치**
   - `next/config`: 파일 최상단
   - Hook mock 변수: describe 블록 외부
   - mock 함수 정의: import 문 다음

3. **Mock 우선순위**
   - Icon 컴포넌트는 반드시 button으로 모킹
   - SVG 아이콘은 간단한 div로 모킹
   - 커스텀 훅은 필요한 반환값만 모킹

4. **에러 대응**
   - `publicRuntimeConfig undefined`: next/config mock 추가
   - `Cannot destructure property`: mock 변수를 describe 외부로 이동
   - `window.opener undefined`: Object.defineProperty 사용

5. **비동기 처리**
   - 모든 상태 변화는 `waitFor` 사용
   - 렌더링 완료 후 assertion
   - fireEvent 후 상태 변화 대기

6. **요소 선택자**
   - disabled 요소: `getElementById` 사용
   - 아이콘 클릭: `data-testid` 사용
   - 텍스트 매칭: 정확한 텍스트 사용

7. **테스트 격리**
   - 각 테스트 전 `jest.clearAllMocks()`
   - 테스트 간 상태 공유 금지
   - 독립적인 시나리오 작성

8. **페이지/컴포넌트 분리**
   - 페이지 테스트: 자식 컴포넌트 mock
   - 컴포넌트 테스트: 실제 로직 테스트
   - 중복 테스트 방지