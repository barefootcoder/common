# Jira Operations

This document covers Jira ticket management operations using the Atlassian MCP server.

## Overview

The Atlassian MCP server provides comprehensive Jira integration including ticket assignment, field updates, checklist management, and status transitions.

## Key Operations

### Ticket Assignment
```
jira_update_issue(issue_key, fields={"assignee": USER_EMAIL})
```

### Development Owner Field
**Field ID**: `customfield_10157`
**Format**: User object with accountId
```
jira_update_issue(issue_key, fields={
    "customfield_10157": {"accountId": USER_ACCOUNT_ID}
})
```

### Getting Ticket Information
```
jira_get_issue(issue_key, fields="assignee,summary,customfield_10157")
```

## Custom Field Reference

| Field Name | Field ID | Type | Usage |
|------------|----------|------|--------|
| Development Owner | customfield_10157 | User Picker | Set to ticket assignee |
| Product Owner | customfield_10072 | User Picker | Usually different from dev owner |
| Checklist Progress | customfield_10036 | Read-only | Shows "Checklist: X/Y" |
| Checklist Progress % | customfield_10037 | Read-only | Shows percentage complete |
| Checklist Content YAML | customfield_10032 | Textarea | YAML format checklist |
| Checklist Text | customfield_10034 | Textarea | Text format checklist |

## Field ID Discovery

To find custom field IDs for new fields:
```
jira_search_fields(keyword="field_name", limit=10)
```

## Checklist Operations (Known Issues)

### Current Status
- Direct updates to checklist fields (`customfield_10032`, `customfield_10034`) currently fail
- The checklist plugin may require specific API endpoints not exposed through standard field updates
- Alternative approaches needed for programmatic checklist management

### Attempted Solutions
1. **YAML Format** (`customfield_10032`):
   ```yaml
   - name: "Task description"
     checked: false
   ```

2. **Text Format** (`customfield_10034`):
   ```
   - [ ] Task description
   - [x] Completed task
   ```

3. **Markdown in Comments** (not recommended - generates unnecessary notifications)

### Research Needed
- Direct checklist plugin API endpoints
- Authentication requirements for plugin-specific operations
- Alternative MCP server capabilities for checklist management

## User Account Information

See `private/user-config.md` for user account details (email, account ID, display name).

## Common Patterns

### Verify and Update Assignment
```python
# Get current assignment
issue = jira_get_issue(ticket_key, fields="assignee,customfield_10157")

# Update if needed (see private/user-config.md for actual values)
updates = {}
if not issue.assignee or issue.assignee.email != USER_EMAIL:
    updates["assignee"] = USER_EMAIL
    
if not issue.customfield_10157:
    updates["customfield_10157"] = {"accountId": USER_ACCOUNT_ID}

if updates:
    jira_update_issue(ticket_key, fields=updates)
```

### Safe Field Updates
Always verify field IDs and data formats before updating:
1. Use `jira_search_fields()` to confirm field IDs
2. Check existing field values with `jira_get_issue()`
3. Use appropriate data formats (strings, objects, arrays)
4. Handle null/empty values appropriately

## Error Handling

Common error scenarios:
- **Field not found**: Double-check field ID with `jira_search_fields()`
- **Permission denied**: Verify user has edit permissions for the field
- **Invalid data format**: Check field type and required format
- **Required fields missing**: Some field updates may require other fields to be set

## Project Context

**Default Project**: CLASS (Tech Classic Perl)
**Ticket Pattern**: CLASS-XXX where XXX is numeric ID
**Common Issue Types**: Task, Bug, Story, Epic