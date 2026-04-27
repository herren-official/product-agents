---
name: figma-publishing
description: Figma MCP를 활용하여 디자인 시안을 프로젝트 컨벤션에 맞게 UI 퍼블리싱
---

# Figma UI 퍼블리싱

Figma 디자인 시안을 분석하여 프로젝트 컨벤션에 맞는 React 컴포넌트를 생성합니다.

## 사용법

```bash
/figma-publishing [Figma URL]                          # 기본 퍼블리싱
/figma-publishing [Figma URL] [target-path]            # 생성 경로 지정
/figma-publishing [Figma URL] "추가 요구사항"            # 추가 컨텍스트와 함께
```

## 참조

- [디자인 파운데이션](../../../.docs/conventions/design-foundation.md) - 타이포그래피, 색상, 반경, 버튼 높이 등 전체 디자인 토큰
- [스타일링 컨벤션](../../../.docs/conventions/styling-convention.md)
- [컴포넌트 개발 가이드](../../../.docs/conventions/component-development.md)
- [프로젝트 아키텍처](../../../.docs/conventions/project-architecture.md)
- [타입스크립트 컨벤션](../../../.docs/conventions/typescript-convention.md)

## 핵심 원칙

> **Figma MCP 출력을 그대로 사용하지 않는다.**
> 반드시 프로젝트의 디자인 토큰과 공통 컴포넌트를 최대한 활용하여 변환한다.

1. **디자인 토큰 우선**: Figma의 raw 값(`font-[...]`, `text-[Npx]`, `var(--color/...)`)을 절대 그대로 쓰지 않고, 프로젝트 토큰(`text-h2`, `text-gray-700`, `rounded-medium` 등)으로 변환한다
2. **공통 컴포넌트 우선**: Figma 요소를 직접 HTML로 구현하기 전에, 프로젝트의 기존 공통 컴포넌트(`Typography`, `Button`, `Chip`, `Divider`, `HeaderBar`, `ImageWithPlaceholder` 등)로 대체 가능한지 먼저 판단한다
3. **아이콘 컴포넌트 우선**: SVG를 인라인으로 넣지 않고, `common/components/icons/`의 기존 아이콘 컴포넌트를 매핑한다
4. **순수 UI 로직은 포함, 비즈니스 로직은 콜백으로 분리**: 아래 기준을 따른다

### 로직 범위 기준

#### 퍼블리싱에 포함하는 것 (순수 UI 로직)

UI가 정상 작동하려면 필요한 인터랙션 로직은 퍼블리싱 단계에서 구현한다:

- **선택 상태 관리**: 체크박스/라디오 토글, 탭 전환, 칩 선택/해제
- **표시 상태 관리**: 아코디언 열기/닫기, 모달/바텀시트 open/close, 더보기/접기
- **폼 입력 처리**: 텍스트 입력, 선택 값 변경 등 로컬 상태
- **UI 피드백**: 로딩 상태 표시, 스켈레톤 전환, 에러 상태 UI

```tsx
// 예: 순수 UI 로직 — 퍼블리싱에 포함
const [isOpen, setIsOpen] = useState(false);
const [selectedChips, setSelectedChips] = useState<string[]>([]);
```

#### 퍼블리싱에 포함하지 않는 것 (비즈니스 로직)

API 호출, 데이터 가공, 비즈니스 규칙 등은 **콜백 props로 자리만 마련**한다:

- API 호출 (데이터 조회, 생성, 수정, 삭제)
- 데이터 유효성 검증 (비즈니스 규칙 기반)
- 라우팅/네비게이션 결정
- 결제, 인증, 권한 관련 처리

```tsx
// 예: 비즈니스 로직은 콜백 props로 분리
type CokDetailInfoProps = {
  // 데이터 props
  name: string;
  price: number;
  memberPrice?: number;
  // 비즈니스 로직 콜백 — 자리만 마련
  onLikeToggle?: () => void;
  onBookingSelect?: (bookingId: string) => void;
  onShare?: () => void;
};
```

#### Figma에서 비즈니스 정책이 보이는 경우

Figma 시안에 비즈니스 흐름(예약 플로우, 결제 단계 등)이 포함되어 있으면:

1. **UI 구조는 시안대로 구현**하되
2. **비즈니스 동작은 콜백 props로 노출** (예: `onSubmit`, `onConfirm`, `onCancel`)
3. 퍼블리싱 계획에 **"이후 비즈니스 로직 연동 필요"** 항목을 명시하여, 후속 작업 범위를 알 수 있게 한다

## 처리 단계

### 1. Figma 디자인 조회

- Figma URL에서 nodeId 추출 (예: `node-id=12020-9405` → `12020:9405`)
- `get_design_context`로 디자인 정보 조회
  - `artifactType`: 대상에 따라 `COMPONENT_WITHIN_A_WEB_PAGE_OR_APP_SCREEN` 또는 `WEB_PAGE_OR_APP_SCREEN`
  - `clientFrameworks`: `react,nextjs`
  - `clientLanguages`: `typescript,css`
- `get_screenshot`로 시각적 참조 이미지 확인
- **섹션 노드인 경우**: 메타데이터만 반환되므로 하위 노드 ID를 추출하여 개별 조회

#### 시안 범위 판단

Figma 노드의 유형에 따라 퍼블리싱 범위와 접근 방식이 달라진다:

| Figma 노드 유형 | 판단 기준 | 접근 방식 |
|---|---|---|
| **전체 페이지** | 여러 섹션 + 헤더 + 바텀 구조 | 페이지 단위로 폴더 생성, 섹션별 하위 컴포넌트 분리 |
| **단일 컴포넌트** | 카드, 모달, 리스트 아이템 등 독립 요소 | 단일 컴포넌트 파일 생성 |
| **상태 변형 세트** | 같은 컴포넌트의 기본/최대/최소 등 여러 변형 | **하나의 컴포넌트**로 생성, 변형은 props로 제어 |

- **상태 변형 판단 기준**: 같은 `data-name`을 공유하거나, 레이아웃 구조가 동일하고 콘텐츠 양/표시 여부만 다른 경우 → 같은 컴포넌트의 변형으로 판단
- 변형 세트인 경우, 가장 많은 요소를 가진 변형(최대 정보)을 기본 구조로 삼고, 나머지는 조건부 렌더링(props)으로 처리
- **변형 간 스타일 차이 검증 (필수)**: 상태 변형 세트로 판단된 경우, **각 변형 노드를 `get_design_context`로 개별 조회**하여 CSS 값 차이를 정확히 파악한다. 기본 변형의 코드만으로 나머지 변형의 스타일을 추측하지 않는다. 특히 다음 항목은 변형 간 차이가 빈번하므로 반드시 비교한다:
  - **색상**: 같은 텍스트 요소가 변형에 따라 다른 색상을 사용하는 경우 (예: 날짜 텍스트가 예정 상태에서는 `brand-300`, 완료 상태에서는 `gray-400`)
  - **표시/숨김**: 특정 요소가 변형에 따라 존재하거나 사라지는 경우
  - **배경색/테두리**: 상태에 따라 컨테이너 스타일이 달라지는 경우

### 2. 디자인 분석

- **스타일 메타데이터 확인**: `get_design_context` 응답에 포함된 스타일 정보 활용
  - 예: `Heading 2: Font(size: 18, weight: 600, lineHeight: 24)`
- **조건부 렌더링 식별**: Figma에서 boolean prop으로 표현된 요소 파악
- **기존 공통 컴포넌트 재사용 판단**: 아래 목록에서 재사용 가능한 컴포넌트를 우선 탐색
  - `Button` — variant(`primary`/`secondary`/`line`/`error`), size(`XL`/`L`/`M`/`S`)
  - `Typography` — variant로 타이포 토큰 적용 (예: `<Typography variant="h2">`)
  - `Chip` — variant(`tab`/`time`/`filter`), selected 상태
  - `Divider` — 섹션 구분선
  - `HeaderBar` — 고정 상단 헤더 (title, leftActions, rightActions)
  - `ImageWithPlaceholder` — 외부/API 이미지 (에러 핸들링, placeholder 포함)
  - `Skeleton` — 로딩 상태 placeholder
  - `CheckBox`, `Radio` — 선택 UI
  - `IconButton` — 아이콘 버튼
  - `BottomSheet`, `SlideSheet`, `DefaultModal`, `FullModal` — 오버레이 UI
- **아이콘 컴포넌트 확인**: `common/components/icons/`에서 기존 아이콘 탐색
  - 주요 아이콘: `HeartIcon`, `ArrowRightIcon`, `ArrowLeftIcon`, `BackIcon`, `CloseIcon`, `ShareIcon`, `SearchIcon`, `InfoIcon`, `MapIcon`, `StarIcon`, `CheckIcon`, `PlusIcon` 등 54종
  - 아이콘은 `IconProps` (`className`, `width`, `height`) 기반이며, `fill-current` + `text-*` 클래스로 색상 제어
  - 예: `<HeartIcon width={12} height={12} className="text-gray-500" />`
  - **기존 아이콘에 없는 경우**: `AskUserQuestion`으로 사용자에게 확인 요청

    ```jsonc
    {
      "questions": [{
        "question": "Figma에 사용된 아이콘 중 기존 프로젝트에 없는 아이콘이 있습니다. 어떻게 처리할까요?",
        "header": "아이콘 처리",
        "options": [
          { "label": "신규 생성", "description": "IconProps 패턴에 맞춰 새 아이콘 컴포넌트를 생성합니다" },
          { "label": "기존 아이콘 대체", "description": "가장 유사한 기존 아이콘으로 대체합니다" },
          { "label": "placeholder", "description": "빈 아이콘 자리만 만들어두고 나중에 추가합니다" }
        ],
        "multiSelect": false
      }]
    }
    ```

### 3. 퍼블리싱 계획 수립 및 확인

- 생성할 컴포넌트 구조, 파일 위치, 재사용 컴포넌트 목록을 정리
- **신규 생성 vs 기존 수정 판단**: target-path에 이미 컴포넌트가 존재하는지 확인
  - **기존 컴포넌트가 있는 경우**: 기존 코드를 읽고, Figma 시안과 차이점을 분석하여 **수정 범위를 먼저 정리**한 후 계획에 포함
  - **신규 생성인 경우**: 컴포넌트 구조와 파일 목록을 계획에 포함
- **계획 승인은 반드시 `AskUserQuestion` Form으로 요청한다**:

```jsonc
// AskUserQuestion 호출 템플릿
{
  "questions": [{
    "question": "위 퍼블리싱 계획대로 진행할까요?",
    "header": "퍼블리싱 승인",
    "options": [
      { "label": "승인", "description": "위 계획대로 컴포넌트를 생성합니다" },
      { "label": "구조 변경", "description": "컴포넌트 분리/합침 등 구조를 변경합니다" },
      { "label": "경로 변경", "description": "파일 생성 위치를 변경합니다" }
    ],
    "multiSelect": false
  }]
}
```

### 4. 토큰 변환 및 코드 생성

Figma MCP 출력을 프로젝트 컨벤션에 맞게 변환합니다.

#### 4-1. 타이포그래피 변환

Figma 스타일 메타데이터의 이름을 프로젝트 타이포 클래스로 매핑합니다:

| Figma 스타일명 | 프로젝트 클래스 |
|---|---|
| `Heading 1` | `text-h1` |
| `Heading 2` | `text-h2` |
| `Heading 3` | `text-h3` |
| `Heading 4` | `text-h4` |
| `Body 1` | `text-body1` |
| `Body 1 Bold` | `text-body1-b` |
| `Body 2` | `text-body2` |
| `Body 3` | `text-body3` |
| `Body 4` | `text-body4` |
| `Accent` | `text-accent` |
| `Price` | `text-price` |
| `Paragraph` | `text-paragraph` |
| `Detail 1` | `text-detail1` |
| `Detail 2` | `text-detail2` |

- 매핑 시 Figma 코드의 `font-[...] text-[Npx] leading-[Npx]`를 제거하고 위 클래스로 대체

#### 4-2. 색상 변환

Figma CSS 변수에서 프로젝트 색상 토큰을 추출합니다:

```
var(--color/gray/700, #282828)  → text-gray-700 또는 bg-gray-700
var(--color/brand/300, #6d5aff) → text-brand-300 또는 bg-brand-300
var(--color/gray/50, #f9f9fb)   → bg-gray-50
```

- 패턴: `var(--color/[color]/[intensity])` → `[속성]-[color]-[intensity]`
- `var(--gray/700)` 처럼 `color/` 접두사가 없는 경우도 동일하게 처리

#### 4-3. 간격 및 크기 변환

임의 값(arbitrary value)을 표준 Tailwind 값으로 변환합니다:

| px 값 | Tailwind 클래스 |
|---|---|
| `4px` | `1` |
| `8px` | `2` |
| `12px` | `3` |
| `16px` | `4` |
| `20px` | `5` |
| `24px` | `6` |
| `32px` | `8` |

- 예: `gap-[20px]` → `gap-5`, `px-[24px]` → `px-6`
- 표준 Tailwind 값에 없는 경우 임의 값 유지: `gap-[18px]`

#### 4-4. 테두리 반경 변환

| px 값 | 프로젝트 토큰 |
|---|---|
| `4px` | `rounded-small` |
| `8px` | `rounded-medium` |
| `12px` | `rounded-large` |
| `20px` | `rounded-xlarge` |

- `rounded-[70px]` 등 토큰에 없는 값은 `rounded-full` 또는 임의 값 유지

#### 4-5. 모바일 레이아웃 변환

이 프로젝트는 **모바일 웹 앱** (max-width: 480px)입니다. Figma 시안의 고정 너비를 그대로 사용하지 않습니다:

| Figma 값 | 변환 결과 | 이유 |
|---|---|---|
| `w-[360px]` (루트 컨테이너) | `w-full` | 모바일 전체 너비 사용 |
| `w-[244px]` (텍스트 영역) | `w-full` 또는 `flex-1` | 고정 너비 → 유동 너비 |
| `size-full` (루트) | `w-full` | 높이는 콘텐츠에 맞게 자동 |

- 루트 컨테이너의 고정 너비(`w-[360px]`, `w-[375px]`) → **반드시 `w-full`로 변환**
- 내부 요소의 고정 너비는 맥락에 따라 판단: 아이콘/버튼 등 의도적 고정 크기는 유지, 텍스트/콘텐츠 영역은 유동 너비로 변환

#### 4-6. 구조적 변환

- `data-name`, `data-node-id` 속성 **모두 제거**
- `className` 문자열 → `cn()` 래핑
- `propValue`, `propValue1` 등 → **의미 있는 prop 이름**으로 변경 (예: `hasMemberPrice`, `hasKeywords`)
- localhost 이미지 URL → 프로젝트 아이콘 컴포넌트 매핑 또는 placeholder 처리
- 불필요한 래핑 `<div>` 제거 (Figma 레이어 구조 그대로가 아닌, 의미 있는 구조로 정리)

### 5. 컨벤션 적용

생성된 코드가 프로젝트 컨벤션을 준수하는지 확인합니다:

#### 5-1. Typography 사용 규칙

두 가지 방식 모두 허용되며, 맥락에 따라 선택한다:

- **`<Typography variant="...">`**: 의미 있는 텍스트 블록 (제목, 본문, 가격 등)
  ```tsx
  <Typography variant="h2">{title}</Typography>
  <Typography variant="body2" className="text-gray-500">{subtitle}</Typography>
  ```
- **raw `className="text-h2"`**: 네이티브 HTML 요소에 직접 적용 (간단한 텍스트, `<span>` 내부 등)
  ```tsx
  <span className="text-detail1 text-brand-300">샵 회원가</span>
  ```

#### 5-2. cn() 사용 패턴

- `className` prop은 반드시 `cn()`의 **마지막 인자**로 전달 (외부 오버라이드 보장)
  ```tsx
  const containerClassName = cn(
    "flex flex-col gap-5",
    isSelected ? "bg-gray-700 text-gray-0" : "bg-gray-0 text-gray-400",
    className  // ← 항상 마지막
  );
  ```
- 조건부 클래스는 `&&` 또는 삼항 연산자 사용
- 동적 클래스(variant/size 등)는 반드시 **object map 패턴** 사용 (템플릿 리터럴 금지)
  ```tsx
  // WRONG: `text-${color}-500`
  // RIGHT:
  const COLOR_MAP = { red: "text-red-500", blue: "text-blue-500" } as const;
  ```

#### 5-3. 변형이 있는 컴포넌트 스타일 패턴

variant/size가 있는 컴포넌트는 **스타일 상수 패턴**을 따른다:

```tsx
const BASE_STYLES = "flex items-center justify-center";

const VARIANT_STYLES_MAP = {
  primary: "bg-brand-300 text-gray-0",
  secondary: "bg-gray-700 text-gray-0",
  line: "border border-gray-200 bg-gray-0 text-gray-700",
} as const;

type Variant = keyof typeof VARIANT_STYLES_MAP;
```

#### 5-4. 컴포넌트 구조 패턴

- **PascalCase 파일명**, Props 타입 정의 (`type`), `className?: string` prop 포함
- **페이지 전용 컴포넌트**: `(pages)/[page]/components/` 하위에 생성
  ```
  CokDetailInfo/
  ├── index.tsx              # 메인 컴포넌트 (필요시 "use client")
  ├── CokDetailInfoSkeleton.tsx  # 로딩 상태 (선택)
  └── __tests__/             # 테스트 (선택)
  ```
- **공통 컴포넌트 (2개 이상 페이지에서 사용)**: `common/components/common/` 에 생성
- `"use client"` 지시어: 인터랙션(onClick, useState 등)이 있을 때만 추가
- 인터랙션 없는 순수 렌더링 컴포넌트는 `"use client"` 생략

#### 5-5. Props 설계 규칙

- `type` 키워드로 정의 (`interface` 금지)
- HTML 속성 확장 시 `&` 사용: `type Props = HTMLAttributes<HTMLDivElement> & { ... }`
- `children`은 명시적 정의 (`PropsWithChildren` 사용 금지)
- 표준 prop 이름 준수: `variant`, `size`, `disabled`, `loading`, `active`, `className`
- **import**: 절대 경로 (`@/app/common/...`), 같은 폴더는 상대 경로

### 6. 검증

- `tsc --noEmit` 으로 타입 에러 확인
- `yarn lint` 으로 린트 에러 확인
- 에러 발생 시 수정 후 재검증

### 7. 스토리북 작성

퍼블리싱된 컴포넌트에 대한 Storybook 스토리를 작성합니다.

#### 7-1. 스토리 파일 위치

```
src/stories/
├── common/components/   # 공통 컴포넌트 스토리 (기존)
└── pages/               # 페이지 전용 컴포넌트 스토리 (신규)
    └── [domain]/
        └── [ComponentName].stories.tsx
```

- **공통 컴포넌트**: `src/stories/common/components/` 하위
- **페이지 전용 컴포넌트**: `src/stories/pages/[domain]/` 하위

#### 7-2. 스토리 작성 패턴

```tsx
import { fn } from "storybook/test";
import { Meta, StoryObj } from "@storybook/nextjs";
import CokDetailInfo from "@/app/(pages)/cok/[id]/components/CokDetail/CokDetailInfo";

const meta = {
  title: "Pages/Cok/CokDetailInfo",
  component: CokDetailInfo,
  tags: ["autodocs"],
  parameters: {
    layout: "centered",
  },
  argTypes: {
    name: { control: "text", description: "시술명" },
    price: { control: "number", description: "가격" },
    // ...
  },
  args: {
    name: "스마일 포인트 웜톤 네일",
    price: 90000,
    memberPrice: 80000,
    duration: "1시간 30분",
    onLikeToggle: fn(),
    onShare: fn(),
  },
} satisfies Meta<typeof CokDetailInfo>;

export default meta;
type Story = StoryObj<typeof meta>;
```

#### 7-3. 스토리 케이스 기준

Figma 시안의 변형 세트를 기반으로 스토리 케이스를 작성합니다:

```tsx
// 기본 상태
export const Default: Story = {
  name: "기본",
};

// 최대 정보 (모든 선택적 요소 표시, 긴 텍스트)
export const MaxContent: Story = {
  name: "최대 정보",
  args: {
    name: "최대 2줄 콕예약 이름이 길어지면 이렇게 적용해주세요. 참고 바랍니다.",
    keywords: ["#키워드가길어져서20자를넘어가면이렇게됨", "#키워드2", "#키워드3"],
    likeCount: 999,
  },
};

// 최소 정보 (선택적 요소 미표시)
export const MinContent: Story = {
  name: "최소 정보",
  args: {
    memberPrice: undefined,
    keywords: [],
    description: undefined,
  },
};
```

#### 7-4. 한글 표기 규칙

스토리북에 표시되는 모든 텍스트는 한글로 작성한다:

- **export 이름**: JavaScript 식별자이므로 영어 PascalCase 유지 (`export const Default`)
- **`name` 속성**: 반드시 한글로 지정하여 스토리북 UI에 한글로 표시
- **`description`**: argTypes, 파라미터 설명 등 모두 한글

```tsx
// export 이름은 영어, name은 한글
export const Confirmed: Story = {
  name: "예약 확정",
  args: { status: "confirmed" },
};

export const WithoutStaffName: Story = {
  name: "담당자 없음",
  args: { staffName: undefined },
};

export const AllStatuses: Story = {
  name: "전체 상태 비교",
  render: () => ( ... ),
};
```

#### 7-5. 스토리 작성 규칙

- **mock 데이터**: Figma 시안의 텍스트를 그대로 사용하여 시각 비교 가능하게 한다
- **콜백 props**: `fn()`으로 처리하여 Actions 패널에서 확인 가능하게 한다
- **이미지 URL**: `mockImage` 유틸 사용 (`@/__mocks__/mockApiUtils/mockImageUrls`)
- **Container 컴포넌트는 스토리 작성 대상에서 제외** — View(순수 UI) 컴포넌트만 작성
- 비즈니스 로직이 혼재된 컴포넌트는 스토리 작성을 건너뛰고, 결과 보고에서 분리 제안

#### 7-6. 스토리 title 네이밍 규칙

| 컴포넌트 유형 | title 패턴 | 예시 |
|---|---|---|
| 공통 UI | `Components/UI/{Name}` | `Components/UI/Button` |
| 공통 컴포넌트 | `Components/Common/{Name}` | `Components/Common/HeaderBar` |
| 페이지 전용 | `Pages/{Domain}/{Name}` | `Pages/Cok/CokDetailInfo` |

### 8. 검증

- `tsc --noEmit` 으로 타입 에러 확인
- `yarn lint` 으로 린트 에러 확인
- 에러 발생 시 수정 후 재검증

### 9. 결과 보고

- 생성/수정된 파일 목록 (컴포넌트 + 스토리)
- 재사용한 공통 컴포넌트 목록
- 적용된 디자인 토큰 요약
- 이후 필요한 작업 (비즈니스 로직 연동이 필요한 콜백 props 목록 등)

## 변환 예시

아래는 Figma MCP 출력을 프로젝트 코드로 변환하는 실제 예시입니다:

```tsx
// ❌ Figma MCP 원본 출력
<div className="bg-[var(--color\/gray\/0,white)] flex flex-col gap-[20px] px-[20px] py-[24px]"
  data-name="콕예약 상세" data-node-id="12020:11272">
  <p className="font-['Wanted_Sans:SemiBold',sans-serif] leading-[24px] text-[18px]
    text-[color:var(--color\/gray\/700,#282828)]">
    스마일 포인트 웜톤 네일
  </p>
  <p className="font-['Wanted_Sans:Bold',sans-serif] leading-[22px] text-[16px]
    text-[color:var(--color\/brand\/300,#6d5aff)]">
    80,000원
  </p>
</div>

// ✅ 프로젝트 컨벤션 적용 후
<div className={cn("flex flex-col gap-5 bg-gray-0 px-5 py-6", className)}>
  <Typography variant="h2">{name}</Typography>
  <Typography className="text-price text-brand-300">
    {formatPrice(memberPrice)}
  </Typography>
</div>
```

## 주의사항

- **비즈니스 로직은 구현하지 않음** — API 연동, 데이터 검증, 라우팅 등은 콜백 props로 자리만 마련 (순수 UI 로직은 포함)
- **데이터는 props로 받을 자리만 마련** — 하드코딩된 Figma 텍스트를 props로 대체 (예: "스마일 포인트 웜톤 네일" → `{name}`)
- Figma의 레이어 구조를 그대로 복사하지 않음 — 의미 있는 컴포넌트 구조로 재구성
- 기존 공통 컴포넌트가 있으면 반드시 재사용 (중복 생성 금지)
- Figma에서 반복되는 요소는 별도 컴포넌트로 분리 여부를 판단하여 제안
- `any` 타입 사용 금지
- 빈 `alt` 속성은 장식 이미지에만 허용, 의미 있는 이미지에는 적절한 alt 텍스트 작성
- Figma의 `font-[...]` 직접 지정 클래스를 절대 그대로 사용하지 않음 — 반드시 타이포 토큰으로 변환
- `var(--color/...)` CSS 변수를 그대로 사용하지 않음 — 반드시 프로젝트 색상 토큰으로 변환
- SVG를 인라인으로 넣지 않음 — 기존 아이콘 컴포넌트 매핑 또는 신규 아이콘 컴포넌트 생성
