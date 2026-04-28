# Alert Thresholds — 이상 감지 임계값

prod-monitor가 이상으로 판단하는 기준값. PR별로 override 가능.

---

## 기본 임계값

### 1. 서버 로그 (CloudWatch)

| 항목 | 임계값 | 분석 윈도 | 액션 |
|:---|:---|:---|:---|
| ERROR 로그 | 10건 이상 | 최근 5분 | 🚨 ALERT |
| Exception stack trace | 5건 이상 | 최근 5분 | 🚨 ALERT |
| Deadlock | 1건 이상 | 누적 | 🚨 ALERT |
| Lock wait timeout | 1건 이상 | 누적 | 🚨 ALERT |
| HikariPool connection unavailable | 1건 이상 | 누적 | 🚨 ALERT |
| JobRepository failure | 1건 이상 | 누적 | 🚨 ALERT (Spring Batch metadata 컬럼 한계 의심) |

### 2. Spring Batch 실행 결과

| 항목 | 임계값 | 액션 |
|:---|:---|:---|
| BATCH_JOB_EXECUTION.STATUS = FAILED | 1건 이상 | 🚨 ALERT |
| BATCH_JOB_EXECUTION.STATUS = UNKNOWN | 1건 이상 | 🚨 ALERT |
| BATCH_JOB_EXECUTION.STATUS = STOPPED | 1건 이상 | 🚨 ALERT |
| BATCH_STEP_EXECUTION.ROLLBACK_COUNT > 0 | 1건 이상 | ⚠️ WARN |
| AggregationStep.READ_COUNT vs StateUpdateStep.READ_COUNT 차이 비율 | > 10% | 🚨 ALERT (OFFSET 페이징 누락 회귀 의심) |
| Job 실행 시간 > cron 주기의 80% (예: 30분 주기에 24분 이상) | 1건 이상 | ⚠️ WARN |

### 3. statistics_target 처리 상태

| 항목 | 임계값 | 액션 |
|:---|:---|:---|
| state = 'FAIL' | 1건 이상 | 🚨 ALERT |
| state = 'PENDING' AND oldest_reg < (cutoff - 2시간) | 1건 이상 | 🚨 ALERT (처리 누락) |
| retry_count > 0 | 10건 이상 | ⚠️ WARN |
| 동일 키 PENDING 중복 | 1개 키에 5개 이상 | ⚠️ WARN |
| EMPLOYEE_WORKING 미래 날짜 신규 SUCCESS | 1건 이상 | 🚨 ALERT (GBIZ-26609 회귀) |

### 4. 통계 테이블 정합성

| 항목 | 임계값 | 액션 |
|:---|:---|:---|
| UK 중복 (6개 통계 테이블) | 1건 이상 | 🚨 CRITICAL |
| SHOP_AGG vs EMPLOYEE 합계 차이 | 절대값 > 10,000원 | ⚠️ WARN |
| SHOP_AGG vs EMPLOYEE 합계 차이 | 절대값 > 100,000원 | 🚨 ALERT |
| daily_employee_working에 empno=0 row | 1건 이상 | 🚨 ALERT (정상은 0건) |
| 음수 working - unavailable row 비율 | > 5% | ⚠️ WARN (GBIZ-26319 가드 동작 검증) |

### 5. 원본 vs 집계 비교

| 항목 | 임계값 | 액션 |
|:---|:---|:---|
| raw_total - agg_total 차이 | 절대값 > 100,000원 | 🚨 ALERT |
| raw_count - agg_count 차이 | 절대값 > 10건 | ⚠️ WARN |
| 위 두 항목이 1시간 이상 지속 | 임계값 초과 유지 | 🚨 CRITICAL (cron 시차 아닌 진짜 누락 의심) |

> 주의: raw vs agg 비교 시 `s.moddate <= '<직전_cron_시각>'` 필터 필수. 미적용 시 cron cycle 시차로 인한 false alarm 다수 발생.

---

## 알림 우선순위

| 등급 | 의미 | 처리 |
|:---:|:---|:---|
| 🚨 CRITICAL | 즉시 롤백 검토 필요 | 리포트 최상단에 빨간색 강조 |
| 🚨 ALERT | 운영 이슈 가능성 높음 | 리포트 상단 노란색 강조 |
| ⚠️ WARN | 추적 필요 | 리포트 본문에 표시 |
| ℹ️ INFO | 참고 사항 | 리포트 본문에 표시 |

---

## 임계값 override 방법

PR 분석 시 `.docs/issues/<PR번호>-prod-monitoring/thresholds.yml` 파일을 만들면 PR별 임계값 변경 가능:

```yaml
# 예시
batch:
  failed_count: 0      # 기본 1 → 더 엄격
  unknown_count: 0
log:
  error_count_5min: 5  # 기본 10 → 더 엄격
integrity:
  shop_vs_emp_diff_critical: 50000  # 기본 100000 → 더 엄격
```

파일이 없으면 본 문서의 기본값 사용.

---

## 참조

- GBIZ-26917 / PR #5352에서 발견된 false alarm 사례:
  1. **Pattern 2 (raw < agg)**: raw 쿼리에 moddate filter 누락하여 false alarm. 이후 `s.moddate <= '<직전_cron_시각>'` 필수화.
  2. **부분 환불 미차감**: `sale_platform_payment.refund_amount`가 통계에 반영 안 되는 의도된 동작이지만 alert로 잡힘. → 통계 정의 재검토 후 false alarm 확정.

이런 케이스를 줄이기 위해 임계값은 보수적으로 (false alarm 줄이는 방향) 설정하되, CRITICAL은 명확한 회귀만 잡도록 유지.
