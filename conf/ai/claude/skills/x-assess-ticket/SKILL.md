---
name: x-assess-ticket
description: Assess the current state of a Jira ticket and produce a summary for development work
argument-hint: [ticket-number]
model: opus
context: fork
disable-model-invocation: true
allowed-tools: Bash(jira-*), Bash(ticket-*), Bash(git log*), Bash(ls*), Bash(mkdir*), Read, Glob, Grep, Write
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

## Guidelines

- **Be complete**: The secondary agent has no Jira access - include everything needed
- **Be concise**: Distill, don't dump. Omit irrelevant comments and redundant info
- **Ask when unclear**: If something is ambiguous and can't be resolved from comments, ask the user
- **Err toward inclusion**: When unsure if something is relevant, include it with a note

[Created and submitted by AI: Claude]
