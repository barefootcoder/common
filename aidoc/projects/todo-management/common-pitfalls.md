# Common Pitfalls and How to Avoid Them

## 1. Date Mistakes (Most Common!)

**Problem**: Using today's date when work is done after midnight (0:00-6:00 AM)
**Impact**: Tasks don't appear in correct views, messes up daily planning
**Solution**: ALWAYS check time and apply 6-hour shift:
- Before 6 AM → Use yesterday's date
- After 6 AM → Use today's date

**Test command to verify**:
```bash
date '+Current time: %H:%M, Work date should be: %m/%d/%Y'
# If hour < 06, manually subtract one day!
```

**Real Example**:
```bash
# At 3:45 AM on August 14th
$ date '+%H:%M'
03:45
# WRONG: Using 8/14/2025
# RIGHT: Using 8/13/2025 (yesterday)
```

## 2. Missing Job Reference

**Problem**: Adding tasks to RawData without a valid Job code
**Impact**: Tasks appear orphaned, don't group properly
**Solution**: Always verify job exists in RawJobs before adding tasks

## 3. Wrong Custom Field IDs

**Problem**: Using incorrect Jira custom field IDs
**Impact**: Updates fail or go to wrong fields
**Solution**: Use `jira_search_fields()` to verify field IDs:
- Development Owner: `customfield_10157`
- Checklist fields: Not accessible via API (Gebsun plugin limitation)

## 4. Column Misalignment in Sheets

**Problem**: Writing wrong number of columns to sheets
**Impact**: Data ends up in wrong columns (e.g., description in Due field)
**Solution**: 
- RawJobs: Always write 7 columns (A-G)
- RawData: Always write 10-11 columns (A-J or A-K)

## 5. Reading Entire Columns

**Problem**: Reading full columns like `RawData!A:A` 
**Impact**: Token overflow, massive API response
**Solution**: Use `find_empty_row()` or read specific ranges

## 6. UTC vs Local Time Confusion

**Problem**: Using UTC time instead of local time
**Impact**: Wrong dates, especially around midnight
**Solution**: Always use local system time:
```bash
date '+%m/%d/%Y'  # Local date
date '+%H:%M'     # Local time for checking 6-hour shift
```

## 7. Forgetting Due Date on Tasks

**Problem**: Creating tasks without Due date or Priority
**Impact**: Tasks don't appear in Today view or other filtered views
**Solution**: For work tasks, ALWAYS set Due = Added date

## 8. Manual Checklist Creation

**Problem**: Trying to automate Gebsun Issue Checklist updates
**Impact**: API calls fail - plugin doesn't expose API
**Solution**: Accept this as manual step, inform user to create checklist items in Jira UI

## Prevention Checklist

Before running any workflow:
- [ ] Check current time: `date '+%H:%M'`
- [ ] Calculate correct work date (apply 6-hour shift if needed)
- [ ] Verify MCP servers are connected
- [ ] Read relevant documentation sections
- [ ] Test with non-critical ticket first