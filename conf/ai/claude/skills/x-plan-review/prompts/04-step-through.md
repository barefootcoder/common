The plan at {PLAN_PATH} describes a sequence of steps to be executed.

Walk through the plan step by step, in execution order. For each step:
  - State what the system state is when the step begins (what exists, what other processes are reading/writing it).
  - State what changes the step makes.
  - State what the system state is when the step ends.
  - Identify what could go wrong at this step: state corruption, race conditions, ordering issues, dependencies on other steps, etc.

You may read any code, scripts, schemas, or other documentation in the repository containing this plan to verify your reasoning about what each step actually does. Do not edit any files. The only file you should write is your own report.

Save your report to: {REPORT_PATH}

End your report with a "Findings" section: a numbered list of issues or concerns you identified. For each finding, include:
  - One-sentence description
  - Severity (critical / major / minor)
  - Evidence: plan line number(s) and/or code file:line references

If you have no concerns, say so explicitly. Do not pad the list.
