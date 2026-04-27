---
name: b2b-web-create-common-component
---

# 공통 컴포넌트 개발 가이드

## 트리거
사용자가 "공통 컴포넌트 만들어줘", "shared component", "common component 개발" 등을 요청할 때 실행됩니다.

## 워크플로우

### Phase 1: 사전 조사

#### 1-1. 피그마 디자인 분석

Figma MCP 도구를 사용하여 디자인을 체계적으로 분석합니다.

1. **전체 구조 파악** — 스크린샷으로 컴포넌트 트리 구조 이해
   - `get_screenshot` → 전체 레이아웃, 컴포넌트 배치 확인
   - `get_design_context` → 컴포넌트 계층, 속성, 스타일 정보 추출

2. **변형(Variant) 수집** — 디자인에 정의된 모든 상태 목록화
   - variant (info, warning, error, success 등)
   - size (small, medium, large 등)
   - state (default, hover, active, disabled, focus 등)
   - 각 변형의 시각적 차이점 기록

3. **디자인 토큰 추출** — 색상, 간격, 타이포 등
   - `get_variable_defs` → Figma 변수/토큰 정의 확인
   - 색상 값, border-radius, padding, font-size 등 수집

4. **엣지 케이스 디자인 확인**
   - 빈 상태, 에러 상태, 긴 텍스트 overflow 처리
   - 모바일/PC 반응형 차이 (있다면 PC는 모바일 뒤에 인터리브)

#### 1-2. 기존 코드와 정합성 검증

피그마 분석 결과를 기존 코드베이스와 대조합니다.

1. **기존 공통 컴포넌트 확인** — 중복 개발 방지
   - `src/components/common/` 디렉토리에서 유사 컴포넌트 검색
   - `.docs/conventions/COMMON_COMPONENTS_HOOKS_GUIDE.md` 참조
   - 기존 컴포넌트를 확장할 수 있는지 먼저 판단

2. **Variant 매핑** — 피그마 variant ↔ 기존 코드 variant 대조
   - 동일 개념인데 이름만 다른 경우 → 피그마 기준으로 통일
   - 피그마에만 있는 variant → 새로 추가
   - 코드에만 있는 variant → 유지 여부 사용자에게 확인

3. **디자인 토큰 매핑** — 피그마 토큰 ↔ 코드 theme 변수 대조
   - 이미 theme에 정의된 값 → 그대로 사용
   - 피그마에만 있는 값 → theme에 추가 필요 여부 판단
   - 불일치 시 → **피그마 기준으로 코드 수정** (피그마 정책 > 실행된 웹)

4. **사용처 분석** — 최소 2개 이상의 도메인에서 사용되어야 공통 컴포넌트 자격
   - 1개 도메인에서만 사용 → `src/components/[도메인]/common/`에 배치
   - 2개 이상 도메인에서 사용 → `src/components/common/`에 배치

#### 1-3. 사용자에게 보고

조사 결과를 다음 형식으로 공유하고 진행 방향 확인:

```
## 사전 조사 결과

### 피그마 분석
- 컴포넌트 구조: [계층 설명]
- Variants: [목록]
- 디자인 토큰: [색상, 간격, 타이포 등]
- 엣지 케이스: [빈 상태, 에러 등]

### 기존 코드 정합성
- 유사 컴포넌트: [있으면 경로와 차이점]
- 재사용 가능 부분: [기존 공통 컴포넌트 활용 가능 여부]
- 토큰 매핑: [일치/불일치 항목]
- 불일치 사항: [피그마 기준으로 수정 필요한 부분]

### 진행 방향 제안
- [신규 생성 / 기존 확장 / 기존 수정]
```

---

### Phase 2: 인터페이스 설계 (가장 중요)

컴포넌트 코드를 작성하기 **전에** Props 인터페이스를 먼저 설계하고 사용자에게 확인받습니다.

#### 2.1 Props 설계 원칙

```typescript
// 1. Props는 최소한으로, 하지만 충분히 유연하게
// 2. 네이밍은 직관적으로 — 문서 없이도 사용법을 추측 가능해야 함
// 3. 도메인 용어가 Props에 등장하면 경고 신호 (비즈니스 로직 침투)

type SectionMessageProps = {
  // 필수 Props — 컴포넌트 존재 이유
  children: React.ReactNode

  // 변형 Props — 열거형으로 시각적 변형 제어
  variant?: 'info' | 'warning' | 'error' | 'success'
  size?: 'small' | 'medium' | 'large'

  // 선택 Props — 기본값이 있어야 함
  closable?: boolean
  icon?: React.ReactNode
}
```

#### 2.2 체크리스트

- [ ] Props에 도메인 용어가 없는가? (예: `paymentType` 금지)
- [ ] 필수 Props가 3개 이하인가?
- [ ] 모든 선택 Props에 기본값이 있는가?
- [ ] `children`으로 확장 가능한가? (합성 > 설정)
- [ ] 네이티브 HTML 속성 전달을 지원하는가? (`...rest` 패턴)
- [ ] `ref` forwarding이 필요한가?

---

### Phase 3: 컴포넌트 구현

#### 3.1 파일 구조

```
src/components/common/[ComponentName]/
├── index.tsx              # 메인 컴포넌트 + export
├── [ComponentName].styles.ts   # styled-components
├── [ComponentName].stories.tsx # Storybook 스토리
└── [ComponentName].test.tsx    # 테스트 (필요 시)
```

#### 3.2 구현 원칙

**합성(Composition) 우선**
```typescript
// 좋은 예 — Compound Component
<Select>
  <Select.Trigger>{selected}</Select.Trigger>
  <Select.Options>
    <Select.Option value="a">옵션 A</Select.Option>
  </Select.Options>
</Select>

// 피해야 할 예 — Props 폭발
<Select
  options={[{ label: '옵션 A', value: 'a' }]}
  renderOption={(opt) => <span>{opt.label}</span>}
  renderTrigger={(selected) => <span>{selected}</span>}
  onSelect={handleSelect}
/>
```

**HTML 시맨틱 존중**
```typescript
// 네이티브 HTML 속성 전달
type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary'
  size?: 'small' | 'medium' | 'large'
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'medium', children, ...rest }, ref) => {
    return (
      <StyledButton ref={ref} $variant={variant} $size={size} {...rest}>
        {children}
      </StyledButton>
    )
  }
)
```

**예측 가능성 — 제어/비제어 지원**
```typescript
// 제어 컴포넌트 (외부에서 상태 관리)
<Toggle checked={isOn} onChange={setIsOn} />

// 비제어 컴포넌트 (내부에서 상태 관리)
<Toggle defaultChecked={true} onChange={handleChange} />
```

#### 3.3 styled-components 규칙

```typescript
// transient props ($prefix) 사용 — DOM에 전달 방지
const StyledButton = styled.button<{ $variant: string; $size: string }>`
  // 디자인 토큰 사용
  padding: ${({ $size }) => PADDING_MAP[$size]};
  background-color: ${({ $variant }) => COLOR_MAP[$variant]};
`

// 단, 간단한 속성 1-2개만 다르면 Flex 등 공통 컴포넌트 직접 사용
// styled-component 분리 금지 (feedback: 공통 컴포넌트 우선 사용)
```

#### 3.4 컴포넌트 구조 (REACT_CONVENTIONS.md 준수)

```typescript
const Component = ({ prop1, prop2 = 'default', children, ...rest }: ComponentProps) => {
  // 1. State 선언
  // 2. Context/Recoil
  // 3. 계산된 값 (useMemo)
  // 4. Effect
  // 5. Handler 함수
  // 6. 조기 반환
  // 7. 메인 렌더링
  return <StyledWrapper {...rest}>{children}</StyledWrapper>
}
```

---

### Phase 4: Storybook 작성

`STORYBOOK_RULES.md` 규칙을 따릅니다.

#### 4.1 필수 스토리

```typescript
import { ComponentStory, Meta } from '@storybook/react'
import Component from '@/components/common/Component'

export default {
  title: 'Components/common/Component',
  component: Component,
  argTypes: {
    variant: {
      options: ['info', 'warning', 'error', 'success'],
      control: { type: 'radio' },
      defaultValue: 'info',
    },
    size: {
      options: ['small', 'medium', 'large'],
      control: { type: 'radio' },
      defaultValue: 'medium',
    },
  },
} as Meta<typeof Component>

const Template: ComponentStory<typeof Component> = (args) => (
  <Component {...args}>내용</Component>
)

// 1. Default — 기본 상태 (필수)
export const Default = Template.bind({})
Default.args = {}

// 2. 각 Variant별 스토리
export const Info = Template.bind({})
Info.args = { variant: 'info' }

export const Warning = Template.bind({})
Warning.args = { variant: 'warning' }

// 3. 엣지 케이스
export const LongContent = Template.bind({})
LongContent.args = { children: '매우 긴 텍스트가 들어가는 경우...' }

export const Empty = Template.bind({})
Empty.args = { children: '' }

export const Disabled = Template.bind({})
Disabled.args = { disabled: true }
```

#### 4.2 엣지 케이스 체크리스트

- [ ] 빈 값 (empty string, null, undefined)
- [ ] 긴 텍스트 (overflow 처리)
- [ ] 비활성 상태 (disabled)
- [ ] 모든 variant 조합
- [ ] 모든 size 조합
- [ ] children이 복잡한 JSX인 경우

---

### Phase 5: 사용자 브리핑

구현 완료 후 다음 형식으로 브리핑합니다:

```
## 구현 완료 브리핑

### 생성된 파일
- `src/components/common/[Name]/index.tsx` — 메인 컴포넌트
- `src/components/common/[Name]/[Name].styles.ts` — 스타일
- `src/components/common/[Name]/[Name].stories.tsx` — 스토리북

### Props 인터페이스
| Prop | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| ... | ... | ... | ... |

### 사용 예시
\`\`\`tsx
<ComponentName variant="info" size="medium">
  내용
</ComponentName>
\`\`\`

### 설계 결정 사항
- [왜 이 패턴을 선택했는지]
- [주의할 점]
```

---

### Phase 6: 시각적 회귀 테스트 (강화된 스펙 검증)

구현 완료 후 **Figma 스펙과 코드 스펙을 수치 단위로 대조**하여 시각적 차이를 검출합니다.

> **절대 규칙**: 스크린샷 눈대중 비교는 금지. 반드시 `get_design_context`로 추출한 숫자 값과 코드를 1:1 대조할 것. 색상만 확인하고 "일치"라고 판단하면 타이포그래피/간격/크기 불일치를 놓칩니다.

#### 6.1 사전 조건

- Storybook 실행 필요 (`node_modules/.bin/start-storybook -p 6006 --ci`)
- Figma 데스크톱 앱이 해당 컴포넌트 페이지에 열려 있어야 함

#### 6.2 Figma 스펙 추출 (필수, 최우선)

Figma Dev Mode MCP로 **개별 컴포넌트 인스턴스의 정확한 수치**를 추출합니다.

```
1. get_metadata로 컴포넌트 인스턴스 nodeId 수집
   - "Variant=X, Action Button=Y" 패턴으로 식별
2. 각 nodeId에 대해 get_design_context 호출 (get_screenshot 아님!)
   - 반환된 Tailwind 코드에서 정확한 픽셀 값 추출
3. 다음 수치를 체계적으로 수집:
```

**추출 필수 항목 (Spec Extraction Checklist):**

| 카테고리 | 항목 | Tailwind 단서 | 예시 |
|---------|------|--------------|------|
| **크기** | 컨테이너 너비 | `w-[500px]` | 500px |
| **크기** | 아이콘 크기 | `size-[14px]` | 14px (inner) |
| **크기** | 아이콘 컨테이너 높이 | `h-[20px]` | 20px (wrapper) |
| **간격** | 컨테이너 padding | `px-[16px] py-[12px]` | 16px/12px |
| **간격** | 아이콘-텍스트 gap | `gap-[6px]` | 6px |
| **간격** | 타이틀-메시지 gap | `gap-[2px]` | 2px |
| **간격** | border-radius | `rounded-[8px]` | 8px |
| **정렬** | 수직 정렬 | `items-start` / `items-center` | flex-start |
| **타이포** | 타이틀 폰트 사이즈 | `text-[length:var(--font/size/r,13px)]` | 13px |
| **타이포** | 타이틀 굵기 | `font/weight/sub-title` → 500 | Medium |
| **타이포** | 타이틀 line-height | `leading-[var(--font/line-height/r,20px)]` | 20px |
| **타이포** | 메시지 폰트 사이즈 | `text-[length:var(--font/size/s,12px)]` | 12px |
| **타이포** | 메시지 굵기 | `font/weight/text` → 400 | Regular |
| **타이포** | 메시지 line-height | `leading-[var(--font/line-height/s,18px)]` | 18px |
| **색상** | 배경 토큰 | `--primary/100` | `#ecf3ff` |
| **색상** | 아이콘 색상 | svg asset | variant별 토큰 |
| **색상** | 타이틀 색상 | `--gray/700` | `#20232b` |
| **색상** | 메시지 색상 | `--gray/500` | `#606268` |

#### 6.3 코드 스펙 추출

기존 코드에서 동일 항목을 추출합니다.

```
1. styled-components 파일 읽기 → padding, gap, border-radius, align-items 추출
2. 컴포넌트 파일 읽기 → Icon size prop, 구조 확인
3. theme 파일 참조 → fontSize.r/s, lineHeight.r/s, fontWeight.medium/bold 실제 값 확인
```

#### 6.4 구조(레이아웃) 검증

Figma의 DOM 계층 구조와 코드의 JSX 구조를 대조합니다. 수치가 맞아도 **요소의 위치가 다르면** 시각적으로 다르게 보입니다.

**검증 항목:**

```
1. Figma `get_design_context`로 Tailwind HTML 구조 추출
2. 각 요소의 부모-자식 관계 확인:
   - 어떤 요소가 어느 flex 컨테이너 안에 있는지
   - 어떤 요소가 다른 요소와 형제(sibling)인지
3. 코드 JSX와 1:1 대조
```

**자주 발견되는 구조 불일치 패턴:**

| 패턴 | Figma | 잘못된 코드 |
|------|-------|-----------|
| **메시지 인덴트** | Title과 Message가 Icon 오른쪽 flex-col 내부 | Message가 Header 밖으로 빠져 왼쪽 끝부터 시작 |
| **버튼 위치** | Bottom Button이 Container 레벨 + `pl-[20px]` | Content Flex 내부에 중첩되어 인덴트 없음 |
| **Container gap** | Bottom 버튼 있을 때 Container gap이 변함 (2→8) | Content gap만 적용되어 버튼 위치 어긋남 |

**체크 항목:**
- [ ] Figma의 `data-name`과 코드의 네이밍이 일치하는가?
- [ ] flex-col / flex-row 방향이 일치하는가?
- [ ] 요소의 부모가 올바른가? (특히 텍스트가 title 컬럼 안에 있는지)
- [ ] 인덴트가 필요한 요소는 `pl-*`가 적용됐는가?

#### 6.5 아이콘 매핑 검증 → `/resolve-icon` 스킬 실행

아이콘 검증은 **`/resolve-icon` 스킬을 실행**하여 수행합니다.

> **절대 규칙**: 아이콘을 자체 제작하지 않는다. 디자인 시스템에 정의된 아이콘만 사용하고, 색상은 CSS로 변경한다.

```
1. Figma Iconography 페이지에서 사용 가능한 아이콘 목록 확인
2. 코드베이스에서 동일 모양의 기존 아이콘 검색 (이름이 아닌 모양으로 매칭)
3. 있으면 재사용 + CSS `svg path:first-child { fill }` 오버라이드
4. 없으면 디자이너에게 요청 (자체 제작/다운로드 금지)
```

상세 프로세스는 `/resolve-icon` 스킬 참조.

#### 6.7 수치 대조 리포트 (핵심)

추출한 Figma 스펙과 코드 스펙을 **숫자 단위로** 대조합니다. 이 리포트는 구조/아이콘/색상 검증도 포함합니다.

```markdown
## 시각적 회귀 테스트 리포트

### 1. 크기/간격
| 항목 | Figma | 코드 | 차이 | 결과 |
|------|-------|------|------|------|
| 아이콘 크기 | 14px | ?px | ?px | ✅/❌ |
| 컨테이너 gap (title-msg) | 2px | ?px | ?px | ✅/❌ |
| 헤더 gap (icon-text) | 6px | ?px | ?px | ✅/❌ |
| 컨테이너 padding | 12px 16px | ? | ? | ✅/❌ |
| border-radius | 8px | ?px | ?px | ✅/❌ |

### 2. 타이포그래피
| 항목 | Figma | 코드 | 결과 |
|------|-------|------|------|
| 타이틀 font-size | 13px | ?px | ✅/❌ |
| 타이틀 font-weight | 500 (Medium) | ? | ✅/❌ |
| 타이틀 line-height | 20px | ?px | ✅/❌ |
| 메시지 font-size | 12px | ?px | ✅/❌ |
| 메시지 font-weight | 400 (Regular) | ? | ✅/❌ |
| 메시지 line-height | 18px | ?px | ✅/❌ |

### 3. 구조/레이아웃 (필수)
| 항목 | Figma | 코드 | 결과 |
|------|-------|------|------|
| 메시지 위치 | Title과 같은 flex-col 내부 | ? | ✅/❌ |
| Bottom 버튼 위치 | Container 레벨 + pl-20 | ? | ✅/❌ |
| Container gap (Bottom 시) | 8px | ? | ✅/❌ |
| 헤더 items 정렬 | items-start | ? | ✅/❌ |

### 4. 색상 (computed style 기준, 모든 variant)
| Variant | Figma 배경 | 렌더 배경 | Figma 아이콘 | 렌더 아이콘 | 결과 |
|---------|-----------|----------|-------------|------------|------|
| Info | #ecf3ff | ? | #227eff | ? | ✅/❌ |
| Success | #eafafa | ? | #15b1ab | ? | ✅/❌ |
| ... | ... | ... | ... | ... | ... |

### 5. 아이콘 매핑 (shape 검증)
| Variant | Figma 요구 모양 | 코드 아이콘 | 모양 일치 | 조치 |
|---------|---------------|-----------|----------|------|
| Info | 원 + 흰색 "!" | badgeInfo | ✅ | 유지 |
| Success | 원 + 흰색 체크 | systemCheck | ❌ 원 없음 | Figma에서 다운로드 |
| Warning | 삼각형 + 흰색 "!" | badgeWarning | ❌ 느낌표뿐 | Figma에서 다운로드 |

### 6. 불일치 요약 및 조치
- **크기/간격 불일치**: [구체 항목]
- **타이포 불일치**: [구체 항목]
- **구조 불일치**: [어떤 요소가 어디로 이동해야 하는지]
- **색상 불일치**: [variant + 정확한 hex 값 차이]
- **아이콘 불일치**:
  - 없는 아이콘 (다운로드 필요): [목록]
  - 있지만 모양 다른 아이콘: [목록 + 다운로드 권장]
  - 일치하여 재사용: [목록]

### 7. 수정 계획
1. [우선순위 1 항목]
2. [우선순위 2 항목]
```

#### 6.8 브라우저 computed style 검증 (색상 확인용)

색상이 실제 적용되는지 Playwright `browser_evaluate`로 검증합니다.

```javascript
() => {
  const svgs = document.querySelectorAll('svg');
  return Array.from(svgs).map((svg, idx) => {
    const paths = svg.querySelectorAll('path');
    const circles = svg.querySelectorAll('circle');
    const rects = svg.querySelectorAll('rect');
    let bgParent = svg.parentElement;
    while (bgParent && window.getComputedStyle(bgParent).backgroundColor === 'rgba(0, 0, 0, 0)') {
      bgParent = bgParent.parentElement;
    }
    return {
      index: idx,
      bg: bgParent ? window.getComputedStyle(bgParent).backgroundColor : null,
      pathFills: Array.from(paths).map(p => window.getComputedStyle(p).fill),
      circleFills: Array.from(circles).map(c => window.getComputedStyle(c).fill),
      rectFills: Array.from(rects).map(r => window.getComputedStyle(r).fill),
    };
  });
}
```

이 결과를 Figma variable_defs 값과 대조하면 **색상 적용 여부**와 **어떤 요소가 어떤 색을 가지는지** 확인 가능합니다.

#### 6.9 스크린샷 시각 검증 (최종 확인)

수치/구조/아이콘 검증 완료 후 스크린샷 시각 비교로 마무리.

```
1. Playwright MCP로 Storybook 스크린샷 캡처 (AllVariants + ActionButtonVariants)
2. Figma MCP get_screenshot으로 각 variant 인스턴스 nodeId 캡처
3. 두 이미지를 나란히 비교하여 최종 시각 검증
```

#### 6.10 한계 및 참고

- **Figma 앱 의존성**: Figma 데스크톱 앱이 해당 컴포넌트 페이지에 열려 있어야 `get_design_context`/`get_screenshot` 사용 가능
- **폰트 렌더링 차이**: 브라우저와 Figma의 폰트 안티앨리어싱 차이는 허용
- **픽셀 퍼펙트**: 2px 이상의 차이는 반드시 조사할 것
- **색상만 비교 금지**: 타이포그래피/간격/크기/구조는 스크린샷으로는 감지 불가, 반드시 숫자/구조 대조
- **아이콘 shape 검증 필수**: 색상이 맞아도 모양이 다르면 시각적 불일치 — 반드시 SVG 경로까지 확인

---

## 안티패턴 (하지 말 것)

1. **Props 폭발** — Props가 10개 이상이면 설계를 다시 생각할 것
2. **도메인 로직 침투** — `paymentStatus`, `customerType` 같은 Props 금지
3. **과도한 추상화** — 사용처가 1곳이면 공통 컴포넌트로 만들지 말 것
4. **불필요한 styled-component** — 간단한 속성 1-2개 차이면 Flex 등 기존 공통 컴포넌트 직접 사용
5. **내부 상태 남용** — 가능한 한 제어 컴포넌트로 설계
6. **네이티브 속성 무시** — `...rest` 패턴으로 HTML 속성 전달 지원

### 시각적 회귀 테스트 안티패턴

7. **색상만 보고 일치 판단** — 타이포/간격/크기/구조는 모두 별도로 검증 필요
8. **스크린샷 눈대중 비교** — 반드시 `get_design_context`의 숫자로 대조
9. **아이콘 자체 제작** — SVG를 직접 만들거나 Figma 에셋 서버에서 다운받아 추가하지 않음. 디자인 시스템 Iconography에 정의된 것만 사용
10. **이름만 보고 아이콘 판단** — `systemCheck`(체크만)와 `etcSuccess`(원+체크)는 이름이 비슷해도 모양이 다름. 반드시 SVG 파일 열어서 확인
11. **이중색 아이콘에 `svg path { fill }` 적용** — 흰색 내부까지 덮어씀. `path:first-child` 사용
12. **Message/Button을 잘못된 flex 레벨에 배치** — Figma의 부모-자식 관계를 정확히 따라갈 것
13. **아이콘 관련 모든 검증은 `/resolve-icon` 스킬 참조**

## 참조 문서

- `.docs/conventions/REACT_CONVENTIONS.md` — React 컴포넌트 규칙
- `.docs/conventions/CODING_CONVENTIONS.md` — 코딩 컨벤션
- `.docs/conventions/STORYBOOK_RULES.md` — 스토리북 규칙
- `.docs/conventions/COMMON_COMPONENTS_HOOKS_GUIDE.md` — 기존 공통 컴포넌트 목록
- `.docs/conventions/UI_STYLING_RULES.md` — UI 스타일링 규칙
- `.docs/conventions/TYPE_CONVENTIONS.md` — 타입 정의 규칙
