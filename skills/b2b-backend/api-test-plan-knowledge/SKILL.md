---
name: b2b-backend-api-test-plan-knowledge
description: "/api-test-plan 커맨드에서 명시적으로 로드하는 전문 지식. 자동 트리거하지 않음."
user-invocable: false
allowed-tools: Read
---

## API 테스트 플랜 작성 전문 지식

### 도구 사용 가이드
| 상황 | 사용 도구 |
|---|---|
| 변경 코드 기반 테스트 플랜 생성 | `/api-test-plan` 커맨드 |
| 생성된 플랜 기반 로그 모니터링 | `/monitor` 커맨드 |
| 모니터링 결과를 플랜에 반영 | `/plan-update` 커맨드 |

### 플랜 작성 원칙
1. **연속 호출 Flow 우선**: 단건 endpoint 검증이 아닌 multi-step Flow 단위로 구성. 단건 호출은 Flow 내부의 한 단계.
2. **12개 섹션 강제**: 변경 개요 / 테스트 설계 원칙 / 영향 범위 / **API 호출 체인** / **상태 전이 테이블** / 연속 호출 Flow / **고위험 교차 (X-IDs)** / 엣지 (E-IDs) / 테스트 데이터 / 모니터링 설정 (filter-pattern + devdb SQL + Sentry) / **배포 선행 체크리스트** / QA 결과 요약. 변경 규모가 작아도 헤더는 유지하고 "해당 없음" 표기.
3. **체크 키워드 명시**: 필수/에러/부정/수량 4분류 태깅 의무.
4. **예상 결과 명시**: 성공 시 / 실패 시 / 부정 (0건) 모두 기술.
5. **모니터링 설정 실행 가능**: 플랜 md 의 filter-pattern 블록은 `?"a" ?"b"` OR 패턴 + `--profile mfa` 까지 즉시 복붙 가능한 형태. devdb SQL 은 단계별 검증 쿼리 포함.
6. **테스트 계정/데이터 명시**: 헤더, URL, shop, customer 등 case-by-case.

### ID 체계 (5개 파일 공통)
- `P0` — 배포/환경 선행 확인 (단일)
- `F1`..`Fn` — 연속 호출 Flow (multi-step). 내부 단계는 `F1.1`, `F1.2` ...
- `X1`..`Xn` — 고위험 교차 케이스 (race / 동시성 / 트랜잭션 경계 / 롤링 / 외부 실패 / 락 타임아웃 등)
- `E1`..`En` — 엣지케이스 (단순 경계값, 권한, 입력 검증 등)
- "Phase" 라는 표현은 P0 외에는 사용 금지. Flow / X-IDs / E-IDs 로 명확히 구분.

### Flow 설계 기준
- 상태 전이 단위 / 신·구 버전 교차 / 동시성·트랜잭션 경계 / 정상→실패 주입 등을 하나의 Flow 로 묶는다.
- Flow 수 권장 7~9 개. 초과 시 Flow 헤더에 우선순위 `[높음]` / `[중]` / `[낮음]` 한국어 표기 (P0 ID 와 시각적 충돌 방지를 위해 `[P1]`/`[P2]` 표기는 금지).
- 변경된 모든 endpoint 가 최소 1개 Flow 에서 multi-step 으로 검증되어야 한다.
- prod 배포 모니터링 시에는 P0 을 최우선으로 포함한다.

### 세부 규칙 참조
키워드 추출, 모니터링 매핑의 상세 규칙은 아래 파일을 참조한다:
- 키워드 추출 규칙: `references/keyword-extraction.md`
- 모니터링 매핑 규칙: `references/log-source-mapping.md`
- 출력 템플릿: `references/plan-template.md`

### 12개 섹션 작성 책임자 매트릭스

| # | 섹션 | 주 책임 에이전트 | 비고 |
|---|---|---|---|
| 1 | 변경 개요 | code-analyzer (경량) / 오케스트레이터 (분산) | layer-analyzer 3개 결과 병합 후 오케스트레이터가 작성 |
| 2 | 테스트 설계 원칙 | 오케스트레이터 (Phase 5) | plan-template 고정 문구 + case-by-case 보강 |
| 3 | 영향 범위 | code-analyzer / layer-analyzer | 분산 모드는 3계층 합산 |
| 4 | API 호출 체인 | code-analyzer (경량) / **layer-analyzer logic 주 책임** (분산) | api·data 계층 결과로 보강 |
| 5 | 상태 전이 테이블 | scenario-builder | Flow 마다 1개 이상 |
| 6 | 연속 호출 Flow | scenario-builder | multi-step 우선 |
| 7 | 고위험 교차 (X-IDs) | scenario-builder | 변경 코드 매칭 카테고리만 |
| 8 | 엣지케이스 (E-IDs) | scenario-builder | |
| 9 | 테스트 데이터 | scenario-builder | Flow / X / E 에서 사용된 데이터 집계 |
| 10 | 모니터링 설정 | infra-mapper (로그 소스 / 주기) + scenario-builder (키워드) | filter-pattern / devdb SQL / Sentry 검색식 통합 |
| 11 | 배포 선행 체크리스트 | code-analyzer + scenario-builder | DB 스키마 변경 / 신규 Bean / 프로퍼티 / 헤더 항목 도출 |
| 12 | QA 결과 요약 | 오케스트레이터 (Phase 5, 빈 표) | `/monitor` 후 `/plan-update` 가 채움 |

## 오케스트레이션 워크플로우

### 실행 흐름
Phase 1 (준비) → Phase 2 (팀 실행) → Phase 3 (통합)

#### Phase 1: 준비
- 사용자 입력에서 브랜치명, 분석 범위 추출
- 기존 플랜 파일 존재 여부 확인 (`.claude/plan/{branch}-test-plan.md`)

#### Phase 2: 팀 실행

##### Step 0: 분석 전략 결정
`git diff --name-only develop...<branch>`로 변경 파일 수를 확인하여 분석 모드를 결정한다.

##### 경량 모드 (변경 파일 20개 이하)
```
code-analyzer (1) → cross-module-detector (2, 순차) → scenario-builder (3) → infra-mapper (4) → plan-reviewer (5)
```
- code-analyzer: 변경 파일 분류 + 영향 범위
- cross-module-detector: code-analyzer 결과를 받아 교차 모듈 호출 식별 + 키워드 보강
- 두 에이전트 결과를 병합하여 scenario-builder에 전달

##### 분산 모드 (변경 파일 21개 이상)
```
layer-analyzer(api) + layer-analyzer(data) + layer-analyzer(logic) (3개 병렬)
  → scenario-builder (2) → infra-mapper (3) → plan-reviewer (4)
```
사전 분류: 변경 파일을 계층별로 분류한다.
- api: Controller, DTO, 설정 파일 (`@RestController`, `@Controller`, Request/Response, application.yml)
- data: Entity, Repository, 마이그레이션 (`@Entity`, JpaRepository, Flyway/Liquibase)
- logic: Service, 배치, Consumer, 외부 연동 (`@Service`, `@Scheduled`, `@SqsListener`, `@KafkaListener`)
- 분류 불가: logic 계층에 배정한다

각 layer-analyzer에게 해당 계층의 파일 목록과 브랜치명을 전달한다.
3개 결과를 code-analyzer의 "코드 분석 결과" 형식으로 병합하여 scenario-builder에 전달한다.

#### Phase 3: 통합
- plan-reviewer 검토 결과 반영
- 최종 플랜 파일 저장: `.claude/plan/{branch}-test-plan.md`

### 작업 모드
| 모드 | 투입 에이전트 | 사용 시나리오 |
|------|-------------|-------------|
| 풀 파이프라인 (경량, 변경 ≤20) | code-analyzer → cross-module-detector → scenario-builder → infra-mapper → plan-reviewer | `/api-test-plan` 기본 실행 (변경 파일 20개 이하) |
| 풀 파이프라인 (분산, 변경 ≥21) | layer-analyzer × 3 (api/data/logic 병렬) → scenario-builder → infra-mapper → plan-reviewer | `/api-test-plan` 기본 실행 (변경 파일 21개 이상). cross-module-detector 는 logic 계층 layer-analyzer 의 "교차 모듈 호출" 출력에 흡수 |
| 분석만 | code-analyzer (경량) 또는 layer-analyzer × 3 (분산) | 변경 영향 범위 + 호출 체인만 파악 (`--analyze-only`) |
| 리뷰만 | plan-reviewer | 기존 플랜의 완결성 검증 (`--review-only`) |

### 에러 핸들링
| 에러 상황 | 대응 전략 |
|----------|----------|
| code-analyzer 실패 (브랜치 없음 등) | 전체 중단, 사용자에게 확인 요청 |
| scenario-builder 실패 | code-analyzer 결과만으로 플랜 골격 생성, "[시나리오 미완성]" 표시 |
| infra-mapper 실패 | 모니터링 설정 없이 플랜 생성, "[모니터링 수동 설정 필요]" 표시 |
| plan-reviewer 실패 | 미검증 플랜으로 저장, "[미검증]" 표시 |

### 기존 파일 활용
- 기존 플랜 파일이 있으면: "기존 플랜이 있습니다. 덮어쓸까요?" 확인
- code-analyzer 결과만 있으면: scenario-builder부터 시작
