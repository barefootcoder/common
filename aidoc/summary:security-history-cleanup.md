# Security-Oriented Git History Cleanup Plan

This document describes the steps an agent should follow to:

1. Remove sensitive-but-not-critical data from this repository's git history.
2. Rewrite and push the cleaned history to GitHub.
3. Avoid reintroducing the old history from other local clones.
4. Find commit messages that reference other commits (by SHA) so they can be reviewed.

The repo is **personal**, and it is acceptable to rewrite public history and force-push.

---

## 0. Inputs Needed From the User

Before starting, obtain the following from the user:

1. **Repository location**
   - Local path to the *primary* working clone where the rewrite will be performed.
   - Git remote URL (e.g., `git@github.com:USER/REPO.git`).

2. **Sensitive patterns**
   - Exact strings or regex patterns that should be removed/obfuscated, such as:
     - Internal IPs (e.g. `192.168.0.10`, `10.1.2.3`).
     - NAS username(s).
     - Syncthing device IDs.
     - Any other hostnames/usernames/devices/IDs they care about.

3. **List of other clones**
   - Machines/paths where this repo has been cloned or mirrored.
   - Any backup locations that may contain `.git` directories for this repo.

Ask the user to confirm they understand:
- We *cannot* guarantee removal from third-party caches/indexes or from anyone else who already cloned the repo.
- We *can* minimize ongoing exposure and clean all of their own clones/backups.

---

## 1. Preflight Checks

1. Change into the primary repo:

   ```bash
   cd /path/to/repo
   ```

2. Confirm current remotes and branches:

   ```bash
   git remote -v
   git branch -a
   ```

3. Ensure the working tree is clean:

   ```bash
   git status
   ```

   If there are uncommitted changes, either:
   - Commit them, **or**
   - Stash them if appropriate, **or**
   - Abort and ask the user what to do.

4. Make a safety backup of the current repo (optional but recommended):

   ```bash
   cd ..
   cp -a repo repo-backup-before-cleanup
   ```

---

## 2. Identify Commit Messages That Reference Other Commits

We want to find commit messages that contain SHA-like tokens, but avoid pure date-like values like `20250604`.

In the primary repo:

```bash
cd /path/to/repo
```

Run this search using PCRE:

```bash
git log --all -Pi --grep='\b(?!20[0-9]{6}\b)[0-9a-f]{7,40}\b' --oneline
```

Explanation of the regex:

- `\b` – word boundary.
- `(?!20[0-9]{6}\b)` – negative look-ahead: reject tokens that are exactly `20` + 6 digits (e.g. `20250604`).
- `[0-9a-f]{7,40}` – hex-looking token (typical for abbreviated/full SHAs).
- `\b` – end word boundary.
- `-P` – use Perl-compatible regex.
- `-i` – case-insensitive, so uppercase hex also matches.

If a more compact output is needed, remove `--oneline` and/or change the pretty format, but **do not** change the grep pattern without reason.

**Agent task:**

- Capture the output of this command.
- Present to the user the list of commits whose messages reference other SHAs.
- Ask whether any of these messages need to be updated after the history rewrite (e.g. references to specific commits that may no longer exist or will change).

---

## 3. Identify Sensitive Data in History

### 3.1. Search the current working tree

For each sensitive pattern provided by the user (e.g., `192.168.0.10`):

```bash
git grep -n '192.168.0.10'
```

Repeat for all known patterns.

### 3.2. Search through history for occurrences

Use `git log -S` or `git log -G` for each pattern. Example:

- String match:

  ```bash
  git log -S '192.168.0.10' --oneline --all
  ```

- Regex match:

  ```bash
  git log -G '192\.168\.0\.[0-9]+' --oneline --all
  ```

**Agent task:**

- Produce a list of files/commits containing sensitive data.
- Group them by type (IP addresses, usernames, device IDs, etc.).
- Confirm with the user how each type should be handled, e.g.:
  - **Replace** with generic placeholders.
  - **Remove** the file entirely from history.
  - **Move** data to a non-version-controlled location and adjust scripts to load from there.

---

## 4. Prepare for History Rewrite (`git filter-repo`)

This plan assumes the availability of `git filter-repo` (preferred) instead of older `git filter-branch`.

1. Verify `git filter-repo` is installed:

   ```bash
   git filter-repo --help >/dev/null 2>&1 || echo "git filter-repo not found"
   ```

2. If not present, instruct the user how to install it for their platform, or reference https://github.com/newren/git-filter-repo.

3. In the repo root, prepare a `replace-text.txt` file for `git filter-repo` if we will be doing string replacements.

   Example format:

   ```text
   # Lines starting with '#' are comments.
   # Format:   literal-or-regex   replacement

   # Replace specific internal IPs
   192.168.0.10             192.168.0.10_REDACTED
   10.1.2.3                 10.1.2.3_REDACTED

   # Replace NAS username
   nasuser                  NAS_USER_REDACTED

   # Replace Syncthing device ID
   ABCD1234EFGH5678IJKL    SYNCTHING_DEVICE_REDACTED
   ```

   Adjust this file based on the user’s actual data and desired replacements.

---

## 5. Perform the History Rewrite

From the repo root:

1. Ensure working tree is clean one more time:

   ```bash
   git status
   ```

2. Run `git filter-repo` with text replacement (and optionally path filters if entire files should be removed):

   ```bash
   git filter-repo --force --replace-text replace-text.txt
   ```

   - Add additional options as needed (e.g., `--path` / `--invert-paths` if removing whole files from history).
   - Use `--force` only if necessary (for example if this repo has already been filtered before).

3. After the rewrite, run verification searches **again**:

   - Check working tree:

     ```bash
     git grep -n '192.168.0.10' || echo "192.168.0.10 not found"
     ```

   - Check history:

     ```bash
     git log -S '192.168.0.10' --oneline --all || echo "no commits with 192.168.0.10"
     ```

   Repeat for all sensitive patterns.

4. Re-run the SHA-reference search from Section 2 to see if any commit messages with SHA references remain and decide if they are acceptable.

---

## 6. Force Push Cleaned History to GitHub

Once the user is satisfied with the local, cleaned history:

1. Confirm the remote:

   ```bash
   git remote -v
   ```

2. Push with a force push. Prefer `--force-with-lease`:

   ```bash
   git push --force-with-lease origin main
   ```

   Replace `main` with the appropriate default branch name. For additional branches:

   ```bash
   git push --force-with-lease origin <branchname>
   ```

3. If the repo has any protected branches on GitHub that disallow force pushes, the user must temporarily relax those settings or explicitly allow force pushes before this step.

---

## 7. Clean Up Other Local Clones and Backups

To avoid reintroducing the old (dirty) history, **every other clone** of this repo must be handled.

### 7.1. Preferred: delete and re-clone

On each machine:

```bash
cd /path/to/parent
rm -rf repo
git clone git@github.com:USER/REPO.git repo
```

### 7.2. Alternative: reset existing clones

If the user wants to keep local branches/config, in each clone:

```bash
cd /path/to/repo
git fetch origin
git reset --hard origin/main      # adjust branch name as needed
```

Then aggressively prune unreachable objects and reflog entries:

```bash
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

Repeat this cleanup in **every** clone and any bare mirrors used as backups.

---

## 8. Check Non-Git-History Surfaces

The following are **not** automatically fixed by rewriting git history:

1. **GitHub issues and comments**
   - Search for sensitive strings (internal IPs, usernames, device IDs).
   - Edit or delete any offending comments.

2. **README / docs / wiki pages**
   - Inspect for references to internal IPs or device IDs.
   - Redact or generalize as needed.

3. **CI logs and artifacts (e.g. GitHub Actions)**
   - Browse recent workflow runs and logs for sensitive strings.
   - Delete artifacts or logs if necessary, where the platform allows.

4. **Any generated documentation sites**
   - If there is a GitHub Pages site or other published documentation, rebuild it from the cleaned repo and redeploy.

---

## 9. Final Verification Checklist

The cleanup is considered complete when:

- [ ] All known sensitive patterns are absent from:
  - [ ] The current working tree.
  - [ ] The entire commit history (verified with `git log -S` or `-G`).
- [ ] The SHA-reference search command:

  ```bash
  git log --all -Pi --grep='\b(?!20[0-9]{6}\b)[0-9a-f]{7,40}\b' --oneline
  ```

  has been reviewed and any remaining commit-message references to SHAs are either:
  - Intentionally left as-is, or
  - Updated to match the new commit SHAs, if the user requests that.

- [ ] Cleaned history has been force-pushed to GitHub.
- [ ] All other local clones have been either:
  - [ ] Deleted and re-cloned, or
  - [ ] Hard-reset to the new history and garbage-collected.
- [ ] External surfaces (issues, docs, CI logs, pages) have been checked and cleaned.

When all boxes are checked, inform the user that:

- The repo and their own clones no longer contain the identified sensitive data in git history.
- Existing external copies (clones, caches, third-party services) may still hold previous versions, but ongoing exposure from this repo is minimized.
