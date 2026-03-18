---
name: x-create-ticket
description: Create a new Jira ticket with user-approved summary and description
argument-hint: [context or instructions]
disable-model-invocation: true
allowed-tools: Bash(jira-*), Bash(ticket-*), Bash(jira issue view *), Read, Grep, Glob, AskUserQuestion
---

# Create Jira Ticket Workflow

You are helping the user create a new Jira ticket.

## CRITICAL: Scope Restriction

**This skill creates a Jira ticket and STOPS. It does NOT onboard the ticket into tracking systems — that's what `/x-take-ticket` is for.**

### FORBIDDEN:
- Modifying any files (triage, timer, Google Sheets)
- Running `/x-take-ticket` or any onboarding steps
- Reading/analyzing code unless the user asked you to base the ticket on code findings
- Offering to do technical work after ticket creation

## Available Scripts

Run these from the skill's `scripts/` directory:
- `jira-create-ticket <PROJECT> <TYPE> <SUMMARY> [DESCRIPTION]` — Creates a ticket, outputs the new ticket key

Also available from `/x-take-ticket`'s scripts (for reading existing tickets):
- `${CLAUDE_SKILL_DIR}/../x-take-ticket/scripts/jira-ticket-info <TICKET>` — Shows ticket details
- `${CLAUDE_SKILL_DIR}/../x-take-ticket/scripts/ticket-config <key>` — Retrieves config values

---

## Step 1: Gather Context

Read the user's arguments and any conversation context to understand what ticket they want to create.

If the user references an existing ticket (e.g., "read CLASS-893"), fetch it:
```bash
~/.claude/skills/x-take-ticket/scripts/jira-ticket-info <TICKET>
```

If the user points to files (plan docs, investigation summaries, etc.), read those files to understand the context.

**Default project**: CLASS (unless the user specifies otherwise).
**Default type**: Task (unless the user specifies otherwise).

---

## Step 2: Draft Summary and Description

Based on the gathered context, draft:

1. **Summary**: A concise ticket title (under ~100 characters). Imperative or noun-phrase style.
2. **Description**: A focused ticket body following these guidelines:

### Description Guidelines

- **Audience**: The main audience is business stakeholders, not developers. Keep technical details minimal.
- **Concise**: 1-3 short paragraphs. No need for exhaustive detail — reference existing plan docs in the repo instead.
- **Business focus**: Lead with the business impact or motivation (why this matters), then briefly describe what will be done.
- **Reference, don't repeat**: If detailed plans, investigation findings, or technical docs exist in the repo, reference their path rather than copying their contents into the ticket.
- **Link parent work**: If this ticket follows from an investigation or spike, mention the parent ticket (e.g., "Investigation under CLASS-893 confirmed...").

---

## Step 3: Get User Approval

Present the drafted summary and description to the user clearly, formatted so they can review it. For example:

> **Summary:** Convert sync-cerpt-widget-performance from full-table sync to incremental sync
>
> **Description:**
>
> The daily sync-cerpt-widget-performance job currently re-syncs the entire table...

Then ask the user to approve or request changes. Wait for explicit approval before creating.

**Do NOT use AskUserQuestion for this** — just present the draft as text and let the user respond naturally. They may want to iterate.

---

## Step 4: Create the Ticket

Once the user approves, create the ticket:

```bash
~/.claude/skills/x-create-ticket/scripts/jira-create-ticket CLASS Task "Summary here" "Description here"
```

**Important `jira` CLI notes** (these are baked into the script, but for reference):
- The `-p PROJECT` flag is REQUIRED — without it, the CLI hangs waiting for interactive project selection
- `--no-input` is REQUIRED to suppress prompts for optional fields
- The script outputs the new ticket key (e.g., `CLASS-938`) on success

---

## Step 5: Verify and Report

After creation:

1. Run `jira-ticket-info` on the new ticket to verify it was created correctly:
   ```bash
   ~/.claude/skills/x-take-ticket/scripts/jira-ticket-info <NEW-TICKET>
   ```

2. Report the result to the user:
   > Created **CLASS-XXX**: https://archeredu.atlassian.net/browse/CLASS-XXX

3. If the user wants to onboard the ticket into tracking systems, suggest:
   > Run `/x-take-ticket XXX` to onboard it.

---

## Completion

After reporting the new ticket, **STOP**. Do not:
- Automatically run `/x-take-ticket`
- Offer to do technical work
- Modify any tracking files
