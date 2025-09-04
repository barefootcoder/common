---
description: Resume a previous session from a summary file
argument-hint: [summary-name or partial-name]
---

You are being asked to resume a previous Claude session by loading a summary file.

The user has provided a summary identifier: $ARGUMENTS

Your task is to:
1. If no summary name is provided or input is empty, ask the user to specify the summary name or partial name
2. Use the `aidoc-locate` command to find the summary file: `aidoc-locate summary $ARGUMENTS`
3. If the command returns multiple matches, show the user the available options and ask them to be more specific
4. If the command returns no output or an error:
   - Report that the requested summary was not found
   - Use `aidoc-locate summary` (without arguments) to list available summaries
   - Ask the user to specify which summary they want to resume
5. Once a single summary file is located, read the entire file
6. Analyze the summary to understand:
   - What work was previously done
   - What tasks were completed
   - What was left pending or in-progress
   - Any open questions or blockers
7. Based on the summary, create a todo list using the TodoWrite tool that includes:
   - Any explicitly mentioned pending tasks
   - Logical next steps based on what was completed
   - Any issues that need resolution
8. Respond with:
   - A brief recap of what was done in the previous session (1-2 sentences)
   - The current status/state as you understand it
   - What you're ready to continue working on
   - The todo list you've created for tracking progress

Keep your response concise but informative. Focus on actionable next steps rather than detailed history.

Example response format:
"I've loaded the summary for [topic]. Previously, we [brief description of completed work]. 
Current state: [key status points].
Ready to continue with [main focus area].

Created todo list:
- [Task 1]
- [Task 2]
- [etc.]"

Note: Summary files are created to capture session context and allow seamless continuation of work across different Claude sessions. They typically contain completed work, pending tasks, code changes, and important context needed to resume effectively.