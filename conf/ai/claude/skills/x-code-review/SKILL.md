---
name: x-code-review
description: Expert code review of the most recent commit
argument-hint: [commit-ref or additional context]
model: opus
disable-model-invocation: true
allowed-tools: Bash(git *), Read, Glob, Grep, Write
---

# Code Review

Perform an expert code review of a git commit.

**Target commit**: `$ARGUMENTS` if it looks like a commit ref (SHA, branch, `HEAD~2`, etc.),
otherwise default to `HEAD`. Any non-ref arguments are additional context about
the problem being solved (ticket references, design notes, etc.).

## Gathering Context

1. **Commit info**: `git show --stat <commit>` and `git log -1 --format=full <commit>`
2. **Full diff**: `git diff <commit>~1..<commit>`
3. **Read touched files**: Read each file modified by the commit in full (skip
   deleted files, skip binary files). This provides surrounding context the diff
   alone can't show.
4. **Related tests**: Search for test files that correspond to changed files.
   Read them even if they weren't part of the commit — missing test updates are
   a finding.
5. **Additional context**: If `$ARGUMENTS` contains a ticket reference, use
   available tools to gather ticket details. If it contains descriptive text,
   use it to understand intent.

## Review Criteria

Evaluate the commit against each of these. If a category has no findings, say so
briefly and move on — don't pad.

### 1. Problem-Solution Fit
Does the code actually solve what the commit message (and any provided context)
says it solves? Look for gaps, partial implementations, or scope creep.

### 2. Correctness / Bugs
Look for:
- Logic errors, off-by-ones, wrong operators
- Unhandled edge cases (empty input, undef/null, boundary values)
- Race conditions, resource leaks
- Incorrect API usage or misunderstood library behavior

### 3. Documentation Quality
- Are comments present where the "why" isn't obvious from the code?
- Are there redundant comments that just restate what the code does? Flag these
  as noise.
- For public APIs: is there sufficient documentation (POD, docstrings, etc.)?
- Is the commit message itself clear and accurate?

### 4. Test Coverage
- Are there tests for the new/changed behavior?
- Do existing tests still cover the modified code paths?
- Are edge cases tested?
- If there are no tests and the change is non-trivial, flag it.

### 5. Unintended Consequences
- Could this change break callers, consumers, or downstream code?
- Are there implicit behavioral changes (changed return values, side effects,
  altered error handling)?
- Config or environment assumptions that might not hold everywhere?

### 6. Security
- Injection risks (SQL, command, XSS, path traversal)
- Credential or secret handling
- Permission/authorization changes
- Unsafe deserialization, eval, or dynamic execution

## Output Format

Print the review directly to the conversation. Only write to a file if the user
explicitly requests it.

```
## Code Review: `<first line of commit message>`

**Commit**: `<short SHA>` by `<author>` on `<date>`
**Files changed**: <count> (<insertions>+, <deletions>-)

### Findings

#### Problem-Solution Fit
<findings or "No issues.">

#### Correctness
<findings or "No issues.">

#### Documentation
<findings or "No issues.">

#### Test Coverage
<findings or "No issues.">

#### Unintended Consequences
<findings or "No issues.">

#### Security
<findings or "No issues.">

### Verdict

<One of:>
- **Ship it** — No significant issues found.
- **Nitpicks only** — Minor suggestions, nothing blocking.
- **Needs changes** — Issues that should be addressed before merging.
- **Rethink approach** — Fundamental concerns with the approach taken.

<Brief justification — 1-3 sentences.>
```

## Constraints

- **Read-only by default**: Do not modify any files unless the user asks you to
  fix something after the review.
- **Be honest, not diplomatic**: If the code has problems, say so clearly. The
  user values directness.
- **Calibrate severity**: Not every suggestion is a blocker. Distinguish between
  "must fix", "should fix", and "consider".
- **Respect the commit scope**: Review what's in the commit. Don't critique
  pre-existing code unless the commit makes it worse.
- **No false positives**: If you're unsure whether something is a bug, say so
  rather than asserting it is one.
