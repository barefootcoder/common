---
description: "Git commit with proper message formatting.  Invoke ONLY when the user has explicitly asked you to commit — NOT proactively because work feels complete, because you are wrapping up a task, or because committing would be the natural next step.  When work feels done, summarize what you did and ASK whether to commit; wait for an explicit go-ahead.  The user values that pause: it is where they say 'oh, but also include X', 'fold this into the last commit instead', or 'one more thing first'.  Once the user HAS asked for a commit, this skill is mandatory: never run `git commit` without loading it first."
---

# Git Commit Skill

Create or amend git commits with proper message formatting.

**This skill is mandatory for all git commits.** Do not run `git commit` directly — always invoke this skill first so that commit message formatting, attribution, and constraints are applied correctly.

## Scope Determination

Invoked as: `/x-commit {{ARGS}}` — or auto-invoked when a commit is needed.

- **No args / auto-invoked**: Commit files modified during this conversation
- **With args**: Specific files, or instructions like "amend", or both

## Commit Message Format

Default form — most commits need nothing more than this:

```
brief description of changes

Generated, partially or fully, using [Claude Code](https://claude.ai/code)
-   model: Claude <MODEL_FAMILY> <MODEL_VER> - <MODEL_ID>
```

A body goes between the subject and the attribution block, but only when warranted (see "Body" below).

### First Line (Subject)

- Use imperative mood ("add feature" not "added feature")
- Do NOT capitalize the first letter — this is a short description, not a sentence
- Do NOT end with a period
- Prefer an *intent* or *purpose* framing over a flat enumeration of changes.  "tweak X to improve Y" reads better than "do A, do B, do C" even when A, B, and C are all accurate — the body, if any, can enumerate.

### Body

**Most commits do not need a body at all.**  Commit messages are written for humans, who have short attention spans and can read the diff if they want detail.  The subject line already identifies the change; the body's only job is to record context the diff cannot convey on its own.

- **The body is for the non-obvious *why*, not the *what*.**  Do not redescribe what changed — the diff does that.  Use the body only for a constraint that forced the approach, a bug being worked around, an alternative tried and abandoned, a non-obvious interaction with other code, or similar.  If the *why* is plain from the subject, omit the body entirely.
- **Keep it short.**  When a body is warranted, one or two sentences is almost always enough.  A multi-line body for a small diff is a sign you are recapping rather than explaining.  Resist the urge to summarize what you just did; trust the reader.
- **Do not hand-wrap.**  Write each paragraph and each bullet as a single, unwrapped physical line, with two spaces between sentences.  The skill reflows the whole message to 95 columns mechanically before committing (see "Producing the Commit" below), so manual line breaks only get in the way — and a sentence break that lands at a manual wrap would lose its double space.
- Use `-` bullet points only when genuinely listing distinct items — multiple conceptually-distinct tweaks count, even within one cohesive change set (an intent-framed subject with a few bullets enumerating the pieces is often the right shape for these).  Do not bullet-itemize ordinary work just to add structure — running prose is fine and usually shorter.
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
- **Keep the message ASCII**: see the global `CLAUDE.md` writing-style rule (no `…`, no space-padded dashes, straight quotes).  Beyond style, ASCII keeps the reflow's column math exact, since the wrapper counts bytes.

### AI Attribution (Last Lines)

- You MUST include the attribution block exactly as shown in the template above.
- The attribution must record the model that did the **actual work being committed** — not whatever model happens to be running `/x-commit`.  Those can differ: `/x-commit` itself is unpinned, but it inherits its model from any wrapping skill that pinned one, so a downcycled wrapper can silently downcycle the commit attribution too.  Do NOT guess, and do NOT trust the "You are powered by..." line in the system prompt — it is templated at session start and goes stale across `/model` switches.  Instead, read the work model directly from the session transcript:
  ```bash
  tac ~/.claude/projects/$(realpath . 2>/dev/null | sed 's|/|-|g')/$CLAUDE_CODE_SESSION_ID.jsonl 2>/dev/null \
    | jq -r 'select(.type=="assistant" and .attributionSkill != "x-commit") | .message.model' \
    | head -1
  ```
  The `attributionSkill != "x-commit"` filter excludes turns spent inside `/x-commit` itself, so the result is the model of the most recent turn that did substantive work (e.g. `claude-opus-4-8`).  From the ID, derive the family/version for the human-readable half — e.g. `claude-opus-4-8` → "Claude Opus 4.8", `claude-sonnet-4-6` → "Claude Sonnet 4.6", `claude-haiku-4-5-20251001` → "Claude Haiku 4.5".  Final line format: `-   model: Claude Opus 4.8 - claude-opus-4-8`.
- **A mismatch between the transcript result and the system-prompt "You are powered by…" line is EXPECTED — it is the whole reason for this probe, not a discrepancy to investigate.**  When the probe returns a model, treat it as authoritative and proceed silently: do not re-probe, count turns per model, or pause to reconcile the two.  The system prompt matters only as the empty-probe fallback below.
- If the transcript probe returns nothing, fall back to the system-prompt line, but flag the uncertainty to the user before committing.  Most common cause: `/x-commit` is the first skill invoked in a brand-new session and there is no prior non-commit turn yet.
- Do NOT add any additional AI attribution beyond the template (no extra "Co-Authored-By", "[Created by AI]", or similar lines).

## Producing the Commit

The body is written unwrapped (one line per paragraph/bullet — see "Body"), so the message
must be reflowed to 95 columns before it is committed.  Write the full drafted message
(subject, body, attribution block) to a file, reflow it, then commit with `-F`:

```bash
~/.claude/skills/x-commit/scripts/reflow-commit-msg < /tmp/commit-msg.draft > /tmp/commit-msg.txt
git commit -F /tmp/commit-msg.txt
```

`reflow-commit-msg` (pure core Perl, no deps) wraps each over-long line independently: the
subject line and the attribution block pass through untouched, fenced ``` ``` ``` code blocks
are preserved verbatim, bullets wrap with a hanging indent, and interior whitespace —
including two-spaces-between-sentences — is preserved wherever a wrap doesn't fall there.  It
is idempotent, so re-running it (e.g. on an already-reflowed message during an amend) is safe.

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
- **Inspect staged state with `git status --porcelain`** or `git diff --cached --name-only` — not `git status -s | grep`.  The user's `color.ui = always` makes anchored greps on colored git output silently fail (see global `CLAUDE.md`).

## Pre-commit Hook Failures

If hooks modify files: stage the changes, amend with `--no-edit`.
