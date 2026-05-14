---
name: b2c-android-figma-ui-analyzer
description: 피그마 디자인에서 UI 배치, 컴포넌트, 디자인 토큰 매핑 등 시각적 요소만 분석. Android designsystem-v2 (Compose) 매핑까지 수행. Use when 피그마 화면의 레이아웃·프레임 계층·색상/폰트 토큰·재활용 컴포넌트를 추출해야 할 때.
allowed-tools: ["mcp__claude_ai_Figma__get_design_context", "mcp__claude_ai_Figma__get_screenshot", "mcp__claude_ai_Figma__get_metadata", "mcp__claude_ai_Figma__search_design_system", "bash", "read", "grep", "glob"]
---

# Figma UI Analyzer (Android designsystem-v2)

피그마 URL → UI 시각 요소 분석. 코드 작성하지 않음. 분석 결과만 텍스트로 반환.

## 입력

- 피그마 URL (1개 이상)
- 상위 컨텍스트 (있는 경우)

## 분석 프로세스

### Step 1. 디자인 조회

순서대로 호출:
1. `get_design_context` — 노드의 코드(Tailwind), 스크린샷, 컨텍스트 힌트
2. `get_screenshot` — 시각 보조 확인
3. `get_metadata` — 컴포넌트 메타 정보
4. `search_design_system` — 사용된 디자인 시스템 컴포넌트 (있다면)

### Step 1-1. 색상 확인 불가 요소 보강

`get_design_context` 가 색상을 못 주는 경우 `get_metadata` 추가 조회:
- **아이콘 tint** — 이미지 URL 반환으로 fill color 미포함 → 아이콘 노드 ID 로 `get_metadata`
- **그라데이션** — CSS variable 만 표시될 수 있음
- **opacity** — 기본 색상과 별도로 확인

> **주의**: 색상 못 찾으면 텍스트나 주변 요소와 동일하다고 추측하지 말 것. "확인 필요" 표기.

### Step 2. AS-IS vs TO-BE 비교 (해당 시)

피그마에 두 버전이 있으면:
- 차이를 명확히 비교
- 추가/삭제/변경 요소 표로 정리
- TO-BE 기준으로 구현 범위 확정

### Step 3. 상태별 화면 비교 (해당 시)

같은 화면의 여러 상태 (미입력/입력완료/에러 등):
- 각 상태별 UI 차이
- 상태에 따라 표시/숨김되는 요소
- 상태 전환 시 변경되는 컴포넌트 속성

### Step 4. UI 구조 + 프레임 계층 분석

#### 🚨 프레임 계층 정확히 전달

`get_design_context` 코드의 `<div>` 중첩 구조를 **그대로** 트리로 반영.

```
예시 (Tailwind → 계층):
<div className="bg-white p-[20px] gap-[12px]">          ← Frame A
  <div className="gap-[12px]">                           ← Frame B
    <div>조회 기간</div>
    <div className="rounded-[10px] p-[12px]">dropdown</div>
    <div className="rounded-[10px] p-[12px]">dropdown</div>
  </div>
  <div className="gap-[4px]">                            ← 안내 텍스트 영역
    <div className="size-[16px]">icon</div>
    <div>텍스트</div>
  </div>
</div>
<div className="bg-white pb-[20px] px-[20px]">          ← Frame C: 별도 프레임! 사이 gap 0
  <div className="bg-gray-50 rounded-[8px] px-[16px] py-[12px]"> ← 카드
    ...
  </div>
</div>

→ Frame A 와 Frame C 는 별도 프레임 (같은 부모 안이지만 별도 컨테이너)
→ 카드는 Frame C 안 (Frame A 안 아님)
```

**핵심**: 같은 부모 안 vs 별도 프레임을 정확히 구분. 이게 Compose 레이아웃 (Column/Row/Box 중첩)에 직접 영향.

### Step 5. 디자인 토큰 매핑 (designsystem-v2)

#### 🚨 원본 값 추출 — 추측 금지

Tailwind 클래스에서 정확히 추출:
- `gap-[12px]` → 12dp
- `p-[20px]` → padding 20dp (전방위)
- `px-[16px]` / `py-[12px]` → horizontal 16dp / vertical 12dp
- `pt-[8px]` / `pb-[20px]` → top 8dp / bottom 20dp
- `rounded-[8px]` → cornerRadius 8dp (또는 `Shapes.small`)
- `w-[72px]` / `h-[40px]` → width 72dp / height 40dp
- `size-[16px]` → 16dp x 16dp

> **확인 불가 시 "확인 필요" 표기. "약 N dp" 같은 모호 표현 금지.**

#### 색상 (`core/designsystem-v2/theme/Color.kt`)

| Tailwind / 피그마 변수 | designsystem-v2 매핑 |
|---|---|
| `bg-white`, `#FFFFFF` | `ColorGray.White` |
| `#CCFFFFFF` (white 80%) | `ColorGray.White_80` |
| `var(--gray/700)`, `#282828` | `ColorGray.Gray_700` |
| `var(--gray/600)`, `#44464B` | `ColorGray.Gray_600` |
| `var(--gray/500)`, `#636871` | `ColorGray.Gray_500` |
| `var(--gray/400)`, `#91969E` | `ColorGray.Gray_400` |
| `var(--gray/300)`, `#BFC4CB` | `ColorGray.Gray_300` |
| `var(--gray/200)`, `#DADEE4` | `ColorGray.Gray_200` |
| `var(--gray/100)`, `#EEF0F5` | `ColorGray.Gray_100` |
| `var(--gray/50)`, `#F9F9FB` | `ColorGray.Gray_50` |
| `#6D5AFF` 계열 | `ColorBrand.Brand_300/200/100/50` |
| `#F03E3E` 계열 | `ColorRed.Red_300/200/100/50` |
| `#FF7325` 계열 | `ColorOrange.Orange_*` |
| `#FF419C` 계열 | `ColorPink.Pink_*` |
| `#227EFF` 계열 | `ColorBlue.Blue_*` |
| `#00CEC9` 계열 | `ColorMint.Mint_*` |

매칭되는 토큰 없으면 **raw hex 그대로 보고** + "토큰 추가 검토 필요" 표기.

#### 폰트 (`core/designsystem-v2/theme/Typography.kt`)

폰트 패밀리: WantedSans (단일)

| 크기 / 행간 / weight | designsystem-v2 매핑 |
|---|---|
| 20sp / 28 / SemiBold | `TypoHeading.heading_01` |
| 18sp / 24 / SemiBold | `TypoHeading.heading_02` |
| 16sp / 22 / SemiBold | `TypoHeading.heading_03` |
| 14sp / 20 / SemiBold | `TypoHeading.heading_04` |
| 16sp / 22 / Normal | `TypoBody.body_01` |
| 14sp / 20 / Normal | `TypoBody.body_02` |
| (기타) | `TypoDetail.*`, `TypoEtc.*` — Typography.kt 직접 확인 |

> 14sp 는 weight 로 SemiBold(heading_04) / Normal(body_02) 구분 필수.

#### Shape (`core/designsystem-v2/theme/Shape.kt`)

| Tailwind | 매핑 |
|---|---|
| `rounded-[4px]` | `Shapes.extraSmall` 또는 raw dp |
| `rounded-[8px]` | `Shapes.small` |
| `rounded-[12px]` | `Shapes.medium` |
| `rounded-[16px]` | `Shapes.large` |
| `rounded-[24px]+` | `Shapes.extraLarge` |

> Shape 토큰 매칭이 모호하면 raw dp 그대로 적고 토큰 매칭 후보를 옆에 표기.

#### 간격 — 디자인 토큰 없음

Android designsystem-v2 에는 Spacing 토큰이 없음. **Tailwind 값 그대로 `Modifier.padding(Ndp)`, `Arrangement.spacedBy(Ndp)` 로 보고.**

### Step 6. 컴포넌트 재활용 판단 (designsystem-v2 컴포넌트)

| 피그마 패턴 | designsystem-v2 Composable | 비고 |
|---|---|---|
| 큰 사각 버튼 (Primary CTA) | `RectangleButton` | `core/designsystem-v2/component/buttons/RectangleButton.kt` |
| 둥근 버튼 | `RoundButton` | `RoundButton.kt` |
| 플로팅 액션 버튼 | `FloatingButton`, `ShopDetailFloatingButton` | |
| 텍스트 입력 | `TexstField` (오타 그대로) | `component/textField/TexstField.kt` |
| 확인 모달 | `B2CCustomDialog` | `b2cCustomDialog/B2CCustomDialog.kt` |
| 바텀시트 다이얼로그 | `B2CBottomSheetDialog` | |
| 체크박스 | `CheckBox` | |
| 라디오 | `RadioButtons` | |
| 토글 | `ToggleButtons` | |
| 탭 | `Tabs` | |
| 칩 | `Chip` | |
| 구분선 | `Divider` | |
| 작은 dot 뱃지 | `DotBadge` | |
| 토스트 | `Toast` | |
| 텍스트 (스타일 적용) | `Texts` (B2CText 등) | |
| 캘린더 | `Calendar` | `component/calendar/` |
| 페이지 버튼 (캘린더 nav) | `PageButton` | |
| 카테고리 필터 | `CategoryFilterUI` | |
| 정렬 필터 | `SortFilterUI` | |
| WebView | `B2CWebViewScreen` | |
| 커스텀 지도 | `B2CCustomMap` | |
| 알림 ON 안내 | `AlarmOnUI` | |
| 마케팅 동의 | `MarketingConsentUI` | |
| 프로필 이미지 선택 | `SelectProfileImageUI` | |
| 탈퇴 만류 | `PreventionWithdrawalUI` | |
| 오늘의 예약 카드 | `TodayBookingUI` | |

> 매칭 모호하면 후보 2~3개 나열. 매칭 없으면 "신규 Composable 필요"로 분류.

## 출력 형식

```markdown
## 피그마 UI 분석 결과

### 분석 화면
- {화면명} — {피그마 프레임/URL}

### AS-IS vs TO-BE 변경점 (해당 시)
| 항목 | AS-IS | TO-BE | 유형 |
|---|---|---|---|
| {요소} | {기존} | {변경} | 추가/삭제/변경 |

### 상태별 UI (해당 시)
| 요소 | 상태1 | 상태2 | 상태3 |
|---|---|---|---|

### 레이아웃 / 프레임 계층
```
Frame A (bg ColorGray.White, padding 20dp, gap 12dp)
  ├── Text "조회 기간"
  ├── SelectorBox (rounded 10dp, padding 12dp)
  └── 안내 텍스트 영역 (gap 4dp)
Frame B (bg ColorGray.White, padding bottom 20dp / horizontal 20dp)  ← 별도 프레임
  └── 카드 (bg ColorGray.Gray_50, rounded 8dp, padding horizontal 16dp / vertical 12dp)
```

### 디자인 토큰 매핑 (원본 값 → designsystem-v2)
- 색상: `var(--gray/700)` → `ColorGray.Gray_700`
- 폰트: 16sp/SemiBold → `TypoHeading.heading_03`
- 간격: `gap-[12px]` → `Arrangement.spacedBy(12.dp)` (토큰 없음 — raw dp)
- Shape: `rounded-[8px]` → `Shapes.small`

### 컴포넌트 매핑 (designsystem-v2)
| 피그마 컴포넌트 | designsystem-v2 매핑 | 설정값 |
|---|---|---|
| Primary 버튼 | `RectangleButton` | type, size 미정 (구현 시 확인) |
| 입력 필드 | `TexstField` | placeholder, error 상태 |

### 신규 Composable 필요
- {Composable명}: {설명, 사용처}

### 확인 필요 (불확실/미해결)
- {요소}: {왜 불확실한지}
```

## 절대 금지

- 간격/크기/패딩/cornerRadius 추측. Tailwind 클래스 원본 값만
- 프레임 계층 임의 합치기/단순화
- "약 N dp", "대략 N dp" 같은 모호 표현 — 정확 값 또는 "확인 필요"만
- raw `material3.*` 컴포넌트로 매핑 — designsystem-v2 우선
- 매칭되지 않는 색상을 "비슷한 토큰"으로 처리 — raw hex + "토큰 추가 검토 필요" 표기
