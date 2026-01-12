#!/bin/bash
# Claude Fork Installer
# Interactive installation script for claude-fork

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
HOOK_FILE="$HOOKS_DIR/session-start.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hook snippet to add
HOOK_SNIPPET='# [claude-fork] Save session ID by TTY for multi-terminal support
transcript_path=$(echo "$input" | jq -r '"'"'.transcript_path // empty'"'"')
if [ -n "$transcript_path" ] && [ -n "$GPG_TTY" ]; then
  session_id=$(basename "$transcript_path" .jsonl)
  tty_id=$(echo "$GPG_TTY" | sed '"'"'s|/|-|g'"'"')
  mkdir -p ~/.claude/sessions
  echo "$session_id" > ~/.claude/sessions/${tty_id}.id
fi'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Claude Fork Installer             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install it with: brew install jq"
    exit 1
fi

# Check for GPG_TTY
if [ -z "$GPG_TTY" ]; then
    echo -e "${YELLOW}Warning: GPG_TTY is not set in your current shell.${NC}"
    echo "Add this to your .zshrc or .bashrc:"
    echo '  export GPG_TTY=$(tty)'
    echo ""
fi

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "$HOOKS_DIR" "$COMMANDS_DIR" "$SESSIONS_DIR"
echo -e "${GREEN}✓${NC} Directories created"
echo ""

# ══════════════════════════════════════════
# Install fork.md command
# ══════════════════════════════════════════
echo -e "${BLUE}Installing /fork command...${NC}"

if [ -f "$COMMANDS_DIR/fork.md" ]; then
    echo -e "${YELLOW}fork.md already exists.${NC}"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_DIR/fork.md" "$COMMANDS_DIR/fork.md"
        echo -e "${GREEN}✓${NC} fork.md updated"
    else
        echo -e "${YELLOW}→${NC} Skipped fork.md"
    fi
else
    cp "$SCRIPT_DIR/fork.md" "$COMMANDS_DIR/fork.md"
    echo -e "${GREEN}✓${NC} fork.md installed"
fi
echo ""

# ══════════════════════════════════════════
# Install/update SessionStart hook
# ══════════════════════════════════════════
echo -e "${BLUE}Configuring SessionStart hook...${NC}"

if [ -f "$HOOK_FILE" ]; then
    # Check if our snippet is already there
    if grep -q "\[claude-fork\]" "$HOOK_FILE"; then
        echo -e "${GREEN}✓${NC} Hook already contains claude-fork snippet"
    else
        echo -e "${YELLOW}Existing hook found at $HOOK_FILE${NC}"
        echo ""
        echo "Current content:"
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        head -20 "$HOOK_FILE"
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        echo ""
        echo "The following snippet needs to be added:"
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        echo "$HOOK_SNIPPET"
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        echo ""
        read -p "Add snippet to existing hook? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            # Add snippet before 'exit 0' if it exists, otherwise at the end
            if grep -q "^exit 0" "$HOOK_FILE"; then
                # Insert before exit 0
                sed -i.bak '/^exit 0/i\
'"$HOOK_SNIPPET"'
' "$HOOK_FILE"
                rm -f "$HOOK_FILE.bak"
            else
                # Append to end
                echo "" >> "$HOOK_FILE"
                echo "$HOOK_SNIPPET" >> "$HOOK_FILE"
            fi
            echo -e "${GREEN}✓${NC} Snippet added to existing hook"
        else
            echo -e "${YELLOW}→${NC} Skipped hook modification"
            echo -e "${YELLOW}  Please add the snippet manually${NC}"
        fi
    fi
else
    # Create new hook file
    echo -e "Creating new hook file..."
    cat > "$HOOK_FILE" << 'HOOKEOF'
#!/bin/bash
# Claude Code SessionStart hook

input=$(cat)

# [claude-fork] Save session ID by TTY for multi-terminal support
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -n "$GPG_TTY" ]; then
  session_id=$(basename "$transcript_path" .jsonl)
  tty_id=$(echo "$GPG_TTY" | sed 's|/|-|g')
  mkdir -p ~/.claude/sessions
  echo "$session_id" > ~/.claude/sessions/${tty_id}.id
fi

exit 0
HOOKEOF
    chmod +x "$HOOK_FILE"
    echo -e "${GREEN}✓${NC} Hook file created"
fi
echo ""

# ══════════════════════════════════════════
# Configure settings.json
# ══════════════════════════════════════════
echo -e "${BLUE}Configuring settings.json...${NC}"

if [ -f "$SETTINGS_FILE" ]; then
    # Check if SessionStart hook is already configured
    if jq -e '.hooks.SessionStart' "$SETTINGS_FILE" > /dev/null 2>&1; then
        # Check if our hook is in the list
        if jq -e '.hooks.SessionStart[] | .hooks[]? | select(.command | contains("session-start.sh"))' "$SETTINGS_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} SessionStart hook already configured in settings.json"
        else
            echo -e "${YELLOW}SessionStart hooks exist but session-start.sh not found${NC}"
            echo "Current SessionStart config:"
            jq '.hooks.SessionStart' "$SETTINGS_FILE"
            echo ""
            read -p "Add session-start.sh to existing hooks? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                # Add our hook to existing array
                jq '.hooks.SessionStart += [{"hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]}]' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                echo -e "${GREEN}✓${NC} Hook added to settings.json"
            else
                echo -e "${YELLOW}→${NC} Skipped settings.json modification"
            fi
        fi
    else
        # No SessionStart hooks, add the whole section
        if jq -e '.hooks' "$SETTINGS_FILE" > /dev/null 2>&1; then
            # hooks object exists, add SessionStart
            jq '.hooks.SessionStart = [{"hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]}]' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        else
            # No hooks object, create it
            jq '. + {"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]}]}}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
        fi
        mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo -e "${GREEN}✓${NC} SessionStart hook added to settings.json"
    fi
else
    # Create new settings.json
    echo '{"hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]}]}}' | jq '.' > "$SETTINGS_FILE"
    echo -e "${GREEN}✓${NC} settings.json created"
fi
echo ""

# ══════════════════════════════════════════
# Done
# ══════════════════════════════════════════
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Installation complete!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Usage:"
echo "  1. Restart Claude Code (or start a new session)"
echo "  2. Run /fork in any session"
echo "  3. Copy the output command to a new terminal"
echo ""
echo -e "${YELLOW}Note: The hook activates on next session start.${NC}"
echo -e "${YELLOW}      Run 'claude' in a new terminal to test.${NC}"
