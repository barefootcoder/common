# Todo Sheet Project

Personal task management system backed by a Google Sheet ("Todo"), with Google
Apps Script macros for in-sheet automation and Claude Code skills for
ticket-onboarding workflows.

## Obtaining the Sheet ID

The spreadsheet ID and other work credentials live in
`private/work-credentials.md` (gitignored). That file is the single source of
truth for Jira account details, the sheet ID, and work file paths.

The `x-take-ticket` skill reads these values at runtime via its `ticket-config`
script.

---

## Sheet Structure

### RawJobs (Job Definitions)

Each row represents a "job" -- a project, ticket, or other unit of work that
may contain multiple tasks.

| Column | Field       | Purpose               | Example              |
|--------|-------------|-----------------------|----------------------|
| A      | Code        | Unique identifier     | CLASS-722            |
| B      | Context     | Work category         | Work                 |
| C      | Added       | Date created          | 8/8/2025             |
| D      | Due         | Due date (optional)   |                      |
| E      | Completed   | Completion date       |                      |
| F      | Project     | Project grouping      |                      |
| G      | Description | Full description      | Clickout data fixes  |

Columns H+ contain auto-calculated fields driven by formulas.

Always write exactly **7 columns (A-G)** to avoid misalignment.

### RawData (Tasks / Items)

Each row is an individual task or action item, optionally linked to a job.

| Column | Field       | Purpose               | Example                        |
|--------|-------------|-----------------------|--------------------------------|
| A      | ID          | Unique numeric ID     | 38556                          |
| B      | Priority    | Priority level        |                                |
| C      | List        | Item type             | Task                           |
| D      | Context     | Work category         | Work                           |
| E      | Added       | Date created          | 8/8/2025                       |
| F      | Due         | Due date              | 8/8/2025                       |
| G      | Completed   | Completion date       |                                |
| H      | Project     | Project code          |                                |
| I      | Job         | Associated job code   | CLASS-722                      |
| J      | Description | Task description      | Fix empty columns              |
| K      | Notes       | Additional notes      |                                |

Always write exactly **10 columns (A-J)** when inserting via the API.  Never
read entire columns (e.g. `RawData!A:A`) -- use specific cell ranges to avoid
token overflow.

### Other Notable Tabs

| Tab           | Purpose                                                  |
|---------------|----------------------------------------------------------|
| RawProjects   | Project definitions that jobs can belong to              |
| Recurring     | Templates for recurring tasks (daily, weekly, etc.)      |
| NewTask       | Quick-entry form for adding tasks from the sheet UI      |
| Today         | Daily schedule / calendar day view                       |
| Diary         | End-of-day archival of completed daily items             |
| RecentItems   | FILTER view of RawData items recently added, due, or completed (controlled by `RecentItemsDaysLookback` named range) |

Several additional helper tabs (ItemId, Job, JumpTab, PushToday, PushJob) serve
as lookup tables consumed by the Google Apps Script macros.

---

## Standard Values

**Contexts**: Work, Errand, Household, Office, Laptop

**List types** (RawData column C): Task, Block, SomedayMaybe, WaitingFor

## ID Management

IDs in RawData column A are sequential integers.  To add a row: find the first
empty row, read the previous row's ID, and increment by 1.

## Priority vs Due Date Rule

Every task **must** have either a Priority or a Due date (or both).  For
ticket-related tasks the convention is to set Due = Added date so the item is
immediately visible.

---

## Common Ad-Hoc Operations

### Read jobs for a ticket

```
mcp__google-sheets__read_range  sheetName: "RawJobs"  range: "RawJobs!A1:G5"
```

### Add a standalone task (no job)

1. `find_empty_row` on RawData
2. Read `RawData!A{row-1}` to get the last ID
3. Write 10 columns: `[["ID", "", "Task", "Context", "DATE", "DATE", "", "", "", "Description"]]`

### Mark a task complete

Write the completion date into column G of the task's row:

```
mcp__google-sheets__write_range  range: "RawData!G{row}:G{row}"  values: [["MM/DD/YYYY"]]
```

---

## Google Apps Script Macros

The sheet's in-app automation lives in `~/proj/GoogleSheets-personal/`.  Two
files are directly relevant to the Todo sheet; two others share the utility
library but operate on different spreadsheets.

### Todo.gas -- main macro file

Approximately 1,470 lines organized into these areas:

- **Lookup functions** -- navigation via helper tabs (ItemId, Job, JumpTab,
  PushToday, PushJob) using `l.sheetLookup()`
- **Item CRUD** -- `rowIntoObject()`, `getObject()`, `newItem()`,
  `updateItem()`, `copyItem()` with read-only vs. editable key separation
- **Completion & status** -- priority-stack popping when items complete,
  delegation, cancellation with notes
- **Priority & due-date management** -- letter+number system (A1-Z3) with
  overflow handling, date pushing, bumping
- **Recurring / in-tray** -- recurring-task templates, new-task creation, TV
  season tracking
- **Daily workflow** -- `newDay()`, `saveDay()`, daily-schedule templates,
  end-of-day archival to a separate CalenDiary spreadsheet
- **Menu system** -- 15+ items across 6 nested submenus

### Barefoot.lib.gas -- shared utility library

Approximately 750 lines providing ~40 functions under the **`l.*`** namespace
(e.g. `l.today()`, `l.sheetLookup()`, `l.tabHeaders()`).

Key categories:

| Category           | Examples                                         |
|--------------------|--------------------------------------------------|
| Date utilities     | `l.today()` (6-hour shift), `l.addDays()`, `l.dateFromCell()` |
| Sheet navigation   | `l.tabHeaders()`, `l.getColumnOfHeader()`, `l.getFirstEmptyRow()` |
| Lookups            | `l.sheetLookup()`, `l.controlObjectForTab()`     |
| UI helpers         | `l.progress()`, `l.confirm()`, `l.prompt()`      |
| Data manipulation  | `l.getDataSlice()`, `l.getDataBlock()`, `l.copyValuesTo()` |
| Debug              | `l.setDEBUG()`, `l.debug()` (multi-level)        |

Key patterns: header-based column access (cached via `CacheService`), relational
lookups via helper tabs, defensive GAS-object type checking.

### Other files (not Todo-related)

- **Budget.gas** -- personal finance ledger (checking/savings, paycheck
  disbursement, receipt splitting)
- **PushSongs.gas** -- simple song-queue management

Both import `Barefoot.lib.gas` but do not interact with the Todo sheet.

---

## Related Resources

- **`/x-take-ticket` skill** -- ticket onboarding workflow that writes to
  RawJobs and RawData (`conf/ai/claude/skills/x-take-ticket/`)
- **reference.md** -- detailed column layouts and file-format docs inside
  the skill directory (`conf/ai/claude/skills/x-take-ticket/reference.md`)
