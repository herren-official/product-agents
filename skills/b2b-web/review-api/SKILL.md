---
name: b2b-web-review-api
description: Notion API 문서를 입력받아 사용처/타입/변경점/정책 영향도/잠재 이슈를 종합 분석. /review-api 실행 시 활성화.
user-invocable: true
---

# Review API

Notion API 명세 문서를 입력받아 **프론트엔드 관점에서 API를 종합 검토**하는 스킬.

## 명령어

```
/review-api {notion-url}
/review-api {notion-url} --with-context "고객차트에서 체크 후 문자하기 버튼 클릭 시 사용"
```

## 분석 항목

| # | 항목 | 설명 |
|---|------|------|
| 1 | API 스펙 파싱 | Method, URI, Request, Response 구조 정리 |
| 2 | 코드베이스 사용처 | 이 API 또는 유사 API가 어디서 사용되는지 전수 조사 |
| 3 | 타입 완성도 | data-contracts.ts 타입 존재 여부, 필드 매핑 검증 |
| 4 | 기존 API 대비 변경점 | 신규/변경 API일 때 기존 코드와의 차이 |
| 5 | 프론트 사용성 이슈 | 호출 패턴 일관성, 불필요 필드, 페이징, 에러 처리 등 |
| 6 | 정책 영향도 | 옵시디언 정책과 교차 검토 — 다른 화면/기능에 미치는 영향 |
| 7 | 잠재 이슈 | 성능, 정합성, 권한, UX, 법적 리스크 |

## 차별점

| 스킬 | 초점 |
|------|------|
| `impact-analysis` | 기능 변경의 **서비스 전반 연쇄 영향** |
| `kickoff-edge-scan` | 개발 착수 전 **엣지케이스/정책 공백** 탐지 |
| **이 스킬** | **API 명세 1건**을 깊이 파고들어 프론트 사용성 + 정책 영향 검토 |

---

## 팀 기반 병렬 실행 아키텍처

> 전제: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + `teammateMode: "tmux"` 설정 필요

### 팀 구조

```
┌─ tmux %0: team-lead (오케스트레이터)
│   └─ Phase 0(Notion 파싱) + Phase 3(교차 분석) + Phase 4(리포트)
│
├─ tmux %1: code-analyst (Tier 1)
│   └─ Phase 1: 코드베이스 사용처 + 타입 + 패턴 분석
│
└─ tmux %2: policy-analyst (Tier 1)
    └─ Phase 2: 옵시디언 정책 영향도 분석
```

### 의존성 그래프

```
Leader: Phase 0 (Notion 파싱)
  │
  ├─→ api-spec.md (파싱 결과)
  │
  ├─ code-analyst ──────┐
  │  Phase 1            │
  │  → api-code.md      │
  │                     ├─→ Leader: Phase 3 (교차 분석 + 이슈 도출)
  └─ policy-analyst ────┤
     Phase 2            │
     → api-policy.md    │
                        └─→ Leader: Phase 4 (최종 리포트)
```

### 실행 흐름

```
1. Phase 0: Leader가 Notion 페이지 fetch → api-spec.md 생성
2. TeamCreate("{apiName}-api-review")
3. TaskCreate x 2:
   - Task 1: "코드 사용처 분석"
   - Task 2: "정책 영향도 분석"
4. Agent x 2 (동시 spawn, tmux 분할):
   - code-analyst → Task 1 수행 (api-spec.md 참조)
   - policy-analyst → Task 2 수행 (api-spec.md 참조)
5. 각 teammate: TaskUpdate(completed) → idle notification
6. Leader: idle 수신 → Phase 3 + Phase 4 직접 수행
7. Shutdown protocol:
   - SendMessage(shutdown_request) to each teammate
   - Wait for shutdown_response(approve)
   - TeamDelete
```

---

## Phase 0: Notion API 문서 파싱 (Leader 직접 수행)

### 절차

1. `notion-fetch`로 Notion 페이지 내용 조회
2. 페이지에 댓글이 있으면 `notion-get-comments`로 댓글도 조회
3. 아래 구조로 정리하여 `api-spec.md` 생성

### 산출물

`.docs/api-review/{apiName}/api-spec.md`:

```markdown
# API Spec: {API 설명}

## 기본 정보
- Method: {GET/POST/PUT/PATCH/DELETE}
- URI: {URI}
- 타입: {신규/변경}
- 상태: {API 명세 완료/개발중/...}
- 플랫폼: {iOS, Android, WEB-REACT}

## 용도
{Notion 문서의 설명 섹션}

## Request
| name | 설명 | 타입 | 출처 | 비고 |
|------|------|------|------|------|

## Response
| name | 설명 | 타입 | 비고 |
|------|------|------|------|

## Response 예시
{JSON 예시}

## Notion 댓글 요약
{댓글에서 도출된 논의 사항, 미결 이슈}

## 사용자 제공 컨텍스트
{--with-context로 전달된 사용 맥락}
```

---

## Phase 1: 코드베이스 분석 (code-analyst teammate)

### code-analyst 프롬프트 템플릿

```
당신은 API 코드 분석 에이전트입니다.

## 임무
코드베이스에서 이 API의 사용 현황, 타입, 호출 패턴을 분석합니다.

## 입력
- api-spec.md 경로: .docs/api-review/{apiName}/api-spec.md
- API URI: {uri}
- API Method: {method}

## 절차

### Step 1: 기존 API 탐색
1. `src/libs/apiV2/modules/Api.ts`에서 URI 패턴 검색
2. `src/libs/apiV1/modules/V1.ts`에서 URI 패턴 검색
3. `src/libs/apiV2/modules/endpoints.ts`에서 엔드포인트 함수 확인
4. URI의 도메인 키워드로 유사 API 검색 (예: "customers" → 고객 관련 API 전체)

### Step 2: 사용처 추적
1. API 함수명으로 queryFactory 검색
2. queryFactory 키로 hooks/components/pages 검색
3. 직접 API 호출 사용처 검색
4. 각 사용처의 호출 맥락 파악 (SSR/CSR, 조건부 호출 등)

### Step 3: 타입 분석
1. `data-contracts.ts`에서 Request/Response 타입 검색
2. `src/types/` 디렉토리에서 프론트 자체 타입 검색
3. API 응답 타입과 Notion 스펙의 필드 대조
4. 타입이 없으면 "미정의" 표기

### Step 4: 호출 패턴 일관성 검사
1. 같은 도메인의 다른 API가 사용하는 패턴 확인:
   - URI 패턴 (path에 shopNo 있는지 vs 토큰 추출)
   - 인증 방식 (GD-Auth-Token 헤더)
   - 페이징 방식 (page/size vs cursor vs 전체 반환)
2. 신규 API가 기존 패턴과 다른 점 도출

### Step 5: 관련 상태/데이터 흐름
1. 이 API 데이터를 소비하는 Recoil atom/selector 추적
2. sessionStorage/localStorage로 전달되는 데이터 확인
3. 페이지 간 데이터 전달 경로 (router.push, query params)

## 산출물
`.docs/api-review/{apiName}/api-code.md`에 저장:

```markdown
# Code Analysis: {apiName}

## 기존 API 현황
| 구분 | API 함수명 | URI | Method | 파일:라인 |
|------|-----------|-----|--------|----------|

## 유사 도메인 API
| API 함수명 | URI | 사용 패턴 | 비고 |
|-----------|-----|----------|------|

## 사용처 전수 목록
| 파일:라인 | 역할 | 호출 방식 | 조건 |
|----------|------|----------|------|

## 타입 매핑
### Request 타입
| Notion 필드 | data-contracts 타입 | 필드명 | 매핑 상태 |
|------------|-------------------|--------|----------|

### Response 타입
| Notion 필드 | data-contracts 타입 | 필드명 | 매핑 상태 |
|------------|-------------------|--------|----------|

## 호출 패턴 비교
| 항목 | 기존 도메인 API 패턴 | 신규 API | 일치 여부 |
|------|-------------------|---------|----------|
| URI에 shopNo | {있음/없음} | {있음/없음} | {O/X} |
| 인증 방식 | {패턴} | {패턴} | {O/X} |
| 페이징 | {방식} | {방식} | {O/X} |
| Response 구조 | {패턴} | {패턴} | {O/X} |

## 데이터 흐름
```
{데이터 생성} → {API 호출} → {상태 저장} → {UI 소비} → {페이지 전달}
```

## 발견 이슈
| # | 이슈 | 심각도 | 설명 |
|---|------|--------|------|
```

완료 후 TaskUpdate(completed)를 호출하세요.
```

---

## Phase 2: 정책 영향도 분석 (policy-analyst teammate)

### policy-analyst 프롬프트 템플릿

```
당신은 정책 영향도 분석 에이전트입니다.

## 임무
옵시디언 정책 문서에서 이 API가 영향을 주거나 받는 정책을 탐색합니다.

## 입력
- api-spec.md 경로: .docs/api-review/{apiName}/api-spec.md
- API 도메인: {domain} (예: customers, booking, shop)

## 옵시디언 Vault 경로
/Users/gimjaehwan/Library/Mobile Documents/iCloud~md~obsidian/Documents/옵시디언/gongbiz/

## 절차

### Step 1: 직접 관련 정책 탐색
1. `policies/` 디렉토리 구조 파악
2. API 도메인과 직접 관련된 정책 파일 읽기
3. `screens/` 하위에서 이 API를 사용하는 화면의 정책 읽기

### Step 2: 교차 도메인 정책 탐색
API의 데이터가 다른 도메인과 만나는 지점 탐색:
- 고객 ↔ 메시지/알림 (수신거부 → 문자 전송)
- 고객 ↔ 예약/매출 (고객 데이터 → 매출 기록)
- 권한 ↔ 기능 접근 (권한 API → 페이지 진입)
- 설정 ↔ 표시 (설정 변경 → 다른 화면 반영)

### Step 3: 6가지 정책 영향도 체크

| # | 체크포인트 | 분석 방법 |
|---|-----------|----------|
| 1 | 데이터 소유권 | 이 API의 데이터를 누가 생성/수정/삭제하는지 |
| 2 | 권한/역할 분기 | 오너/직원/어시스턴트별 접근 차이 |
| 3 | 다른 화면 영향 | 이 API 데이터가 표시/사용되는 다른 화면 |
| 4 | 상태 동기화 | API 데이터 변경 시 다른 화면의 실시간 반영 여부 |
| 5 | 법적/컴플라이언스 | 개인정보, 수신동의, 마스킹 관련 규정 |
| 6 | 운영 시나리오 | 매장에서 실제 사용 시 발생 가능한 정책 충돌 |

## 산출물
`.docs/api-review/{apiName}/api-policy.md`에 저장:

```markdown
# Policy Analysis: {apiName}

## 직접 관련 정책
| 파일 | 정책 요약 | API 연관성 |
|------|----------|-----------|

## 교차 도메인 영향
| 도메인 | 연결점 | 정책 근거 | 영향 유형 |
|--------|--------|----------|----------|

## 권한/역할 분기
| 역할 | 접근 가능 여부 | 데이터 차이 | 정책 근거 |
|------|-------------|-----------|----------|

## 다른 화면 영향
| 화면 | 영향 방식 | 심각도 | 설명 |
|------|----------|--------|------|

## 법적/컴플라이언스
| 항목 | 해당 여부 | 설명 |
|------|----------|------|

## 미해결 정책 (확인 필요)
| # | 질문 | 영향 범위 | 확인 대상 |
|---|------|----------|----------|
```

완료 후 TaskUpdate(completed)를 호출하세요.
```

---

## Phase 3: 교차 분석 + 이슈 도출 (Leader 직접 수행)

> 두 teammate 완료 후 leader가 `api-code.md` + `api-policy.md`를 읽고 수행.

### 교차 분석 포인트

| # | 분석 | 방법 |
|---|------|------|
| 1 | 패턴 불일치 | 기존 도메인 API 패턴과 신규 API의 차이 → 프론트 구현 복잡도 |
| 2 | 정책-코드 갭 | 정책에 정의된 동작이 API 스펙에 반영 안 된 것 |
| 3 | 불필요 데이터 | 사용 맥락 대비 Response에 불필요한 필드 |
| 4 | 누락 데이터 | 사용 맥락상 필요하지만 Response에 없는 필드 |
| 5 | 에러/실패 시나리오 | API 실패 시 프론트 동작 정책 |
| 6 | 성능 리스크 | 대량 데이터, 페이징 부재, 빈번 호출 |
| 7 | 정합성 리스크 | 데이터 변경 타이밍, 캐시, race condition |
| 8 | 보안/권한 | 마스킹, 인증, 권한 체크 누락 가능성 |

---

## Phase 4: 최종 리포트 (Leader 직접 수행)

### 입력 파일

```
.docs/api-review/{apiName}/
├── api-spec.md     ← Leader (Phase 0)
├── api-code.md     ← code-analyst (Phase 1)
└── api-policy.md   ← policy-analyst (Phase 2)
```

### 최종 리포트 구조

리포트는 **파일로 저장하지 않고 대화에 직접 출력**한다.
사용자가 빠르게 읽고 바로 백엔드/기획에 피드백할 수 있도록.

```markdown
# API Review: {API 설명}

## 1. API 스펙 요약
| 항목 | 값 |
|------|---|
| Method | {method} |
| URI | {uri} |
| 타입 | {신규/변경} |
| 용도 | {한줄 요약} |

### Request
{테이블}

### Response
{테이블 + 각 필드 설명}

---

## 2. 코드베이스 현황
### 기존 사용처
{사용처 테이블 — 없으면 "신규 API, 기존 사용처 없음"}

### 유사 API와 패턴 비교
{호출 패턴 비교 테이블}

---

## 3. 변경점
{기존 API 대비 변경 사항 — 신규면 "해당 없음 (신규 API)"}

---

## 4. 정책 영향도
### 직접 영향
{영향받는 정책/화면}

### 간접 영향
{교차 도메인 영향}

---

## 5. 잠재 이슈
| # | 카테고리 | 이슈 | 심각도 | 설명 |
|---|---------|------|--------|------|

---

## 6. 백엔드/기획 확인 필요 사항
| # | 질문 | 영향 범위 | 우선순위 |
|---|------|----------|---------|

---

## 7. 프론트 구현 시 참고
- 호출 시점: {권장 시점}
- 에러 처리: {권장 방식}
- 캐시 전략: {권장 방식}
- 기존 코드 수정 범위: {예상 파일 목록}
```

---

## Claude 행동 규칙

1. **Notion 파싱 우선** — Phase 0에서 API 스펙을 완전히 파싱한 후 teammate에 전달
2. **댓글도 분석** — Notion 댓글에 미결 논의가 있으면 반드시 이슈로 포함
3. **패턴 비교 필수** — 같은 도메인의 기존 API와 패턴이 다르면 반드시 지적
4. **증거 기반** — 코드 분석은 file:line, 정책 분석은 정책 파일 경로 첨부
5. **프론트 관점** — 백엔드 내부 구현이 아닌, 프론트에서 이 API를 쓸 때의 관점
6. **정책 부족 시 요청** — 옵시디언에 관련 정책이 없으면 사용자에게 추가 정보 요청
7. **팀 라이프사이클 준수** — TeamCreate → TaskCreate → Agent spawn → idle 대기 → Shutdown → TeamDelete
8. **최종 리포트는 대화에 출력** — 파일 저장 없이 사용자가 바로 읽을 수 있게
