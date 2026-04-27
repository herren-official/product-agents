---
name: b2b-web-create-unit-test
description: "프로젝트 맞춤형 단위 테스트 파일 자동 생성 (UNIT_TESTING_RULES.md 기반)"
argument-hint: "[파일경로]"
allowed-tools: ["read", "write", "grep", "bash", "edit"]
---

# 단위 테스트 자동 생성

대상 파일 경로: {파일경로}

## 처리 단계

1. **파일 검증 및 분석**
   - 파일 존재 확인
   - 파일 타입 판별 (컴포넌트/훅/유틸리티)
   - 테스트 대상 함수/컴포넌트 식별
   - 기존 테스트 파일 존재 여부 확인

2. **테스트 생성**
   - [단위 테스트 작성 룰](/docs/conventions/UNIT_TESTING_RULES.md) 적용
   - 파일 타입별 적절한 템플릿 선택:
     - **컴포넌트**: React Testing Library 기반
       - 기본 렌더링 테스트
       - Props 변화 테스트
       - 이벤트 핸들러 테스트
       - 스타일/클래스 테스트
     - **훅**: renderHook 사용
       - 초기 상태 테스트
       - 상태 업데이트 테스트
       - 의존성 변화 테스트
     - **유틸리티**: 순수 함수 테스트
       - 정상 입력값 테스트
       - 엣지 케이스 테스트
       - 에러 처리 테스트
   - API 호출 시 jest.mock() 사용
   - **목데이터 사용**: `src/__mocks__/data/` 디렉토리의 중앙화된 목데이터 활용
     - 기존 목데이터가 있으면 재사용
     - 없으면 도메인별 폴더에 새로 생성
     - 타입 정의 필수 (API 응답 타입 사용)

3. **파일 저장** (FOLDER_STRUCTURE_CONVENTIONS.md 적용)
   - 원본 파일과 동일 디렉토리에 `.test.{ts,tsx}` 생성
   - **도메인 구조 기준 저장 위치**:
     ```
     src/domains/{domain}/{feature}/
     ├── components/
     │   ├── Button.tsx
     │   └── Button.test.tsx      # 컴포넌트 테스트
     ├── hooks/
     │   ├── useFeature.ts
     │   └── useFeature.test.ts   # 훅 테스트
     └── utils/
         ├── formatPrice.ts
         └── formatPrice.test.ts  # 유틸 테스트
     ```
   - **기존 구조 (components/hooks/utils)**:
     ```
     src/components/common/Button/
     ├── index.tsx
     └── Button.test.tsx

     src/hooks/common/
     ├── useAuth.ts
     └── useAuth.test.ts
     ```
   - 파일명 규칙: `{원본파일명}.test.{ts,tsx}`

4. **테스트 실행 및 검증**
   - 생성된 테스트 파일 실행: `yarn test -- {테스트파일} --watchAll=false`
   - 모든 테스트 케이스 통과 확인
   - 테스트 실패 시 오류 분석 및 수정
   - 최종 통과 여부 및 커버리지 보고

## 테스트 명명 규칙 (스타일 B: 사용자 여정)

**[.docs/conventions/TEST_NAMING_CONVENTIONS.md 참조]**

Unit 테스트는 **스타일 B (사용자 여정)** 패턴을 따릅니다:

```
describe('페이지/컴포넌트명') → describe('기능/요소') → test('~하면 ~가 ~된다')
```

## 테스트 템플릿 예시

### 컴포넌트 테스트
```typescript
import { render, theme } from '@/__test__/mock'
import { screen, fireEvent } from '@testing-library/dom'
import ComponentName from '.'

describe('캘린더 설정 페이지', () => {
  describe('예약메모 토글', () => {
    test('활성화하면 캘린더 페이지에서 예약메모가 보인다', () => {
      render(<ComponentName />)
      // 테스트 구현
    })

    test('비활성화하면 캘린더 페이지에서 예약메모가 숨겨진다', () => {
      // 테스트 구현
    })
  })

  describe('시간 설정', () => {
    test('시작 시간을 선택하면 종료 시간 옵션이 필터링된다', () => {
      // 테스트 구현
    })
  })
})
```

### 훅 테스트
```typescript
import { renderHook, act } from '@testing-library/react'
import useHookName from './useHookName'
import { mockData } from '@/__mocks__/data/domain/domainName.mocks'

describe('useAuth 훅', () => {
  describe('로그인 상태', () => {
    test('로그인하면 사용자 정보가 저장된다', () => {
      const { result } = renderHook(() => useHookName())
      // 검증
    })

    test('로그아웃하면 사용자 정보가 초기화된다', () => {
      // 검증
    })
  })

  describe('토큰 갱신', () => {
    test('만료 임박 시 자동으로 토큰이 갱신된다', () => {
      // 검증
    })
  })
})
```

### 유틸 함수 테스트
```typescript
import functionName from './functionName'

describe('formatPrice 함수', () => {
  describe('숫자 포맷팅', () => {
    test.each([
      [1000, '1,000원'],
      [1000000, '1,000,000원']
    ])('입력값 %s는 %s로 변환된다', (input, expected) => {
      expect(functionName(input)).toBe(expected)
    })
  })

  describe('예외 처리', () => {
    test('음수를 입력하면 0원이 반환된다', () => {
      // 검증
    })
  })
})
```

## 사용 예시

```bash
/create-unit-test src/components/common/Button/index.tsx
/create-unit-test src/hooks/common/useAuth.ts
/create-unit-test src/utils/common/formatDate.ts
```

## 주의사항
- 테스트 파일명은 반드시 `*.test.{ts,tsx}` 형식 사용
- 한글로 명확한 테스트 설명 작성
- 컴포넌트는 `@/__test__/mock`의 render 사용 (theme 포함)
- 최소 커버리지: 전체 70%, 공통 컴포넌트 90%
- **목데이터 관리 규칙** (UNIT_TESTING_RULES.md 참조):
  - 위치: `src/__mocks__/data/도메인명/파일명.mocks.ts`
  - 네이밍: `mock` 접두사 + 설명적인 이름 (예: `mockEmployeeIncentiveList`)
  - 타입: 실제 API 응답 타입 import하여 사용
  - 특수 케이스: 빈 데이터(`mockEmpty~`), 실제 데이터(`mockRealistic~`)
  - 헬퍼 함수: 반복적인 데이터 생성 시 `createMock~` 함수 제공
