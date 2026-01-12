#!/bin/bash
# Claude Code SessionStart hook snippet for fork support
# Add this to your existing SessionStart hook or use as standalone

input=$(cat)

# [claude-fork] Save session ID by TTY for multi-terminal support
# Extract from transcript_path (more reliable than .session_id field)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -n "$GPG_TTY" ]; then
  session_id=$(basename "$transcript_path" .jsonl)
  tty_id=$(echo "$GPG_TTY" | sed 's|/|-|g')
  mkdir -p ~/.claude/sessions
  echo "$session_id" > ~/.claude/sessions/${tty_id}.id
fi

exit 0
