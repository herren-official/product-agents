---
name: instaget-front-figma-publishing
description: Figma MCP를 활용하여 디자인 시안을 인스타겟 프론트엔드 컨벤션(styled-components, Next.js Pages Router)에 맞게 UI 퍼블리싱
---

# Figma UI 퍼블리싱 (인스타겟 웹)

Figma 디자인 시안을 분석하여 인스타겟 프론트엔드 프로젝트의 컨벤션에 맞는 React 컴포넌트를 생성합니다.

## 사용법

```bash
/instaget-front-figma-publishing [Figma URL]                    # 기본 퍼블리싱
/instaget-front-figma-publishing [Figma URL] [target-path]      # 생성 경로 지정
/instaget-front-figma-publishing [Figma URL] "추가 요구사항"      # 추가 컨텍스트와 함께
```

## 프로젝트 스택

- **프레임워크**: Next.js (Pages Router)
- **스타일링**: styled-components
- **언어**: TypeScript
- **상태관리**: React Query (tanstack-query)
- **PC/Mobile**: 별도 라우트 (`src/app/pc/`, `src/app/mobile/`)

## 핵심 원칙

> **Figma MCP 출력을 그대로 사용하지 않는다.**
> 반드시 프로젝트의 공통 컴포넌트와 theme 시스템에 맞게 변환한다.

1. **공통 컴포넌트 우선**: Flex, Text, Icon, Spacing, Divider 등 기존 컴포넌트 재사용
2. **Theme 색상 우선**: 하드코딩 색상 대신 theme 객체 사용
3. **styled-components 사용**: Tailwind/CSS Module이 아닌 styled-components로 작성

## 처리 단계

### 1. Figma 디자인 조회

- Figma URL에서 nodeId 추출 (`node-id=12020-9405` → `12020:9405`)
- `get_design_context`로 디자인 정보 조회
- `get_screenshot`로 시각적 참조 이미지 확인

### 2. 디자인 분석 및 컴포넌트 매핑

#### 공통 컴포넌트 확인

| Figma 요소 | 인스타겟 컴포넌트 | import |
|-----------|-----------------|--------|
| Flex 레이아웃 | `<Flex>` | `@app/components/flex` |
| 텍스트 | `<Text.XXL_B>` 등 | `@common/text` |
| 아이콘 | `<Icon icon="..." />` | `@app/components/icon` |
| 여백 | `<Spacing size="20" />` | `@app/components/spacing` |
| 구분선 | `<Divider.vertical />` | `@app/components/Divider` |
| 칩 | `<Chips>` | `@app/components/chips` |
| 링크 | `<Link>` | `next/link` |
| 이미지 | `<Image>` | `next/image` |

#### Text 컴포넌트 매핑

사용 가능한 Text 컴포넌트 (존재하지 않는 것은 사용 금지):

| 사이즈 | Bold | Regular | 기타 |
|--------|------|---------|------|
| XXXXL | `XXXXL_B` | — | — |
| XXXL | `XXXL_B` | `XXXL_R` | — |
| XXL | `XXL_B` | `XXL_R` | — |
| XL | `XL_B` | `XL_R` | — |
| L | `L_B` | `L_R` | — |
| M | `M_B` | `M_R` | — |
| S | `S_B` | `S_R_24`, `S_R_22` | — |
| XS | `XS_B` | `XS_R` | — |
| XXS | `XXS_B` | `XXS_R` | — |
| XXXS | `XXXS_B` | `XXXS_R` | — |

**주의**: `Text.r11` 같이 존재하지 않는 컴포넌트 사용 금지

#### Flex 컴포넌트 규칙

- **gap 속성은 반드시 숫자로 전달** (문자열 사용 금지)
  - ❌ `gap="4px"` (적용 안 됨)
  - ✅ `gap={4}`

### 3. 퍼블리싱 계획 수립 및 확인

- 생성할 컴포넌트 구조, 파일 위치, 재사용 컴포넌트 목록 정리
- **계획 승인은 반드시 `AskUserQuestion` Form으로 요청한다**

```jsonc
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

#### 4-1. 색상 변환 (Theme 우선)

styled-components에서는 **theme 객체 사용**:

```tsx
// ❌ 하드코딩 금지
color: #fff;
background: #000;
color: var(--color-mono70);

// ✅ theme 객체 사용
color: ${({ theme }) => theme.color.gray[800]};
color: ${({ theme }) => theme.color.mono70};
background: ${({ theme }) => theme.color.primary};
```

#### 4-2. 레이아웃 변환

- Figma의 flex 레이아웃 → `<Flex>` 컴포넌트 또는 styled-components flex 사용
- 고정 너비/높이 → 반응형으로 변환

#### 4-3. 구조적 변환

- `data-name`, `data-node-id` 속성 **모두 제거**
- Figma 레이어 구조를 그대로 복사하지 않음 → 의미 있는 컴포넌트 구조로 재구성
- localhost 이미지 URL → placeholder 또는 아이콘 컴포넌트 매핑

### 5. 컴포넌트 구조 패턴

#### 파일 구조

```
ComponentName/
├── ComponentName.tsx           # 메인 컴포넌트
├── ComponentName.styles.ts     # styled-components 스타일
└── index.ts                    # export (선택)
```

#### PC/Mobile 분리

인스타겟은 PC와 모바일이 별도 라우트로 분리되어 있다:

```
src/app/pc/main/components/MainServiceList/
src/app/mobile/main/components/MainServiceList/
```

- Figma 시안이 PC/Mobile 모두 있으면 각각 별도 컴포넌트로 생성
- 공통 로직은 custom hook으로 분리 가능

#### 스타일 작성 패턴

```tsx
// ComponentName.styles.ts
import styled from 'styled-components'
import Flex from '@app/components/flex'

export const Container = styled.div`
  padding: 40px 0;
  background: ${({ theme }) => theme.color.white};
`

export const Wrapper = styled(Flex)`
  max-width: 1200px;
  margin: 0 auto;
  flex-direction: column;
`
```

### 6. 검증

```bash
# 타입 체크
yarn tsc --noEmit

# 린트 체크
yarn lint
```

- 에러 발생 시 수정 후 재검증

### 7. 결과 보고

- 생성/수정된 파일 목록
- 재사용한 공통 컴포넌트 목록
- 이후 필요한 작업 (비즈니스 로직 연동이 필요한 부분 등)

## 변환 예시

```tsx
// ❌ Figma MCP 원본 그대로 사용
<div style={{ display: 'flex', gap: '8px', color: '#282828' }}>
  <span style={{ fontSize: '14px', fontWeight: 600 }}>서비스</span>
</div>

// ✅ 인스타겟 컨벤션 적용
<Flex gap={8} alignItems="center">
  <Text.S_B>서비스</Text.S_B>
</Flex>
```

## 주의사항

- **비즈니스 로직은 구현하지 않음** — API 연동, 라우팅 등은 콜백 props로 자리만 마련
- **styled-components 사용** — Tailwind, CSS Module 사용 금지
- **Flex 컴포넌트의 gap은 반드시 숫자** — `gap={8}` (O) / `gap="8px"` (X)
- **Text 컴포넌트는 실제 존재하는 것만 사용** — 없는 컴포넌트 사용 시 에러 발생
- **theme 색상 사용** — 하드코딩 색상값 금지
- 기존 공통 컴포넌트가 있으면 반드시 재사용 (중복 생성 금지)
- `any` 타입 사용 금지
- 패키지 매니저는 yarn 사용
