# Claude Code Session Fork

Fork your Claude Code sessions for parallel work. Create independent copies of your current conversation to explore different approaches simultaneously.

## How it works

1. A `SessionStart` hook saves the current session ID to a TTY-specific file
2. The `/fork` command reads this ID, copies the session file with a new UUID, and outputs a resume command
3. You run the resume command in a new terminal to continue with the forked session

## Quick Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-fork.git
cd claude-fork
./install.sh
```

The installer will:
- Create necessary directories
- Install the `/fork` command
- Configure the SessionStart hook (or add to existing one)
- Update settings.json

## Manual Installation

### 1. Add the SessionStart hook

If you don't have a SessionStart hook yet, copy `session-hook.sh` to `~/.claude/hooks/`:

```bash
mkdir -p ~/.claude/hooks
cp session-hook.sh ~/.claude/hooks/session-start.sh
chmod +x ~/.claude/hooks/session-start.sh
```

If you already have a SessionStart hook, add this snippet to it:

```bash
# Save session ID by TTY for multi-terminal support
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -n "$transcript_path" ] && [ -n "$GPG_TTY" ]; then
  session_id=$(basename "$transcript_path" .jsonl)
  tty_id=$(echo "$GPG_TTY" | sed 's|/|-|g')
  mkdir -p ~/.claude/sessions
  echo "$session_id" > ~/.claude/sessions/${tty_id}.id
fi
```

### 2. Configure the hook in settings

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Install the fork command

Copy `fork.md` to your Claude Code commands directory:

```bash
mkdir -p ~/.claude/commands
cp fork.md ~/.claude/commands/
```

## Usage

1. In any Claude Code session, run `/fork`
2. Copy the output command (e.g., `claude -r abc123-def456-...`)
3. Open a new terminal and run the command
4. You now have an independent copy of your session

## Requirements

- `jq` for JSON parsing
- `GPG_TTY` environment variable (usually set by your shell for GPG agent, also used here for terminal identification)

## How the fork works

- Creates a copy of the session `.jsonl` file with a new UUID
- Replaces all `sessionId` references inside the file
- Removes the last 2 lines (the `/fork` command itself and response)
- Sets proper file permissions (600)

## Limitations

- The fork is a snapshot at the moment of `/fork` command
- Forked sessions are independent — changes in one don't affect the other
- You must run the resume command in a **new terminal** (not the same one)
- Don't use `-c` flag with `-r` when resuming a fork — it overrides the session ID

## Troubleshooting

**Fork command says "Could not find session ID"**
- Make sure the SessionStart hook is configured
- Restart Claude Code to trigger the hook

**Resume opens the original session instead of fork**
- Don't use `claude -r ID -c`, use `claude -r ID` without `-c`
- Check file permissions: `ls -la ~/.claude/projects/*/FORK_ID.jsonl` should show `-rw-------`
