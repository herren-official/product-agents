#!/usr/bin/env bash
# product-agents/setup.sh
# ~/.claude/agents/ 와 ~/.claude/skills/ 에 심볼릭 링크를 생성합니다.
# 사용법: ./setup.sh

set -e

AGENTS_DIR="$HOME/.claude/agents"
SKILLS_DIR="$HOME/.claude/skills"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

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
    echo "✅ agent: $name → $file"
  done
}

link_skills() {
  local dir="$REPO_DIR/skills"
  [ -d "$dir" ] || return

  # skills/<service>/<skill-name>/SKILL.md 구조를 순회하며
  # ~/.claude/skills/<service-lowercase>-<skill-name>/ 로 평탄 링크 생성
  for service_dir in "$dir"/*/; do
    [ -d "$service_dir" ] || continue
    local service_prefix
    service_prefix="$(basename "$service_dir" | tr '[:upper:]' '[:lower:]')"

    for skill_dir in "$service_dir"*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name name target
      skill_name="$(basename "$skill_dir")"
      name="${service_prefix}-${skill_name}"
      target="$SKILLS_DIR/$name"

      if [ -L "$target" ]; then
        rm "$target"
      elif [ -d "$target" ]; then
        echo "⚠️  $name 은 일반 디렉토리로 존재합니다. 백업 후 교체합니다."
        mv "$target" "$target.bak"
      fi

      ln -s "${skill_dir%/}" "$target"
      echo "✅ skill: $name → ${skill_dir%/}"
    done
  done
}

echo "🔗 에이전트 심볼릭 링크 생성 중..."
link_agents "01-inception"
link_agents "02-spec"
link_agents "03-plan"
link_agents "04-build"
link_agents "05-test"
link_agents "06-review"
link_agents "07-ship"
link_agents "08-operations"

echo ""
echo "🔗 스킬 심볼릭 링크 생성 중..."
link_skills

echo ""
echo "완료:"
echo "  - 에이전트 $(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')개 → $AGENTS_DIR"
echo "  - 스킬 $(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')개 → $SKILLS_DIR"
