# Integrity Query Templates

GBIZ-26917 / PR #5352 모니터링에서 검증된 표준 정합성 쿼리 템플릿.
PR 분석 시 영향 테이블 기반으로 동적으로 활용한다.

> 모든 쿼리는 **replica DB read-only**. INSERT/UPDATE/DELETE 절대 금지.

---

## A. BATCH_JOB_EXECUTION 상태 검증

### A-1. 6개 통계 Job 실행 상태
```sql
SELECT
  ji.JOB_NAME, je.STATUS, je.EXIT_CODE,
  je.START_TIME, je.END_TIME,
  TIMESTAMPDIFF(SECOND, je.START_TIME, je.END_TIME) AS duration_sec,
  LEFT(IFNULL(je.EXIT_MESSAGE, ''), 200) AS exit_msg
FROM BATCH_JOB_EXECUTION je
JOIN BATCH_JOB_INSTANCE ji ON je.JOB_INSTANCE_ID = ji.JOB_INSTANCE_ID
WHERE ji.JOB_NAME IN (<영향 Job 목록>)
  AND je.START_TIME >= '<배포_이후>'
ORDER BY ji.JOB_NAME, je.START_TIME DESC;
```
**기대값**: 모든 Job `STATUS=COMPLETED`, `EXIT_CODE=COMPLETED`
**이상값**: `FAILED`, `STOPPED`, `UNKNOWN`, `EXIT_MESSAGE`에 stack trace

### A-2. Step Execution READ vs WRITE 일치
```sql
SELECT
  STEP_EXECUTION_ID, STEP_NAME, STATUS,
  COMMIT_COUNT, READ_COUNT, WRITE_COUNT, FILTER_COUNT, ROLLBACK_COUNT,
  TIMESTAMPDIFF(SECOND, START_TIME, END_TIME) AS duration_sec
FROM BATCH_STEP_EXECUTION
WHERE START_TIME >= '<배포_이후>'
ORDER BY STEP_EXECUTION_ID DESC LIMIT 30;
```
**기대값**: AggregationStep READ_COUNT == StateUpdateStep READ_COUNT (동일 JobExecution)
**이상값**: StateUpdateStep READ_COUNT가 AggregationStep의 약 50% (OFFSET 페이징 누락 — GBIZ-26932 fix 이후 발생 안 해야 함)

---

## B. 통계 테이블 row 수 / 합계 (D-1 vs D-day)

### B-1. 일별 매출 통계
```sql
SELECT
  sale_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  COUNT(DISTINCT shopno) AS unique_shops,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_sale_amount) AS sum_total_sale_amount,
  SUM(total_actual_amount) AS sum_total_actual_amount,
  SUM(total_deducted_amount) AS sum_total_deducted_amount
FROM daily_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY sale_date, scope
ORDER BY sale_date, scope;
```

### B-2. 시간별 매출 통계
```sql
SELECT
  sale_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount
FROM hourly_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY sale_date, scope;
```

### B-3. 채널별 매출 (PlatformType별)
```sql
SELECT
  sale_date, platform_type,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount,
  SUM(CASE WHEN sale_count = 0 AND total_actual_amount = 0 AND total_deducted_amount = 0
           THEN 1 ELSE 0 END) AS all_zero_row_count
FROM daily_channel_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY sale_date, platform_type, scope;
```

### B-4. 고객 유형별 매출
```sql
SELECT
  sale_date, customer_type,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(customer_count) AS sum_customer_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount
FROM daily_customer_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY sale_date, customer_type, scope;
```

### B-5. 일별 예약 통계
```sql
SELECT
  booking_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(total_booking_count) AS sum_total_booking,
  SUM(booking_count) AS sum_booking,
  SUM(noshow_count) AS sum_noshow,
  SUM(booking_cancel_count) AS sum_cancel
FROM daily_booking_statistics
WHERE booking_date IN ('<D-1>', '<D-day>')
GROUP BY booking_date, scope;
```

### B-6. 일별 직원 근무 통계
```sql
SELECT
  working_date,
  COUNT(*) AS row_count,
  COUNT(DISTINCT shopno) AS unique_shops,
  COUNT(DISTINCT empno) AS unique_employees,
  SUM(working_times) AS sum_working_minutes,
  SUM(rest_times) AS sum_rest_minutes,
  SUM(unavailable_times) AS sum_unavailable_minutes,
  SUM(booking_times) AS sum_booking_minutes,
  SUM(CASE WHEN empno = 0 THEN 1 ELSE 0 END) AS empno_zero_count_should_be_0,
  SUM(CASE WHEN CAST(working_times AS SIGNED) - CAST(unavailable_times AS SIGNED) < 0
           THEN 1 ELSE 0 END) AS negative_available_row_count
FROM daily_employee_working_statistics
WHERE working_date IN ('<D-1>', '<D-day>')
GROUP BY working_date;
```

---

## C. 무결성 검증

### C-1. UK 중복 검증 (6개 통계 테이블)
```sql
-- daily_sale_statistics
SELECT shopno, empno, sale_date, COUNT(*) AS dup_count
FROM daily_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY shopno, empno, sale_date HAVING COUNT(*) > 1 LIMIT 50;

-- daily_channel_sale_statistics
SELECT shopno, empno, sale_date, platform_type, COUNT(*) AS dup_count
FROM daily_channel_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>')
GROUP BY shopno, empno, sale_date, platform_type HAVING COUNT(*) > 1 LIMIT 50;

-- (나머지 4개 테이블 동일 패턴)
```
**기대값**: 모든 테이블 0건
**이상값**: 1건 이상 — 동시성 락 깨짐 또는 컨슈머 중복 처리 의심

### C-2. SHOP_AGG vs EMPLOYEE 합계 일치
```sql
SELECT
  sale_date, shopno,
  SUM(CASE WHEN empno = 0 THEN total_actual_amount ELSE 0 END) AS shop_amt,
  SUM(CASE WHEN empno > 0 THEN total_actual_amount ELSE 0 END) AS sum_emp_amt,
  SUM(CASE WHEN empno = 0 THEN total_actual_amount ELSE 0 END)
    - SUM(CASE WHEN empno > 0 THEN total_actual_amount ELSE 0 END) AS diff
FROM <daily_*_statistics>
WHERE sale_date = '<D-day>'
GROUP BY sale_date, shopno
HAVING diff <> 0
ORDER BY ABS(diff) DESC LIMIT 50;
```

### C-3. customer_type 분류 정합성
```sql
-- NEW = NEW_GENERAL + NEW_INTRODUCE 검증
SELECT
  sale_date,
  CASE
    WHEN customer_type IN ('RETURNING','RETURNING_ASSIGNED','RETURNING_SUBSTITUTE') THEN 'RETURNING_GROUP'
    WHEN customer_type IN ('NEW','NEW_GENERAL','NEW_INTRODUCE') THEN 'NEW_GROUP'
    WHEN customer_type = 'UNREGISTERED' THEN 'UNREGISTERED'
    ELSE 'OTHER'
  END AS customer_group,
  SUM(customer_count) AS sum_customer_count,
  SUM(total_actual_amount) AS sum_amt
FROM daily_customer_sale_statistics
WHERE sale_date IN ('<D-1>', '<D-day>') AND empno = 0
GROUP BY sale_date, customer_group;
```

---

## D. statistics_target 처리 상태

### D-1. state 분포
```sql
SELECT
  batch_type, batch_period, state,
  CASE WHEN empno = 0 THEN 'SHOP' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS cnt,
  MIN(regdate) AS oldest_reg,
  MAX(moddate) AS latest_mod,
  AVG(retry_count) AS avg_retry
FROM statistics_target
WHERE regdate >= '<배포_이후>'
GROUP BY batch_type, batch_period, state, scope
ORDER BY batch_type, batch_period, state, scope;
```
**기대값**: SUCCESS 위주, FAIL 0건
**이상값**: FAIL 누적, retry_count > 0 다수, PENDING long tail

### D-2. 동일 키 PENDING 중복 검증
```sql
SELECT
  shopno, empno, target_date, batch_type, batch_period,
  COUNT(*) AS dup_count
FROM statistics_target
WHERE state = 'PENDING'
GROUP BY shopno, empno, target_date, batch_type, batch_period
HAVING COUNT(*) > 1
ORDER BY dup_count DESC LIMIT 20;
```

### D-3. EMPLOYEE_WORKING 미래 날짜 skip 검증
```sql
SELECT COUNT(*) AS future_employee_working_count
FROM statistics_target
WHERE batch_type = 'EMPLOYEE_WORKING'
  AND target_date > CURRENT_DATE
  AND state = 'SUCCESS'
  AND moddate >= '<배포_이후>';
```
**기대값**: 0건 (GBIZ-26609 미래 날짜 skip)

---

## E. 원본 vs 집계 정합성 (advanced)

### E-1. raw sale 합계 vs daily_sale_statistics(SHOP_AGG)
```sql
WITH raw_total AS (
    SELECT
        STR_TO_DATE(s.saledate, '%Y%m%d') AS sale_date,
        COUNT(DISTINCT s.saleno) AS raw_sale_count,
        COALESCE(SUM(sc.saleamt - sc.deducted_membership_amount - sc.deducted_point_amount), 0) AS raw_total_actual
    FROM sale s
        INNER JOIN saledetail sd ON s.saleno = sd.saleno
        INNER JOIN salecharge sc ON sd.id = sc.sale_detail_id
    WHERE s.saledate IN ('<D-1_yyyyMMdd>', '<D-day_yyyyMMdd>')
      AND s.state = '등록'
      AND s.moddate <= '<직전_cron_시각>'  -- cron 시차 보정 필수
    GROUP BY s.saledate
),
agg_total AS (
    SELECT
        sale_date,
        SUM(sale_count) AS agg_sale_count,
        SUM(total_actual_amount) AS agg_total_actual
    FROM daily_sale_statistics
    WHERE sale_date IN ('<D-1>', '<D-day>') AND empno = 0
    GROUP BY sale_date
)
SELECT
    r.sale_date,
    r.raw_sale_count, a.agg_sale_count,
    (r.raw_sale_count - a.agg_sale_count) AS diff_count,
    r.raw_total_actual, a.agg_total_actual,
    (r.raw_total_actual - a.agg_total_actual) AS diff_actual_amount
FROM raw_total r JOIN agg_total a ON r.sale_date = a.sale_date
ORDER BY r.sale_date;
```
**중요**: `s.moddate <= '<직전_cron_시각>'` 필터 누락 시 cron cycle 시차로 인한 false alarm 발생

---

## F. 30분 주기 cron 검증

### F-1. 6개 Job trigger 간격
```sql
WITH job_runs AS (
    SELECT ji.JOB_NAME, je.START_TIME,
           LAG(je.START_TIME) OVER (PARTITION BY ji.JOB_NAME ORDER BY je.START_TIME) AS prev_start
    FROM BATCH_JOB_EXECUTION je
        JOIN BATCH_JOB_INSTANCE ji ON je.JOB_INSTANCE_ID = ji.JOB_INSTANCE_ID
    WHERE ji.JOB_NAME IN (<6개 Job>)
      AND je.START_TIME >= '<배포_이후>'
)
SELECT JOB_NAME, START_TIME, prev_start,
       TIMESTAMPDIFF(SECOND, prev_start, START_TIME) AS interval_seconds
FROM job_runs WHERE prev_start IS NOT NULL
ORDER BY JOB_NAME, START_TIME;
```
**기대값**: `interval_seconds ≈ 1800` (오차 ±5초)

---

## 사용 가이드

PR 변경 분석에서 영향 테이블 목록을 추출 후, 위 카테고리에서 해당하는 쿼리를 자동 선택해 실행:

| 영향 영역 | 우선 적용 쿼리 |
|:---|:---|
| 통계 테이블 변경 | A, B, C-1, C-2 |
| 배치 Job 변경 | A, D, F |
| 신규 도메인 서비스 (API) | B, C-2 |
| Reader/Writer 변경 | A-2 (Step READ vs WRITE 일치) |
| 채널/고객 분류 변경 | B-3, B-4, C-3 |
| 샵 단위 집계 (empno=0) 변경 | B-1~B-5의 SHOP_AGG, C-2 |
