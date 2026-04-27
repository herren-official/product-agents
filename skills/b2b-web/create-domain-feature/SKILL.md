---
name: b2b-web-create-domain-feature
description: "도메인 기반 폴더 구조로 기능 생성 (FOLDER_STRUCTURE_CONVENTIONS.md 기반)"
argument-hint: "[도메인명/기능명]"
allowed-tools: ["read", "write", "bash", "edit", "glob"]
---

# 도메인 기능 자동 생성

대상: {도메인명/기능명}

## 폴더 구조 규칙

**[FOLDER_STRUCTURE_CONVENTIONS.md 참조]**

도메인 기반 폴더 구조를 따릅니다:

```
src/domains/{domain}/
├── components/            # 기능별 하위 컴포넌트
│   ├── {Feature}/         # 기능 단위 폴더
│   │   ├── components/    # 하위 UI 컴포넌트
│   │   ├── hooks/         # 커스텀 훅
│   │   └── ...
│   └── common/            # 공통 컴포넌트
├── contexts/              # Context API
├── hooks/                 # 도메인 공통 훅
└── ...
```

## 처리 단계

1. **입력 파싱**
   - 도메인명과 기능명 분리
   - 예: `statistics/dashboard` → 도메인: statistics, 기능: dashboard

2. **폴더 구조 생성**
   - 도메인 폴더가 없으면 생성
   - 기능 하위 폴더 생성

3. **기본 파일 생성**
   - index.tsx (진입점)
   - ...컨벤션 구조에 맞게 필요한 파일 혹은 폴더 생성

4. **추상화 레벨 적용**
   - 1Depth: 페이지 구조, UI 매칭
   - 2Depth: 분기처리, 이벤트
   - 3Depth: 정적 UI, 스타일

## 생성 템플릿

### index.tsx (1Depth - 진입점)

```tsx
import { Header } from './ui/Header'
import { Content } from './ui/Content'
import { PageLayout } from '@/components/common/Layout'

const DashboardPage = () => {
  return (
    <PageLayout>
      <Header />
      <Content />
    </PageLayout>
  )
}

export default DashboardPage
```

### ui/Header.tsx (2Depth - 기능 단위)

```tsx
import { useFeatureState } from '../hooks/useFeatureState'
import { Title } from '../components/Title'
import { FilterButton } from '../components/FilterButton'

export const Header = () => {
  const { state, actions } = useFeatureState()

  return (
    <HeaderWrapper>
      <Title text={state.title} />
      {state.showFilter && (
        <FilterButton onClick={actions.toggleFilter} />
      )}
    </HeaderWrapper>
  )
}
```

### components/Title.tsx (3Depth - 정적 UI)

```tsx
interface TitleProps {
  text: string
}

export const Title = ({ text }: TitleProps) => {
  return (
    <TitleWrapper>
      <Icon name="dashboard" />
      <TitleText>{text}</TitleText>
    </TitleWrapper>
  )
}
```

### types/index.ts

```tsx
// TYPE_CONVENTIONS.md 참조
// interface: 객체 데이터 모델, Props
// type: 나머지

export interface DashboardState {
  title: string
  showFilter: boolean
  data: DashboardData[]
}

export interface DashboardData {
  id: number
  name: string
  value: number
}

export type FilterType = 'all' | 'today' | 'week' | 'month'
export type SortOrder = 'asc' | 'desc'
```

### hooks/useFeatureState.ts

```tsx
import { useRecoilState } from 'recoil'
import { dashboardAtom } from '../state/dashboardAtom'

export const useFeatureState = () => {
  const [state, setState] = useRecoilState(dashboardAtom)

  const actions = {
    toggleFilter: () => {
      setState(prev => ({ ...prev, showFilter: !prev.showFilter }))
    },
    setTitle: (title: string) => {
      setState(prev => ({ ...prev, title }))
    },
  }

  return { state, actions }
}
```

### state/dashboardAtom.ts

```tsx
import { atom } from 'recoil'
import { DashboardState } from '../types'

export const dashboardAtom = atom<DashboardState>({
  key: 'dashboardState',
  default: {
    title: '대시보드',
    showFilter: false,
    data: [],
  },
})
```

### constants/index.ts

```tsx
export const DASHBOARD_CONSTANTS = {
  DEFAULT_TITLE: '대시보드',
  MAX_ITEMS: 10,
  REFRESH_INTERVAL: 30000,
} as const

export const FILTER_OPTIONS = [
  { value: 'all', label: '전체' },
  { value: 'today', label: '오늘' },
  { value: 'week', label: '이번 주' },
  { value: 'month', label: '이번 달' },
] as const
```

## 사용 예시

```bash
/create-domain-feature statistics/dashboard
/create-domain-feature booking/calendar
/create-domain-feature customer/detail
/create-domain-feature payment/history
```

## 추상화 레벨 요약

| Depth | 책임 | 위치 | 예시 |
|-------|------|------|------|
| 1Depth | 페이지 구조, UI 매칭 | `index.tsx` | `<Header /><Content />` |
| 2Depth | 분기처리, 이벤트 | `ui/` | `{state && <Section />}` |
| 3Depth | 정적 UI, 스타일 | `components/` | `<Icon /><Text />` |

## 주의사항

- 폴더명 PascalCase 사용
- 파일명은 PascalCase (컴포넌트) 또는 camelCase (훅, 유틸)
- 타입 규칙(TYPE_CONVENTIONS.md) 준수
- 3depth를 초과하지 않도록 설계
- 각 depth별 책임 명확히 분리
