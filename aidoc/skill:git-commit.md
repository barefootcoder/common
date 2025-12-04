# Git Commit Skill

You are helping the user create or amend git commits. This skill focuses on the core commit workflow: staging changes and writing good commit messages.

## Core Responsibilities

**Creating New Commits:**
- Review current changes with `git status` and `git diff`
- Stage appropriate files with `git add` (you can use `git add -p` for partial staging if needed)
- Review recent commit history with `git log` to understand commit message style
- Create well-structured commit messages following project conventions
- Verify the commit was created successfully

**Amending Existing Commits:**
- Use `git commit --amend` to fix the most recent commit message or add more changes
- Before amending, always verify the HEAD commit is the user's (check author/date)
- Before amending, check that the commit hasn't been pushed to a shared branch
- When pre-commit hooks modify files, amend the commit to include those changes

**Safety Guidelines:**
- NEVER use `git commit --amend` on commits that have been pushed to shared branches (check with `git status`)
- NEVER skip hooks with `--no-verify` unless explicitly requested by the user
- NEVER use `git rebase -i` or other interactive history rewriting operations
- If the user asks for complex history manipulation (squashing multiple commits, reordering, etc.), politely explain that this skill focuses on simple commit operations and they should handle that manually

## Project-Specific Commit Message Format

Follow the commit message convention from CLAUDE.md:
```
Brief description of changes

Optional detailed explanation when needed.

Generated, partially or fully, using [Claude Code](https://claude.ai/code)
-   model: Claude {{current-model-name}} {{current-model-ver}} - {{current-model-id}}
```

**Important Notes:**
- Replace the template placeholders with actual current model information (e.g., "Sonnet 4.5 - claude-sonnet-4-5-20250929")
- The commit message should END with the model information line
- Do NOT add a separate `[Created and submitted by AI: Claude]` line for git commits
- Use imperative mood in the brief description ("Add feature" not "Added feature")

## Typical Workflow

When creating a new commit:
1. Run `git status` to see what's changed
2. Run `git diff` (or `git diff --staged`) to review the actual changes
3. Run `git log -5 --oneline` to see recent commit message style
4. Stage the appropriate files with `git add`
5. Create a commit with a clear, descriptive message
6. Run `git status` to verify success

When amending a commit:
1. Run `git log -1 --format='[%h] (%an <%ae>) %s'` to verify this is your commit
2. Check `git status` to ensure you're not on a shared branch that's already pushed
3. If adding more changes, stage them with `git add`
4. Run `git commit --amend` with updated message if needed
5. Verify the amended commit with `git log -1`

## Handling Pre-Commit Hooks

If a commit fails because a pre-commit hook modified files:
1. Check that the HEAD commit is yours and hasn't been pushed
2. Stage the hook's changes with `git add`
3. Amend the commit with `git commit --amend --no-edit`

## What This Skill Does NOT Handle

This skill intentionally does NOT cover:
- Interactive rebasing (`git rebase -i`)
- Squashing multiple commits
- Cherry-picking commits
- Creating/applying patches
- Reordering commit history
- Splitting commits
- Complex history manipulation

For these operations, the user should handle them manually or use other specialized tools.

[Created and submitted by AI: Claude]
