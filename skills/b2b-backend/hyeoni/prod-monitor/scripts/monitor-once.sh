#!/bin/bash
# 1회 모니터링 스크립트 — 4개 서버 로그 + DB 정합성 검증
#
# 사용법: ./monitor-once.sh <output-dir> <env: prod|dev>
# 출력: <output-dir>/snapshots/monitor-<TIMESTAMP>.md

set -e

OUTPUT_DIR="${1:?출력 디렉토리가 필요합니다}"
ENV="${2:-prod}"

DB_CNF="${HOME}/.claude/skills/gongbiz-db/${ENV}.cnf"
SNAPSHOT_DIR="$OUTPUT_DIR/snapshots"
ALERTS_LOG="$OUTPUT_DIR/alerts.log"
mkdir -p "$SNAPSHOT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="$SNAPSHOT_DIR/monitor-$TIMESTAMP.md"

# 환경별 CloudWatch 로그 그룹 매핑
if [ "$ENV" = "prod" ]; then
  LOG_BATCH="/ecs/prod-ecs-td-gongbiz-crm-b2b-batch"
  LOG_CONSUMER="/ecs/prod-td-gongbiz-crm-b2b-consumer"
  LOG_WEB="/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-web/var/log/gongbiz/application.log"
  LOG_APP="/aws/elasticbeanstalk/prod-eb-gongbiz-crm-b2b-app/var/log/gongbiz/application.log"
else
  LOG_BATCH="/ecs/dev-ecs-td-gongbiz-crm-b2b-batch"
  LOG_CONSUMER="/ecs/dev-td-gongbiz-crm-b2b-consumer"
  LOG_WEB=""
  LOG_APP=""
fi

# 5분 윈도
START_TS=$(($(date +%s) - 300))000
END_TS=$(date +%s)000

cat > "$REPORT" <<EOF
# 모니터링 리포트 — $TIMESTAMP

| 항목 | 값 |
|------|----|
| 환경 | $ENV |
| 실행 시각 | $(date -Iseconds) |
| 분석 윈도 | 최근 5분 |

---

## 🚨 ALERT 요약

EOF

ALERTS=()

# 1. 서버 로그 ERROR/Exception 카운트
echo "🔍 1/4: 서버 로그 분석..."
for LOG_GROUP in "$LOG_BATCH" "$LOG_CONSUMER" "$LOG_WEB" "$LOG_APP"; do
  [ -z "$LOG_GROUP" ] && continue
  ERR_COUNT=$(aws logs filter-log-events --profile mfa \
    --log-group-name "$LOG_GROUP" \
    --start-time "$START_TS" --end-time "$END_TS" \
    --filter-pattern "?ERROR ?Exception" \
    --query "length(events)" --output text 2>/dev/null || echo "0")

  if [ "$ERR_COUNT" -ge 10 ]; then
    ALERTS+=("🚨 ALERT: $LOG_GROUP ERROR 로그 $ERR_COUNT건 (>= 10)")
  fi
  echo "  - $LOG_GROUP: ERROR $ERR_COUNT건" >> "$REPORT"

  # Deadlock / Lock wait
  LOCK_COUNT=$(aws logs filter-log-events --profile mfa \
    --log-group-name "$LOG_GROUP" \
    --start-time "$START_TS" --end-time "$END_TS" \
    --filter-pattern "?Deadlock ?\"Lock wait\" ?\"JobRepository failure\"" \
    --query "length(events)" --output text 2>/dev/null || echo "0")

  if [ "$LOCK_COUNT" -ge 1 ]; then
    ALERTS+=("🚨 ALERT: $LOG_GROUP Lock/Deadlock/JobRepository failure $LOCK_COUNT건")
  fi
done

# 2. BATCH_JOB_EXECUTION 상태
echo "🔍 2/4: BATCH_JOB_EXECUTION 검증..."
echo "" >> "$REPORT"
echo "## BATCH_JOB_EXECUTION (최근 1시간)" >> "$REPORT"
echo '```' >> "$REPORT"
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT ji.JOB_NAME, je.STATUS, je.EXIT_CODE,
  TIMESTAMPDIFF(SECOND, je.START_TIME, je.END_TIME) AS dur_sec,
  je.START_TIME, je.END_TIME
FROM BATCH_JOB_EXECUTION je
JOIN BATCH_JOB_INSTANCE ji ON je.JOB_INSTANCE_ID = ji.JOB_INSTANCE_ID
WHERE je.START_TIME >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY je.START_TIME DESC LIMIT 30;
" 2>&1 >> "$REPORT" || true
echo '```' >> "$REPORT"

FAIL_COUNT=$(mysql --defaults-extra-file="$DB_CNF" nailshop -BNe "
SELECT COUNT(*) FROM BATCH_JOB_EXECUTION
WHERE START_TIME >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
  AND STATUS IN ('FAILED', 'UNKNOWN', 'STOPPED');
" 2>/dev/null || echo "0")

if [ "$FAIL_COUNT" -ge 1 ]; then
  ALERTS+=("🚨 ALERT: BATCH_JOB_EXECUTION FAILED/UNKNOWN/STOPPED $FAIL_COUNT건")
fi

# 3. statistics_target FAIL state
echo "🔍 3/4: statistics_target 검증..."
echo "" >> "$REPORT"
echo "## statistics_target 분포" >> "$REPORT"
echo '```' >> "$REPORT"
mysql --defaults-extra-file="$DB_CNF" nailshop --table -e "
SELECT batch_type, batch_period, state,
  CASE WHEN empno = 0 THEN 'SHOP' ELSE 'EMPLOYEE' END AS scope,
  COUNT(*) AS cnt
FROM statistics_target
WHERE state IN ('PENDING', 'FAIL', 'PROCESSING')
GROUP BY batch_type, batch_period, state, scope
ORDER BY state, batch_type, scope;
" 2>&1 >> "$REPORT" || true
echo '```' >> "$REPORT"

ST_FAIL=$(mysql --defaults-extra-file="$DB_CNF" nailshop -BNe "
SELECT COUNT(*) FROM statistics_target WHERE state = 'FAIL';
" 2>/dev/null || echo "0")

if [ "$ST_FAIL" -ge 1 ]; then
  ALERTS+=("🚨 ALERT: statistics_target FAIL state $ST_FAIL건")
fi

# 4. UK 중복 검증
echo "🔍 4/4: UK 중복 검증..."
echo "" >> "$REPORT"
echo "## UK 중복 (최근 2일)" >> "$REPORT"
echo '```' >> "$REPORT"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
DUP_TOTAL=$(mysql --defaults-extra-file="$DB_CNF" nailshop -BNe "
SELECT
  (SELECT COUNT(*) FROM (SELECT 1 FROM daily_sale_statistics WHERE sale_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, sale_date HAVING COUNT(*)>1) t1) +
  (SELECT COUNT(*) FROM (SELECT 1 FROM daily_channel_sale_statistics WHERE sale_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, sale_date, platform_type HAVING COUNT(*)>1) t2) +
  (SELECT COUNT(*) FROM (SELECT 1 FROM daily_customer_sale_statistics WHERE sale_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, sale_date, customer_type HAVING COUNT(*)>1) t3) +
  (SELECT COUNT(*) FROM (SELECT 1 FROM hourly_sale_statistics WHERE sale_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, sale_date, start_time HAVING COUNT(*)>1) t4) +
  (SELECT COUNT(*) FROM (SELECT 1 FROM daily_booking_statistics WHERE booking_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, booking_date HAVING COUNT(*)>1) t5) +
  (SELECT COUNT(*) FROM (SELECT 1 FROM daily_employee_working_statistics WHERE working_date IN ('$YESTERDAY','$TODAY') GROUP BY shopno, empno, working_date HAVING COUNT(*)>1) t6);
" 2>/dev/null || echo "0")
echo "UK 중복 row 합계: $DUP_TOTAL" >> "$REPORT"
echo '```' >> "$REPORT"

if [ "$DUP_TOTAL" -ge 1 ]; then
  ALERTS+=("🚨 CRITICAL: 통계 테이블 UK 중복 $DUP_TOTAL건")
fi

# ALERT 요약 작성
if [ ${#ALERTS[@]} -eq 0 ]; then
  sed -i.bak '/^## 🚨 ALERT 요약$/a\
\
✅ 이상 없음 (모든 임계값 정상 범위 내)\
' "$REPORT" && rm -f "$REPORT.bak"
else
  ALERT_BLOCK=""
  for A in "${ALERTS[@]}"; do
    ALERT_BLOCK="$ALERT_BLOCK\n- $A"
    echo "[$TIMESTAMP] $A" >> "$ALERTS_LOG"
  done
  # macOS sed 호환을 위해 awk 활용
  awk -v ab="$ALERT_BLOCK" '/^## 🚨 ALERT 요약$/{print; print ""; printf "%s\n", ab; next}1' "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"
fi

echo ""
echo "✅ 모니터링 리포트 생성: $REPORT"
echo ""
if [ ${#ALERTS[@]} -gt 0 ]; then
  echo "🚨 발견된 ALERT (${#ALERTS[@]}건):"
  for A in "${ALERTS[@]}"; do
    echo "  - $A"
  done
else
  echo "✅ 이상 없음"
fi
