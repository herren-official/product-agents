# Workflow Phases — 단계별 가이드

운영 배포 모니터링 워크플로우 4단계 (Phase 0 ~ Phase 4) 가이드.
GBIZ-26917 / PR #5352의 모니터링 패턴을 추상화한 것.

---

## Phase 0: PR 변경 분석

### 목적
배포 대상 PR의 변경 범위를 식별하여 모니터링해야 할 영역을 자동 도출.

### 입력
- PR URL: `https://github.com/herren-official/gongbiz-crm-b2b-backend/pull/<NUMBER>`

### 분석 항목
| 카테고리 | 도출 방법 |
|:---|:---|
| 변경된 API 엔드포인트 | `Controller` 파일의 `@RequestMapping` / `@GetMapping` 등 어노테이션 추출 |
| 변경된 배치 Job | `*JobConfig.kt` / `*Scheduler.kt` 파일 변경 분석 |
| 변경된 도메인 서비스 | `*Service.kt` / `*Facade.kt` 변경 |
| 영향받는 DB 테이블 | Entity 변경 + Repository 쿼리 변경 + Native SQL 변경 추적 |
| 영향받는 ECS/EB 서버 | 변경된 모듈로 매핑 (`gongbiz-crm-b2b-backend` → EB web/app, `gongbiz-crm-b2b-batch` → ECS batch, `gongbiz-crm-b2b-consumer` → ECS consumer) |
| GBIZ 티켓 번호 | 커밋 메시지에서 추출 |

### 출력
`.docs/issues/<PR번호>-prod-monitoring/plan.md` 자동 생성.

#### 플랜 md 표준 구조

```markdown
# <PR 제목> 운영 배포 모니터링 플랜

| 항목 | 값 |
|------|----|
| 작성일 | YYYY-MM-DD |
| 대상 PR | #<NUMBER> |
| 배포 시작 | (사용자 입력 또는 deployment 메타데이터) |
| 비교 기준 | D-1 vs D-day |
| Replica DB | prod-rds-gongbiz-replica or dev-rds-gongbiz-crm |

## 0. 배포 개요
### 0-1. 변경 범위 요약
### 0-2. 정합성 위험도 분류

## 1. 인프라 매핑 (CloudWatch Log Group)

## 2. Phase별 모니터링 시나리오
### Phase A — 배포 직후
### Phase B — 첫 배치 실행 후
### Phase C — API 호출 모니터링
### Phase D — 정합성 검증

## 3. Replica DB 정합성 체크 쿼리
### 3-1. BATCH_JOB_EXECUTION 상태
### 3-2. 통계 테이블 row 수 / 합계
### 3-3. statistics_target 처리 상태
### 3-4. SHOP_AGG vs EMPLOYEE 합계 일치
### 3-5. UK 중복 검증

## 4. 단계별 체크리스트
### T-15: 사전 준비
### T+0 ~ T+20: 배포 직후
### T+20 ~ T+50: 첫 배치
### T+50 ~ T+80: 정합성 1차
### 롤백 트리거

## 5. 모니터링 자동화 명령어 모음

## 5-A. D-1 Baseline 스냅샷

## 6. QA 결과 요약 테이블
| Phase | 시각 | 결과 | 비고 |
|:---:|:---:|:---:|------|
```

---

## Phase 1: Baseline 스냅샷

### 목적
배포 전 D-1 데이터를 캡처하여 D-day 대비 비교 기준으로 활용.

### 실행 시점
- `--baseline` 플래그 또는 `--once`/`--periodic`의 첫 실행 시 1회

### 표준 쿼리 (영향 테이블별)

PR 분석에서 도출된 영향 테이블 목록을 기반으로 다음 쿼리 자동 생성:

#### 통계 테이블 (`daily_*_statistics`, `hourly_*_statistics`)
```sql
SELECT
  '<D-1>' AS sale_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(<주요 컬럼>) AS sum_<컬럼>
FROM <테이블>
WHERE <date_컬럼> = '<D-1>'
GROUP BY scope WITH ROLLUP;
```

#### `statistics_target`
```sql
SELECT
  batch_type, batch_period, state,
  CASE WHEN empno = 0 THEN 'SHOP' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS cnt
FROM statistics_target
WHERE regdate >= '<D-1 00:00:00>'
GROUP BY batch_type, batch_period, state, scope;
```

#### `BATCH_JOB_EXECUTION`
```sql
SELECT
  ji.JOB_NAME, je.STATUS, je.START_TIME, je.END_TIME,
  TIMESTAMPDIFF(SECOND, je.START_TIME, je.END_TIME) AS duration_sec
FROM BATCH_JOB_EXECUTION je
JOIN BATCH_JOB_INSTANCE ji ON je.JOB_INSTANCE_ID = ji.JOB_INSTANCE_ID
WHERE ji.JOB_NAME IN (<영향 Job 목록>)
  AND je.START_TIME >= '<D-1 00:00:00>'
  AND je.START_TIME <  '<D-day 00:00:00>'
ORDER BY ji.JOB_NAME, je.START_TIME DESC;
```

### 출력
`.docs/issues/<PR번호>-prod-monitoring/snapshots/baseline-NN-<주제>.txt`

---

## Phase 2: 모니터링 실행

### 2-A. 서버 로그 모니터링 (AWS CloudWatch)

#### 4개 서버 매핑 (참고: `~/.claude/skills/api-test-plan/references/log-source-mapping.md`)
| 환경 | 모듈 | 로그 그룹 |
|:---|:---|:---|
| `prod-ecs-service-gongbiz-crm-b2b-batch` | gongbiz-crm-b2b-batch | `/ecs/prod-ecs-td-gongbiz-crm-b2b-batch` |
| `prod-ecs-service-gongbiz-crm-b2b-consumer` | gongbiz-crm-b2b-consumer | `/ecs/prod-td-gongbiz-crm-b2b-consumer` |
| `prod-eb-gongbiz-crm-b2b-web` | gongbiz-crm-b2b-backend | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-web/var/log/gongbiz/application.log` |
| `prod-eb-gongbiz-crm-b2b-app` | gongbiz-crm-b2b-backend | `/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-app/var/log/gongbiz/application.log` |

#### 표준 키워드 필터
- 일반 에러: `?ERROR ?Exception`
- DB 락: `?Deadlock ?\"Lock wait\"`
- Spring Batch 실패: `?\"JobRepository failure\" ?\"Step Execution\"`
- Hikari 풀: `?HikariPool ?\"Connection is not available\"`
- PR 관련 GBIZ 티켓: `?GBIZ-XXXXX`

### 2-B. DB 정합성 검증

`references/integrity-query-templates.md` 참조.

---

## Phase 3: 이상 감지

`references/alert-thresholds.md` 참조.

---

## Phase 4: 결과 기록

`plan-update` skill 위임 — Phase별 OK/NOK 결과를 plan.md의 §6 QA 결과 요약 표에 갱신.
