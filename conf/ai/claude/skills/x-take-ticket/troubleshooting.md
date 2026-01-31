# Troubleshooting

Reference documentation for debugging issues with the ticket onboarding workflow.

## Jira Checklist API Limitations

**Issue**: Direct updates to Jira checklist fields fail
**Status**: No API available - requires manual intervention

**Plugin Details**:
- **Plugin**: Gebsun Issue Checklist (`com.gebsun.plugins.jira.issuechecklist`)
- **Vendor**: Gebsun (https://gebsun.com/)
- **Not Smart Checklist**: This is a different plugin than Smart Checklist by Railsware

**Available Fields** (all fail on write):
- `customfield_10032` - "Checklist Content YAML" (textarea)
- `customfield_10034` - "Checklist Text" (textarea)
- `customfield_10036` - "Checklist Progress" (read-only, shows "4/11")
- `customfield_10037` - "Checklist Progress %" (read-only)

**Root Cause**:
- Gebsun plugin does not expose public API documentation
- Plugin uses proprietary storage mechanisms beyond standard custom fields
- Direct field updates are blocked by plugin's internal architecture

**Workaround**: User must create checklist items manually in Jira UI after ticket assignment.

**Alternative Plugins** (if migration is considered):
- Smart Checklist by Railsware (has full API support)
- HeroCoders Checklist (REST API documented at docs.herocoders.com)

---

## Date/Time Issues

### UTC vs Local Time
**Problem**: Dates appear wrong due to UTC/local confusion
**Solution**: Always use local system time. The `ticket-preflight` script handles the 6-hour time-shift logic automatically.

### Time-Shift Logic
Work after midnight (0:00-6:00) counts as "yesterday":
- Before 6 AM → Use yesterday's date
- After 6 AM → Use today's date

The preflight script calculates and displays the correct work date.

---

## Jira Field Issues

### Wrong Custom Field IDs
**Problem**: Updates fail or go to wrong fields
**Solution**: Verify field IDs using jira CLI:
```bash
jira issue view TICKET --raw | jq '.fields | keys'
```

**Known Field IDs**:
- Development Owner: `customfield_10157`
- Product Owner: `customfield_10072`

### Development Owner Update Fails
The `jira-take-ticket` script tries two formats:
1. Direct account ID: `customfield_10157=ACCOUNT_ID`
2. JSON wrapper: `customfield_10157={"accountId":"ACCOUNT_ID"}`

If both fail, set Development Owner manually in Jira UI.

---

## Google Sheets Issues

### Column Misalignment
**Problem**: Data ends up in wrong columns
**Cause**: Writing wrong number of columns
**Solution**:
- RawJobs: Always write exactly 7 columns (A-G)
- RawData: Always write exactly 10 columns (A-J)

### Token Overflow
**Problem**: Massive API response causes failures
**Cause**: Reading entire columns (e.g., `RawData!A:A`)
**Solution**: Use `find_empty_row()` and read specific cell ranges only

### Invalid Range
**Problem**: Sheet operations fail with "invalid range"
**Causes**:
- Sheet name is case-sensitive (use `RawJobs` not `rawjobs`)
- Range format incorrect (use `Sheet!A1:G1` format)

---

## File Edit Issues

### Vim Swap File Detected
**Problem**: Preflight reports unsaved changes
**Solution**:
1. In vim, save with `:w` (no need to exit)
2. Re-run `ticket-preflight` to verify
3. After edits complete, reload in vim with `:e!`

### Stale Swap File
**Problem**: Swap file exists but no vim session
**Solution**: Delete the swap file:
```bash
rm /export/work/ce/.triage.md.swp
rm /export/work/timer/.timer-new.swp
```

### Triage Date in Past
**Problem**: Preflight fails with "triage date is in the past"
**Cause**: The triage file's meeting date has passed
**Solution**: Update triage file with next meeting date before onboarding

### Tab vs Space Issues
**Problem**: File format looks wrong after edit
**Cause**: Spaces used instead of tabs
**Solution**: Ensure Edit tool uses actual tab characters (`\t`), not spaces

---

## Script Issues

### ticket-config Returns Empty
**Problem**: Config values not returned
**Cause**: Config file format changed or file missing
**Solution**: Verify config file exists and format matches expected patterns:
```bash
cat ~/common/aidoc/projects/home-network/private/credentials.md
```

### jira CLI Not Working
**Problem**: jira commands fail
**Possible causes**:
- Not authenticated: Run `jira auth`
- Wrong project context: Ensure ticket has correct prefix (CLASS-XXX)
- Network issues: Check connectivity to Jira instance

---

## Rollback Procedures

### Jira Changes
- Assignment and field changes can be reverted manually in Jira UI
- Status transitions may need to go through intermediate states

### Google Sheets Changes
- Delete the added row in RawJobs and/or RawData
- Note the row numbers for reference before deleting

### File Changes
If files are under version control:
```bash
git checkout -- /export/work/ce/triage.md
git checkout -- /export/work/timer/timer-new
```

Otherwise, manually remove the added entries.
