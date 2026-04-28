#!/bin/bash
# D-1 baseline 스냅샷 스크립트
#
# 사용법: ./snapshot-baseline.sh <output-dir> <env: prod|dev>
# 출력: <output-dir>/snapshots/baseline-NN-*.txt

set -e

OUTPUT_DIR="${1:?출력 디렉토리가 필요합니다}"
ENV="${2:-prod}"

DB_CNF="${HOME}/.claude/skills/gongbiz-db/${ENV}.cnf"
if [ ! -f "$DB_CNF" ]; then
  echo "❌ DB 설정 파일이 없습니다: $DB_CNF" >&2
  exit 1
fi

SNAPSHOT_DIR="$OUTPUT_DIR/snapshots"
mkdir -p "$SNAPSHOT_DIR"

# D-1 / D-day 자동 계산
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)

echo "🔍 Baseline 스냅샷 수집 시작 (env=$ENV, D-1=$YESTERDAY)..."

# 1. BATCH_JOB_EXECUTION
echo "  📊 1/5: BATCH_JOB_EXECUTION..."
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT
  ji.JOB_NAME, je.STATUS, je.EXIT_CODE,
  je.START_TIME, je.END_TIME,
  TIMESTAMPDIFF(SECOND, je.START_TIME, je.END_TIME) AS duration_sec,
  LEFT(IFNULL(je.EXIT_MESSAGE, ''), 100) AS exit_msg
FROM BATCH_JOB_EXECUTION je
JOIN BATCH_JOB_INSTANCE ji ON je.JOB_INSTANCE_ID = ji.JOB_INSTANCE_ID
WHERE je.START_TIME >= '$YESTERDAY 00:00:00'
  AND je.START_TIME <  '$TODAY 00:00:00'
ORDER BY ji.JOB_NAME, je.START_TIME DESC
LIMIT 100;
" > "$SNAPSHOT_DIR/baseline-01-batch-job-execution.txt" 2>&1

# 2. daily/hourly sale statistics
echo "  📊 2/5: daily/hourly sale statistics..."
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT '$YESTERDAY' AS sale_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count, COUNT(DISTINCT shopno) AS unique_shops,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_sale_amount) AS sum_total_sale_amount,
  SUM(total_actual_amount) AS sum_total_actual_amount,
  SUM(total_deducted_amount) AS sum_total_deducted_amount
FROM daily_sale_statistics WHERE sale_date = '$YESTERDAY'
GROUP BY scope WITH ROLLUP;

SELECT '$YESTERDAY' AS sale_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount
FROM hourly_sale_statistics WHERE sale_date = '$YESTERDAY'
GROUP BY scope WITH ROLLUP;
" > "$SNAPSHOT_DIR/baseline-02-daily-hourly-sale.txt" 2>&1

# 3. channel/customer
echo "  📊 3/5: channel/customer statistics..."
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT '$YESTERDAY' AS sale_date, platform_type,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount,
  SUM(CASE WHEN sale_count = 0 AND total_actual_amount = 0 AND total_deducted_amount = 0
           THEN 1 ELSE 0 END) AS all_zero_row_count
FROM daily_channel_sale_statistics WHERE sale_date = '$YESTERDAY'
GROUP BY platform_type, scope ORDER BY platform_type, scope;

SELECT '$YESTERDAY' AS sale_date, customer_type,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count,
  SUM(customer_count) AS sum_customer_count,
  SUM(sale_count) AS sum_sale_count,
  SUM(total_actual_amount) AS sum_total_actual_amount
FROM daily_customer_sale_statistics WHERE sale_date = '$YESTERDAY'
GROUP BY customer_type, scope ORDER BY customer_type, scope;
" > "$SNAPSHOT_DIR/baseline-03-channel-customer.txt" 2>&1

# 4. booking/employee_working
echo "  📊 4/5: booking/employee_working..."
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT '$YESTERDAY' AS booking_date,
  CASE WHEN empno = 0 THEN 'SHOP_AGG' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS row_count, COUNT(DISTINCT shopno) AS unique_shops,
  SUM(total_booking_count) AS sum_total_booking,
  SUM(booking_count) AS sum_booking,
  SUM(noshow_count) AS sum_noshow,
  SUM(booking_cancel_count) AS sum_cancel
FROM daily_booking_statistics WHERE booking_date = '$YESTERDAY'
GROUP BY scope WITH ROLLUP;

SELECT '$YESTERDAY' AS working_date,
  COUNT(*) AS row_count, COUNT(DISTINCT shopno) AS unique_shops,
  COUNT(DISTINCT empno) AS unique_employees,
  SUM(working_times) AS sum_working_minutes,
  SUM(unavailable_times) AS sum_unavailable_minutes,
  SUM(booking_times) AS sum_booking_minutes,
  SUM(CASE WHEN empno = 0 THEN 1 ELSE 0 END) AS empno_zero_count_should_be_0
FROM daily_employee_working_statistics WHERE working_date = '$YESTERDAY';
" > "$SNAPSHOT_DIR/baseline-04-booking-employee-working.txt" 2>&1

# 5. statistics_target 분포
echo "  📊 5/5: statistics_target 분포..."
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT batch_type, batch_period, state,
  CASE WHEN empno = 0 THEN 'SHOP' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS cnt,
  MIN(regdate) AS oldest_reg, MAX(moddate) AS latest_mod
FROM statistics_target
WHERE regdate >= '$YESTERDAY 00:00:00'
GROUP BY batch_type, batch_period, state, scope
ORDER BY batch_type, batch_period, state, scope;

SELECT 'future_employee_working_targets' AS check_name,
  COUNT(*) AS count,
  MIN(target_date) AS earliest, MAX(target_date) AS latest
FROM statistics_target
WHERE batch_type = 'EMPLOYEE_WORKING' AND target_date > CURRENT_DATE;
" > "$SNAPSHOT_DIR/baseline-05-statistics-target.txt" 2>&1

echo "✅ Baseline 스냅샷 완료: $SNAPSHOT_DIR/baseline-*.txt"
ls -la "$SNAPSHOT_DIR"/baseline-*.txt
