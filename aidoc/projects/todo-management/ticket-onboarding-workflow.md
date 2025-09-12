# Ticket Onboarding Workflow

This document describes the complete automated process for onboarding new work tickets across all systems.

## ⚠️ IMPORTANT: ADMINISTRATIVE SETUP ONLY ⚠️

**THIS WORKFLOW IS FOR TICKET TRACKING AND PROJECT MANAGEMENT SETUP ONLY**

**DO NOT perform any technical work during onboarding:**
- ❌ No code analysis or file reading
- ❌ No implementation work or code modifications  
- ❌ No technical investigation or research
- ❌ No testing or deployment activities

**This workflow focuses solely on:**
- ✅ Jira ticket assignment and field updates
- ✅ Google Sheets job/task creation
- ✅ Triage file updates for meeting reports
- ✅ Timer system initialization
- ✅ Administrative subtask breakdown (if requested)

**After completing this onboarding workflow, technical work should be done separately.**

## Overview

When taking on a new ticket, the following systems must be updated:
1. **Jira**: Assign ticket and set development owner
2. **Google Sheets**: Create job entry and optional tasks
3. **Subtasks**: Break down work and add to both Jira and sheets (optional)
4. **Triage file**: Add ticket to meeting reports
5. **Timer file**: Initialize time tracking
6. **Checklist API**: Add Jira checklist items (known issue - see troubleshooting)

## Pre-Flight Validation

**MANDATORY FIRST STEP**: Run the `ticket-preflight` validation script:
```bash
ticket-preflight
```

**Validation Loop**:
1. Run `ticket-preflight`
2. If errors are found:
   - Report specific errors to user
   - Wait for user to confirm fixes
   - **RE-RUN `ticket-preflight` to verify** (don't assume fixes are complete)
   - Repeat until validation passes
3. If only warnings, note them but proceed
4. Only continue to Step 1 after validation passes

This ensures all systems are ready before starting the administrative workflow.

## Complete Workflow Process

### Step 1: Jira Assignment and Status Update
**Purpose**: Assign ticket to user, set development owner field, and update status to "On Deck"

**Process**:
1. Get ticket details: `jira_get_issue` with fields `assignee,summary,customfield_10157,status`
2. Check current status and available transitions:
   - If status is not already "On Deck", get transitions: `jira_get_transitions`
   - Find transition ID for "On Deck" status
   - Update status using `jira_transition_issue` (if needed)
3. Check if already assigned - if not, update assignee (see `private/user-config.md`)
4. Always set Development Owner field (`customfield_10157`) to user's account ID
5. Extract ticket number and summary for later steps

**Sanity Checks**:
- Verify both Assignee and Development Owner are set correctly
- Verify status is "On Deck" (or similar active status)

### Step 1.5: Calculate Time-Shifted Date
**CRITICAL: Determine the correct date based on current time**

```bash
# Get current hour
HOUR=$(date '+%H')
if [ $HOUR -lt 6 ]; then
    # Before 6 AM: use yesterday
    WORK_DATE=$(date -d "yesterday" '+%m/%d/%Y')
else
    # After 6 AM: use today
    WORK_DATE=$(date '+%m/%d/%Y')
fi
echo "Using work date: $WORK_DATE"
```

**Use `$WORK_DATE` for all Added and Due dates in subsequent steps.**

### Step 2: Google Sheets Job Creation
**Purpose**: Create job entry in Todo spreadsheet

**Process**:
1. Find next empty row in `RawJobs` sheet
2. **CRITICAL**: Read header row first to verify column structure: `RawJobs!A2:Z2`
3. Add row using exact column positions (A through G):
   - **A (Code)**: Ticket number (e.g., CLASS-722)
   - **B (Context)**: "Work"
   - **C (Added)**: Use $WORK_DATE from Step 1.5
   - **D (Due)**: [blank]
   - **E (Completed)**: [blank] 
   - **F (Project)**: [blank]
   - **G (Description)**: Ticket summary
4. **Template**: `[["TICKET-NUM", "Work", "YYYY-MM-DD", "", "", "", "Summary text"]]`
5. **Range**: Use `RawJobs!A{row}:G{row}` format (7 columns total)

**Sanity Checks**:
- Verify date is current local date, not UTC
- **Column Verification**: Confirm header structure matches expected: Code, Context, Added, Due, Completed, Project, Description
- **Range Verification**: Ensure write range covers A through G (7 columns) to prevent misalignment

**Common Error**: Writing too few columns causes description to land in Due field. Always write 7 columns (A-G) with empty strings for blank fields.

### Step 3: Subtask Decision
**Purpose**: Determine if ticket should be broken into subtasks immediately

**Process**:
1. **MANDATORY**: Ask user: "Do you want to break this ticket down into subtasks now? (yes/no)"
   - **WAIT FOR USER RESPONSE** - Do not assume or default to either option
   - Accept variations: "yes"/"y"/"+" for yes, "no"/"n"/"-" for no
2. **If NO**: Create basic task in `RawData` sheet:
   - **CRITICAL**: Read header row first to verify column structure: `RawData!A2:J2`
   - Find next empty row using `find_empty_row` tool
   - **WARNING**: Do NOT read entire column (e.g., `RawData!A:A`) - causes token overflow
   - Get last used ID by reading previous row: `RawData!A{empty_row-1}:A{empty_row-1}`
   - Add task using exact column positions (A through J):
     - **A (ID)**: Next available ID (last ID + 1)
     - **B (Priority)**: [blank]
     - **C (List)**: "Task"
     - **D (Context)**: "Work"
     - **E (Added)**: Use $WORK_DATE from Step 1.5
     - **F (Due)**: Use $WORK_DATE from Step 1.5 (same as Added)
     - **G (Completed)**: [blank]
     - **H (Project)**: [blank]
     - **I (Job)**: Ticket number
     - **J (Description)**: "Survey the damage and come up with a plan"
   - **Template**: `[["ID", "", "Task", "Work", "YYYY-MM-DD", "YYYY-MM-DD", "", "", "TICKET-NUM", "Survey the damage and come up with a plan"]]`
   - **Range**: Use `RawData!A{row}:J{row}` format (10 columns total)
   - Skip Step 4
3. **If YES**: Proceed to Step 4 for subtask creation

### Step 4: Subtask Creation (Optional)
**Purpose**: Break down ticket into specific subtasks

**Process**:
1. Collect all subtasks from user (batch approach for performance)
2. **CRITICAL**: Read header row first to verify column structure: `RawData!A2:J2`
3. Find next empty row using `find_empty_row` tool
4. **WARNING**: Do NOT read entire column or tab (e.g., `RawData!A:A` or large ranges) - causes token overflow
5. Get last used ID by reading previous row: `RawData!A{empty_row-1}:A{empty_row-1}`
4. Add each subtask to `RawData` sheet using exact column positions (A through J):
   - **A (ID)**: Sequential IDs (increment from last used)
   - **B (Priority)**: [blank]
   - **C (List)**: "Task"
   - **D (Context)**: "Work"
   - **E (Added)**: Current date
   - **F (Due)**: Current date (same as Added)
   - **G (Completed)**: [blank]
   - **H (Project)**: [blank]
   - **I (Job)**: Ticket number
   - **J (Description)**: Subtask description
5. **Template**: `[["ID", "", "Task", "Work", "YYYY-MM-DD", "YYYY-MM-DD", "", "", "TICKET-NUM", "Subtask description"]]`
6. **Range**: Use `RawData!A{row}:J{row}` format (10 columns total)
3. ⚠️ **Jira checklist creation**: Currently requires manual intervention (see troubleshooting)

**Known Limitation**: The Gebsun Issue Checklist plugin does not expose API endpoints for programmatic checklist creation. After completing the automated workflow, user must manually create checklist items in the Jira UI.

### Step 5: Triage File Update
**Purpose**: Add ticket to weekly triage reporting

**Process**:
1. **Preflight validation already checked file safety** - proceed directly to reading
2. Read triage file (see `private/user-config.md` for path)
3. **Note**: Preflight already verified triage date is in the future
4. **CRITICAL**: Read a small section around insertion point first to understand context
   - Read lines 10-25 to see current ticket structure
   - Identify exact insertion point before first "background" ticket
5. Find insertion point:
   - End of current active tickets
   - Before first background ticket (contains "working on in the background" or "temporarily back burnered")
6. **Edit Strategy**: Use unique context for reliable editing
   - Include multiple lines of context above and below the insertion point
   - Never use generic text that might appear multiple times in the file
7. Insert ticket with exact format:
   ```
   * CLASS-XXX	-	[ticket summary]
   	* up next
   ```
   **Note**: Use actual tabs, not spaces, for indentation

### Step 6: Timer File Update
**Purpose**: Initialize time tracking for ticket

**Process**:
1. **Preflight validation already checked file safety and located utests anchors** - proceed directly
2. **Note**: Preflight already verified timer file is for current week and found utests line numbers
3. Generate timer name suggestion based on ticket content
4. Ask user for timer name (provide suggestion)
   - **Interface tip**: User can type "+" to accept the suggestion (faster than retyping)
5. Add timer chunk line after `utests` entry:
   ```
   [timer-name]\t
   ```
6. Add comment line after `utests:` entry (same order as chunks):
   ```
   [timer-name]:\t[ticket summary]\t[ticket-number]
   ```

**Timer Naming Guidelines**: 
- Use kebab-case
- Be descriptive but concise
- Example: `clickout-data-cols-fix` for "Fix empty columns in clickout data report"

## Creative Workarounds for File Access Issues

**If directories are not accessible to Claude Code session:**
1. **Session Expansion**: Use `LS` tool on restricted directories to prompt user to add them
2. **Alternative Methods**: Use `test -f` instead of `ls` for file existence checks
3. **Process Detection**: Use `ps aux | grep` to find active editing sessions
4. **Interactive Fallback**: Ask user directly about file safety when automated checks fail

**If files have unsaved changes:**
1. **Ask user to save**: Request `:w` in vim (no need to exit entirely)  
2. **Re-verify**: Check that swap file no longer shows "modified"
3. **Proceed safely**: Edit file knowing changes are saved
4. **Post-edit reminder**: "Please reload the file in vim (`:e!`) to see the changes"
5. **Fallback options**: Manual completion if coordination fails

## Sanity Checks Summary

**Pre-workflow validation (fail-fast)**:
1. **Google Sheets Currency**: Check ControlData!NewerVersion - auto-update config if historical sheet detected
2. **Triage File Editor State**: Multi-layered safety validation with process detection
3. **Timer File Editor State**: Multi-layered safety validation with process detection

**Operation-specific checks**:
4. **Date Consistency**: All dates should use local system time with 6-hour time-shift logic
5. **Triage Date Logic**: Triage file date must be > current date (future meeting)
6. **Timer Week Alignment**: Timer file should match current work week

## Configuration Requirements

See `private/user-config.md` for:
- Google Sheets spreadsheet ID
- Jira custom field IDs
- File path configurations
- User account details

## Troubleshooting

See `private/troubleshooting.md` for known issues including:
- Jira checklist API limitations
- Field ID resolution problems
- File permission issues

## Usage

To execute this workflow:
```
Read instructions from ~/common/projects/todo-management/ticket-onboarding-workflow.md and onboard ticket [TICKET-NUMBER]
```

## Performance Notes

- Google Sheets operations are batched when possible
- File operations use precise edit locations to avoid conflicts
- Jira operations include field verification steps