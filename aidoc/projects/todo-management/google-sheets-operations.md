# Google Sheets Operations

This document covers operations for the Todo spreadsheet, which implements a GTD (Getting Things Done) system.

## Overview

The Todo spreadsheet uses a multi-tab structure where most tabs are views of underlying data. The core data lives in two primary tabs:
- **RawJobs**: Job definitions (projects/tickets)
- **RawData**: Individual items/tasks

## Spreadsheet Structure

### Core Data Tabs

#### RawJobs Tab
**Purpose**: Contains job definitions (typically corresponding to tickets or projects)

| Column | Field | Purpose | Example |
|--------|-------|---------|---------|
| A | Code | Unique identifier | CLASS-722 |
| B | Context | Work category | Work |
| C | Added | Date created | 8/8/2025 |
| D | Due | Due date (optional) | |
| E | Completed | Completion date | |
| F | Project | Project grouping | |
| G | Description | Full description | "Clickout data report fixes" |
| H+ | Calculated | Auto-calculated fields | |

#### RawData Tab  
**Purpose**: Contains individual tasks and items

| Column | Field | Purpose | Example |
|--------|-------|---------|---------|
| A | ID | Unique numeric ID | 38556 |
| B | Priority | Priority level | |
| C | List | Item type | Task |
| D | Context | Work category | Work |
| E | Added | Date created | 8/8/2025 |
| F | Due | Due date | |
| G | Completed | Completion date | |
| H | Project | Project code | |
| I | Job | Associated job code | CLASS-722 |
| J | Description | Task description | "Fix empty columns" |
| K | Notes | Additional notes | |

### View Tabs
- **Jobs**: View of open jobs (incomplete jobs from RawJobs)
- **Today**: Current day's priorities
- **Work**: Work-related items and jobs
- **Focus**: High-priority focus items
- **Projects**: Project-based views
- **OpenItems**: All incomplete items

## Common Operations

### Adding a New Job

1. **Find next row**: Use `find_empty_row` for RawJobs tab
2. **Add job data**:
   ```
   Code: [JOB-IDENTIFIER]
   Context: "Work"
   Added: [CURRENT_DATE]  
   Description: [JOB_DESCRIPTION]
   [Leave other fields blank - they auto-calculate]
   ```

**Example**:
```python
next_row = find_empty_row(spreadsheet_id, "RawJobs")
write_range(spreadsheet_id, f"RawJobs!A{next_row}:G{next_row}", 
           [["CLASS-722", "Work", "8/8/2025", "", "", "", 
             "Clickout data report fixes"]])
```

### Adding Tasks to a Job

### ⚠️ CRITICAL: Date Handling for Tasks

**ALWAYS CHECK THE CURRENT TIME BEFORE SETTING DATES:**
```bash
date '+%H:%M'  # Check current hour
```

**Time-Shift Logic (MANDATORY):**
- If current time is **00:00-06:00**: Use **YESTERDAY's date**
- If current time is **06:01-23:59**: Use **TODAY's date**

**Example:**
```bash
# At 3:45 AM on August 14th
CURRENT_TIME="03:45"  # Before 6 AM
TASK_DATE="8/13/2025"  # Use August 13th (yesterday)

# At 9:30 AM on August 14th  
CURRENT_TIME="09:30"  # After 6 AM
TASK_DATE="8/14/2025"  # Use August 14th (today)
```

**This applies to BOTH Added and Due dates for work tasks!**

1. **Find next ID**: Read last row of RawData column A to get highest ID
2. **Add task data** for each task:
   ```
   ID: [LAST_ID + 1]
   List: "Task"
   Context: "Work"  
   Added: [CURRENT_DATE - apply time shift!]
   Due: [CURRENT_DATE - apply time shift!]
   Job: [JOB_CODE]
   Description: [TASK_DESCRIPTION]
   ```

**Example**:
```python
# Get next ID
last_rows = read_range(spreadsheet_id, "RawData!A36335:A36340")
next_id = int(last_rows[-1][0]) + 1

# Add tasks
tasks = [
    [str(next_id), "", "Task", "Work", "8/8/2025", "8/8/2025", "", "", 
     "CLASS-722", "Fix empty columns", ""],
    [str(next_id+1), "", "Task", "Work", "8/8/2025", "8/8/2025", "", "", 
     "CLASS-722", "Remove unnecessary columns", ""]
]
write_range(spreadsheet_id, f"RawData!A{next_row}:K{next_row+1}", tasks)
```

### Standard Task Types

- **Task**: Regular work items (most common)
- **Block**: Completed work items (historical)  
- **SomedayMaybe**: Future possibilities
- **WaitingFor**: Waiting for external dependencies

### Context Categories

- **Work**: Work-related items
- **Errand**: Personal errands
- **Household**: Home tasks
- **Office**: Office/administrative work
- **Laptop**: Computer-based tasks

## Date Handling

**Format**: Google Sheets auto-formats dates
**Input**: Any reasonable date format (MM/DD/YYYY, M/D/YY, etc.)
**Display**: Typically M/D/YY format

**Time-Shifted Date Logic**: Since work often extends past midnight, dates are "time-shifted" by 6 hours:
- If current time is 0:00-6:00, use "yesterday's" date
- If current time is 6:01-23:59, use "today's" date
- Always use local system time, not UTC

## Job Concept

A **job** is any grouping of items that has a definitive endpoint. Jobs are designed to be completed eventually, distinguishing them from **projects** which are inherently open-ended.

**Examples of jobs**:
- Work tickets (CLASS-722)
- Personal projects with clear completion criteria
- Time-bounded initiatives
- Specific deliverables

**Job characteristics**:
- Has a clear definition of "done"
- Contains one or more actionable tasks
- Will eventually be marked complete
- May correspond to external tracking systems (Jira, etc.)

## ID Management

- **RawData IDs**: Sequential numeric IDs, increment from highest existing
- **Job Codes**: Usually match ticket numbers (e.g., CLASS-722) or descriptive codes
- **Uniqueness**: IDs must be unique within RawData tab

## Batch Operations

For performance, batch multiple operations:
```python
# Instead of multiple single writes
write_range(spreadsheet_id, "RawData!A100:K102", [
    [row1_data],
    [row2_data], 
    [row3_data]
])
```

## GTD System Integration

### Job → Task Relationship
- One **job** can have multiple **tasks** (subtasks)
- Tasks reference their parent job via the **Job** column
- Jobs represent complete units of work; tasks are actionable steps

### Workflow States
1. **Planning**: Job created, basic survey task added
2. **Breakdown**: Job expanded into specific tasks  
3. **Execution**: Tasks completed individually
4. **Completion**: All tasks done, job marked complete

### Standard Survey Task
When not immediately breaking down a job:
```
Description: "Survey the damage and come up with a plan"
List: "Task"
Context: "Work"
Due: [CURRENT_DATE]
Job: [JOB_CODE]
```

## Priority vs Due Date Requirements

**Critical Rule**: Every task must have either a **Priority** OR a **Due** date (or both)
- **Neither**: Causes system problems and task visibility issues
- **Due only**: Most common for work tasks (recommended approach)
- **Priority only**: For flexible-timing items
- **Both**: Rare cases with urgent, time-sensitive work

**For ticket-related tasks**: Always set **Due** = **Added** date to ensure immediate visibility and proper task management.

## Error Prevention

### Common Issues
1. **Duplicate IDs**: Always increment from highest existing ID
2. **Missing Job References**: Ensure tasks reference valid job codes
3. **Date Formatting**: Use consistent date formats
4. **Blank Required Fields**: ID, List, and Description are typically required

### Validation Checks
- Verify job code exists before adding tasks
- Check ID uniqueness before adding
- Confirm date is reasonable (not far future/past)
- Ensure Context and List values are from standard set

## Performance Considerations

- Use `find_empty_row()` instead of reading entire columns
- Batch writes when adding multiple items
- Limit range reads to necessary data only
- Cache spreadsheet info for multiple operations

## Configuration

See `private/config.md` for:
- Authentication details
- Default contexts and list types
- Standard job/task patterns

See `private/user-config.md` for:
- Spreadsheet ID