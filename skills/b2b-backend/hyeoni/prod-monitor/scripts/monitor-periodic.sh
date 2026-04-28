#!/bin/bash
# 주기 모니터링 스크립트 — monitor-once.sh를 30분마다 반복
#
# 사용법: ./monitor-periodic.sh <output-dir> <env: prod|dev> [interval-seconds]
# 기본 interval: 1800초 (30분)
#
# 종료: Ctrl+C 또는 외부에서 process 종료

set -e

OUTPUT_DIR="${1:?출력 디렉토리가 필요합니다}"
ENV="${2:-prod}"
INTERVAL="${3:-1800}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONCE_SCRIPT="$SCRIPT_DIR/monitor-once.sh"

if [ ! -x "$ONCE_SCRIPT" ]; then
  chmod +x "$ONCE_SCRIPT" || true
fi

echo "🔄 주기 모니터링 시작 (env=$ENV, interval=${INTERVAL}s, output=$OUTPUT_DIR)"
echo "    종료하려면 Ctrl+C"

trap 'echo ""; echo "🛑 주기 모니터링 종료 (사용자 중단)"; exit 0' INT TERM

ITERATION=1
while true; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔁 Iteration #$ITERATION  ($(date -Iseconds))"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  bash "$ONCE_SCRIPT" "$OUTPUT_DIR" "$ENV" || echo "⚠️ Iteration #$ITERATION 실패 (계속 진행)"

  ITERATION=$((ITERATION + 1))
  echo ""
  echo "💤 다음 실행까지 ${INTERVAL}초 대기..."
  sleep "$INTERVAL"
done
