---
name: x-security-audit
description: Audit the specified commits being pushed to a public repo for leaked secrets and sensitive data
argument-hint: <commits to push: a count or a range>
model: opus
disable-model-invocation: true
allowed-tools: Bash(git *), Read, Glob, Grep
---

# Pre-Push Security Audit

Review the commits the user is about to push for sensitive data: secrets,
credentials, keys, and tokens that must not leave the machine, plus internal
details (hostnames, employer URLs, infra names) that are not secrets but matter
on a public repo.

**The target remote is always a public repo.** The user only runs this skill
before pushing to a public GitHub repo, never a private one. Treat internal
hostnames, employer/SSO URLs, infra codenames, and usernames as worth flagging
accordingly: they are not secrets, but they are going somewhere the world can
read.

**Input**: `$ARGUMENTS` names the commits being pushed. It is either a count
("22", "the next 5") or an explicit range (`origin/master..HEAD`, `abc^..def`).
Resolve it to a concrete range in Step 1.

**The push itself is handled by `vp1`** (an alias for `vc push-some`). `vp1`
takes care of the mechanics you would otherwise have to guard against: it
pushes ONLY the specified commits (not everything ahead of the remote) and it
fetches first. So you do not need to worry that a plain `git push` would send
extra commits, and you do not need to remind the user to fetch. Your job is
purely to audit exactly the specified set.

## Parsing git output

`git` here is configured with `color.ui = always`, so it emits ANSI escapes
even when piped. Always parse with color-immune forms: `--no-color`,
`--porcelain`, `--name-only`, `--format=...`. Never pipe `git status -s` or a
colored `git diff` into an anchored `grep`/`awk`: the status column and `+`
markers are wrapped in escape codes and anchors silently match nothing.

## Step 1: Resolve the specified commits into a range

Turn `$ARGUMENTS` into a concrete `BASE..TIP`, matching exactly what `vp1` will
push.

- **A count `N`**: `vp1 N` pushes the oldest N unpushed commits (the next N in
  line above the remote), so:
  ```
  git rev-parse --abbrev-ref @{u}                 # upstream, e.g. origin/master
  ahead=$(git rev-list --count --no-color @{u}..HEAD)
  # BASE = @{u} ; TIP = HEAD~(ahead - N)
  ```
  Audit `@{u}..HEAD~(ahead-N)`. (Example: 95 ahead, N=22 -> TIP = `HEAD~73`,
  so the range is `@{u}..HEAD~73`.)
- **An explicit range**: use it as given.

Confirm `TIP` is the commit that becomes the new remote head, then operate on
`BASE..TIP` for everything below.

## Step 2: Inventory the range

```
git log --oneline --no-color BASE..TIP
git diff --stat --no-color BASE..TIP
```

Confirm the commit list matches what the user expects to push, and note the
high-risk files (config files, `settings.json`, `*.conf`, READMEs, anything
under a `private/`-style path, scripts that read credentials).

## Step 3: Scan the diff for secret patterns

Scan added lines (the `+` side) across the whole range:

```
git diff --no-color BASE..TIP | grep -nEi \
  '(password|passwd|secret|api[-_ ]?key|api[-_ ]?token|access[-_ ]?key|private[-_ ]?key|auth[-_ ]?token|bearer|credential|client[-_ ]?secret|aws_|AKIA|ghp_|github_pat|xox[baprs]-|-----BEGIN|vault|passphrase)'
```

And a second pass for identifiers and embedded blobs:

```
git diff --no-color BASE..TIP | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nEi \
  '([0-9]{1,3}\.){3}[0-9]{1,3}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|https?://|[A-Za-z0-9+/]{40,}={0,2}|root@|[a-z0-9._-]+@[a-z0-9.-]+:'
```

Triage every hit. A match is a lead, not a verdict: `aws secretsmanager
describe-secret` in a permission allowlist is fine; `AKIA...` followed by 16
chars is not. Read the surrounding lines before deciding.

## Step 4: Verify credential references point at gitignored files

A commit that *moves* or *references* a credentials file is safe only if the
file itself is not in the push. For every credential path you see referenced:

```
git diff --name-only --no-color BASE..TIP | grep -i private    # should be empty
git ls-files | grep -iE 'private/|credential|secret'           # should not list it
git check-ignore -v <the/credentials/path>                     # should report a .gitignore rule
```

Confirm the real secret values live in an ignored file and only a *path
reference* is in the diff. If an actual credentials file is tracked or staged,
that is a hard block.

## Step 5: Read the high-risk files in full

For each high-risk file (and anything flagged in Steps 3-4), read the committed
version, not just the diff hunk: `git show TIP:path/to/file`. The diff hides
surrounding context where a secret might sit. Pay special attention to
`settings.json` (env vars, tokens), `*.conf`, and any README that documents
infrastructure.

## Step 6: Classify findings

Sort everything into two buckets and keep them clearly separate:

- **Hard blocks** (do not push): live secrets, API tokens, private keys,
  passphrases, database credentials, a tracked credentials file.
- **FYI / your judgment** (does not block): internal hostnames, employer URLs,
  infra/project codenames, personal machine names, vendor Atlassian domains.
  Because the repo is public these are always worth listing so the user can
  decide, but they do not block the push.

## Step 7: History caveat

Deleting a file in one of these commits does **not** remove it from history. If
a "removed" file already existed at the remote tip, its content is already
public and a delete commit cannot scrub it: that needs a history rewrite, not a
new commit. Call this out when a commit removes a sensitive file.

## Output format

```
## Pre-Push Security Audit

**Range audited**: `BASE..TIP`  (<N> commits)
**Remote**: `<owner/repo>` (public)

### Hard blocks
<each secret, with file:line, or "None.">

### FYI (your judgment, not blockers)
<internal naming / URLs / infra, or "None.">

### Notes
<how the count resolved, delete-vs-history caveats, etc., or "None.">

### Verdict
<One of:>
- **Clear to push** -- no secrets in the audited range.
- **Clear, with FYIs** -- no secrets; note the items above before pushing.
- **DO NOT PUSH** -- secrets present; list what must be removed first.
```

## Constraints

- **Read-only. Never push.** This skill audits and reports; the user runs `vp1`.
  Do not run `git push` (or any command that mutates the remote or history)
  even if the verdict is clean.
- **Audit exactly the specified commits.** Resolve `$ARGUMENTS` to the range
  `vp1` will push and audit that, no more and no less.
- **Leads are not verdicts.** A pattern hit needs a look at context before you
  call it a secret. No false alarms: an allowlisted command name or an example
  value is not a leak.
- **Keep blocks and FYIs apart.** Do not inflate internal naming into a block,
  and do not bury a real secret among FYIs.
- **Be direct.** If there is a leak, say so plainly and name the file and line.
