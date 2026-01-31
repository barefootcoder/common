# Reference Documentation

Detailed reference information for the ticket onboarding workflow.

## Jira Configuration

### Custom Field IDs
| Field Name | Field ID | Type | Notes |
|------------|----------|------|-------|
| Development Owner | customfield_10157 | User Picker | Set during onboarding |
| Product Owner | customfield_10072 | User Picker | Usually different from dev |
| Checklist Progress | customfield_10036 | Read-only | Shows "X/Y" format |
| Checklist Progress % | customfield_10037 | Read-only | Percentage complete |

### Project Information
- **Default Project**: CLASS (Tech Classic Perl)
- **Ticket Pattern**: CLASS-XXX (number-only input gets CLASS- prefix)

### Status Workflow
Typical transition path: `To Do` → `On Deck` → `In Progress` → `In Review` → `Done`

The `jira-take-ticket` script transitions to "On Deck" status.

---

## Google Sheets Structure

### RawJobs Tab (Job Definitions)
| Column | Field | Purpose | Example |
|--------|-------|---------|---------|
| A | Code | Unique identifier | CLASS-722 |
| B | Context | Work category | Work |
| C | Added | Date created | 8/8/2025 |
| D | Due | Due date (optional) | |
| E | Completed | Completion date | |
| F | Project | Project grouping | |
| G | Description | Full description | "Clickout data fixes" |
| H+ | (Calculated) | Auto-calculated fields | |

### RawData Tab (Tasks/Items)
| Column | Field | Purpose | Example |
|--------|-------|---------|---------|
| A | ID | Unique numeric ID | 38556 |
| B | Priority | Priority level | |
| C | List | Item type | Task |
| D | Context | Work category | Work |
| E | Added | Date created | 8/8/2025 |
| F | Due | Due date | 8/8/2025 |
| G | Completed | Completion date | |
| H | Project | Project code | |
| I | Job | Associated job code | CLASS-722 |
| J | Description | Task description | "Fix empty columns" |
| K | Notes | Additional notes | |

### Standard Values

**Contexts**: Work, Errand, Household, Office, Laptop

**List Types**: Task, Block, SomedayMaybe, WaitingFor

### ID Management
- IDs are sequential numeric values
- Always increment from the highest existing ID
- Use `find_empty_row()` then read the previous row's ID

### Priority vs Due Date Rule
Every task must have either a **Priority** OR a **Due** date (or both).
For ticket-related tasks: Set Due = Added date for immediate visibility.

---

## Triage File Structure

### Overall Format
```
YYYY/M/D meeting
=================
* TICKET	-	Description
	* status
		* optional subtask info
* TICKET	-	Another ticket
	* different status

YYYY/M/D meeting (previous week)
=================
...
```

### Ticket Status Hierarchy (within each meeting section)
1. **Done tickets**: `* done`
2. **Staging tickets**: `* on staging`
3. **Trunk tickets**: `* on trunk`
4. **Current tickets**: `* up next`, `* working on it`
5. **Background tickets**: `* working on in the background`, `* temporarily back burnered`

### New Ticket Insertion
Insert new tickets:
- At end of current/active tickets
- Before first background ticket
- With status `* up next`

### Format Requirements
- Use actual TAB characters between elements
- Line 1: `* TICKET<TAB>-<TAB>Summary`
- Line 2: `<TAB>* up next`

---

## Timer File Structure

### Two-Paragraph Format
Each week has two paragraphs that must stay synchronized:

**Paragraph 1 - Timer Chunks** (timestamps):
```
email	1754341915-1754342672,1754426748-1754428017,
review	1754341813-1754341915,
utests
new-timer
```

**Paragraph 2 - Timer Definitions** (descriptions):
```
email:	checking email	SAVE
review:	reviewing time and tickets	SAVE
utests:	fix some failing unit tests ()	SAVEp
new-timer:	"Ticket summary"	CLASS-XXX
```

### Timer Definition Third Column
The third column controls persistence to next week:

| Value | Behavior | Example |
|-------|----------|---------|
| Ticket number | Not saved to next week | `CLASS-722` |
| `SAVE` | Full comment saved | `checking email` stays |
| `SAVEp` | Partial save (parentheses cleared) | `meeting ()` keeps `meeting` |

**For ticket work**: Always use the ticket number as the third field.

### Timer Naming Convention
- Use kebab-case: `word-word-word`
- Be descriptive but concise
- Based on ticket content
- Examples: `clickout-data-cols-fix`, `sandbox-build-improvements`

### Order Consistency
Timer chunks and definitions must maintain the same order within their respective paragraphs.

### Anchor Point
The `utests` timer serves as the insertion anchor. New timers are added immediately after `utests` in both paragraphs.

---

## Date/Time Configuration

### Time Zone
- **Local Time Zone**: Pacific (PDT/PST)
- Always use local system time, not UTC

### Time-Shift Logic (6 AM Boundary)
Since work often extends past midnight:
- 0:00-5:59: Use **yesterday's** date
- 6:00-23:59: Use **today's** date

The `ticket-preflight` script calculates and displays the correct work date.

### Date Formats
- **Input**: Any reasonable format (Google Sheets auto-converts)
- **Display**: Typically M/D/YY or MM/DD/YYYY
