---
description: Create or amend git commits using the git-commit skill
---

You need to help the user create or amend a git commit using the git-commit skill instructions.

## Step 1: Locate the skill file

First, run `aidoc-locate skill git-commit` to find the appropriate skill file to use:

```bash
aidoc-locate skill git-commit
```

**Important:** If this command returns an error, STOP immediately and inform the user that they need to address the issue with `aidoc-locate` before proceeding. Do not attempt to guess the file location.

## Step 2: Read the skill instructions

Once you have the file path from `aidoc-locate`, read that file to load the git-commit skill instructions.

## Step 3: Determine the commit scope

The user invoked this command as: `/x-commit {{ARGS}}`

**If no arguments were provided (ARGS is empty):**
- The user wants to commit all files that have been modified in the current conversation context
- Review the conversation history to identify which files have been created, edited, or modified
- Use the git-commit skill instructions to stage and commit those files

**If arguments were provided:**
- The arguments represent either:
  - Specific file paths the user wants to commit, OR
  - Special instructions (e.g., "amend the last commit", "add these changes to the previous commit"), OR
  - A combination of both files and instructions
- Parse the arguments to understand what the user wants
- Use the git-commit skill instructions to fulfill the request

## Step 4: Follow the skill instructions

Apply the git-commit skill guidance you loaded in Step 2 to:
- Review current repository state with `git status` and `git diff`
- Stage the appropriate files
- Create or amend the commit with a proper message
- Verify the operation succeeded

Remember to follow all safety guidelines and commit message formatting conventions from the skill file.

[Created and submitted by AI: Claude]
