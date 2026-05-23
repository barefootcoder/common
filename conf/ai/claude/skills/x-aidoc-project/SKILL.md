---
name: x-aidoc-project
description: Load aidoc project context from aidoc/projects/ directory
argument-hint: <project-name>
model: sonnet
disable-model-invocation: true
allowed-tools: Bash(*), Read, Glob, Edit, Write
---

# Load Aidoc Project Context

Load aidoc project instructions for a named project area. ("Aidoc project" is the formal name for a directory under `aidoc/projects/`; informally just "project".)

**Input**: $ARGUMENTS (project name)

## Bundled Script

`scripts/aidoc-locate` - Locates aidoc files/projects in `./aidoc` and `~/common/aidoc`

## Load Workflow

### 1. Locate the project

Run `~/.claude/skills/x-aidoc-project/scripts/aidoc-locate project $ARGUMENTS`.

- If no argument provided, ask user for project name
- If not found, run without the name arg to list available projects

### 2. Load context

Read the `README.md` in the returned directory. Also read any files the README references (dependencies, related docs).

### 3. Check the project's TODO list

If `TODO.md` exists in the project directory, read it. Get today's date with `date +%F`.

For each item under "Outstanding":
- Dated `YYYY-MM-DD` ≤ today → **due**
- Dated `YYYY-MM-DD` > today → **upcoming**
- Marked `anytime` (or undated) → **pending, no deadline**

Surface **due** and **pending** items to the user when confirming the load, and ask whether they'd like to address any before or after the task they came here for. Mention **upcoming** items only briefly (no need to badger).

If no `TODO.md` exists, skip silently.

### 4. Confirm ready

Brief confirmation that project context is loaded. Then wait for the user's specific task.

## Standing rules for the rest of the session

You are now operating as the maintainer of this aidoc project, not a transient agent. The next agent to load this project starts from these docs and from `TODO.md` — keep both current.

### Keep project docs updated as you work

When something material changes — new tooling added, a hypothesis confirmed or ruled out, a recurring issue resolved, a status item moved forward — update the relevant doc. Don't wait for the user to ask.

The right *amount* of update varies: sometimes a one-line tweak to a status bullet, sometimes a new `summary:<topic>.md` covering an entire investigation, occasionally nothing at all if the session was purely exploratory. Use judgement. The bar: would the next agent be confused, redo work, or miss context if they only had what's currently in the docs?

Prefer editing existing docs over creating new ones. Only create a new `summary:*.md` if the work is substantial enough to warrant its own file (multi-step investigation, complex incident, decision with extensive rationale).

### Capture deferred work in TODO.md

Any time follow-up work is identified that won't happen in this session, add it to `TODO.md` in the project directory. This applies equally to:

- **User-deferred work**: "do that next week" / "check results in a couple days" / "run this monitor and analyze tomorrow"
- **Agent-deferred work** (you, recommending something for later): "after the merge freeze lifts we should circle back to X" / "in a week the data will be enough to analyze" / "revisit this once the hardware intervention is done"

Either way: write it down in `TODO.md`, don't leave it in conversation memory. The user explicitly does not want to be responsible for remembering these — and neither should you assume they will. If you advise something for later, *you* are responsible for capturing it; the rule isn't "the user told me to defer this", it's "this work needs doing later".

Create `TODO.md` on first use (see format below). Tell the user briefly when you've added something, with the scheduled absolute date.

**Date handling:** get today with `date +%F`. For relative offsets ("in 3 days", "next Friday"), compute the absolute date with `date -d "+3 days" +%F` or `date -d "next Friday" +%F`. Always store as `YYYY-MM-DD`, never as a relative phrase like "next week".

**When completing a TODO item later**, move it from Outstanding to Done with the completion date — don't delete it. Future agents benefit from the history.

### TODO.md format

If you need to create `TODO.md` from scratch, use this structure:

```markdown
# {Project Name} — Outstanding Tasks

Follow-up work deferred from previous sessions. The `x-aidoc-project`
skill scans this file on load and surfaces due/pending items.

## Outstanding

- **YYYY-MM-DD** — Description _(added YYYY-MM-DD by <session context>)_
- **anytime** — Description with no deadline _(added YYYY-MM-DD)_

## Done

- ~~YYYY-MM-DD~~ — Description _(added YYYY-MM-DD, completed YYYY-MM-DD)_
```

"Session context" in the `_(added …)_` parenthetical is a short phrase identifying the session that added it, e.g. `_(added 2026-05-22 during RAPL cap mitigation work)_`. Helps future agents find the relevant `summary:*.md` if more detail is needed.
