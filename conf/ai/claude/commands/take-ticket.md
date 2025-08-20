---
description: Take ownership of a Jira ticket and execute complete onboarding workflow
argument-hint: [ticket-number]
---

You are being asked to take ownership of a Jira ticket and execute the complete ticket onboarding workflow.

⚠️  **CRITICAL: THIS IS ADMINISTRATIVE SETUP ONLY** ⚠️
**DO NOT perform any technical work during onboarding - no code analysis, file modifications, or implementation work. This workflow is purely for ticket tracking and project management setup.**

The user has provided: $ARGUMENTS

Your task is to:
1. **Parse ticket number**: 
   - If input is empty, ask the user for the ticket number
   - If input is just a decimal number (e.g., "123"), prepend "CLASS-" to make "CLASS-123"
   - If input already has a project prefix (e.g., "CLASS-456", "PROJ-789"), use as-is

2. **Execute ADMINISTRATIVE workflow only**: Read the instructions from `~/common/projects/todo-management/ticket-onboarding-workflow.md` and follow the complete onboarding process for the ticket.

3. **Follow all SETUP steps systematically** (no technical work):
   - Jira assignment and development owner field updates
   - Google Sheets job and task creation
   - Optional subtask breakdown (ask user preference)
   - Triage file updates for meeting reports
   - Timer system initialization
   - Handle any manual steps (like Jira checklist creation)

4. **After onboarding completion**: Inform the user that the ticket is now properly set up in all tracking systems and that they can begin technical work separately.

Start by confirming the ticket number you'll be processing, then proceed with the ADMINISTRATIVE workflow systematically.

**Important**: This workflow coordinates updates across Jira, Google Sheets, triage files, and timer files. Follow the sanity checks and error handling specified in the workflow documentation. Do not analyze code, read technical files, or begin implementation during this process.