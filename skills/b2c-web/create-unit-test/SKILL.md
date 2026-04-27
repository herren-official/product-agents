---
name: create-unit-test
description: 프로젝트 맞춤형 단위 테스트 파일 자동 생성
---

# 단위 테스트 자동 생성

지정된 파일을 분석하여 프로젝트 컨벤션에 맞는 단위 테스트를 자동 생성합니다.

## 사용법

```bash
/create-unit-test src/components/Button.tsx
/create-unit-test src/hooks/useAuth.ts
/create-unit-test src/utils/formatDate.ts
```

## 참조 컨벤션

- [테스트 전략 컨벤션](../../../.docs/conventions/testing-strategy.md) — 핵심 철학, 명명 규칙, 패턴
- [테스트 Mock 시스템 가이드](../../../.docs/conventions/testing-mock-system.md) — Mock Store, Factory, Handler

## 처리 단계

1. **파일 분석**
   - 지정된 파일의 코드 읽기
   - 파일 타입 판별 (컴포넌트 / 훅 / 유틸리티)
   - 테스트 대상 함수/컴포넌트 식별
   - import 의존성 분석 (API 호출, 외부 라이브러리, 내부 모듈)

2. **테스트 생성**
   - 파일 타입별 적절한 템플릿 선택
   - **테스트 명명 규칙** 적용 (아래 상세)
   - **describe 계층 구조** 적용 (아래 상세)
   - MSW 모킹 설정 (API 호출이 있는 경우)

3. **파일 저장**
   - 원본 파일과 동일 디렉토리에 `.test.tsx` 또는 `.test.ts` 생성
   - 예: `Button.tsx` → `Button.test.tsx`

4. **테스트 실행 및 검증**
   - `yarn test [테스트파일경로] --watchAll=false`
   - 모든 테스트 케이스 통과 확인
   - 실패 시 오류 분석 및 수정
   - 최종 통과 여부 보고

## 명명 규칙 — Given-When-Then

단위 테스트는 반드시 **Given-When-Then** 패턴으로 작성합니다.

```typescript
test('Given: [전제조건] / When: [액션] / Then: [기대결과]', () => {})
```

- 한글로 작성
- `test` 키워드 사용 (`it` 아님)
- 결과 중심 설명

## describe 계층 구조

```typescript
describe('대상명', () => {             // 1단계: 테스트 대상
  describe('기능 카테고리', () => {      // 2단계: 기능 그룹
    test('Given-When-Then', () => {})  // 3단계: 개별 케이스
  });
});
```

### 카테고리 네이밍 가이드

| 대상 | 권장 카테고리 |
|---|---|
| **컴포넌트** | 렌더링, 조건부 렌더링, 사용자 인터랙션, 로딩 상태, 에러 상태 |
| **훅** | 초기 상태, 데이터 조회, 쿼리 옵션, 상태 변경, 에러 처리 |
| **유틸 함수** | 정상 입력, 엣지 케이스, 에러 처리 |

## 파일 타입별 템플릿

### 컴포넌트

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import Component from './Component';

describe('Component', () => {
  describe('렌더링', () => {
    test('Given: 유효한 props / When: 렌더링 / Then: 주요 요소가 표시된다', () => {
      render(<Component title="테스트" />);
      expect(screen.getByText('테스트')).toBeInTheDocument();
    });
  });

  describe('사용자 인터랙션', () => {
    test('Given: 활성 상태 / When: 버튼 클릭 / Then: onClick이 호출된다', async () => {
      const handleClick = jest.fn();
      render(<Component onClick={handleClick} />);
      await userEvent.click(screen.getByRole('button'));
      expect(handleClick).toHaveBeenCalledTimes(1);
    });
  });

  describe('조건부 렌더링', () => {
    test('Given: disabled props / When: 렌더링 / Then: 비활성화 스타일 적용', () => {
      render(<Component disabled />);
      expect(screen.getByRole('button')).toHaveClass('opacity-50');
    });
  });
});
```

### 커스텀 훅

```typescript
import { renderHook, act } from '@testing-library/react';
import useCustomHook from './useCustomHook';

describe('useCustomHook', () => {
  describe('초기 상태', () => {
    test('Given: 훅 초기화 / When: 마운트 / Then: 기본값이 설정된다', () => {
      const { result } = renderHook(() => useCustomHook());
      expect(result.current.value).toBe(0);
    });
  });

  describe('상태 변경', () => {
    test('Given: 초기 상태 / When: increment 호출 / Then: 값이 1 증가한다', () => {
      const { result } = renderHook(() => useCustomHook());
      act(() => result.current.increment());
      expect(result.current.value).toBe(1);
    });
  });
});
```

### 유틸리티 함수

```typescript
import { formatPrice } from './formatPrice';

describe('formatPrice', () => {
  describe('정상 입력', () => {
    test('Given: 양수 / When: 포맷팅 / Then: 콤마 포함 문자열 반환', () => {
      expect(formatPrice(10000)).toBe('10,000');
    });

    test('Given: 0 / When: 포맷팅 / Then: "0" 반환', () => {
      expect(formatPrice(0)).toBe('0');
    });
  });

  describe('엣지 케이스', () => {
    test('Given: null / When: 포맷팅 / Then: "-" 반환', () => {
      expect(formatPrice(null)).toBe('-');
    });
  });
});
```

## 핵심 원칙

- **`any` 타입 사용 금지** — `as any`, `: any` 모두 금지 (빌드 에러 발생)
- **사용자 관점으로 작성** — 기술적 구현이 아닌 행동/동작 검증
- **AAA 패턴** — Arrange(준비) → Act(실행) → Assert(검증) 순서
- **Testing Library 쿼리 우선순위** — getByRole > getByLabelText > getByText > getByTestId
- **jest.mock 내 require 사용 시** — `eslint-disable-next-line @typescript-eslint/no-require-imports` 주석 추가
- **Mock 컴포넌트** — named function 사용 (`display-name` 룰 준수)

## 테스트하지 말 것

- 단순 정적 텍스트 ("환영합니다" 표시 확인)
- 하드코딩된 상수 데이터
- 단순 props 바인딩 (name="홍길동" → "홍길동" 표시)
- 고정된 디자인 스타일 (rounded-lg, shadow-md 등)
