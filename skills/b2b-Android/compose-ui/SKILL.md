---
name: b2b-android-compose-ui
description: Compose UI 구현. "UI 만들어줘", "Compose 화면", "디자인 구현", "화면 개발", "Figma 구현" 요청 시 사용
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, mcp__Figma_Dev_Mode_MCP__get_figma_data, mcp__Figma_Dev_Mode_MCP__download_figma_images, EnterPlanMode
user-invocable: true
---

# Compose UI 구현 스킬

Figma 디자인을 B2B 디자인 시스템 기반 Compose 코드로 변환한다.

## 사용법

```bash
/compose-ui <figma-url> [컴포넌트명] [파일명]
```

**파라미터:**
- `figma-url`: Figma 디자인 URL (필수)
- `컴포넌트명`: 생성할 Compose 컴포넌트 이름 (선택, 기본값: Figma 노드명 기반)
- `파일명`: 생성할 파일명 (선택, 기본값: 컴포넌트명 + "Screen.kt")

**사용 예시:**
```bash
/compose-ui https://www.figma.com/design/JYLn8WR8HRw0RIh1ahKmaW/...
/compose-ui https://figma.com/... PaymentMethodAddScreen
/compose-ui https://figma.com/... PaymentMethodAddScreen CustomScreen.kt
```

## 🎯 핵심 원칙

**필수 요구사항:**
1. **Plan Mode로 구현 계획 수립**
   - 작업 시작 전 Plan Mode 진입하여 전체 구현 계획 수립
   - Figma 디자인 분석, 컴포넌트 분해, 디자인 시스템 매핑 계획 작성
   - 사용자 승인 후 구현 진행

2. **디자인 시스템 문서 필수 숙지**
   - 작업 시작 전 반드시 모든 관련 문서 읽기
   - `.docs/design-system.md` - 메인 가이드 (필수)
   - `.docs/design-system/*.md` - 모든 하위 문서 (필수)
   - 특히 iconography.md, colors.md, typography.md는 필수 참조

### ✅ 필수
- B2B 디자인 시스템 컴포넌트 우선 사용
- ColorB2B, Typography 사용
- Preview 함수 작성
- 모든 컴포넌트에 `modifier: Modifier = Modifier` 파라미터 필수
- 한국어 주석 및 KDoc 스타일 문서화

### ⛔ 금지
- Material3 기본 컴포넌트 직접 사용 (B2B 컴포넌트로 래핑된 것 사용)
- 하드코딩된 색상/폰트
- Scaffold 사용 금지 (BaseActivity 호환)

## 패키지 구조

```
com.gongnailshop.herren_dell1.gongnailshop.compose/
├── theme/
│   ├── B2BTheme         // 테마
│   ├── ColorB2B         // 색상
│   └── Typography       // 타이포그래피
└── component/
    ├── RectangleButton  // 사각형 버튼
    ├── RoundButton      // 둥근 버튼
    ├── BoxTextField     // 박스 입력필드
    ├── LineTextField    // 밑줄 입력필드
    ├── B2BToggleSwitch  // 토글
    ├── B2BCheckbox      // 체크박스
    ├── B2BTab           // 탭
    └── ...
```

## 주요 컴포넌트 매핑

| Figma | Compose |
|-------|---------|
| rectangle_button | RectangleButton |
| Button | RoundButton, IconButton |
| text_box_M/S/XS | BoxTextField |
| toggle switch | B2BToggleSwitch |
| check box | B2BCheckbox |
| tab_base | B2BTab |
| Topbar | TopBar |

## 자동화 흐름 (🔄 반복적 구현 방식)

### Phase 0: 사전 준비 (필수)

#### Plan Mode로 전체 작업 계획 수립
Plan Mode에 진입하여 다음 항목을 분석하고 구현 계획을 작성:
1. Figma URL 분석 및 작업 범위 파악
2. 필요한 디자인 시스템 문서 목록 작성
3. 예상 컴포넌트 리스트 및 복잡도 추정
4. 작업 순서 및 의존성 파악
5. 예상 문제점 및 해결 방안 준비
6. 사용자 승인 후 구현 시작

#### 디자인 시스템 문서 전체 숙지
```
필수 읽기 순서:
1. .docs/design-system.md - 전체 구조 파악
2. .docs/design-system/typography.md - 텍스트 스타일 매핑
3. .docs/design-system/colors.md - 색상 매핑
4. .docs/design-system/iconography.md - 아이콘 매핑
5. .docs/design-system/spacing.md - 간격 시스템
6. .docs/design-system/buttons.md - 버튼 컴포넌트
7. .docs/design-system/text-fields.md - 입력 필드
8. .docs/design-system/form-controls.md - 폼 컨트롤
9. .docs/design-system/modals.md - 모달 시스템
10. .docs/design-system/misc-components.md - 기타 컴포넌트
```

### Phase 1: Figma 데이터 수집 및 초기 분석

#### 1. Figma 디자인 데이터 추출 및 교차 검증
- **전체 구조 파악**:
  - `mcp__Figma_Dev_Mode_MCP__get_figma_data`로 디자인 데이터 추출
  - 화면 구조, 컴포넌트 계층, 스타일 정보 수집
  - **원본 Figma 데이터 보존**: 최종 검증용으로 저장
- **자동 스크린샷 다운로드 및 시각적 검증**:
  - `mcp__Figma_Dev_Mode_MCP__download_figma_images` 사용
  - `.docs/design-screenshots/` 디렉토리에 저장
  - **교차 검증**:
    - Read 도구로 스크린샷 확인하여 실제 디자인 파악
    - Figma MCP 데이터의 구조/색상/간격 정보와 대조
    - 시각적 UI와 데이터 값의 일치성 확인
- **사용된 컴포넌트 목록 작성**

### Phase 2: 디자인 시스템 검증 및 매핑

#### 매핑 전략 수립
- Figma 컴포넌트와 B2B 컴포넌트 1:1 매핑 전략
- 존재하지 않는 컴포넌트에 대한 대체 방안
- 커스텀 구현이 필요한 부분 식별

#### 체계적인 매핑 검증
- **아이콘 매핑**: iconography.md 기준으로 정확한 drawable 리소스 확인
- **색상 매핑**: colors.md 기준으로 ColorB2B 클래스 매칭
- **텍스트 스타일**: typography.md 기준으로 B2BTheme.typography 매칭
- **컴포넌트 매핑**: 각 컴포넌트별 md 파일에서 사용법 확인

### Phase 3: 복잡도 분석 및 마스터 플랜 수립

#### 컴포넌트 분해 계획
```
1. 전체 UI를 논리적 단위로 분해
2. 각 컴포넌트의 재사용성 평가
3. 컴포넌트 간 의존성 관계 파악
4. Bottom-up 구현 순서 결정
```

#### 복잡도 기반 구현 전략
- **복잡도 점수 계산**:
  - 노드 수 (10개 미만: 단순, 10-30개: 중간, 30개 이상: 복잡)
  - 중첩 깊이 (3단계 미만: 단순, 3-5단계: 중간, 5단계 이상: 복잡)
  - 상호작용 수 (버튼, 입력 필드 등)
- **컴포넌트 분해 및 구현 순서 결정**
- **복잡도별 구현 전략 조절**:
  - 단순 컴포넌트: 즉시 구현
  - 중간 컴포넌트: 매핑 확인 후 구현
  - 복잡 컴포넌트: 하위 컴포넌트로 분해 후 구현

#### 컴포넌트 리스트 예시
```
1. CategoryTag (복잡도: 1)
2. QuantitySelector (복잡도: 2)
3. PriceDisplay (복잡도: 3)
4. DateTimeSection (복잡도: 5)
5. TreatmentItemCard (복잡도: 8)
```

### Phase 4: 적응형 반복 컴포넌트 구현 (Loop)

각 컴포넌트마다 다음 4단계를 반복 실행:

#### [반복 N/Total] {컴포넌트명} 구현

##### Step 1: 개별 컴포넌트 생성
- Figma 스펙 확인 → B2B 매핑 → 구현 → 검증
- modifier 파라미터 필수 포함
- B2B 디자인 시스템 정확히 매핑
- iconography.md 기준으로 아이콘 정확히 사용

##### Step 2: 즉시 빌드 테스트
```bash
# 부분 컴파일 테스트
./gradlew compileDevDebugKotlin --include-build

# 에러 발생 시
if (hasError) {
    fixImports()
    fixResourceReferences()
    recompile()
}
```

##### Step 3: Preview 생성 및 검증
- 개별 컴포넌트 Preview 작성
- Figma 디자인과 시각적 비교
- 색상, 간격, 크기 확인

##### Step 4: 진행 상황 보고
```
✅ [1/8] QuantitySelector 구현 완료 (2초)
✅ [2/8] CategoryTag 구현 완료 (1초)
✅ [3/8] PriceDisplay 구현 완료 (2초)
🔄 [4/8] TreatmentItemCard 구현 중...
```

### Phase 5: 점진적 통합 및 검증

#### 1. 중간 통합 테스트 (50% 완료 시점)
- 핵심 컴포넌트들 먼저 통합
- 기본 레이아웃 구조 검증
- 컴포넌트 간 상호작용 테스트

### Phase 6: 전체 통합 및 최종 검증

#### 1. 슬롯 패턴으로 통합

**BaseActivity 호환 슬롯 구조 적용:**
- 메인 Screen 컴포넌트 구성
- TopBarSlot, ContentSlot, BottomBarSlot 분리
- Scaffold 사용하지 않음 (BaseActivity 호환)
- 각 슬롯별 private 함수로 구현
- 콜백 함수들 파라미터로 전달

#### 2. modifier 활용 패턴

**스마트 modifier 처리:**
- 외부 주입: weight, size, align 등 레이아웃 관련
- 내부 적용: background, border, 컴포넌트 고유 스타일
- 모든 컴포넌트에 `modifier: Modifier = Modifier` 파라미터 필수

#### 3. 최종 빌드 테스트

```bash
./gradlew assembleDevDebug

# 성공 시
BUILD SUCCESSFUL in 16s
✅ 전체 통합 완료!

# 실패 시
if (hasError) {
    analyzeError()
    fixIntegrationIssues()
    rebuildAll()
}
```

#### 4. Figma 디자인 일치성 최종 검증

**검증 항목:**
1. **레이아웃 구조 검증**:
   - Figma 원본과 컴포넌트 배치 순서 비교
   - 섹션별 구조 (Header, Content, Footer) 일치 여부
   - 중첩 구조 (Card 내부 구성, List 아이템 구조 등) 확인

2. **디자인 시스템 매핑 재확인**:
   - `design-system.md` 매핑 테이블 기준으로 컴포넌트 올바른 사용 확인
   - 색상: Figma Color Token → ColorB2B 정확한 매핑
   - 타이포그래피: Figma Text Style → B2BTheme.typography 정확한 매핑
   - 간격: Figma Spacing → dp 값 정확한 변환

3. **세부 스타일 검증**:
   - 텍스트 크기, 색상, Weight 확인
   - 버튼 크기, 스타일, 라운딩 확인
   - 카드/컨테이너 배경색, 패딩, 마진 확인
   - 아이콘 크기, 위치, 색상 확인

4. **반응형 동작 확인**:
   - weight() 사용한 비율 레이아웃 Figma와 일치 여부
   - fillMaxWidth(), wrapContent 등 크기 동작 확인

**검증 실패 시 수정 사항:**
```
❌ Figma 디자인 불일치 발견:
- 제목 텍스트: titleL → titleM24로 변경 필요
- 카드 간격: 16.dp → 12.dp로 조정 필요
- 버튼 스타일: PRIMARY → SECONDARY로 변경 필요
```

## 반복적 구현의 장점

1. **빌드 속도 향상**:
   - 기존: 85초 (전체 한 번에)
   - 개선: 16초 (단계별 누적)
   - **81% 단축!**

2. **정확도 향상**:
   - 각 컴포넌트에 집중
   - 즉각적인 검증
   - Figma 일치도 95% 이상

3. **디버깅 용이**:
   - 문제 발생 위치 명확
   - 단계별 수정 가능
   - 롤백 용이

4. **재사용성**:
   - 독립적인 컴포넌트
   - 다른 화면에서 활용 가능
   - 컴포넌트 라이브러리 구축

## 에러 핸들링

### Figma URL 접근 불가
```
❌ Figma URL에 접근할 수 없습니다.
- URL이 올바른지 확인해주세요
- Figma 파일의 접근 권한을 확인해주세요
```

### 컴포넌트 구현 실패
```
❌ [3/8] DateTimeSection 구현 실패
- 에러: Unresolved reference 'ic_calendar'
- 해결: 대체 아이콘 'ic_check_calendar' 사용
✅ 재시도 후 성공
```

### 통합 단계 실패
```
❌ 슬롯 패턴 통합 실패
- 에러: Type mismatch in ContentSlot
- 해결: 파라미터 타입 수정
✅ 재빌드 후 성공
```

### 컴파일 에러 처리 규칙
1. **import 경로 검증**: Grep/Glob 도구로 실제 클래스 존재 확인
2. **리소스 파일 확인**: drawable, string 리소스 존재 여부 체크
3. **타입 에러 해결**: 파라미터 타입, 반환 타입 정확히 매칭
4. **에러 발생 시**: 작업을 멈추지 말고 대안 방법으로 해결
   - 없는 drawable → 기존 유사한 drawable 사용
   - 없는 컴포넌트 → 화면 전용 private 컴포넌트로 생성
   - import 에러 → 정확한 패키지 경로 찾아서 수정

## 특별 고려사항

### BaseActivity 호환성
- Scaffold 사용하지 않음
- 슬롯 패턴으로 topBar, bottomBar 분리
- B2BTheme는 BaseActivity에서 적용되므로 중복 적용 안함
- TopBar는 항상 기본 구현 제공 (생략하지 않음)

### 디자인 시스템 준수
- 모든 색상은 ColorB2B 사용
- 타이포그래피는 B2BTheme.typography 사용
- 간격은 design-system.md의 spacing 가이드 준수
- 기존 B2B 컴포넌트 최대한 활용

### modifier 패턴
- 모든 private 컴포넌트에 `modifier: Modifier = Modifier` 파라미터 필수
- 외부 주입 modifier와 내부 스타일 modifier 분리
- 확장성과 재사용성 극대화

### 성능 최적화
- LazyColumn 사용으로 긴 리스트 최적화
- remember와 derivedStateOf 활용
- 불필요한 recomposition 방지

## 완성 기준

✅ **필수 체크리스트:**
- [ ] `./gradlew assembleDevDebug` 성공 확인
- [ ] Android Studio에서 에러 없이 빌드 가능
- [ ] Preview가 정상적으로 렌더링
- [ ] 모든 import 문이 올바른 경로
- [ ] 런타임 에러 없이 실행 가능
- [ ] Figma 디자인과 95% 이상 일치

## 빌드 실패 시 반복 처리 흐름

1. **1차 빌드 실행**: `./gradlew assembleDevDebug`
2. **실패 시**: 에러 로그 분석
3. **에러 수정**: 컴파일 에러 해결
4. **재빌드**: 1단계로 돌아가서 반복
5. **성공 시**: Figma 디자인 일치성 검증 진행
6. **최종 확인**: 모든 체크리스트 완료

## 상세 문서

- 디자인 시스템: [design-system.md](../../../.docs/design-system.md)
- 버튼: [buttons.md](../../../.docs/design-system/buttons.md)
- 텍스트필드: [text-fields.md](../../../.docs/design-system/text-fields.md)
- 색상: [colors.md](../../../.docs/design-system/colors.md)
- 타이포그래피: [typography.md](../../../.docs/design-system/typography.md)
