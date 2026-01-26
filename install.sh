#!/bin/bash
# Claude Orchestra - Manual Installation Script
# For users who clone the repo and want to install to their project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Claude Orchestra - Manual Installer                  ║${NC}"
echo -e "${BLUE}║                                                                 ║${NC}"
echo -e "${BLUE}║   For marketplace install, use:                                ║${NC}"
echo -e "${BLUE}║   /plugin marketplace add picpal/claude-orchestra              ║${NC}"
echo -e "${BLUE}║   /plugin install claude-orchestra@claude-orchestra            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory (where claude-orchestra repo is cloned)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Verify we're in the right directory
if [ ! -d "$SCRIPT_DIR/agents" ] || [ ! -d "$SCRIPT_DIR/commands" ]; then
  echo -e "${RED}Error: agents/ or commands/ directory not found${NC}"
  echo "Please run this script from the claude-orchestra directory"
  exit 1
fi

# Target directory (user's project)
TARGET_DIR="${1:-.}"

# Convert to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  echo -e "${RED}Error: Target directory does not exist: $1${NC}"
  exit 1
}

echo -e "${CYAN}Source:${NC} $SCRIPT_DIR"
echo -e "${CYAN}Target:${NC} $TARGET_DIR"
echo ""

# Check for existing installation
if [ -d "$TARGET_DIR/.claude/agents" ]; then
  echo -e "${YELLOW}Warning: Existing Claude Orchestra installation detected${NC}"
  read -p "Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
  fi
fi

echo -e "${GREEN}Installing Claude Orchestra...${NC}"
echo ""

# Create .claude directory structure
echo "📁 Creating directories..."
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/rules"
mkdir -p "$TARGET_DIR/.claude/contexts"
mkdir -p "$TARGET_DIR/.claude/hooks/verification"
mkdir -p "$TARGET_DIR/.claude/hooks/learning/learned-patterns"
mkdir -p "$TARGET_DIR/.claude/hooks/compact"

# Create .orchestra directory structure
mkdir -p "$TARGET_DIR/.orchestra/plans"
mkdir -p "$TARGET_DIR/.orchestra/notepads"
mkdir -p "$TARGET_DIR/.orchestra/logs"
mkdir -p "$TARGET_DIR/.orchestra/mcp-configs"
mkdir -p "$TARGET_DIR/.orchestra/templates"

# Copy agents
echo "🤖 Installing 12 agents..."
cp -r "$SCRIPT_DIR/agents/"* "$TARGET_DIR/.claude/agents/"

# Copy commands
echo "📝 Installing 11 commands..."
cp -r "$SCRIPT_DIR/commands/"* "$TARGET_DIR/.claude/commands/"

# Copy rules
echo "📋 Installing 6 rules..."
cp -r "$SCRIPT_DIR/rules/"* "$TARGET_DIR/.claude/rules/"

# Copy contexts
echo "🔄 Installing 3 contexts..."
cp -r "$SCRIPT_DIR/contexts/"* "$TARGET_DIR/.claude/contexts/"

# Copy hooks
echo "🪝 Installing 15 hooks..."
cp -r "$SCRIPT_DIR/hooks/"* "$TARGET_DIR/.claude/hooks/"

# Set execute permissions for hooks
find "$TARGET_DIR/.claude/hooks" -name "*.sh" -exec chmod +x {} \;

# Copy settings.json
echo "⚙️  Installing settings..."
cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"

# Copy orchestra init files
echo "📊 Installing orchestra state files..."
cp "$SCRIPT_DIR/orchestra-init/config.json" "$TARGET_DIR/.orchestra/config.json"
cp "$SCRIPT_DIR/orchestra-init/state.json" "$TARGET_DIR/.orchestra/state.json"

if [ -d "$SCRIPT_DIR/orchestra-init/mcp-configs" ]; then
  cp -r "$SCRIPT_DIR/orchestra-init/mcp-configs/"* "$TARGET_DIR/.orchestra/mcp-configs/" 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/orchestra-init/templates" ]; then
  cp -r "$SCRIPT_DIR/orchestra-init/templates/"* "$TARGET_DIR/.orchestra/templates/" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!                            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed to: $TARGET_DIR"
echo ""
echo -e "${CYAN}.claude/${NC}"
echo "  ├── agents/      (12 agents)"
echo "  ├── commands/    (11 commands)"
echo "  ├── rules/       (6 rules)"
echo "  ├── contexts/    (3 contexts)"
echo "  ├── hooks/       (15 hooks)"
echo "  └── settings.json"
echo ""
echo -e "${CYAN}.orchestra/${NC}"
echo "  ├── config.json"
echo "  ├── state.json"
echo "  ├── plans/"
echo "  └── logs/"
echo ""
echo -e "${YELLOW}Quick Start:${NC}"
echo "  /start-work    - Start a work session"
echo "  /status        - Check current status"
echo "  /tdd-cycle     - TDD cycle guide"
echo "  /verify        - Run verification loop"
echo ""
echo ""
