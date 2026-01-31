---
name: x-take-ticket
description: Claim a Jira ticket and set up tracking (administrative only - NO technical work)
argument-hint: [ticket-number]
model: opus
context: fork
disable-model-invocation: true
allowed-tools: Bash(ticket-*), Bash(jira-*), mcp__google-sheets__*, Read, Edit
---

# Ticket Onboarding Workflow

You are onboarding a Jira ticket into the user's task management systems.

## CRITICAL: Scope Restriction

**THIS SKILL IS 100% ADMINISTRATIVE. You MUST complete ALL steps below, then STOP.**

### FORBIDDEN (never do these):
- Reading/searching/analyzing code files
- Creating implementation plans
- Exploring the codebase
- Offering help with the ticket after setup

### REQUIRED (you MUST do ALL of these):
1. Pre-flight validation
2. Jira setup (assign, set dev owner, transition)
3. Google Sheets job creation (RawJobs)
4. Google Sheets task creation (RawData) - ask about subtasks first
5. Triage file update
6. Timer file update

**Ticket argument**: $ARGUMENTS (if just a number, prepend "CLASS-")

## Available Scripts

Run these from the skill's `scripts/` directory:
- `ticket-preflight` - Validates system readiness, outputs work date
- `ticket-config <key>` - Retrieves: account-id, cloud-id, email, triage-file, timer-file, sheets-id
- `jira-ticket-info <TICKET>` - Shows ticket summary
- `jira-take-ticket <TICKET>` - Assigns ticket, sets dev owner, transitions to "On Deck"

---

## Step 1: Pre-flight Validation

Run `ticket-preflight` and wait for it to pass.

**If errors occur:**
1. Report them to user
2. Wait for user to confirm fixes
3. **Re-run `ticket-preflight`** (don't assume fixes are complete)
4. Repeat until validation passes

**Record the work date** from output line: "For ticket onboarding, use date: MM/DD/YYYY"

---

## Step 2: Jira Setup

1. Run `jira-take-ticket <TICKET>` to assign, set dev owner, and transition
2. Run `jira-ticket-info <TICKET>` to verify and get the summary

**Save the ticket summary for later steps.**

---

## Step 3: Google Sheets Job Creation

**Get configuration:**
```bash
ticket-config sheets-id
```

**Process:**
1. Call `mcp__google-sheets__find_empty_row` with `sheetName: "RawJobs"`
2. Write job row using `mcp__google-sheets__write_range`:
   - Range: `RawJobs!A{row}:G{row}`
   - Values: `[["TICKET", "Work", "WORK_DATE", "", "", "", "Summary text"]]`

**Columns (7 total, A-G):**
| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| Code | Context | Added | Due | Completed | Project | Description |
| CLASS-XXX | Work | MM/DD/YYYY | | | | Ticket summary |

**WARNING:** Always write exactly 7 columns. Writing fewer columns causes data misalignment.

---

## IMPORTANT: Workflow Continuity

After completing Steps 1-3, you will ask the user questions in Steps 4 and 6.

**Before asking any question**, output a context summary to preserve gathered values:
```
Context gathered:
- Work date: [DATE]
- Ticket: [TICKET]
- Summary: [SUMMARY]
- Sheets ID: [ID]
```

**After user responds:**
- Continue directly to the remaining steps
- Do NOT attempt to re-invoke this skill
- The skill context remains active throughout the entire workflow
- Use the values from the context summary above

---

## Step 4: Subtask Decision and Task Creation

**First**, output the context summary (see above).

**Then ASK THE USER:** "Do you want to break this ticket down into subtasks now?"

Wait for their response, then continue directly to the appropriate section below.

### If NO (or user declines):

Create a single "survey" task in RawData:

1. Call `mcp__google-sheets__find_empty_row` with `sheetName: "RawData"`
2. Get last ID: Call `mcp__google-sheets__read_range` with range `RawData!A{row-1}:A{row-1}`
3. Calculate new ID = last ID + 1
4. Write task using `mcp__google-sheets__write_range`:
   - Range: `RawData!A{row}:J{row}`
   - Values: `[["ID", "", "Task", "Work", "WORK_DATE", "WORK_DATE", "", "", "TICKET", "Survey the damage and come up with a plan"]]`

### If YES:

1. Collect all subtask descriptions from user (batch approach)
2. Find empty row and last ID as above
3. Write each subtask with sequential IDs, same format but with their descriptions

**RawData Columns (10 total, A-J):**
| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| ID | Priority | List | Context | Added | Due | Completed | Project | Job | Description |
| 12345 | | Task | Work | MM/DD/YYYY | MM/DD/YYYY | | | CLASS-XXX | Task description |

**WARNING:** Do NOT read entire columns (e.g., `RawData!A:A`) - causes token overflow. Always use specific cell ranges.

---

## Step 5: Triage File Update

**Get file path:**
```bash
ticket-config triage-file
```

**Process:**
1. Read the triage file
2. Find the insertion point:
   - End of current active tickets
   - **Before** first background ticket (look for "working on in the background" or "temporarily back burnered")
3. Insert the new ticket with this exact format (use actual TAB characters, not spaces):

```
* CLASS-XXX	-	[ticket summary]
	* up next
```

**Format breakdown:**
- Line 1: `* TICKET<TAB>-<TAB>Summary`
- Line 2: `<TAB>* up next`

**Use the Edit tool** to insert at the correct location.

---

## Step 6: Timer File Update

**Get file path:**
```bash
ticket-config timer-file
```

**Reading the timer file:**
The timer file may exceed read limits. Use the line numbers from preflight output:
- Preflight shows: `Timer structure located (utests at lines X/Y)`
- Read chunk section: `offset=1, limit=X+10`
- Read comment section: `offset=Y-5, limit=30`

**Process:**
1. Read the timer file (using offset/limit as needed)
2. Locate the `utests` anchor lines (there are two sections - chunks and comments)
3. **Ask user for timer name** - suggest one based on ticket content (user can type "+" to accept)
4. Insert in BOTH sections, after the `utests` entries

**CRITICAL: TAB Character Handling**

Timer lines use TAB separators. When editing:
- Empty timer chunks still need a trailing TAB: `utests\t` not `utests`
- Chunk entries have format: `name\t` (name + TAB, no timestamps for new entries)
- Comment entries have format: `name:\tSUMMARY\tTICKET` (TABs between fields)

**Chunk section** (first paragraph) - add line after `utests<TAB>` line:
```
[timer-name]<TAB>
```

**Comment section** (second paragraph) - add line after `utests:<TAB>...` line:
```
[timer-name]:<TAB>[summary]<TAB>[ticket]
```

**Timer naming:** Use kebab-case based on ticket content (e.g., `clickout-data-cols-fix`)

**Use the Edit tool** to insert in both locations.

**Verification after editing:**
```bash
head -20 "$(ticket-config timer-file)" | cat -A
```
Lines should show `^I` for each TAB character. If TABs are missing, the edit corrupted the file.

---

## Completion

After ALL six steps are complete, respond with ONLY:

> "Administrative setup complete for CLASS-XXX."

**Then STOP. Do not:**
- Offer to help with the ticket
- Ask what to do next
- Suggest exploring the codebase
- Say "let me know if you need anything"

**Your job is finished. The user will start a new conversation for technical work.**
