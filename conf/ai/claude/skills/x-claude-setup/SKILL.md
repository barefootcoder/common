---
name: x-claude-setup
description: Load full context for modifying Claude Code configuration, settings, hooks, MCP servers, skills, or the wrapper script on this machine
model: sonnet
disable-model-invocation: true
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, Agent(claude-code-guide)
---

# Claude Code Setup Context

Load comprehensive context for working on the Claude Code installation and configuration on this machine.

**Input**: $ARGUMENTS (optional: specific area to focus on, e.g. "hooks", "mcp", "permissions", "npm")

## Step 1: Get Claude Code Knowledge

Invoke the `claude-code-guide` agent to answer whatever question the user is asking. Include this context in your prompt to the agent:

> The user runs Claude Code on Linux Mint inside GNU screen + Kitty terminal.
> They have a Perl wrapper script, custom hooks, MCP servers, and a symlinked config structure.
> Please answer their question with full knowledge of Claude Code's capabilities.

If the user's request is purely about local config (e.g., "change my npmrc"), skip the agent and just do it.

## Step 2: Local Setup Reference

Use this reference to understand the local installation before making changes.

### Installation & Launch

- **Claude binary**: Native install at `~/.local/bin/claude` (symlink to `~/.local/share/claude/versions/<version>`)
- **Wrapper script**: `~/common/bin/claude` (Perl) — the user invokes this, not the binary directly
  - Adds `~/common/conf/ai/devtools` and `~/go/bin` to `$PATH`
  - Queries `screen -Q info` to propagate correct terminal dimensions (`$COLUMNS`/`$LINES`)
  - Sets `$TERM=screen-256color` and `$CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`
  - Auto-symlinks `CLAUDE.local.md` for work repos using `$CE_REMOTE_USERNAME`
  - Suppresses screen's message line flash during size query via `msgwait 0`/`msgwait 3`

### Symlink Structure

These files under `~/.claude/` are symlinks into `~/common/conf/ai/claude/` (version-controlled):

| Symlink | Target |
|---------|--------|
| `CLAUDE.md` | `conf/ai/claude/CLAUDE.md` |
| `settings.json` | `conf/ai/claude/settings.json` |
| `skills/` | `conf/ai/claude/skills/` |
| `commands/` | `conf/ai/claude/commands/` |
| `agents/` | `conf/ai/claude/agents/` |
| `statusline-command.sh` | `conf/ai/claude/statusline-command.sh` |

**Not symlinked** (local-only): `.credentials.json`, `history.jsonl`, `sessions/`, `projects/`, `cache/`, `plugins/`, `plans/`, `tasks/`

When editing config, edit the real file in `~/common/conf/ai/claude/` — the symlink ensures `~/.claude/` sees it. Changes are committable via git in `~/common`.

### Terminal Environment (GNU screen)

Claude Code runs inside GNU screen sessions. This causes known issues:
- **Rendering corruption**: Full-screen redraws produce null bytes, overlapping text, mangled Unicode
- **Root cause**: Claude Code's Ink/React TUI emits rapid escape sequences; screen's VT100 emulator can desync
- **DEC mode 2026** (synchronized output) is not supported by screen
- **Terminal size**: Can report 80x24 instead of actual size without the wrapper's `screen -Q info` fix
- **Detailed writeup**: `aidoc/projects/home-network/summary:claude-code-terminal-corruption.md`
- **Mitigations investigated**: claude-chill (PTY proxy), Kitty terminal (now active), terminal size propagation (implemented in wrapper)

### Hooks (`settings.json` → `hooks`)

| Event | Script | Purpose |
|-------|--------|---------|
| `Notification` | `claude-code-set-notification` | Writes JSON marker to `/tmp/` when Claude needs attention |
| `UserPromptSubmit` | `claude-code-clear-notification` | Clears marker when user provides input |
| `SessionEnd` | `claude-code-clear-notification` | Clears marker on exit |
| `PostToolUse` | `claude-code-clear-notification` | Clears marker after tool execution |

**Not yet configured but available**: `PreToolUse` hook with `approve-safe-bash` — a Perl script that auto-approves compound Bash commands (pipes, `&&`, `||`) when all segments are read-only. See `conf/ai/devtools/approve-safe-bash` and `aidoc/summary:approve-safe-bash-hook.md`.

### MCP Servers (`settings.json` → `mcpServers`)

| Server | Type | Notes |
|--------|------|-------|
| `google-sheets` | Local node | `~/proj/claude-code-gsheets-mcp-server/google_sheets_mcp_server.js` |
| `playwright` | npx | `@playwright/mcp@latest` — runs via npx from cache |
| `atlassian-remote` | SSE | `https://mcp.atlassian.com/v1/sse` |

### npm Safety

- `~/.npmrc` has `ignore-scripts=true` globally (defense against supply-chain attacks like the axios RAT incident)
- When installing a trusted package that needs postinstall scripts: `npm install --ignore-scripts=false <package>`
- The `playwright` MCP server runs via `npx` from a cached copy; reinstalling it requires the override flag

### Permissions (`settings.json` → `permissions`)

The `allow` list is extensive — read-only commands, git read operations, skill scripts, MCP tools, and safe CLI tools are pre-approved. The `deny` list blocks destructive curl operations and dangerous find flags.

Key patterns:
- Skill scripts are allowed for both `/home/buddy/` and `/home/bburden/` paths (home vs. work machine)
- `git -C` operations are allowed in settings but **discouraged in CLAUDE.md** when targeting cwd
- `additionalDirectories` grants access to `~/common/aidoc`, `~/common`, and `~/docs/ai/screenshots`

### Status Line

Custom bash script (`statusline-command.sh`) that parses the transcript to show:
- Model name with cost tier indicator (color-coded)
- Per-model token cost calculation (Opus/Sonnet/Haiku rates)
- Context window usage with color warnings (yellow 60%+, red 75%+)
- Sandbox mode indicator
- Project name from cwd

### Devtools (`~/common/conf/ai/devtools/`)

| Script | Purpose |
|--------|---------|
| `approve-safe-bash` | PreToolUse hook: auto-approves read-only compound commands |
| `check-dir-age` | Checks age of a directory (for staleness detection) |
| `claude-code-set-notification` | Notification hook: writes attention-needed marker |
| `claude-code-clear-notification` | Clears notification marker |
| `repo-last-pulled` | Reports when a repo was last pulled |

## Step 3: Make Changes

With the above context loaded, help the user with their specific request. When modifying:
- **settings.json**: Edit `~/common/conf/ai/claude/settings.json` (the real file)
- **Wrapper script**: Edit `~/common/bin/claude`
- **Skills**: Create/edit under `~/common/conf/ai/claude/skills/`
- **Devtools**: Create/edit under `~/common/conf/ai/devtools/`
- **Status line**: Edit `~/common/conf/ai/claude/statusline-command.sh`

Offer to commit changes when done.
