# 도메인별 에이전트 팀 매핑 가이드

프로젝트 특성에 따라 추천할 에이전트 조합을 정리한다. `agent-team.md` 작성 시 참조한다.

---

## 기본 팀 (모든 프로젝트 공통)

| 에이전트 | 역할 | 호출 시점 |
|---|---|---|
| `oh-my-claudecode:architect` | 설계 초안 검토 (트레이드오프·설계 결정 타당성) | `design-draft.md` 생성 직후 |
| `oh-my-claudecode:critic` | 누락/리스크 반박 (엣지 케이스, 비현실적 Phase 분할 지적) | architect 검토 직후 |
| `planner` | 요구사항→구현 계획 수립 | 설계 초안 확정 후 |
| `tdd-guide` | TDD 사이클 가이드 | 기능 구현 시작 전 |
| `code-reviewer` | 코드 품질 리뷰 | 각 커밋/PR 직전 |
| `security-reviewer` | 보안 검토 | PR 생성 전 |

### 설계 초안 검토 호출 예시 (kickoff 직후 필수)

```
# 1. architect — 설계 결정과 Phase 분할 타당성 검토
Task(subagent_type="oh-my-claudecode:architect",
     model="opus",
     prompt=".claude/docs/{epic}/design-draft.md를 검토하라.
     특히 다음을 평가:
     1. 7절 주요 설계 결정의 근거/트레이드오프 분석이 충분한가
     2. Phase 분할(1.4)이 배포 일정/롤아웃 관점에서 합리적인가
     3. 데이터 모델(4절)의 FK/인덱스/제약이 조회 패턴과 맞는가
     4. 영향 범위(8절)에서 누락된 모듈/파일이 있는가
     각 이슈는 Critical/Warning/Info로 분류하고 구체적 수정 제안을 남겨라.")

# 2. critic — architect가 놓친 엣지/리스크 반박
Task(subagent_type="oh-my-claudecode:critic",
     model="opus",
     prompt=".claude/docs/{epic}/design-draft.md와 architect의 검토 결과를 읽고 반박하라.
     다음을 찾아라:
     1. 초안이 '모든 케이스를 다룬다'고 가정한 지점의 엣지 케이스
     2. Phase 1 범위가 너무 크거나 작은 근거
     3. 외부 시스템 장애/지연/일관성 문제에 대한 대비 부족
     4. 마이그레이션 롤백 체크리스트(4.3.1)의 허점
     5. 기존 API 호환성 전제가 실제로 유효한지
     Critical 이슈는 '반드시 해결' 태그를 붙여라.")
```

설계 초안이 architect + critic 양쪽에서 모두 Pass되기 전에 `/plan`이나 구현 단계로 넘어가지 않는다.

---

## 도메인별 추가 에이전트

### A. 신규 API 개발 (Spring Boot 3.3 모듈)
적용 모듈: `gongbiz-crm-b2b-api`, `b2c-gongbiz-api`

| 에이전트 | 역할 |
|---|---|
| `architect` | Port & Adapter 구조 설계 검토 |
| `Explore` | 기존 패키지 구조/유사 기능 탐색 |
| `build-error-resolver` | Spring Boot 3.3 + QueryDSL jakarta classifier 빌드 이슈 해결 |

### B. 레거시 유지보수 (Spring Boot 2.7 모듈)
적용 모듈: `gongbiz-crm-b2b-backend`, `gongbiz-crm-b2b-admin`, `gongbiz-crm-batch`

| 에이전트 | 역할 |
|---|---|
| `architect` | MyBatis/JPA 혼재 영역의 영향 분석 |
| `review-transaction` | 트랜잭션 경계 검토 |
| `refactor-cleaner` | 레거시 코드 안전 정리 |

### C. 배치 작업
적용 모듈: `gongbiz-crm-b2b-batch`, `gongbiz-crm-batch`, `gongbiz-crm-settlement-batch`, `gongbiz-notification-batch`

| 에이전트 | 역할 |
|---|---|
| `architect` | chunk/step 설계, 멱등성 검토 |
| `e2e-runner` | 배치 End-to-End 시나리오 실행 |
| `infra-mapper` | CloudWatch 로그 그룹 매핑 |

### D. Kafka 컨슈머
적용 모듈: `gongbiz-crm-b2b-consumer`

| 에이전트 | 역할 |
|---|---|
| `architect` | 메시지 스키마, 재처리/DLQ 전략 |
| `security-reviewer` | 메시지 파싱 취약점 |

### E. 외부 API 연동 (결제/알림/Firebase 등)
적용 모듈: `gongbiz-crm-b2b-payment-domain`, `gongbiz-notification`, `gongbiz-crm-b2b-gongbizstore-infrastructure-shopby`

| 에이전트 | 역할 |
|---|---|
| `architect` | 재시도/타임아웃/서킷브레이커 설계 |
| `security-reviewer` | 인증/비밀관리 검토 |
| `researcher` | 외부 API 문서 조사 |

### F. 통계/집계 배치
적용 모듈: `gongbiz-crm-b2b-batch` (statistics), `gongbiz-crm-batch`

| 에이전트 | 역할 |
|---|---|
| `architect` | 집계 파이프라인 정확성 검토 |
| `scientist` | 데이터 검증 쿼리 설계 (gongbiz-db로 검증) |
| `tdd-guide` | 집계 로직 단위/통합 테스트 |

### G. Lambda 함수
적용 모듈: `gongbiz-lambda`

| 에이전트 | 역할 |
|---|---|
| `architect` | 3-Tier 구조 준수 확인 |
| `build-error-resolver` | Shadow JAR 빌드 이슈 |

### H. UI/Frontend 영향
적용: 피그마 요구사항이 있을 때

| 에이전트 | 역할 |
|---|---|
| `vision` | 피그마 이미지 분석 |
| `oh-my-claudecode:frontend-ui-ux` | UI 구현 가이드 |

---

## 에이전트 팀 제안 템플릿 (`agent-team.md`에 쓸 형식)

```markdown
# {epic} — 추천 에이전트 팀

## 프로젝트 특성
- 도메인: {예: 통계 집계 배치 + 신규 API}
- 주요 모듈: {목록}
- 리스크: {예: 데이터 정합성, 성능}

## 권장 팀 구성

### 계획 단계 (기본)
- **planner** — 요구사항 인터뷰 및 구현 계획 생성
  - 호출 예시: `/plan` 또는 `Task(subagent_type="planner", prompt="...")`
- **architect** — {도메인} 설계 검토
  - 호출 예시: `Task(subagent_type="architect", prompt="{프로젝트명}의 {도메인} 아키텍처 검토")`

### 구현 단계
- **tdd-guide** — 각 기능 구현 전 테스트 작성
  - 호출 예시: `/tdd "{구현할 기능}"`
- **{도메인 특화 에이전트}** — {역할}

### 검증 단계
- **code-reviewer** — 코드 리뷰
- **security-reviewer** — 보안 검토
- **api-test-plan** — QA 플랜 생성: `/api-test-plan {branch}`
- **monitor** — 배포 후 모니터링: `/monitor dev .claude/plan/{plan}.md`

## 병렬화 포인트
- 계획 단계에서 `Explore` + `architect` 동시 실행 가능
- 검증 단계에서 `code-reviewer` + `security-reviewer` 동시 실행 가능

## 스킬 조합 순서 (추천)
1. `/project-kickoff {epic}` — (이미 실행됨)
2. **design-draft.md의 [수동 검토 필요] 섹션을 엔지니어가 채움**
3. **architect + critic 교차 검증** (Critical 이슈 해결까지 반복)
4. `/plan` — 구현 계획
5. `/create-br {md파일}` 또는 `/create-branch` — 브랜치 생성
6. 구현 반복: `/tdd` → `/build-fix` → `/review-transaction`
7. `/create-commit` → `/create-pr`
8. `/api-test-plan {branch}` → `/monitor`
```