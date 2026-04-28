#!/bin/bash
# PR URL → 변경 범위 추출 스크립트
#
# 사용법: ./analyze-pr.sh <PR-URL> <output-dir>
# 출력: <output-dir>/analysis.md (변경 범위 요약)

set -e

PR_URL="${1:?PR URL이 필요합니다 (예: https://github.com/.../pull/5352)}"
OUTPUT_DIR="${2:?출력 디렉토리가 필요합니다}"

# PR 번호 추출
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
if [ -z "$PR_NUMBER" ]; then
  echo "❌ PR URL에서 PR 번호를 추출할 수 없습니다: $PR_URL" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
ANALYSIS_FILE="$OUTPUT_DIR/analysis.md"

echo "🔍 PR #$PR_NUMBER 분석 중..."

# PR 메타데이터 가져오기
PR_JSON=$(gh pr view "$PR_NUMBER" --json baseRefName,headRefName,title,files,body)
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
BASE_REF=$(echo "$PR_JSON" | jq -r '.baseRefName')
HEAD_REF=$(echo "$PR_JSON" | jq -r '.headRefName')

# 변경 파일 목록
CHANGED_FILES=$(echo "$PR_JSON" | jq -r '.files[].path')

# GBIZ 티켓 추출
TICKET=$(gh pr view "$PR_NUMBER" --json commits --jq '.commits[].messageHeadline' | grep -oE 'GBIZ-[0-9]+' | sort -u | head -1)

# 카테고리별 분류
CONTROLLERS=$(echo "$CHANGED_FILES" | grep -E "Controller\.kt$" | grep -v Test | sort -u)
JOB_CONFIGS=$(echo "$CHANGED_FILES" | grep -E "JobConfig\.kt$" | sort -u)
SERVICES=$(echo "$CHANGED_FILES" | grep -E "(Service|Facade)\.kt$" | grep -v Test | sort -u)
ENTITIES=$(echo "$CHANGED_FILES" | grep -E "/entity/.+\.kt$" | sort -u)
REPOSITORIES=$(echo "$CHANGED_FILES" | grep -E "Repository.*\.kt$" | grep -v Test | sort -u)
SCHEDULER_FILES=$(echo "$CHANGED_FILES" | grep -E "Scheduler\.kt$" | sort -u)
LIQUIBASE_CHANGES=$(echo "$CHANGED_FILES" | grep -E "(changelog|liquibase|migration).+\.(xml|sql)$" | sort -u)

# 모듈별 분류 (영향 서버)
HAS_BACKEND=$(echo "$CHANGED_FILES" | grep -c "^gongbiz-crm-b2b-backend/" || true)
HAS_BATCH=$(echo "$CHANGED_FILES" | grep -c "^gongbiz-crm-b2b-batch/" || true)
HAS_CONSUMER=$(echo "$CHANGED_FILES" | grep -c "^gongbiz-crm-b2b-consumer/" || true)
HAS_API=$(echo "$CHANGED_FILES" | grep -c "^gongbiz-crm-b2b-api/" || true)

# 영향 테이블 추출 (Entity / Repository 기반)
AFFECTED_TABLES=$(echo "$ENTITIES" | xargs -I {} basename {} .kt 2>/dev/null | sort -u)

cat > "$ANALYSIS_FILE" <<EOF
# PR #$PR_NUMBER 변경 분석

| 항목 | 값 |
|------|----|
| PR 제목 | $PR_TITLE |
| GBIZ 티켓 | ${TICKET:-N/A} |
| Base | $BASE_REF |
| Head | $HEAD_REF |
| 변경 파일 수 | $(echo "$CHANGED_FILES" | wc -l) |

## 영향받는 서버

EOF

[ "$HAS_BACKEND" -gt 0 ] && echo "- 🟢 \`prod-eb-gongbiz-crm-b2b-web\` + \`prod-eb-gongbiz-crm-b2b-app\` (gongbiz-crm-b2b-backend 변경)" >> "$ANALYSIS_FILE"
[ "$HAS_BATCH" -gt 0 ] && echo "- 🟢 \`prod-ecs-service-gongbiz-crm-b2b-batch\` (gongbiz-crm-b2b-batch 변경)" >> "$ANALYSIS_FILE"
[ "$HAS_CONSUMER" -gt 0 ] && echo "- 🟢 \`prod-ecs-service-gongbiz-crm-b2b-consumer\` (gongbiz-crm-b2b-consumer 변경)" >> "$ANALYSIS_FILE"
[ "$HAS_API" -gt 0 ] && echo "- 🟢 \`prod-ecs-service-gongbiz-crm-b2b-api\` (gongbiz-crm-b2b-api 변경)" >> "$ANALYSIS_FILE"

cat >> "$ANALYSIS_FILE" <<EOF

## 변경 카테고리

### 변경된 Controller (API 엔드포인트)
\`\`\`
${CONTROLLERS:-(없음)}
\`\`\`

### 변경된 JobConfig (배치 Job)
\`\`\`
${JOB_CONFIGS:-(없음)}
\`\`\`

### 변경된 Scheduler
\`\`\`
${SCHEDULER_FILES:-(없음)}
\`\`\`

### 변경된 Service / Facade
\`\`\`
${SERVICES:-(없음)}
\`\`\`

### 변경된 Entity
\`\`\`
${ENTITIES:-(없음)}
\`\`\`

### 변경된 Repository
\`\`\`
${REPOSITORIES:-(없음)}
\`\`\`

### Liquibase 마이그레이션
\`\`\`
${LIQUIBASE_CHANGES:-(없음)}
\`\`\`

## 영향받는 DB 테이블 (Entity 기반 추정)

\`\`\`
${AFFECTED_TABLES:-(추정 불가, Repository/Native SQL 분석 필요)}
\`\`\`

> 더 정밀한 분석은 \`api-test-plan\` skill 위임 권장.
EOF

echo "✅ 분석 완료: $ANALYSIS_FILE"
