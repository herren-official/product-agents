---
name: b2b-android-prd
description: 화면 명세서(PRD) 자동 생성. Activity명 또는 패키지 경로를 받아 코드 분석 후 4개 파일(화면/정책/상태/API)로 분리 작성한다. "PRD 만들어줘", "화면 명세서", "prd 생성", "화면 분석", "화면 문서화", "정책서 만들어줘" 요청 시 사용. 화면의 동작, 비즈니스 규칙, 상태 관리, API 연동을 문서화할 때 반드시 이 스킬을 사용할 것.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
user-invocable: true
---

# PRD (화면 명세서) 자동 생성

Activity명 또는 패키지 경로를 받아서 해당 화면의 코드를 분석하고, 4개 파일로 분리된 PRD를 자동 생성합니다.

## 📚 참고 문서

- [PRD 구조 및 템플릿](.docs/prd/README.md) - 파일 구조, 작성 규칙
- [Login PRD 예시](.docs/prd/app/login/login/) - 실제 작성된 PRD (login.md, login.policy.md, login.state.md, login.api.md)

---

## 사용법

```bash
/prd LoginActivity                    # Activity명으로 실행
/prd CustomerAddActivity              # 다른 화면
/prd tab/customers/add                # 패키지 경로로 실행
/prd login findId findPassword        # 여러 화면 동시 (각각 팀 에이전트)
```

---

## 실행 단계

### Step 1: 입력 분석 및 대상 파일 검색

#### 1-1. 입력 파싱

```bash
INPUT="$1"

# Activity명인 경우 (예: LoginActivity, CustomerAddActivity)
if [[ "$INPUT" == *"Activity"* ]]; then
    ACTIVITY_NAME="$INPUT"
    SCREEN_NAME="${INPUT%Activity}"  # Activity 접미사 제거
elif [[ "$INPUT" == *"/"* ]]; then
    # 패키지 경로인 경우 (예: tab/customers/add)
    PACKAGE_PATH="$INPUT"
fi
```

#### 1-2. 파일 검색

Activity명 또는 패키지 경로로 관련 파일을 검색한다:

```bash
# UI Layer 검색
find app/src/main/java -path "**/ui/**" -name "${SCREEN_NAME}*.kt" | sort

# 검색 대상:
# - {Screen}Activity.kt
# - {Screen}ViewModel.kt
# - {Screen}Contract.kt
# - {Screen}Screen.kt
# - {Screen}Display.kt (있는 경우)
```

```bash
# Network Layer 검색 (도메인명 추론)
# ViewModel에서 import하는 Repository/Service를 추적하여 network 모듈 파일 검색
grep -r "Repository\|Service" {ViewModel파일} | grep "import"
```

**파일을 못 찾은 경우**: 사용자에게 정확한 경로를 요청한다.

#### 1-3. 패키지 경로 결정

Activity 파일의 실제 위치에서 `ui/` 이후 경로를 추출하여 PRD 저장 경로를 결정한다:

```
공비서 (app 모듈):
실제 위치: app/src/main/java/.../ui/login/LoginActivity.kt
PRD 경로: .docs/prd/app/login/login/

실제 위치: app/src/main/java/.../ui/tab/customers/add/CustomerAddActivity.kt
PRD 경로: .docs/prd/app/tab/customers/customerAdd/

비즈콜 (bizcall 모듈):
실제 위치: gongbiz-crm-bizcall/src/main/java/.../callLog/CallLogActivity.kt
PRD 경로: .docs/prd/bizcall/callLog/
```

**모듈 판별:**
- `app/src/main/java` 하위 → `.docs/prd/app/`
- `gongbiz-crm-bizcall/src/main/java` 하위 → `.docs/prd/bizcall/`

**네이밍 규칙:**
- 디렉토리: 모듈 구분(`app/` or `bizcall/`) + UI 패키지 구조 미러링
- 화면 디렉토리: Activity명에서 `Activity` 제거, camelCase (첫 글자 소문자)
- 파일명: `{camelCase화면명}.md`, `{camelCase화면명}.policy.md` 등

---

### Step 2: 파일별 병렬 분석

검색된 파일 수만큼 서브 에이전트(Explore)를 **1:1 병렬** 스폰한다. 각 서브 에이전트는 **1개 파일만 전담**하여 전체 읽기 + 분석한다.

> **핵심**: 파일 개수 = 서브 에이전트 수. 각 서브가 1파일만 담당하므로 컨텍스트 부담 없이 깊이 있는 분석이 가능하다.

```
예시: LoginActivity (파일 6개 → 서브 6개)
├── Sub 1: LoginActivity.kt       → 진입/이탈, Intent, SideEffect 처리, 생명주기
├── Sub 2: LoginViewModel.kt      → 모든 함수, 비즈니스 규칙, API 호출
├── Sub 3: LoginContract.kt       → UiState 필드, SideEffect, 계산 프로퍼티
├── Sub 4: LoginScreen.kt         → UI 트리, 인터랙션, 조건부 렌더링
├── Sub 5: LoginService.kt        → API 엔드포인트, 요청 파라미터
└── Sub 6: LoginRepository.kt     → Repository 구현, Entity → Flow 변환

예시: CustomerDetail (파일 12개 → 서브 12개)
├── Sub 1: CustomerDetailActivity.kt
├── Sub 2: CustomerDetailViewModel.kt
├── Sub 3: CustomerDetailContract.kt
├── Sub 4: CustomerDetailScreen.kt
├── Sub 5: CustomerDetailSaleTabDisplay.kt
├── Sub 6: CustomerDetailBookTabDisplay.kt
├── Sub 7: CustomerDetailMemoDisplay.kt
├── Sub 8: CustomerService.kt
├── Sub 9: CustomerRepository.kt
├── Sub 10: CustomerEntity.kt
├── Sub 11: CustomerVo.kt
└── Sub 12: strings.xml (에러 메시지 등 관련 문자열)
```

#### 각 서브 에이전트 프롬프트 (파일 유형별)

**Activity 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. 진입 경로 (이 Activity를 startActivity하는 코드 전부 검색)
2. Intent 파라미터 (putExtra, getExtra, companion object 상수)
3. handleSideEffect 처리 분기
4. handleUiState 처리
5. onBackPressed / BackHandler
6. 화면 전환 (startActivity, finish, setResult)
7. 생명주기 처리 (onCreate, onResume 등)
thoroughness: very thorough
""")
```

**ViewModel 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. 모든 public/private 함수 목록 + 동작 설명
2. reduceState 호출 전수 (어떤 함수에서 어떤 상태 변경)
3. postSideEffect 호출 전수
4. viewModelLaunch 내부 API 호출 패턴
5. 비즈니스 규칙 / 조건문 분기 (모든 if/when)
6. 에러 처리 패턴
7. init 블록 동작
thoroughness: very thorough
""")
```

**Contract 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. UiState 전체 필드 (필드명, 타입, 기본값, 용도)
2. 계산 프로퍼티 (get() 커스텀 게터)
3. copy() 오버라이드 구조
4. UiSideEffect 전체 케이스
5. UiEvent 전체 케이스 (있는 경우)
6. 하위 data class (PhoneNumberCertification 등)
7. 상태 전이 흐름
thoroughness: very thorough
""")
```

**Screen / Display 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. UI 레이아웃 트리 (ASCII)
2. 각 UI 요소 + 스타일/크기/색상
3. 조건부 렌더링 (if/when)
4. 버튼 활성화/비활성화 조건
5. 상태별 UI 렌더링 테이블
6. 모든 클릭/입력/IME 이벤트 → 콜백 매핑
7. Display 전환 조건 (여러 Display인 경우)
thoroughness: very thorough
""")
```

**Service 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. 모든 API 엔드포인트 (HTTP 메서드, URL)
2. 요청 헤더, 쿼리 파라미터, Path 파라미터, Body
3. 응답 타입 (NetworkResponse / ResponseBase / ResponsePaging)
4. 관련 Entity/Body 클래스 경로
thoroughness: very thorough
""")
```

**Repository 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. 모든 메서드 (suspend vs Flow 구분)
2. Service 호출 매핑
3. 에러 처리
thoroughness: very thorough
""")
```

**Entity / VO 파일:**
```
Agent(subagent_type="Explore", prompt="""
{파일경로}를 전체 읽고 분석:
1. 전체 필드 (필드명, 타입, nullable 여부)
2. 중첩 data class 구조
3. mapperToVo() 매핑 함수 (있는 경우)
4. default() 처리 패턴
thoroughness: very thorough
""")
```

---

### Step 3: 취합 서브 에이전트 (4개 병렬)

분석 결과를 카테고리별 취합 서브 에이전트에게 전달하여 파일을 작성한다. 각 취합 에이전트는 **필요한 분석 결과만** 받아서 해당 파일을 Write한다.

```
취합 에이전트 4개 (병렬):
├── Sub: {화면}.md 작성       ← Activity + Screen + Display 분석 결과
├── Sub: {화면}.policy.md 작성 ← ViewModel 분석 결과
├── Sub: {화면}.state.md 작성  ← Contract 분석 결과
└── Sub: {화면}.api.md 작성    ← Service + Repository + Entity/VO 분석 결과
```

> **분량 판단**: 각 취합 에이전트는 작성 전 예상 분량을 판단하고, 200줄 초과 시 자동 분리한다 (Step 3-1 참조).

#### 취합 에이전트 프롬프트

```
Agent(
  subagent_type="general-purpose",
  mode="auto",
  prompt="""
  아래 분석 결과를 바탕으로 {파일경로}에 PRD 문서를 작성해줘.
  
  [분석 결과]
  {해당 카테고리의 분석 결과들}
  
  [템플릿]
  {아래 파일별 템플릿}
  
  [분리 규칙]
  - 200줄 이하: 단일 파일로 Write
  - 200줄 초과: 기능/탭/도메인별로 분리하여 여러 파일로 Write
    - 메인 파일에는 공통 내용 + 하위 파일 참조 링크 추가
    - 하위 파일명: {화면}.{카테고리}.{기능}.md (예: customerDetail.policy.sale.md)
  
  [작성 규칙]
  - 한국어, 자연어로 동작 설명
  - 조건문/분기는 구체적으로
  - 실제 문자열 리소스 값 사용
  """
)
```

### Step 3-1: 200줄 초과 시 자동 분리 전략

취합 에이전트가 분량을 판단하여 자동으로 파일을 분리한다.

#### 분리 차원 (파일 타입별)

| 파일 | 분리 기준 | 예시 |
|------|---------|------|
| `{화면}.md` | Display 컴포넌트 단위 | `customerDetail.md` + `customerDetail.saleTab.md` |
| `{화면}.policy.md` | 기능/탭 영역 단위 | `customerDetail.policy.md` + `customerDetail.policy.sale.md` |
| `{화면}.state.md` | 하위 data class 단위 | `customerDetail.state.md` + `customerDetail.state.saleTab.md` |
| `{화면}.api.md` | API Service 도메인 단위 | `customerDetail.api.md` + `customerDetail.api.sale.md` |

#### 분리 시 메인 파일 구조

```markdown
# 고객 상세 - 비즈니스 규칙 (CustomerDetailActivity)

## 1. 공통 정책
(공통 내용: 권한 체크, 데이터 변경 감지 등)

## 탭별 상세 정책
- [매출 탭 정책](customerDetail.policy.sale.md)
- [멤버십 정책](customerDetail.policy.membership.md)
- [시술 이력 정책](customerDetail.policy.booking.md)
```

#### 단순 화면 vs 복잡한 화면 예시

```
단순 (Login - 4파일):
login/
├── login.md
├── login.policy.md
├── login.state.md
└── login.api.md

복잡 (CustomerDetail - 12파일):
customerDetail/
├── customerDetail.md
├── customerDetail.saleTab.md
├── customerDetail.bookTab.md
├── customerDetail.policy.md
├── customerDetail.policy.sale.md
├── customerDetail.policy.membership.md
├── customerDetail.state.md
├── customerDetail.state.saleTab.md
├── customerDetail.api.md
├── customerDetail.api.customer.md
├── customerDetail.api.sale.md
└── customerDetail.api.membership.md
```

---

### Step 4: 파일별 템플릿

#### 파일 1: `{화면}.md` — 화면 개요 + UI + 인터랙션

```markdown
# {화면명} ({ActivityClass})

## 1. 개요
화면 목적, 아키텍처 (MVI/MVVM), 핵심 파일 테이블

## 2. 진입 경로 및 파라미터
진입 화면, Intent 파라미터, 진입 시 초기화

## 3. UI 구성
ASCII 레이아웃 트리, 각 UI 요소 설명, 상태별 렌더링 테이블, 버튼 활성화 조건

## 4. 사용자 인터랙션
모든 이벤트 → 동작 매핑 테이블, 뒤로가기, 키보드

## 5. SideEffect / 화면 전환
모든 SideEffect → Activity 처리 매핑

## 6. 관련 화면
진입/이탈 화면 테이블
```

#### 파일 2: `{화면}.policy.md` — 비즈니스 규칙 + 엣지 케이스

```markdown
# {화면명} - 비즈니스 규칙 ({ActivityClass})

## 1. 유효성 검증
클라이언트/서버 검증 규칙

## 2. 주요 정책
(화면별 상이 - 로그인 정책, 인증 정책, 저장 정책 등)

## 3. 에러 처리 정책
에러 메시지 (실제 strings.xml 값), 재시도 정책

## 4. 엣지 케이스
네트워크 에러, 빈 응답, 연속 클릭, 타이머 만료, 백그라운드 복귀 등
```

#### 파일 3: `{화면}.state.md` — 상태 관리

```markdown
# {화면명} - 상태 관리 ({ActivityClass})

## 1. UiState 필드
전체 필드 테이블 (필드명, 타입, 기본값, 용도)

## 2. 계산 프로퍼티
계산식과 용도

## 3. 하위 데이터 클래스
PhoneNumberCertification, TimerItem 등 (있는 경우)

## 4. 상태 전이 흐름
초기 → 중간 → 최종 흐름도
```

#### 파일 4: `{화면}.api.md` — API 연동

```markdown
# {화면명} - API 연동 ({ActivityClass})

## 1. {API 엔드포인트별}
엔드포인트, HTTP 메서드, 요청 파라미터, 응답 구조, 호출 시점

## 2. Entity 구조
전체 필드 테이블

## 3. VO 매핑
Entity → VO 변환 규칙

## 4. 에러 처리
HTTP 에러별 분기, ErrorResponse 구조
```

---

### Step 5: 디렉토리 생성 및 Write

```bash
# 디렉토리 생성
mkdir -p .docs/prd/{패키지경로}/{화면명camelCase}/

# 취합 에이전트가 직접 Write (4개 이상 파일)
# 200줄 이하 → 4파일
# 200줄 초과 → 분리된 파일 추가 생성
```

### Step 6: CHECKLIST.md 업데이트

PRD 생성 완료 후 `.docs/prd/CHECKLIST.md`의 해당 화면 항목을 `[x]`로 체크하고, 진행률 테이블을 업데이트한다.

```bash
# 예: CustomerAddActivity PRD 완료 시
# - [ ] add — CustomerAddActivity  →  - [x] add — CustomerAddActivity

# 진행률 테이블도 업데이트
# | tab/customers | 14 | 15 | 93% |  →  | tab/customers | 15 | 15 | 100% |
# | **전체** | **29** | **117** | **24.8%** |  →  업데이트
```

---

## 여러 화면 동시 처리

여러 화면을 한 번에 요청받은 경우, 화면별로 **독립적인 병렬 처리**를 수행한다.

각 화면은 다음과 같은 구조로 처리된다:
1. 화면별로 서브 에이전트 3개 병렬 스폰 (viewmodel/ui/data)
2. 결과 취합 후 4개 파일 Write
3. 모든 화면이 완료되면 결과 요약 보고

```
/prd LoginActivity FindIdActivity FindPasswordActivity

→ LoginActivity:     Sub(VM) + Sub(UI) + Sub(API) → 4파일 Write
→ FindIdActivity:    Sub(VM) + Sub(UI) + Sub(API) → 4파일 Write
→ FindPasswordActivity: Sub(VM) + Sub(UI) + Sub(API) → 4파일 Write
```

---

## 작성 규칙

### 필수
- **한국어** 작성
- **자연어**로 동작 설명 (코드 붙여넣기 아님)
- 조건문/분기는 **구체적으로** 명시 ("유효성 검증 있음" ❌ → "ID/PW 모두 입력 시 버튼 활성화" ✅)
- 실제 **문자열 리소스 값** 사용 (strings.xml에서 확인, 추측 금지)
- UiState 필드는 **전수 조사** (누락 금지)
- SideEffect는 **전수 조사** (누락 금지)
- API 파라미터는 **실제 코드의 파라미터명** 사용

### 금지
- 코드 복붙 (자연어 설명으로 변환)
- 추상적 표현 ("에러 처리 있음", "데이터 로드", "화면 업데이트")
- 문자열 리소스 추측 (반드시 strings.xml 확인)
- 분석 대상 파일 부분 읽기 (전체 읽기 필수)

---

## 완료 보고

모든 파일 생성 후 결과를 요약한다:

```
PRD 생성 완료: {화면명}

📁 생성된 파일:
├── .docs/prd/{경로}/{화면}.md           ← 개요, UI, 인터랙션
├── .docs/prd/{경로}/{화면}.policy.md    ← 비즈니스 규칙, 엣지 케이스
├── .docs/prd/{경로}/{화면}.state.md     ← UiState, 상태 전이
└── .docs/prd/{경로}/{화면}.api.md       ← API, Entity, VO

📊 분석 결과:
- ViewModel 함수: N개
- UiState 필드: N개
- SideEffect: N개
- API 엔드포인트: N개
- 엣지 케이스: N건
```

---

## 기존 PRD 업데이트

이미 PRD가 존재하는 화면을 다시 분석하는 경우:

1. 기존 4개 파일을 Read
2. 서브 에이전트로 코드 재분석
3. 변경된 부분만 Edit으로 반영 (전체 재작성 아님)
4. 변경 사항 diff 요약 보고

---

## 상세 문서

PRD 구조: [.docs/prd/README.md](.docs/prd/README.md)
