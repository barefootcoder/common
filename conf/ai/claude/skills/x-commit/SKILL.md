---
description: "Git commit with proper message formatting. MUST be invoked any time you are about to run `git commit` — whether the user explicitly requests a commit, you are wrapping up a task, or committing is part of a larger workflow. Never run `git commit` without loading this skill first."
---

# Git Commit Skill

Create or amend git commits with proper message formatting.

**This skill is mandatory for all git commits.** Do not run `git commit` directly — always invoke this skill first so that commit message formatting, attribution, and constraints are applied correctly.

## Scope Determination

Invoked as: `/x-commit {{ARGS}}` — or auto-invoked when a commit is needed.

- **No args / auto-invoked**: Commit files modified during this conversation
- **With args**: Specific files, or instructions like "amend", or both

## Commit Message Format

```
brief description of changes

Optional detailed explanation when needed.  Complete sentences are fine
in the body.

- Bullet points for individual changes, only when truly needed.

Generated, partially or fully, using [Claude Code](https://claude.ai/code)
-   model: Claude <MODEL_FAMILY> <MODEL_VER> - <MODEL_ID>
```

### First Line (Subject)

- Use imperative mood ("add feature" not "added feature")
- Do NOT capitalize the first letter — this is a short description, not a sentence
- Do NOT end with a period

### Body

- Word-wrap body text at 95 characters.  Do not leave lines unwrapped — GitHub does not always handle long lines gracefully in commit messages.  For reference, this ruler is exactly 95 characters:
  `xxxxx----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9`
- Complete sentences are preferred for describing the overall picture of what was done.  Use two spaces between sentences when the next sentence starts on the same line.
- Do not exhaustively enumerate every change — summarize instead.  If you must list individual changes, use `-` bullet points.
- Use backticks liberally for inline code formatting (GitHub renders these in commit messages).  Backtick the following:
  - Commands: `git`, `npm`, `sed` (even common ones like `bash` when referring to typing/running something)
  - Code snippets and keywords: `@ARGV`, `if`, `while`, `use strict`
  - Full command lines: `date +%Y-%m-%d`, `npx ccusage`
  - Command switches: `-A`, `-x`, `--grep`
  - Pathnames (including partial paths): `/var/tmp/launch-project/`, `**/private/`, `-hold` suffix.  End directory paths with a trailing `/` to distinguish them from files.
  - Environment variables (always include `$`): `$PATH`, `$PERL5LIB`
  - Keystrokes: `Ctrl-G`, `^G`, `Meta-V`, `Esc`
  - Anything typed literally into a program or config: `:set paste`, `select count(*) from tblfoo`, `additionalDirectories`
- Do NOT backtick generic English words that happen to also be technical concepts (e.g. stdin, cron job, pull request are fine without backticks)

### AI Attribution (Last Lines)

- You MUST include the attribution block exactly as shown in the template above.
- Before composing the message, look up the exact model you are running as.  Do NOT guess, and do NOT trust the "You are powered by..." line in the system prompt — it is templated at session start and goes stale across `/model` switches.  Instead, read the current model directly from the session transcript:
  ```bash
  tac ~/.claude/projects/$(pwd | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl \
    | jq -r 'select(.type=="assistant") | .message.model' | head -1
  ```
  This emits the model ID of your most recent assistant turn (e.g. `claude-opus-4-7`).  From the ID, derive the family/version for the human-readable half — e.g. `claude-opus-4-7` → "Claude Opus 4.7", `claude-sonnet-4-6` → "Claude Sonnet 4.6", `claude-haiku-4-5-20251001` → "Claude Haiku 4.5".  Final line format: `-   model: Claude Opus 4.7 - claude-opus-4-7`.
- If the transcript probe returns nothing (e.g. very first turn of a new session, transcript file not yet flushed), fall back to the system-prompt line, but flag the uncertainty to the user before committing.
- Do NOT add any additional AI attribution beyond the template (no extra "Co-Authored-By", "[Created by AI]", or similar lines).

## Amending Commits

When asked to amend a commit (e.g., to fold in additional changes):

1. **Read the existing commit message first** (`git log -1 --format=%B`).
2. **Assess the nature of the new code being added:**
   - *Bug fix / typo correction for the original commit's code* — no message
     change needed; use `--no-edit`.
   - *Additional feature work or separate fixes* — the message must be
     updated to cover the new material.
3. **When updating the message, _integrate_ — do not replace.**
   - Start from the full existing message text.
   - Add new information describing the additional changes, typically just
     above the AI attribution block.
   - If the new code materially changes something already described in the
     message (e.g., a different approach was taken, a file mentioned was
     replaced), revise that part of the message so it reflects the final
     state.  Do NOT leave stale descriptions of earlier iterations.
   - Do NOT discard context from the original message that is still accurate.
4. **Write for the final snapshot, not the edit history.**  Future readers
   will see one commit.  The message should describe that commit coherently,
   as if everything was done at once.  Never phrase things as "also added" or
   "additionally fixed" — just state what the commit does.

## Constraints

- **No amending pushed commits** - verify with `git status` first
- **No `--no-verify`** unless explicitly requested
- **No interactive rebase** - this skill handles simple commits only
- Before amending, confirm HEAD is the user's commit

## Pre-commit Hook Failures

If hooks modify files: stage the changes, amend with `--no-edit`.
