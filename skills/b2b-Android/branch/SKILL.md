---
name: b2b-android-branch
description: 브랜치 자동 생성. "브랜치 만들어줘", "branch 생성", "새 브랜치" 요청 시 사용
allowed-tools: Bash, Read, Grep, mcp__notionMCP__notion-search, mcp__notionMCP__notion-fetch
user-invocable: true
---

# 브랜치 생성 스킬

GBIZ 번호 또는 Notion 링크를 기반으로 컨벤션에 맞는 브랜치를 생성한다.

## 실행 단계

### 1단계: 컨벤션 확인
`.docs/conventions/branch-convention.md` 파일 읽기

현재 브랜치 상태도 함께 확인:
```bash
git branch --show-current
git status --porcelain
```

### 2단계: 입력 분석 및 GBIZ 번호 확인

- **GBIZ 번호 직접 입력**: `GBIZ-XXXXX` 패턴 감지
- **숫자만 입력**: `20756` → 자동으로 `GBIZ-20756`으로 변환
- **Notion URL 입력**: URL에서 GBIZ 번호 추출 또는 Notion 카드에서 GBIZ 번호 검색
- **간단한 설명과 함께**: `GBIZ-18655 인센티브 설정` 형태로 입력 가능
- **Base 브랜치 지정**: 두 번째 인자로 base 브랜치 명시 (선택사항)

#### GBIZ 번호 정규화
```bash
INPUT="$1"
# 숫자만 입력된 경우 GBIZ- 접두사 자동 추가 (4자리 이하는 5자리로 0 패딩)
if [[ "$INPUT" =~ ^[0-9]+$ ]]; then
    if [[ ${#INPUT} -le 4 ]]; then
        INPUT=$(printf "%05d" "$INPUT")
    fi
    GBIZ_NUMBER="GBIZ-$INPUT"
    echo "📌 숫자를 GBIZ-$INPUT으로 변환"
elif [[ "$INPUT" =~ (GBIZ-[0-9]+) ]]; then
    GBIZ_NUMBER="${BASH_REMATCH[1]}"
else
    # Notion URL 또는 기타 형식 처리
    GBIZ_NUMBER=""
fi
```

- 4자리 이하 숫자는 5자리로 0 패딩 (예: `8655` → `GBIZ-08655`, `123` → `GBIZ-00123`)

### 3단계: Notion 카드 검색

GBIZ 번호로 작업 카드 검색하여 제목/내용 파악:

```bash
# GBIZ 번호로 Notion 작업 카드 검색
mcp__notionMCP__notion-search --query "GBIZ-XXXXX"
# 또는 Notion URL로 직접 페치
mcp__notionMCP__notion-fetch --id "notion-page-id"
```

- **카드 제목 분석**: 작업 내용 파악
- **카드 설명 분석**: 상세 작업 내용 확인
- **외부 링크 수집**: Figma, API 문서 등 참고 자료

### 4단계: Feature Type 결정

Feature Type은 **고정된 목록이 아니며**, 에픽/작업 성격에 따라 자유롭게 결정된다.

아래 우선순위에 따라 **순서대로 판단**하며, 먼저 매칭되는 단계에서 결정한다:

#### 우선순위 1: 부모가 feature 브랜치 → feature-type 상속

현재(부모) 브랜치가 `{feature-type}/GBIZ-` 패턴인 경우, feature-type을 그대로 상속한다.

```bash
CURRENT_BRANCH=$(git branch --show-current)

if [[ "$CURRENT_BRANCH" =~ ^([a-z-]+)/GBIZ- ]]; then
    FEATURE_TYPE="${BASH_REMATCH[1]}"
    echo "📌 부모 브랜치의 Feature Type 상속: $FEATURE_TYPE"
fi
```

#### 우선순위 2: 부모가 그 외 브랜치 → Notion 에픽 속성에서 결정

부모 브랜치가 `dev`, `main`, 버전 브랜치(`b2b/8.10.11`), 기타 브랜치인 경우,
Notion 카드의 **에픽 속성**을 조회하여 feature-type을 결정한다.

**MCP 호출 흐름**:
1. `mcp__notionMCP__notion-fetch`로 GBIZ 카드 페이지 조회
2. 응답의 `properties`에서 **"에픽"** 필드의 URL(relation) 추출
3. 에픽 URL로 다시 `mcp__notionMCP__notion-fetch` 호출하여 에픽 페이지 조회
4. 에픽 제목에서 키워드를 추출하여 feature-type 매핑
   - 예: "인센티브 정책 개편" → `incentive`
   - 예: "캘린더 리뉴얼" → `calendar`
   - 예: "Shop UX 개선" → `shop-ux`
5. 에픽 속성이 없으면 → **우선순위 3으로 폴백**

#### 우선순위 3: 에픽도 없는 경우 → Notion 카드 제목 키워드로 추론

에픽 속성이 없거나 에픽에서 feature-type을 결정할 수 없는 경우,
Notion 카드 제목의 키워드를 기반으로 추론한다.

- **키워드 매칭**:
  - "인센티브" → `incentive`
  - "통계" → `statistics`
  - "고객" → `customer`
  - "예약" → `reservation`
  - "매출" → `sale`
  - "직원" → `worker`
  - "캘린더" → `calendar`
- **기본값**: 명확하지 않으면 `b2b` 사용

**자주 사용되는 Feature Type 예시**:
- `b2b`, `incentive`, `calendar`, `statistics`
- `customer`, `sale`, `worker`, `reservation`
- `shop-ux`, `epic-{name}` 등

### 5단계: 작업 타입 자동 결정

카드 제목과 내용을 분석하여 작업 타입 결정:

- **"추가", "구현", "개발"** → `feat`
- **"수정", "개선", "변경"** → `fix` 또는 `feat`
- **"UI", "화면", "디자인"** → `ui`
- **"테스트", "test"** → `test`
- **"리팩토링", "refactor"** → `refactor`
- **"문서", "가이드"** → `docs`
- **"설정", "환경"** → `chore`

| 타입 | 설명 | PR Label |
|------|------|----------|
| `feat` | 새 기능 | Feature |
| `fix` | 버그 수정 | BugFix |
| `ui` | UI/UX | UI |
| `refactor` | 리팩토링 | Refactor |
| `test` | 테스트 | Test |
| `chore` | 설정 | Setting |

### 6단계: 브랜치명 생성

```
{feature-type}/{GBIZ-번호}-{작업타입}-{간략한-설명}
```

#### 간략한 설명 생성 규칙
- Notion 카드 제목에서 플랫폼 태그 제거: `[CRM][Android]` 등
- 핵심 키워드만 추출하여 하이픈으로 연결
- 최대 3-4개 단어로 제한
- 소문자 변환 및 특수문자 제거

예시:
- `incentive/GBIZ-18655-feat-incentive-setting-logic`
- `calendar/GBIZ-18607-feat-product-sale-day-ui-logic`
- `b2b/GBIZ-18651-test-viewmodel-unit-test`

### 7단계: Base 브랜치 결정

#### 자동 결정 (인자 없는 경우)
```bash
# ⚠️ 중요: 항상 현재 브랜치를 기준으로 생성
CURRENT_BRANCH=$(git branch --show-current)
BASE_BRANCH="$CURRENT_BRANCH"  # 무조건 현재 브랜치에서 분기

echo "📌 현재 브랜치: $CURRENT_BRANCH"
echo "🔀 새 브랜치를 현재 브랜치에서 생성합니다"
```

#### 수동 지정 (두 번째 인자)
```bash
# 사용 예시
/branch GBIZ-18655 dev           # dev를 base로 지정
/branch GBIZ-18655 main          # main을 base로 지정
/branch GBIZ-18655               # 자동 결정
```

### 8단계: 브랜치 생성 프로세스

#### 8-1. 사전 확인
```bash
# Base 브랜치 존재 확인
git show-ref --verify --quiet refs/heads/$BASE_BRANCH || \
git show-ref --verify --quiet refs/remotes/origin/$BASE_BRANCH

# 생성할 브랜치명이 이미 존재하는지 확인
git show-ref --verify --quiet refs/heads/$NEW_BRANCH_NAME
```

#### 8-2. 현재 브랜치 상태 확인
```bash
echo "✨ 현재 브랜치 '$CURRENT_BRANCH'에서 새 브랜치를 생성합니다"
```

#### 8-3. 브랜치 생성
```bash
# 브랜치 생성 및 전환
git checkout -b $NEW_BRANCH_NAME

# 성공 메시지
echo "✅ 브랜치 생성 완료: $NEW_BRANCH_NAME"
echo "📋 Base 브랜치: $BASE_BRANCH"
echo "🔗 Notion 카드: $NOTION_URL"
```

## 에러 처리

### GBIZ 번호 추출 실패
```bash
if [[ ! "$INPUT" =~ GBIZ-[0-9]+ ]]; then
  echo "❌ GBIZ 번호를 찾을 수 없습니다."
  echo "💡 사용법: /branch GBIZ-18655 또는 Notion URL"
  exit 1
fi
```

### Notion 카드 검색 실패
```bash
if [[ -z "$NOTION_TITLE" ]]; then
  echo "⚠️ Notion 카드를 찾을 수 없습니다."
  echo "📝 기본 템플릿으로 브랜치를 생성하시겠습니까?"
  # 기본 브랜치명: b2b/$GBIZ_NUMBER-feat-new-feature
fi
```

### 브랜치명 중복
```bash
if git show-ref --verify --quiet refs/heads/$NEW_BRANCH_NAME; then
  echo "❌ 브랜치가 이미 존재합니다: $NEW_BRANCH_NAME"
  echo "🔄 다른 이름을 사용하거나 기존 브랜치로 전환하시겠습니까?"
  exit 1
fi
```

## 에픽 → Feature Type 매핑

Notion 에픽 이름에서 feature-type을 추출:
- 에픽 이름을 소문자로 변환하여 그대로 사용
- 공백은 하이픈(-)으로 대체
- 예: "Shop UX 개선" → `shop-ux`

## 사용 예시

### 예시 1: 현재 브랜치에서 분기 (feature type 상속)
```bash
# 현재 브랜치: incentive/GBIZ-18655-feat-incentive-setting-logic
# 입력: GBIZ-18673
# Notion 카드: "[CRM][Android] 클로드 자동 PR 테스트 카드"
# 생성된 브랜치: incentive/GBIZ-18673-test-claude-auto-pr  # ✅ incentive 유지
# (NOT: test/GBIZ-18673-... ❌)
```

### 예시 2: dev 브랜치에서 새로 시작
```bash
# 현재 브랜치: dev
# 입력: https://www.notion.so/24148de8e0ea809d8182f5f78f33655d
# Notion 카드: "[CRM][Android] 통계 일별 조회 방식 개선"
# 생성된 브랜치: statistics/GBIZ-18607-feat-daily-statistics-improvement
```

### 예시 3: Base 브랜치 직접 지정
```bash
# 입력: GBIZ-18324 dev
# Notion 카드: "[CRM][Android] 고객 상세 플로팅 버튼 UI 개선"
# Base 브랜치: dev (직접 지정)
# 생성된 브랜치: customer/GBIZ-18324-ui-customer-detail-floating-button
```

## 성공 시 다음 단계 안내

```bash
echo "🚀 다음 단계:"
echo "1. 코드 작업을 시작하세요"
echo "2. 작업 완료 후: /commit으로 커밋"
echo "3. PR 생성: /pr로 자동 PR 생성"
echo ""
echo "📖 참고 문서:"
echo "- Notion 카드: $NOTION_URL"
# Figma 링크가 있으면 함께 표시
```

## 핵심 규칙

### ✅ 필수
- GBIZ 번호 포함
- 소문자 사용
- 하이픈으로 단어 구분
- **부모 브랜치가 dev 아니면 → 부모 브랜치 feature-type 유지**
- **부모 브랜치가 dev면 → Notion 에픽 기반 feature-type 사용**

### ⛔ 금지
- 대문자 사용
- 언더스코어 사용
- GBIZ 번호 없이 생성

## 사용법

```bash
/branch 20756                        # 숫자만 → GBIZ-20756으로 자동 변환
/branch GBIZ-18655                   # GBIZ 번호로 자동 브랜치 생성
/branch 18655 dev                    # 숫자 + base 브랜치 지정
/branch GBIZ-18655 dev              # GBIZ 번호 + base 브랜치 지정
/branch https://notion.so/...       # Notion URL로 브랜치 생성
/branch "GBIZ-18655 인센티브 설정"     # 설명과 함께 브랜치 생성
```

## 상세 문서

컨벤션: [branch-convention.md](../../../.docs/conventions/branch-convention.md)
