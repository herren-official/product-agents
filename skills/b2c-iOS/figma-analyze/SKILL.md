---
name: b2c-ios-figma-analyze
description: "Figma URL을 분석하여 디자인 구조, 토큰, 컴포넌트를 추출하고 DesignSystem 매핑을 수행합니다"
argument-hint: "<Figma URL>"
disable-model-invocation: false
allowed-tools: ["Read", "Grep", "Glob", "mcp__figma-dev-mode-mcp-server__get_screenshot", "mcp__figma-dev-mode-mcp-server__get_metadata", "mcp__figma-dev-mode-mcp-server__get_design_context", "mcp__figma-dev-mode-mcp-server__get_variable_defs", "mcp__figma-dev-mode-mcp-server__get_code_connect_map"]
---

# /b2c-ios-figma-analyze - Figma 디자인 분석

## 실행 알림
이 스킬이 실행되면 가장 먼저 "[b2c-ios-figma-analyze] 스킬이 실행되었습니다."를 출력할 것

$ARGUMENTS

## 0. 사전 준비

**반드시 DesignSystem 가이드를 읽어 매핑 테이블을 확인할 것:**
```
Read: .docs/conventions/DESIGN_SYSTEM.md
```
- Color System: hex -> DesignSystem 토큰 매핑
- Typography System: size/weight -> 토큰 매핑
- Spacing System: pt -> 토큰 매핑
- Radius System: pt -> 토큰 매핑
- Components: 전체 컴포넌트 인벤토리

## 실행 프로세스

### 1단계: URL 파싱

Figma URL에서 `fileKey`와 `nodeId`를 추출:

```
URL 패턴: https://www.figma.com/design/{fileKey}/{fileName}?node-id={nodeId}
```

| 파라미터 | 추출 위치 | 예시 |
|---------|----------|------|
| `fileKey` | `/design/` 뒤 영숫자 | `"abc123DEF456"` |
| `nodeId` | `node-id` query param | `"123:456"` (URL에서 `123-456` -> `123:456`, `%3A` -> `:` URL 디코딩 포함) |

### 2단계: Figma MCP 도구 순차 호출

**Step 2.1: 스크린샷**
```
Tool: mcp__figma-dev-mode-mcp-server__get_screenshot
Parameters:
  - fileKey: (추출값)
  - nodeId: (추출값)
```

**Step 2.2: 메타데이터**
```
Tool: mcp__figma-dev-mode-mcp-server__get_metadata
Parameters:
  - fileKey: (추출값)
  - nodeId: (추출값)
```

**Step 2.3: 디자인 컨텍스트 (코드 레벨)**
```
Tool: mcp__figma-dev-mode-mcp-server__get_design_context
Parameters:
  - fileKey: (추출값)
  - nodeId: (추출값)
  - clientLanguages: ["swift"]
  - clientFrameworks: ["swiftui"]
```

**Step 2.4: 변수 정의 (디자인 토큰)**
```
Tool: mcp__figma-dev-mode-mcp-server__get_variable_defs
Parameters:
  - fileKey: (추출값)
  - nodeIds: [(추출값)]
```

**Step 2.5: Code Connect Map (선택)**
```
Tool: mcp__figma-dev-mode-mcp-server__get_code_connect_map
Parameters:
  - fileKey: (추출값)
  - nodeIds: [(추출값)]
```

### 3단계: 디자인 요소 추출

Figma 분석 결과에서 다음 항목을 정리:

- [ ] 화면 레이아웃 구조 (VStack/HStack/ZStack 계층)
- [ ] 사용된 색상 (hex 값 목록)
- [ ] 타이포그래피 스타일 (size, weight, line height)
- [ ] 간격 값 (padding, gap)
- [ ] 코너 반경 값
- [ ] 컴포넌트 인스턴스 (버튼, 입력, 카드 등)
- [ ] 아이콘 에셋
- [ ] 이미지 플레이스홀더
- [ ] 인터랙션 상태 (default, pressed, disabled 등)
- [ ] 네비게이션 구조 (TopBar 구성)

### 4단계: DesignSystem 매핑

**DESIGN_SYSTEM.md를 참조하여** 추출된 Figma 디자인 요소를 프로젝트 DesignSystem 토큰에 매핑:

#### 4.1 색상 매핑
- Figma hex -> DESIGN_SYSTEM.md "Color System" 섹션의 토큰으로 변환
- 매칭 안 되는 색상은 "Custom color - 디자이너 확인 필요"로 플래그

#### 4.2 타이포그래피 매핑
- Figma font size + weight -> DESIGN_SYSTEM.md "Typography System" 섹션의 토큰
- 사용법: `.fontTypography(.heading2)`, `.textColor(.gray_700)`

#### 4.3 간격 매핑
- Figma spacing -> DESIGN_SYSTEM.md "Spacing System" 섹션의 토큰
- 정확히 매칭되지 않으면 가장 가까운 토큰 제안 후 플래그

#### 4.4 Radius 매핑
- Figma corner radius -> DESIGN_SYSTEM.md "Radius System" 섹션의 토큰 (small/medium/large/xLarge)

#### 4.5 컴포넌트 매핑
- Figma UI 요소 -> DESIGN_SYSTEM.md "Components" 섹션의 DesignSystem 컴포넌트
- 기존 컴포넌트 우선 사용, 없으면 신규 필요 여부 판단

## 출력 형식

```markdown
### Figma 디자인 분석 결과

#### 화면 구조
{VStack/HStack 계층 다이어그램}

#### 디자인 토큰 매핑

| Category | Figma Value | DesignSystem Token | Status |
|----------|------------|-------------------|--------|
| Color | #4E3BFF | .brand_300 | Match |
| Color | #FF1234 | - | Custom (확인 필요) |
| Typography | 18pt SemiBold | .heading2 | Match |
| Spacing | 20pt | .horizontalSpacing | Match |
| Radius | 8pt | .medium | Match |

#### 컴포넌트 매핑

| Figma Element | DesignSystem Component | Configuration |
|--------------|----------------------|---------------|
| Primary Button | Button + .primary | shape: .rectangle, size: .large |
| Navigation Bar | .topBar() modifier | title: "...", backButton |

#### 플래그 항목 (디자이너 확인 필요)
- (매칭 안 되는 색상, 간격, 컴포넌트 등)
```

## 에러 처리

| 에러 | 대응 |
|------|------|
| Figma URL 파싱 실패 | URL 형식 확인 요청 |
| MCP 도구 접근 실패 | Figma 파일 접근 권한 확인 |
| nodeId 없음 | URL에서 특정 프레임 선택 요청 |
| 디자인 토큰 매핑 불가 | 플래그 처리 후 디자이너 확인 권고 |
