---
name: b2b-web-resolve-icon
---

# 아이콘 매핑 & 검증 가이드

## 트리거
컴포넌트에서 아이콘을 사용할 때, 또는 `/create-common-component` Phase 6에서 아이콘 검증이 필요할 때 실행됩니다.

## 핵심 원칙

> **절대 규칙**: 아이콘을 자체 제작하지 않는다. 디자인 시스템에 정의된 아이콘만 사용하고, 색상은 CSS로 변경한다.

1. **디자인 시스템 Iconography 페이지가 유일한 소스** — 여기에 없는 아이콘은 사용 불가
2. **코드베이스에서 동일 모양 검색** — 이름이 달라도 모양이 같으면 재사용
3. **색상은 CSS 오버라이드** — SVG 파일을 새로 만들지 않음
4. **없으면 디자이너에게 요청** — 임의로 SVG를 만들거나 Figma에서 다운받지 않음

---

## 워크플로우

### Step 1: Figma 디자인 시스템에서 아이콘 확인

컴포넌트에 필요한 아이콘이 Figma Iconography 페이지에 있는지 확인합니다.

```
1. Figma Iconography 페이지 열기
   - URL: https://www.figma.com/design/50JaNq4enFRlGgprzaced4/공비서-디자인-시스템?node-id=449-7077
   - 또는 get_metadata로 아이콘 목록 조회

2. 컴포넌트가 사용하는 아이콘의 Figma 이름 확인
   - get_design_context로 컴포넌트 분석 시 img 상수에서 아이콘 이름 추출
   - 예: data-name="screamer", data-name="etc", id="Exclude" 등

3. Iconography 페이지에서 해당 아이콘 찾기
   - 카테고리별 검색: System, Etc, Badge, Reserve state 등
   - get_screenshot으로 아이콘 모양 시각적 확인
```

### Step 2: 코드베이스에서 동일 모양 검색

**이름이 아닌 모양으로 매칭합니다.** 같은 모양이 다른 이름으로 이미 존재할 수 있습니다.

```
1. 전체 아이콘 파일 목록 확인
   ls src/assets/design-system/icons/

2. 후보군 좁히기 — 키워드로 필터링
   ls src/assets/design-system/icons/ | grep -i "check\|success\|fail\|warning\|info\|screamer"

3. SVG 파일 내용 직접 확인 — 모양 대조
   cat src/assets/design-system/icons/icon-etc-*.svg
   
   확인 포인트:
   - 외곽 도형: circle? triangle? rectangle?
   - 내부 기호: checkmark? X? "!"? "i"?
   - path 수: 1개(cutout)? 2개(외곽+내부)?

4. svgr.tsx에서 등록 이름 확인
   grep "icon-etc-success\|icon-etc-fail" src/components/common/Icon/svgr.tsx
```

**자주 발견되는 동일 모양 패턴:**

| 필요한 모양 | 가능한 기존 이름들 |
|-----------|-----------------|
| 원 + 체크 | `etcSuccess`, `etcCheck`, `crCheck` |
| 원 + X | `etcFail`, `systemRoundX` |
| 원 + ! | `etcScreamer` |
| 삼각형 + ! | `etcWarning` |
| 원 + i | `systemInfo` |

### Step 3: 색상 변경 방식 결정

기존 아이콘의 SVG 구조에 따라 CSS 오버라이드 방식이 달라집니다.

#### 패턴 A: 단색 아이콘 (path 1개, 또는 모든 path 같은 색)

```
SVG 구조: <path fill="#20232B"/>
CSS: svg { path { fill: ${color}; } }
```
예: `systemInfo`, `systemCheck`, `badgeWarning`

#### 패턴 B: 이중색 아이콘 (외곽 colored + 내부 white)

```
SVG 구조:
  <path fill="#227EFF"/>     ← 외곽 (첫 번째 path)
  <path fill="white"/>       ← 내부 (두 번째 path)

CSS: svg { path:first-child { fill: ${color}; } }
```
예: `etcScreamer`, `etcFail`, `etcSuccess`, `etcWarning`

**구분 방법**: SVG 파일을 열어 `fill="white"` 또는 `fill="#FFFFFF"`가 있으면 이중색 → `path:first-child` 패턴 사용

#### 패턴 C: evenodd cutout (path 1개, fill-rule="evenodd")

```
SVG 구조: <path fill-rule="evenodd" fill="#227EFF"/>
CSS: svg { path { fill: ${color}; } }
```
cutout 영역은 배경이 보임 (투명). 이 경우 단색 오버라이드로 충분.

### Step 4: 매핑 결과 보고

```markdown
## 아이콘 매핑 결과

### 매핑 테이블
| 용도 | Figma 아이콘 | 코드 아이콘 | SVG 파일 | 색상 패턴 | 상태 |
|------|------------|-----------|---------|----------|------|
| Info | screamer | etcScreamer | icon-etc-screamer.svg | path:first-child | 기존 사용 |
| Success | Check | etcSuccess | icon-etc-success.svg | path:first-child | 기존 사용 |
| Warning | Warning | etcWarning | icon-etc-warning.svg | path:first-child | 기존 사용 |
| Error | fail | etcFail | icon-etc-fail.svg | path:first-child | 기존 사용 |

### 신규 SVG 파일
- 없음 (모두 기존 아이콘 활용)

### 조치 필요
- 없음 / [디자이너에게 요청 필요한 아이콘 목록]
```

---

## 안티패턴 (하지 말 것)

1. **SVG 자체 제작** — 디자인 시스템에 없는 아이콘을 직접 만들지 않음
2. **Figma 에셋 서버에서 다운로드** — localhost:3845에서 받은 SVG는 임시 에셋, 코드베이스에 추가하지 않음
3. **이름만 보고 판단** — `systemCheck`(체크만)와 `etcSuccess`(원+체크)는 이름이 비슷해도 모양이 다름
4. **currentColor 패턴** — 프로젝트 컨벤션은 `svg path { fill }` 오버라이드, `currentColor`는 사용하지 않음
5. **모든 path에 fill 적용** — 이중색 아이콘에서 `svg path { fill }` 하면 흰색 내부까지 덮어씀 → `path:first-child` 사용

## 참조

- Figma Iconography: `node-id=449-7077`
- 아이콘 파일 위치: `src/assets/design-system/icons/`
- 아이콘 등록: `src/components/common/Icon/svgr.tsx`
- 기존 색상 오버라이드 참고: `src/components/Naver/.../SettlementStatusSection.styles.ts` (`path:first-child` 패턴)
