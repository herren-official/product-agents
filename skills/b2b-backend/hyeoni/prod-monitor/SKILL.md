---
name: b2b-backend-prod-monitor
description: 운영 배포 후 서버 로그 + DB 정합성을 통합 모니터링한다. PR URL을 입력하면 변경 분석부터 결과 리포트 생성까지 자동 실행.
argument-hint: <PR-URL> [--once|--periodic] [--env prod|dev] [--baseline]
context: fork
agent: general-purpose
---

# Prod Monitor Skill

운영(또는 dev) 배포 후 다음을 통합 모니터링하는 오케스트레이터 skill.

1. **PR 변경 범위 자동 분석** — `api-test-plan` skill 위임
2. **D-1 baseline 스냅샷** — `gongbiz-db` skill 위임
3. **서버 로그 모니터링** — AWS CloudWatch CLI
4. **DB 정합성 검증** — `gongbiz-db` skill 위임 + 표준 쿼리 템플릿
5. **이상 감지 + 마크다운 리포트 생성** — 임계값 기반 분석
6. **결과 표 갱신** — `plan-update` skill 위임

## 사용 방법

```bash
# 1회 실행 (스냅샷)
/b2b-backend-prod-monitor https://github.com/herren-official/gongbiz-crm-b2b-backend/pull/5352 --once --env prod

# 주기 실행 (30분마다, /loop skill 위임)
/b2b-backend-prod-monitor https://github.com/herren-official/gongbiz-crm-b2b-backend/pull/5352 --periodic --env prod

# Baseline만 캡처 (배포 전)
/b2b-backend-prod-monitor https://github.com/herren-official/gongbiz-crm-b2b-backend/pull/5352 --baseline --env prod

# dev 환경
/b2b-backend-prod-monitor https://github.com/herren-official/gongbiz-crm-b2b-backend/pull/5352 --once --env dev
```

## 입력 파싱

`$ARGUMENTS`에서 다음을 추출한다:
- **PR URL** (필수): `https://github.com/.../pull/<NUMBER>` 형식
- **`--once` / `--periodic`** (옵션, 기본 `--once`): 1회 실행 또는 주기 실행
- **`--env prod|dev`** (옵션, 기본 `prod`): 모니터링 대상 환경
- **`--baseline`** (옵션): baseline만 캡처하고 종료

PR URL이 없으면 사용자에게 질문한다.

## 실행 흐름

### Phase 0: PR 변경 분석

1. PR URL에서 PR 번호 추출
2. `gh pr view <PR>` + `gh pr diff <PR>`로 변경된 파일 + diff 가져오기
3. **변경 범위 분석** — `api-test-plan` skill의 분석 로직 활용 또는 직접 수행:
   - 변경된 API 엔드포인트
   - 변경된 배치 Job
   - 변경된 도메인 서비스
   - 영향받는 DB 테이블
   - 영향받는 ECS/EB 서버
4. **모니터링 플랜 md 자동 생성**:
   - 출력 경로: `.docs/issues/<PR번호>-prod-monitoring/plan.md`
   - 템플릿: `references/workflow-phases.md`
   - 변경 범위 + Phase별 모니터링 시나리오 + 단계별 체크리스트 포함

### Phase 1: Baseline 스냅샷 (`--baseline` 또는 `--once`/`--periodic` 시작 시 1회)

1. PR 분석 결과의 영향 테이블 목록 추출
2. **D-1 baseline 쿼리 자동 생성** — `references/integrity-query-templates.md`의 표준 패턴 활용:
   - Row count 분포 (배치 타입 / scope별)
   - 합계 (sale_count, total_actual_amount 등)
   - SHOP_AGG vs EMPLOYEE 합계 일치 여부
   - statistics_target state 분포
   - BATCH_JOB_EXECUTION 상태
3. `gongbiz-db` skill을 통해 replica DB에서 실행
4. 결과 저장: `.docs/issues/<PR번호>-prod-monitoring/snapshots/baseline-NN-*.txt`

### Phase 2: 모니터링 실행

#### `--once` 모드
1. **서버 로그 검색** — AWS CLI로 4개 서버(ECS 2개 + EB 2개) CloudWatch 로그에서 ERROR/Exception/Deadlock 등 키워드 필터
2. **DB 정합성 검증** — `gongbiz-db` skill로 다음 표준 검증:
   - C-3: UK 중복 검증 (6개 통계 테이블)
   - A-1: raw vs SHOP_AGG 합계 비교
   - BATCH_JOB_EXECUTION 상태
   - statistics_target FAIL/PENDING 분포
   - 그 외 PR 변경 범위 기반 동적 쿼리
3. **결과 분석** — `references/alert-thresholds.md` 임계값과 비교
4. 결과 저장: `.docs/issues/<PR번호>-prod-monitoring/snapshots/monitor-<TIMESTAMP>.md`

#### `--periodic` 모드
1. `loop` skill 위임 — 30분마다 `--once` 모드 반복 실행
2. 매 실행 결과를 누적 저장: `.docs/issues/<PR번호>-prod-monitoring/snapshots/monitor-<TIMESTAMP>.md`
3. `Ctrl+C` 또는 `cancel` 명령으로 종료

### Phase 3: 이상 감지 + 리포트 생성

`references/alert-thresholds.md`의 임계값과 비교하여 다음 중 하나라도 해당되면 **이상으로 표시**:

- BATCH FAIL: 1건 이상 발생
- ERROR 로그: 5분 동안 10건 이상
- statistics_target FAIL state: 1건 이상
- 정합성 차이: 합계 차이 > 10,000원 또는 row count 차이 > 5건
- UK 중복: 1건 이상

이상이 발견되면:
- 모니터링 리포트 md의 상단에 **ALERT** 섹션 추가
- 콘솔에 명확히 강조 출력 (사용자가 직접 확인)
- 임계값 초과 항목별 근거 데이터(쿼리 결과 일부) 포함

### Phase 4: 결과 기록

`--once` 또는 `--periodic` 종료 후 `plan-update` skill 위임 — 모니터링 플랜 md의 QA 결과 요약 표 갱신.

## 산출물 디렉토리 구조

```
.docs/issues/<PR번호>-prod-monitoring/
├── plan.md                                  # Phase 0에서 생성한 모니터링 플랜
├── snapshots/
│   ├── baseline-01-batch-job-execution.txt  # D-1 baseline
│   ├── baseline-02-daily-hourly-sale.txt
│   ├── ...
│   ├── monitor-20260428-063000.md           # `--once` 결과 (timestamp별)
│   └── monitor-20260428-070000.md
└── alerts.log                               # 이상 감지 이력 (timestamp + 임계값 초과 항목)
```

## 의존 skill

- `api-test-plan`: PR 변경 분석
- `gongbiz-db`: replica DB 쿼리
- `loop`: 주기적 실행
- `plan-update`: 결과 표 갱신

## 의존 외부 도구

- `gh` (GitHub CLI): PR 정보 조회
- `aws` (AWS CLI, profile=mfa): CloudWatch 로그 검색
- `mysql` (MariaDB client): replica DB 직접 쿼리

## 참고 파일

- 워크플로우 단계별 가이드: `references/workflow-phases.md`
- 정합성 쿼리 템플릿: `references/integrity-query-templates.md`
- 이상 감지 임계값: `references/alert-thresholds.md`
- AWS 로그 그룹 매핑: `~/.claude/skills/api-test-plan/references/log-source-mapping.md` (글로벌)

## 실 사례 — GBIZ-26917 운영 배포 모니터링

이 skill은 `epic-statistics-etc` 브랜치 (PR #5352)의 운영 배포 모니터링 워크플로우를 추상화한 것이다. 실제 사례:

- 산출물 예시: `.docs/issues/epic-statistics-etc-prod-monitoring.md`
- 검증된 모니터링 플로우: 06:10 배포 → 06:30 배치 → 정합성 검증
- 발견 사례:
  1. dailyChannelSaleAggregationJob 32분 → 16초 단축 검증
  2. statistics_target race condition (cutoff 적용 전후 비교)
  3. OFFSET 페이징 누락 (BATCH_STEP_EXECUTION READ_COUNT 비교로 식별)
  4. 부분 환불 미차감 (sale_platform_payment.refund_amount 비반영) — false alarm 후 정정

## 안전 장치

- replica DB만 사용 (read-only) — INSERT/UPDATE/DELETE 절대 금지
- AWS profile은 `--profile mfa` 필수 (사용자 권한)
- `--periodic` 모드는 사용자가 명시적으로 종료할 때까지 실행
