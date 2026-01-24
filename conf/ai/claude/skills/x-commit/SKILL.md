---
model: sonnet
disable-model-invocation: true
---

# Git Commit Skill

Create or amend git commits with proper message formatting.

## Scope Determination

Invoked as: `/x-commit {{ARGS}}`

- **No args**: Commit files modified during this conversation
- **With args**: Specific files, or instructions like "amend", or both

## Commit Message Format

```
Brief description of changes

Optional detailed explanation when needed.

Generated, partially or fully, using [Claude Code](https://claude.ai/code)
-   model: Claude {{current-model-name}} {{current-model-ver}} - {{current-model-id}}
```

- Replace template placeholders with actual model info (e.g., "Sonnet 4 - claude-sonnet-4-20250514")
- Use imperative mood ("Add feature" not "Added feature")
- Do NOT add a separate `[Created and submitted by AI: Claude]` line for git commits

## Constraints

- **No amending pushed commits** - verify with `git status` first
- **No `--no-verify`** unless explicitly requested
- **No interactive rebase** - this skill handles simple commits only
- Before amending, confirm HEAD is the user's commit

## Pre-commit Hook Failures

If hooks modify files: stage the changes, amend with `--no-edit`.
