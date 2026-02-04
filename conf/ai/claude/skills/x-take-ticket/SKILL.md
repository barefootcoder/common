---
name: x-take-ticket
description: Claim a Jira ticket and set up tracking (administrative only - NO technical work)
argument-hint: [ticket-number]
model: opus
disable-model-invocation: true
allowed-tools: Bash(ticket-*), Bash(jira-*), Bash(sed *), Bash(head *), Bash(TIMER_FILE=*), mcp__google-sheets__*, Read, Edit, AskUserQuestion
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

## Step 4: Subtask Decision and Task Creation

**Use the AskUserQuestion tool** with these parameters:
- question: "Do you want to break this ticket down into subtasks now?"
- header: "Subtasks"
- options:
  - label: "No", description: "Create a single 'Survey the damage' task"
  - label: "Yes", description: "I'll provide subtask descriptions"

**When the user answers, continue IMMEDIATELY. Do NOT:**
- Output any preamble or acknowledgment
- Ask if they need help with anything else
- Interpret their response as a new task

**If user says NO (or selects "No"):**

Create a single "survey" task in RawData:

1. Call `mcp__google-sheets__find_empty_row` with `sheetName: "RawData"`
2. Get last ID: Call `mcp__google-sheets__read_range` with range `RawData!A{row-1}:A{row-1}`
3. Calculate new ID = last ID + 1
4. Write task using `mcp__google-sheets__write_range`:
   - Range: `RawData!A{row}:J{row}`
   - Values: `[["ID", "", "Task", "Work", "WORK_DATE", "WORK_DATE", "", "", "TICKET", "Survey the damage and come up with a plan"]]`

**Then proceed IMMEDIATELY to Step 5.**

**If user says YES (or selects "Yes"):**

1. Ask user to provide all subtask descriptions (they can list them all at once)
2. Find empty row and last ID as above
3. Write each subtask with sequential IDs, same format but with their descriptions

**Then proceed IMMEDIATELY to Step 5.**

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

**Then proceed IMMEDIATELY to Step 6.**

---

## Step 6: Timer File Update

### 6a. Get File Path and Read File

**Get file path:**
```bash
ticket-config timer-file
```

**Reading the timer file:**
The timer file may exceed read limits. Use the line numbers from preflight output:
- Preflight shows: `Timer structure located (utests at lines X/Y)`
- Read chunk section: `offset=1, limit=X+10`
- Read comment section: `offset=Y-5, limit=30`

### 6b. Ask for Timer Name

Generate a suggested timer name in kebab-case based on the ticket content (e.g., `clickout-data-cols-fix`), then **use the AskUserQuestion tool** with these parameters:
- question: "What timer name should I use? (Type '+' to accept the suggestion above, or enter your own)"
- header: "Timer"
- options:
  - label: "+", description: "Accept the suggested timer name"
  - label: "Custom", description: "I'll type my own timer name"

### 6c. Process the Answer and Complete

**When the user answers, continue IMMEDIATELY to finish the skill.**

- If user types "+" or selects "+": Use your suggested timer name
- Otherwise: Use what they provided as the timer name

**Locate the `utests` anchor lines** (there are two sections - chunks and comments)

**Insert in BOTH sections**, after the `utests` entries.

#### WARNING: Do NOT Use the Edit Tool for Timer File

The Edit tool strips trailing whitespace, but the timer file has lines with **trailing TAB characters** that MUST be preserved. Using Edit will corrupt these lines, causing repeated failed attempts.

**Use `sed` instead** to insert lines while preserving all whitespace:

```bash
# Get the timer file path
TIMER_FILE="$(ticket-config timer-file)"

# Insert chunk entry (after the line matching "^utests<TAB>")
# Format: name<TAB> (trailing tab, no timestamps for new entries)
sed -i '/^utests\t/a [timer-name]\t' "$TIMER_FILE"

# Insert comment entry (after the line matching "^utests:<TAB>")
# Format: name:<TAB>summary<TAB>ticket
sed -i '/^utests:\t/a [timer-name]:\t[summary]\t[ticket]' "$TIMER_FILE"
```

**Important sed notes:**
- Use `\t` for TAB characters in the pattern and replacement
- The `/a` command appends a line after the match
- Replace `[timer-name]`, `[summary]`, and `[ticket]` with actual values
- Escape any special characters in the summary (especially `/` and `&`)

**Example with real values:**
```bash
TIMER_FILE="$(ticket-config timer-file)"
sed -i '/^utests\t/a clickout-fix\t' "$TIMER_FILE"
sed -i '/^utests:\t/a clickout-fix:\tFix clickout data columns\tCLASS-897' "$TIMER_FILE"
```

**Verification after editing:**
```bash
head -20 "$(ticket-config timer-file)" | cat -A
```
Lines should show `^I` for each TAB character. New lines should appear immediately after the `utests` lines.

**Then proceed IMMEDIATELY to Completion.**

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
