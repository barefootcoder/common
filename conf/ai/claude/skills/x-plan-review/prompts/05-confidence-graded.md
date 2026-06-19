The plan at {PLAN_PATH} needs review. Read it, read any code/schema/scripts in the surrounding repository as needed to verify its claims, and identify problems with it.

For every finding you report, tag your confidence:
  - HIGH:   I have direct evidence from the plan or code that demonstrates this issue.
  - MEDIUM: This is likely an issue based on patterns or reasonable inference, but I haven't fully verified it.
  - LOW:    I suspect this could be an issue, but the evidence is weak or speculative.

Be honest with your confidence ratings. A LOW-confidence concern framed as "I'm not sure" is more useful than a HIGH-confidence claim that turns out to be wrong.

Do not edit any files. The only file you should write is your own report.

Save your report to: {REPORT_PATH}

End your report with a "Findings" section: a numbered list of issues or concerns you identified. For each finding, include:
  - One-sentence description
  - Severity (critical / major / minor)
  - Confidence (HIGH / MEDIUM / LOW)
  - Evidence: plan line number(s) and/or code file:line references

If you have no concerns, say so explicitly. Do not pad the list.
