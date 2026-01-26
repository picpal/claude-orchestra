#!/bin/bash
# Claude Orchestra - Uninstaller

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              Claude Orchestra Uninstaller                      ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

TARGET_DIR="${1:-.}"

# Convert to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  echo -e "${RED}Error: Directory does not exist: $1${NC}"
  exit 1
}

echo -e "${YELLOW}Target: ${NC}$TARGET_DIR"
echo ""

# Check if installed
if [ ! -d "$TARGET_DIR/.claude/agents" ] && [ ! -f "$TARGET_DIR/.orchestra/config.json" ]; then
  echo -e "${YELLOW}Claude Orchestra is not installed in this directory${NC}"
  exit 0
fi

echo "This will remove:"
echo ""
echo -e "${YELLOW}.claude/${NC}"
echo "  ├── agents/      (12 Orchestra agents)"
echo "  ├── commands/    (11 Orchestra commands)"
echo "  ├── rules/       (6 rules)"
echo "  ├── contexts/    (3 contexts)"
echo "  ├── hooks/       (15 hooks)"
echo "  └── settings.json"
echo ""
echo -e "${YELLOW}.orchestra/${NC}"
echo "  ├── config.json"
echo "  ├── state.json"
echo "  ├── plans/       (your work plans)"
echo "  └── logs/        (session logs)"
echo ""
echo -e "${YELLOW}CLAUDE.md${NC}"
echo ""

read -p "Are you sure you want to uninstall? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Uninstall cancelled"
  exit 0
fi

echo ""
echo "Removing Claude Orchestra..."

# Remove .claude components
AGENTS=(
  "maestro.md" "planner.md" "interviewer.md" "plan-checker.md"
  "plan-reviewer.md" "architecture.md" "searcher.md" "explorer.md"
  "image-analyst.md" "high-player.md" "low-player.md" "code-reviewer.md"
)

COMMANDS=(
  "start-work.md" "status.md" "tdd-cycle.md" "verify.md" "code-review.md"
  "learn.md" "checkpoint.md" "e2e.md" "refactor-clean.md" "update-docs.md" "context.md"
)

RULES=(
  "security.md" "testing.md" "git-workflow.md" "coding-style.md"
  "performance.md" "agent-rules.md"
)

CONTEXTS=("dev.md" "research.md" "review.md")

echo "🗑️ Removing agents..."
for file in "${AGENTS[@]}"; do
  rm -f "$TARGET_DIR/.claude/agents/$file"
done

echo "🗑️ Removing commands..."
for file in "${COMMANDS[@]}"; do
  rm -f "$TARGET_DIR/.claude/commands/$file"
done

echo "🗑️ Removing rules..."
for file in "${RULES[@]}"; do
  rm -f "$TARGET_DIR/.claude/rules/$file"
done

echo "🗑️ Removing contexts..."
for file in "${CONTEXTS[@]}"; do
  rm -f "$TARGET_DIR/.claude/contexts/$file"
done

echo "🗑️ Removing hooks..."
rm -rf "$TARGET_DIR/.claude/hooks"

echo "🗑️ Removing settings..."
rm -f "$TARGET_DIR/.claude/settings.json"

# Handle .orchestra
if [ -d "$TARGET_DIR/.orchestra" ]; then
  echo ""
  if [ -d "$TARGET_DIR/.orchestra/plans" ] && [ "$(ls -A "$TARGET_DIR/.orchestra/plans" 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️ .orchestra/plans/ contains your work plans${NC}"
    read -p "Delete .orchestra entirely? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$TARGET_DIR/.orchestra"
      echo "🗑️ Removed .orchestra/"
    else
      echo "📁 Keeping .orchestra/plans/"
      rm -f "$TARGET_DIR/.orchestra/config.json"
      rm -f "$TARGET_DIR/.orchestra/state.json"
      rm -rf "$TARGET_DIR/.orchestra/mcp-configs"
      rm -rf "$TARGET_DIR/.orchestra/templates"
      rm -rf "$TARGET_DIR/.orchestra/logs"
      rm -rf "$TARGET_DIR/.orchestra/notepads"
    fi
  else
    rm -rf "$TARGET_DIR/.orchestra"
    echo "🗑️ Removed .orchestra/"
  fi
fi

# Remove CLAUDE.md
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  rm -f "$TARGET_DIR/CLAUDE.md"
  echo "🗑️ Removed CLAUDE.md"
fi

# Clean up empty directories
for dir in agents commands rules contexts; do
  [ -d "$TARGET_DIR/.claude/$dir" ] && [ -z "$(ls -A "$TARGET_DIR/.claude/$dir")" ] && rmdir "$TARGET_DIR/.claude/$dir"
done
[ -d "$TARGET_DIR/.claude" ] && [ -z "$(ls -A "$TARGET_DIR/.claude")" ] && rmdir "$TARGET_DIR/.claude"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Uninstall Complete!                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
