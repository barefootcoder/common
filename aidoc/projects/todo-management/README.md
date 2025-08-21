# Todo Management Project

This project contains automated workflows for managing tickets, tasks, and time tracking across multiple systems.

## Project Overview

This system automates the process of taking on new work tickets by coordinating updates across:
- Jira ticket management
- Google Sheets task tracking (GTD-based system)
- Triage reporting (Markdown files)
- Time tracking system

The primary workflow handles the complete onboarding process for new tickets, eliminating manual copy-paste operations and ensuring consistent data entry across all systems.

## Key Documentation

### Core Workflows
- **[ticket-onboarding-workflow.md](ticket-onboarding-workflow.md)**: Complete automated process for taking on new tickets
  - Jira assignment and field updates
  - Google Sheets job and task creation
  - Triage file updates for meeting reports
  - Timer system initialization
  - Subtask breakdown handling

### System Operations
- **[jira-operations.md](jira-operations.md)**: Jira ticket management using Atlassian MCP server
- **[google-sheets-operations.md](google-sheets-operations.md)**: Todo spreadsheet operations (jobs, tasks, GTD system)
- **[file-management.md](file-management.md)**: Triage reporting and timer file management

### Configuration
- **private/config.md**: System configuration, IDs, and sensitive information
- **private/troubleshooting.md**: Known issues and debugging information

## ⚠️ Critical Rules - READ FIRST

1. **DATE HANDLING**: This system uses time-shifted dates for after-midnight work
   - Check current time with `date '+%H:%M'`
   - If before 6 AM, use YESTERDAY's date
   - If after 6 AM, use TODAY's date
   - This affects: Added dates, Due dates, all date fields

2. **Never assume dates** - always calculate based on current time
3. **Common mistakes**: See [common-pitfalls.md](common-pitfalls.md) for detailed list

## Prerequisites

- Atlassian MCP server configured for Jira access
- Google Sheets MCP server configured
- Access to triage and timer files
- Claude Code environment with appropriate file permissions

## Quick Start

For onboarding a new ticket, see the [ticket-onboarding-workflow.md](ticket-onboarding-workflow.md) process. The workflow can be triggered with a command like:

```
Read instructions from ~/common/projects/todo-management/ticket-onboarding-workflow.md and onboard ticket CLASS-XXX
```

## Current Status

**Fully Automated**: Steps 1-3, 5-6 (Jira assignment, Google Sheets, file management)
**Manual Intervention Required**: Step 4 checklist creation due to Gebsun plugin limitations
**Overall**: ~90% automation achieved with robust sanity checking and error handling

## Future Enhancements

This system is designed to be extensible for additional todo management processes, time tracking workflows, and reporting automation.

**Priority improvements**:
- Research alternative checklist solutions for full automation
- Add support for multiple project tracking systems
- Implement automated testing and validation workflows