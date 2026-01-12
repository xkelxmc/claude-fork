---
description: Fork current session - copy and get resume command
allowed-tools: Bash(cat:*), Bash(chmod:*), Bash(echo:*), Bash(head:*), Bash(sed:*), Bash(uuidgen:*), Bash(wc:*)
---

# Fork Session

Fork the current Claude Code session for parallel work.

## Execute this script

Run this entire script as a single bash command:

```bash
# Get session ID from TTY-based file (set by SessionStart hook)
TTY_ID=$(echo "$GPG_TTY" | sed 's|/|-|g')
OLD_SESSION_ID=$(cat ~/.claude/sessions/${TTY_ID}.id 2>/dev/null)

if [ -z "$OLD_SESSION_ID" ]; then
  echo "Error: Could not find session ID for this terminal"
  exit 1
fi

PROJECT_PATH=$(echo "$PWD" | sed 's|/|-|g')
SESSIONS_DIR="$HOME/.claude/projects/${PROJECT_PATH}"
CURRENT_SESSION="$SESSIONS_DIR/${OLD_SESSION_ID}.jsonl"

if [ ! -f "$CURRENT_SESSION" ]; then
  echo "Error: Session file not found"
  exit 1
fi

NEW_SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
FORK_FILE="$SESSIONS_DIR/${NEW_SESSION_ID}.jsonl"

# Copy without last 2 lines (the /fork command and response), replace session ID
TOTAL_LINES=$(wc -l < "$CURRENT_SESSION")
KEEP_LINES=$((TOTAL_LINES - 2))
head -n "$KEEP_LINES" "$CURRENT_SESSION" | sed "s/$OLD_SESSION_ID/$NEW_SESSION_ID/g" > "$FORK_FILE"
chmod 600 "$FORK_FILE"

echo ""
echo "Forked: ${OLD_SESSION_ID:0:8} -> ${NEW_SESSION_ID:0:8}"
echo ""
echo "To continue in a new terminal:"
echo "  claude -r $NEW_SESSION_ID"
```

## Important

- The fork is a snapshot BEFORE this /fork command
- Run the resume command in a NEW terminal window
- Requires SessionStart hook that saves session ID by TTY
