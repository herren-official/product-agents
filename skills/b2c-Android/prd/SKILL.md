---
name: b2c-android-prd
description: B2C feature 모듈의 화면 명세서(PRD) 자동 생성. feature 모듈명 또는 Screen명을 받아 코드 분석 후 `.docs/prd/{feature}.md` 를 작성/업데이트한다. "PRD 만들어줘", "화면 명세서", "prd 생성", "화면 분석", "화면 문서화", "정책서 만들어줘" 요청 시 사용.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent
user-invocable: true
---

# PRD (화면 명세서) 자동 생성 (B2C)

B2C feature 모듈 단위로 PRD 를 생성한다. B2C는 Compose Navigation + Route 기반이며 feature 모듈 = PRD 1개 원칙을 따른다.

**반드시 먼저 읽을 문서**
- `.docs/prd/README.md` — 전체 PRD 색인
- `.docs/prd/login.md` 또는 `.docs/prd/shop-detail.md` — 좋은 참고 예시

## 사용법

```
/prd payment                     # feature 모듈 이름 (feature/payment/ 전체 분석)
/prd booking-process             # 하이픈 포함
/prd shop-detail                 # 동일
/prd LoginScreen                 # 특정 Screen 파일명 (해당 feature 모듈 추론)
/prd payment review              # 여러 모듈 순차 처리
```

## 실행 단계

### 1단계: 입력 파싱 및 대상 결정

1. **feature 모듈명인지 확인**: `feature/{name}/` 존재 여부
   ```bash
   ls /Users/herren/Documents/GitHub/gongbiz-b2c-android/feature/ | grep -i "^{input}$"
   ```
2. **Screen 파일명인 경우**: `find` 으로 소속 feature 추적
   ```bash
   find /Users/herren/Documents/GitHub/gongbiz-b2c-android/feature -name "{input}.kt" -path "*/src/main/*"
   ```
3. **기존 PRD 존재 확인**: `.docs/prd/{feature}.md` 존재 여부 — 있으면 **업데이트 모드**, 없으면 **신규 생성 모드**

### 2단계: 모듈 구조 파악

feature 모듈 내부 전체 파일 목록 + 역할 식별:

```bash
# 전체 파일 트리
find /Users/herren/Documents/GitHub/gongbiz-b2c-android/feature/{name}/src/main/java -name "*.kt"
```

식별해야 할 카테고리:
- **Screen**: `{Name}Screen.kt` (Route + Screen composable)
- **ViewModel**: `{Name}ViewModel.kt`
- **Contract**: `{Name}Contract.kt` (UiState / SideEffect / ActionEvent)
- **Navigation**: `graph/{Name}Navigation.kt`, Route 정의는 `core:navigation`
- **Component**: `component/` 또는 `componenet/` 하위 재사용 컴포넌트
- **UseCase**: `core:domain` 에 관련된 파일 (Import 추적)
- **Repository / Service**: `core:data-api` / `core:data` 의 관련 파일 (Import 추적)

> B2C는 Activity 기반이 아니다. **Route / Screen / ViewModel / Contract 가 최소 단위**.

### 3단계: 파일별 병렬 분석

식별된 파일 수만큼 Explore 서브 에이전트를 병렬 스폰. 각 서브는 1 파일 전담.

#### 서브 에이전트 프롬프트 (파일 유형별)

**Screen (Route + Screen):**
```
{파일경로}를 전체 읽고 분석:
1. Route composable: 진입 파라미터, SavedStateHandle.toRoute(), SideEffect 수집
2. Screen composable: UI 레이아웃 트리 (ASCII)
3. 조건부 렌더링 (isLoading / error / empty / content 분기)
4. 상태별 UI 렌더링 테이블
5. 모든 클릭/입력/IME 이벤트 → ViewModel 콜백 매핑
6. BottomSheet / Dialog 트리거 조건
thoroughness: very thorough
```

**ViewModel:**
```
{파일경로}를 전체 읽고 분석:
1. 모든 public/private 함수 + 동작 설명
2. reduceState / reduceSuccessState 호출 전수 (언제/무엇이 바뀌는지)
3. postSideEffect 호출 전수
4. apiFlow / slackFlow / collectInLaunch 내부 API 호출 패턴
5. 비즈니스 규칙 / 모든 if/when/let 분기
6. 에러 처리 (.catch, onErrorMessageHandle 등)
7. init 블록 동작
8. SharedViewModel / savedStateHandle 연동
thoroughness: very thorough
```

**Contract:**
```
{파일경로}를 전체 읽고 분석:
1. UiState 전체 필드 (필드명, 타입, 기본값, 용도)
2. 계산 프로퍼티 (get() 커스텀 게터)
3. SuccessState 구조 (BaseUiState<T>.Success<T>)
4. SideEffect 전체 케이스
5. ActionEvent 전체 케이스 (있을 때)
6. 하위 data class / enum
thoroughness: very thorough
```

**Navigation:**
```
{파일경로}를 전체 읽고 분석:
1. Route 정의 (@Serializable data class)
2. 딥링크 패턴 (gongshop://...)
3. typeMap 지정 타입
4. navGraphBuilder 구성 (이 feature 가 등록하는 화면들)
thoroughness: very thorough
```

**UseCase (core:domain):**
```
{파일경로}를 전체 읽고 분석:
1. operator fun invoke() 시그니처 및 파라미터
2. 여러 Repository 조합 로직
3. 반환 Data 구조
4. Dispatcher (flowOn) / catch 처리
thoroughness: very thorough
```

**Repository / Service:**
create-api 컨벤션 기준으로 간단히:
1. 엔드포인트 목록
2. Service 반환 타입 (NetworkResponse<Entity, ErrorResponse>)
3. Repository 반환 타입 (Flow<Vo?> / ResponsePaging)

### 4단계: 단일 PRD 파일 작성

B2C는 **feature 모듈 당 1개 PRD 파일**이 원칙. 4개 파일 분리 패턴은 사용하지 않는다.

**저장 경로**: `.docs/prd/{feature-name}.md` (feature 디렉토리 이름 그대로, 하이픈 포함)

**템플릿 구조**:

```markdown
# {Feature 표시명} 모듈 기획 정책서 (Product Requirements Document)

## 1. 개요

{모듈 목적 / 사용자 가치 / 핵심 동작 1~2문단}

### 핵심 파일 구조
\`\`\`
feature/{name}/
├── ...
\`\`\`

## 2. 화면 구성

### 2.1 {ScreenName1}

(화면 목적, Route 파라미터, UI 구성 — ASCII 트리, 주요 인터랙션, 분기 시나리오)

### 2.2 {ScreenName2}

...

## 3. EntryType / 분기 정책 (필요 시)

(동일 화면이 여러 플로우로 동작할 때만 — login, payment 등에서 사용)

## 4. 데이터 로드 전략

### 4.1 {Screen} 진입 시
- 호출 API / UseCase
- 초기 상태
- 캐시/DB 병행 여부

## 5. 상태 관리

### 5.1 {ScreenName}UiState
| 필드 | 타입 | 기본값 | 용도 |
|-----|-----|-------|------|

### 5.2 계산 프로퍼티
...

## 6. SideEffect 정의

### 6.1 {ScreenName}SideEffect
| 케이스 | 트리거 | 처리 |
|-------|-------|------|

## 7. 사용자 인터랙션 플로우

### 7.1 {주요 플로우 1}
(시퀀스 다이어그램 혹은 번호 목록으로)

### 7.2 {주요 플로우 2}

## 8. API 연동

### 8.1 {엔드포인트}
- Method / URL
- 파라미터
- 응답 Vo
- 에러 처리

## 9. 네비게이션

- 진입 경로
- 이탈 경로
- 딥링크

## 10. 비즈니스 규칙 및 엣지 케이스

(유효성 검증 / 권한 체크 / 네트워크 에러 / 빈 응답 / 연속 클릭 등 구체 규칙)

## 11. 관련 문서

- 상위 컨벤션: [../conventions/project-convention.md](../conventions/project-convention.md)
- API 컨벤션: [../conventions/api-convention.md](../conventions/api-convention.md)
```

### 5단계: 업데이트 모드 (기존 PRD 있는 경우)

1. 기존 `.docs/prd/{feature}.md` Read
2. 서브 에이전트 분석 결과와 diff
3. **변경된 섹션만** Edit (전체 재작성 금지)
4. 변경 이력을 변경 요약에 포함 (PR 에 넣기 쉽게)

### 6단계: 작성 완료 후 README 갱신

신규 feature PRD 를 생성한 경우 `.docs/prd/README.md` 의 문서 목록 테이블에 추가한다.

### 7단계: 완료 보고

```
PRD 생성 완료: {feature-name}

파일: .docs/prd/{feature-name}.md

분석 결과:
- Screen: N개
- ViewModel 함수: N개
- UiState 필드: N개
- SideEffect: N개
- API 엔드포인트: N개
- 사용자 플로우: N개
- 엣지 케이스: N건
```

## 작성 규칙

### 필수
- **한국어** 자연어
- 조건문/분기는 **구체적으로** 명시 ("유효성 검증 있음" ❌ → "ID/PW 모두 입력 시 버튼 활성화" ✅)
- 실제 **문자열 리소스 값** 사용 (strings.xml 확인, 추측 금지)
- UiState 필드 **전수** 조사
- SideEffect **전수** 조사
- Route 파라미터는 `core:navigation` 의 `@Serializable` 정의와 일치시키기
- **Compose Navigation + BaseIntentViewModel (MVI)** 기준으로 작성 — Activity 용어 사용 금지

### 금지
- 코드 복붙 (자연어 설명으로 변환)
- 추상적 표현 ("에러 처리 있음", "데이터 로드")
- 문자열 리소스 추측
- Activity / onCreate / startActivity 같은 구식 용어
- 4개 파일 분리 (B2C 는 단일 파일)

## 참고 문서

- [PRD 색인](../../.docs/prd/README.md)
- [프로젝트 컨벤션](../../.docs/conventions/project-convention.md) — MVI / Route / 모듈 구조
- [API 컨벤션](../../.docs/conventions/api-convention.md) — API 섹션 작성 시
