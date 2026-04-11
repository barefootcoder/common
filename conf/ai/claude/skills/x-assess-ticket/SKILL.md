---
name: x-assess-ticket
description: Assess the current state of a Jira ticket and produce a summary for development work
argument-hint: [ticket-number]
model: opus
disable-model-invocation: true
allowed-tools: Bash(jira-*), Bash(ticket-*), Bash(git log*), Bash(ls*), Bash(mkdir*), Bash(date*), Read, Glob, Grep, Write, mcp__google-sheets__*
---

# Ticket Assessment Workflow

You are assessing the current state of a Jira ticket to determine what's been done and what needs to happen next. Your output enables development work by a secondary agent without Jira access.

**Ticket argument**: $ARGUMENTS (if just a number, prepend "CLASS-")

**Scripts available** in this skill's `scripts/` directory:
- `jira-ticket-info <TICKET>` - Quick summary (status, assignee, etc.)
- `jira-ticket-detail <TICKET>` - Full details (description, comments, links, attachments)
- `jira-download-attachments <TICKET> [DIR]` - Downloads all attachments to directory

## Workflow

### 1. Pre-flight
Test jira CLI access:
```bash
jira-ticket-info $TICKET
```
If this fails with authentication errors, inform user to check their Jira credentials and stop.

### 2. Gather Ticket Information
Run `jira-ticket-detail $TICKET` to get the full picture: description, comments, linked issues, and attachments.

**Pay special attention to comments** - they often contain:
- Requirement updates that supersede the original description
- Bug reports explaining why previous work was reverted
- QA feedback with acceptance criteria changes
- Developer notes with root cause analysis

### 3. Check Existing Work
```bash
ls -la aidoc/ticket-docs/$TICKET/ 2>/dev/null || echo "No existing directory"
```

If directory exists, read any existing summary files to understand prior session work.

If not, create it:
```bash
mkdir -p aidoc/ticket-docs/$TICKET
```

### 4. Search Git History
```bash
git log --oneline --grep="$TICKET"
```

Note any commits, especially:
- Previous implementation attempts
- Reverts (original + revert commits both matter)

### 5. Handle Attachments
If attachments exist and appear relevant (especially images, mockups, CSVs):
```bash
jira-download-attachments $TICKET aidoc/ticket-docs/$TICKET/
```

Images and mockups are high priority - they often contain essential context for UI work or bug reproduction.

### 6. Identify Relevant Files
Based on ticket content, comments, and git history, identify repository files that are relevant. Sources:
- File paths mentioned in ticket/comments
- Files touched by previous commits
- Files inferred from functionality description

### 7. Determine Next Steps
Analyze all gathered information to determine what needs to happen:
- **New implementation**: List acceptance criteria and technical guidance
- **Bug fix**: Describe bug, repro steps, root cause analysis
- **Re-implementation after revert**: Note what was reverted, why, and the recommended approach
- **QA feedback**: List specific changes requested

### 8. Write Summary File
Create: `aidoc/ticket-docs/$TICKET/summary=YYYYMMDD-<next-step>.md`

Where `<next-step>` is a kebab-case description of the primary action (e.g., `fix-totals`, `implement-sorting`, `address-qa-feedback`).

Use this template:

```markdown
# $TICKET: <Summary>

**Generated**: YYYY-MM-DD
**Status**: <from Jira>
**URL**: https://archeredu.atlassian.net/browse/$TICKET

## Overview
<2-3 sentences on what this ticket is about>

## Current State
<Where things stand - work done? Reverted? Awaiting QA?>

## Requirements

### Original
<Acceptance criteria from description>

### Updates
<Modifications from comments - who requested, when>

## Technical Context

### Relevant Files
- `path/to/file.ext` - <why relevant>

### Previous Commits
<Commits referencing this ticket, if any>

### Technical Analysis
<Root cause or implementation notes from comments>

## Attachments
<List downloaded files with descriptions>

## Linked Tickets
<Summarize relevant info - secondary agent can't access Jira>

## Next Steps
<Clear, actionable description>

1. <First step>
2. <Second step>

## Testing Checklist
<Testing requirements from ticket/comments>

---
[Created and submitted by AI: Claude]
```

## 9. Update Todo Sheet (Split Open Item)

After writing the summary file, update the Google Sheets todo list to close the assessment task and create the next task.

**Get configuration:**
```bash
ticket-config sheets-id
```

**Calculate work date (sheet's "today"):**
The sheet's concept of "today" is shifted by -6 hours (times before 6 AM count as the previous day):
```bash
date -d "6 hours ago" '+%-m/%-d/%Y'
```

### 9a. Find the Assessment Task

**Primary method (search from bottom of RawData):**
1. Call `mcp__google-sheets__find_empty_row` with `sheetName: "RawData"` → row N
2. Call `mcp__google-sheets__read_range` with range `RawData!A{N-20}:J{N}` (last 20 rows)
3. Look for the row whose Job column (I) matches the ticket number

**Fallback (if not found in last 20 rows):**
1. Call `mcp__google-sheets__read_range` with range `OpenItems!A2:J500`
2. Find the row whose Job column (I) matches the ticket number — note the ID from column A
3. Read `RawData!A{N-100}:A{N}` and search for that ID to get the actual RawData row number
4. Read that row's full data from RawData

### 9b. Close the Existing Task

Update the found row on **RawData** (not OpenItems):
- Set **Completed** (column G) to the work date
- Set **Priority** (column B) to empty string

Use `mcp__google-sheets__write_range` to write just those two cells.

### 9c. Create the Follow-up Task

1. The first empty row N (from step 9a) is where the new task goes
2. Get the last ID: call `mcp__google-sheets__read_range` with range `RawData!A{N-1}:A{N-1}`
3. New ID = last ID + 1
4. Determine due date: if the original task's Due (column F) is in the future, keep it; otherwise use the work date
5. Write the new row using `mcp__google-sheets__write_range`:
   - Range: `RawData!A{N}:J{N}`
   - Values: `[["ID", "", "Task", "Work", "WORK_DATE", "DUE_DATE", "", "", "TICKET", "Implement Claude's plan and review results"]]`

**RawData Columns (10 total, A-J):**
| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| ID | Priority | List | Context | Added | Due | Completed | Project | Job | Description |

**Then proceed to Completion.**

---

## Completion

After ALL steps are complete (including the sheet update), report:
- The summary file path
- That the assessment task was closed and the implementation task was created

**Then STOP.**

---

## Guidelines

- **Be complete**: The secondary agent has no Jira access - include everything needed
- **Be concise**: Distill, don't dump. Omit irrelevant comments and redundant info
- **Ask when unclear**: If something is ambiguous and can't be resolved from comments, ask the user
- **Err toward inclusion**: When unsure if something is relevant, include it with a note

[Created and submitted by AI: Claude]
