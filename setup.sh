#!/usr/bin/env bash
# product-agents/setup.sh
# ~/.claude/agents/ 에 심볼릭 링크를 생성합니다.
# 사용법: ./setup.sh

set -e

AGENTS_DIR="$HOME/.claude/agents"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$AGENTS_DIR"

link_agents() {
  local phase="$1"
  local dir="$REPO_DIR/$phase"
  [ -d "$dir" ] || return

  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    local name
    name="$(basename "$file")"
    local target="$AGENTS_DIR/$name"

    if [ -L "$target" ]; then
      rm "$target"
    elif [ -f "$target" ]; then
      echo "⚠️  $name 은 일반 파일로 존재합니다. 백업 후 교체합니다."
      mv "$target" "$target.bak"
    fi

    ln -s "$file" "$target"
    echo "✅ $name → $file"
  done
}

echo "🔗 심볼릭 링크 생성 중..."
link_agents "01-inception"
link_agents "02-spec"
link_agents "03-plan"
link_agents "04-build"
link_agents "05-test"
link_agents "06-review"
link_agents "07-ship"
link_agents "08-operations"

echo ""
echo "완료: $(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')개 에이전트 연결됨"
echo "경로: $AGENTS_DIR"
