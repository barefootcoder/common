---
name: x-take-ticket
description: Claim a Jira ticket and set up tracking (administrative only - NO technical work)
argument-hint: [ticket-number]
model: opus
disable-model-invocation: true
allowed-tools: Bash(ticket-*), Bash(jira-*), Bash(timer-update *), mcp__google-sheets__*, Read, Edit, AskUserQuestion
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
0. Get ticket info and ask for timer name (only user prompt — do this FIRST)
1. Pre-flight validation
2. Jira setup (assign, set dev owner, transition)
3. Google Sheets job creation (RawJobs)
4. Google Sheets task creation (RawData)
5. Triage file update
6. Timer file update

**Ticket argument**: $ARGUMENTS (if just a number, prepend "CLASS-")

## Available Scripts

Run these from the skill's `scripts/` directory:
- `ticket-preflight` - Validates system readiness, outputs work date
- `ticket-config <key>` - Retrieves: account-id, cloud-id, email, triage-file, timer-file, sheets-id
- `jira-ticket-info <TICKET>` - Shows ticket summary
- `jira-take-ticket <TICKET>` - Assigns ticket, sets dev owner, transitions to "On Deck"
- `timer-update <name> <summary> <ticket>` - Inserts timer entries into both sections of the timer file

---

## Step 0: Get Ticket Info and Timer Name

This is the ONLY user interaction in the entire workflow. Do it first so everything else runs autonomously.

1. Run `jira-ticket-info <TICKET>` to get the ticket summary
2. Generate a suggested timer name in kebab-case based on the ticket content (e.g., `clickout-data-cols-fix`)
3. **Use the AskUserQuestion tool** with these parameters:
   - question: "What timer name should I use? (Type '+' to accept the suggestion above, or enter your own)"
   - header: "Timer"
   - options:
     - label: "+", description: "Accept the suggested timer name"
     - label: "Custom", description: "I'll type my own timer name"

**When the user answers, continue IMMEDIATELY. Do NOT ask anything else.**

- If user types "+" or selects "+": Use your suggested timer name
- Otherwise: Use what they provided as the timer name

**Save the timer name and ticket summary for later steps.**

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
2. Run `jira-ticket-info <TICKET>` to verify (summary was already saved from Step 0)

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

## Step 4: Task Creation

Create a single "assess" task in RawData:

1. Call `mcp__google-sheets__find_empty_row` with `sheetName: "RawData"`
2. Get last ID: Call `mcp__google-sheets__read_range` with range `RawData!A{row-1}:A{row-1}`
3. Calculate new ID = last ID + 1
4. Write task using `mcp__google-sheets__write_range`:
   - Range: `RawData!A{row}:J{row}`
   - Values: `[["ID", "", "Task", "Work", "WORK_DATE", "WORK_DATE", "", "", "TICKET", "Have Claude assess the ticket"]]`

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

**Run the `timer-update` script** with the timer name (from Step 0), summary, and ticket:

```bash
timer-update <timer-name> '<summary>' <ticket>
```

**Example:**
```bash
timer-update clickout-fix 'Fix clickout data columns' CLASS-897
```

The script handles:
- Finding the timer file path
- Inserting the chunk entry after `utests`
- Inserting the comment entry after `utests:`
- Escaping special characters in the summary
- Verifying both entries were added correctly

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
