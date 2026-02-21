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

- Word-wrap body text at ~100 characters.  Do not leave lines unwrapped — GitHub does not always handle long lines gracefully in commit messages.
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
- Before composing the message, look up the exact model you are running as.  Do NOT guess — confirm the model family name, version, and full model ID.  For example: "Claude Opus 4.6 - claude-opus-4-6" or "Claude Sonnet 4.5 - claude-sonnet-4-5-20250929".
- Do NOT add any additional AI attribution beyond the template (no extra "Co-Authored-By", "[Created by AI]", or similar lines).

## Constraints

- **No amending pushed commits** - verify with `git status` first
- **No `--no-verify`** unless explicitly requested
- **No interactive rebase** - this skill handles simple commits only
- Before amending, confirm HEAD is the user's commit

## Pre-commit Hook Failures

If hooks modify files: stage the changes, amend with `--no-edit`.
