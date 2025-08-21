# File Management Operations

This document covers operations for triage reporting and timer tracking files.

## Overview

Two key files support the workflow:
- **Triage file** (`triage.md`): Weekly meeting reports and ticket status
- **Timer file** (`timer-new`): Time tracking with coded entries

## Triage File Operations

### File Location
See `private/user-config.md` for specific file paths.

### File Structure
The triage file is organized by meeting weeks, with the most recent meeting at the top:

```
2025/8/12 meeting
=================
* CLASS-XXX	-	Ticket description
	* status/progress
		* subtask info (optional)
* CLASS-YYY	-	Another ticket
	* different status

2025/8/5 meeting  
=================
* [previous week's tickets...]
```

### Ticket Status Hierarchy
Within each meeting section, tickets are roughly ordered:
1. **Done tickets**: `* done`
2. **Staging tickets**: `* on staging` 
3. **Trunk tickets**: `* on trunk`
4. **Current tickets**: `* up next`, `* working on it`, etc.
5. **Background tickets**: `* working on in the background`, `* temporarily back burnered`

### Adding New Tickets

**Process**:
1. **Sanity Check**: Verify triage date > current date
   - **Good**: Future date (normal - editing upcoming meeting)
   - **Bad**: Past date (would modify historical reports)
2. **Find insertion point**: End of current tickets, before first background ticket
3. **Insert format**:
   ```
   * CLASS-XXX\t-\t[ticket summary]
   \t* up next
   ```

**Example insertion**:
```markdown
* CLASS-706	-	Sandbox improvements
	* making progress
		* 4 total subtasks done
* CLASS-722	-	"Clickout data report fixes"    <-- NEW TICKET
	* up next                                      <-- NEW STATUS  
* CLASS-614	-	Devops script improvements       <-- BACKGROUND START
	* working on in the background
```

## Timer File Operations

### File Location
See `private/user-config.md` for specific file paths.

### File Structure
Each week has two paragraphs:
1. **Timer chunks**: `timer-code\t[timestamp-ranges,]`
2. **Timer definitions**: `timer-code:\tdescription\textra`

```
email	1754341915-1754342672,1754426748-1754428017,
review	1754341813-1754341915,1754351403-1754352208,
utests	
clickout-data-cols-fix	
redshift-logs-fmt-wrong	1754349987-1754350853,

email:	checking email	SAVE
review:	reviewing time and tickets	SAVE  
utests:	fix some failing unit tests ()	SAVEp
clickout-data-cols-fix:	"Clickout data report fixes"	CLASS-722
redshift-logs-fmt-wrong:	log format fixes	CLASS-698
```

### Adding New Timer Entries

**Process**:
1. **Sanity Check**: Verify timer file date matches current work week
2. **Generate timer name**: Ask user, provide suggestion based on ticket
3. **Add chunk line**: Insert after `utests` in first paragraph
   ```
   [timer-name]\t
   ```
4. **Add definition line**: Insert after `utests:` in second paragraph  
   ```
   [timer-name]:\t[description]\t[ticket-number]
   ```

**Timer Naming Guidelines**:
- Use kebab-case: `word-word-word`
- Be descriptive but concise
- Based on ticket content/purpose
- Examples: `clickout-data-cols-fix`, `sandbox-build-improvements`

### Timer Definition Extras
The third field in definition lines controls comment persistence:

- **Ticket number** (e.g., `CLASS-722`): Comment is not saved to next week
- **SAVE**: Full comment is saved to next week's timers
  - Example: `email:\tchecking email\tSAVE` 
  - Next week: `email:\tchecking email\tSAVE`
- **SAVEp**: Partial comment is saved (content in parentheses removed)
  - Example: `company-mtg:\tall-hands meeting (Archie awards)\tSAVEp`
  - Next week: `company-mtg:\tall-hands meeting ()\tSAVEp`

For ticket-related work, always use the ticket number as the extra field.

### Order Consistency  
Timer chunks and definitions must maintain the same order within their respective paragraphs.

## Date and Time Considerations

### Time-Shifted Dates
Since work often extends past midnight, use 6-hour time-shift logic:
- If current time 0:00-6:00: Use "yesterday's" date
- If current time 6:01-23:59: Use "today's" date  

### Week Alignment
- **Triage file**: Future meeting dates (next Monday)
- **Timer file**: Current work week alignment
- Both should be consistent with work schedule

## File Format Requirements

### Triage File
- Use actual **tab characters** between elements
- Format: `* TICKET\t-\tDESCRIPTION`
- Status lines indented with tabs: `\t* status`
- Subtask info double-indented: `\t\t* details`

### Timer File  
- Use actual **tab characters** as separators
- Chunk format: `timer-name\t[timestamps]`
- Definition format: `timer-name:\tdescription\tticket`
- Single continuous lines (no word wrapping)

## Error Prevention

### Common Issues
1. **Wrong date logic**: Past dates in triage (modifying history)
2. **Insertion location**: Adding to wrong section or wrong order
3. **Tab vs spaces**: Must use actual tab characters
4. **Line wrapping**: Keep timer definitions on single lines
5. **Order mismatch**: Timer chunks/definitions in different orders

### Validation Checks
- Verify file dates before editing
- Confirm insertion points are correct
- Check tab character usage
- Validate timer name uniqueness
- Ensure consistent formatting

## File Paths Configuration

Different environments may use different paths:
- **Development**: `/export/work/...` 
- **Production**: `~/work/...`
- **Alternative**: User-specific paths in `~/common/...`

See `private/user-config.md` for environment-specific path configurations.

## Backup Considerations

These files contain important historical data:
- **Triage file**: Meeting reports and progress tracking
- **Timer file**: Time tracking records for billing/reporting

Consider backup strategies for:
- Weekly automatic backups
- Version control integration
- Cross-machine synchronization