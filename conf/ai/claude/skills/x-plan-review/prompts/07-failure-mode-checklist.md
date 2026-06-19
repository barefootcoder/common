The plan at {PLAN_PATH} describes an implementation effort that changes the state of some system. Evaluate it against this checklist of failure modes common to implementation plans:

  A. Unintended state changes: could the plan accidentally modify,
     delete, or overwrite data, config, files, or other state in ways
     the author didn't intend?
  B. Partial-state / inconsistency: could the system end up in a
     half-applied state where some changes landed but others didn't?
  C. Race conditions / timing: are there steps whose ordering matters,
     where concurrent processes (crons, deploys, users, other automation)
     could interleave badly with the plan's steps?
  D. Coverage gaps: could in-flight, boundary, or edge-case items be
     missed by the plan's enumeration of what to change?
  E. Naming / ID / path conflicts: could renames, drops, aliases, or
     identifier reassignments conflict with each other, or with
     assumptions elsewhere in the system?
  F. Rollback gaps: if something fails mid-execution, can it be rolled
     back, and how cleanly? Which steps are irreversible?
  G. External dependencies: is the plan correct about what other systems
     (services, schedules, hooks, downstream consumers) currently do and
     will do, both during and after execution?

For each category, state whether the plan addresses the risk, and if so how; if not, what gap exists. You may read any code, schemas, scripts, or other documentation in the repository containing this plan to verify. Do not edit any files. The only file you should write is your own report.

Save your report to: {REPORT_PATH}

End your report with a "Findings" section: a numbered list of issues or concerns you identified. For each finding, include:
  - One-sentence description
  - Severity (critical / major / minor)
  - Evidence: plan line number(s) and/or code file:line references

If you have no concerns, say so explicitly. Do not pad the list.
