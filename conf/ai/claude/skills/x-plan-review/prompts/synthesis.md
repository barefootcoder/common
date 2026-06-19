You are synthesizing the results of a plan review. Eight subagents have read the plan at {PLAN_PATH} under four different review prompts (two runs each). Their reports are in {SUBDIR}/reports/.

Your task is to produce two outputs in one pass:

1. **{SYNTHESIS_PATH}** — detailed cluster-by-cluster synthesis with evidence. For users who want to understand the basis for each finding.

2. **{ACTION_LIST_PATH}** — clean, terse checklist of plan edits. The primary user-facing artifact. Include ONLY items that warrant changes to the plan document itself, written at or below the plan's existing abstraction level.

## Inputs

- Target plan: {PLAN_PATH}
- 8 subagent reports: {SUBDIR}/reports/*.md
- Variant prompt copies (for context): {SUBDIR}/prompts/*.md
- Read access to the entire surrounding repository for verifying report claims

## Guiding principles

**A plan is a high-level document for humans.** It is improved by being concise and readable, NOT by being exhaustive. If the plan is too detailed in spots, the right fix is usually to trim — not to bring everything else up to that level of detail.

**Findings come in two flavors.** Some warrant editing the plan; others are concerns the executor will encounter when they reach the relevant step and don't need to appear in the plan at all. Treat these differently.

**Default toward less:** less detail, fewer bullets, shorter action items. When you could write the action list with N items or N-2 items consolidated, prefer N-2.

## Process

### Step 1 — Read the plan and all 8 reports

Reports are typically 12-40KB each. Read them all before clustering.

### Step 2 — Characterize the plan's abstraction level

In one or two sentences, characterize what kind of document the plan is. Examples:

- "A 3-phase high-level migration overview with prose bullets, occasionally dropping into specific commands."
- "A step-by-step runbook where each bullet is an executable instruction."
- "A design doc with rationale, no execution steps."

Note the **median granularity** of the plan's bullets — most bullets sit at some level (a short phrase? a sentence? a code snippet?). That median is your target. If a few bullets sit notably higher in detail than the rest (e.g. inline SQL when the rest is prose), treat those as **candidates for trimming**, not as the level to match.

This characterization governs Steps 4 and 5.

### Step 3 — Cluster findings

Across all 8 reports, identify unique concerns and cluster duplicates together. (E.g. if 6 reports flag the same race condition, that's one cluster.) For each cluster, note which reports raised it (`<variant>:<run>` pairs) and the severity each variant assigned.

### Step 4 — Verify and double-tag each cluster

For each cluster, verify the cited evidence by reading the actual code or plan lines yourself.

Then assign **two** tags: a **severity** and a **kind**.

**Severity:**

- **REAL-CRITICAL** — demonstrates a serious risk that could block or break execution
- **REAL-MAJOR** — meaningful concern that should be addressed
- **REAL-MINOR** — real but small; an improvement, not a blocker
- **PADDING** — technically true but trivial, out-of-scope, or not actionable
- **FABRICATED** — cited evidence doesn't support the claim, or claim contradicts code
- **UNVERIFIED** — couldn't verify with available info; note why

**Kind:**

- **PLAN-EDIT** — warrants a change to the plan document. Reserved for:
  - The plan literally reproduces something that's wrong (a regex, a SQL statement, a specific file/line ref the plan spells out).
  - A sequencing or ordering problem in the plan.
  - A whole step is missing, ambiguous, or rests on a wrong assumption.
  - A bullet in the plan is more granular than the rest and should be trimmed.
- **IMPL-NOTE** — real concern, but the executor will encounter it naturally when they get to the relevant step. The plan doesn't need to call it out. Examples:
  - Orphan working tables a cleanup step will discover.
  - Specific column types or syntax inside a file the plan doesn't reproduce.
  - File:line references the plan doesn't already call out.
  - Verification mechanics the executor will design at implementation time.

**Prefer IMPL-NOTE over PLAN-EDIT when in doubt.** Padding the plan with edits that don't need to be there is the failure mode this rule exists to prevent. A useful test: would adding this to the plan make the plan *easier* to read for the next human reviewer, or just longer?

### Step 5 — Consolidate

Look at the PLAN-EDIT clusters together. Where multiple clusters point at the same area or concern, **merge them into a single edit**. For example, three findings about stale references to the same table in different files should become one edit ("clean up dangling references elsewhere in the tree"), not three separate edits enumerating files.

The synthesis still lists the original clusters separately (for evidence), but the action list shows the consolidated edit.

### Step 6 — Write the synthesis file

Write to `{SYNTHESIS_PATH}`. Format:

```markdown
# Synthesis: Plan Review of <plan-basename>

[Created and submitted by AI: Claude]

## Method

[Brief paragraph — what you read, what you verified. 3-6 sentences.]

## Plan characterization

[Your one-or-two-sentence characterization from Step 2, plus a note on the plan's median granularity.]

## Findings clusters

### F1. [One-line description]

- **Severity:** REAL-CRITICAL | REAL-MAJOR | REAL-MINOR | PADDING | FABRICATED | UNVERIFIED
- **Kind:** PLAN-EDIT | IMPL-NOTE | (N/A for PADDING/FABRICATED)
- **Raised by:** [list of `<variant>:<run>` pairs with the severity each assigned]
- **Verification:** [what you confirmed against code/plan, with file:line refs]
- **Plan location:** [line numbers in the plan, if applicable]
- **Recommendation:** [for PLAN-EDIT: the edit. For IMPL-NOTE: what the executor should know. For PADDING/FABRICATED: brief note on why it doesn't warrant action.]

[Repeat for each cluster. Order by severity within kind: REAL-CRITICAL PLAN-EDIT first, then REAL-CRITICAL IMPL-NOTE, then REAL-MAJOR PLAN-EDIT, etc. PADDING/FABRICATED/UNVERIFIED last.]

## Honest caveats

[Where you had to make judgment calls; what evidence you couldn't fully verify. 3-6 bullets.]
```

### Step 7 — Write the action list

Write to `{ACTION_LIST_PATH}`. This is the user-facing artifact and the strictest part of your output.

**Inclusion rules:**

- Include ONLY clusters tagged PLAN-EDIT with severity REAL-CRITICAL, REAL-MAJOR, or REAL-MINOR.
- Skip IMPL-NOTE, PADDING, FABRICATED, UNVERIFIED entirely. Those live in synthesis.md.
- Apply Step 5 consolidations — fewer, broader items beat many narrow ones.

**Terseness rules:**

- Each action item is **one short sentence** describing the change.
- **No parentheticals.** No `(because X)` or `(this prevents Y)` or `(note that Z)`. The synthesis has the why.
- **Match or undercut the plan's abstraction level.** If the plan is prose bullets, don't propose SQL snippets. If the plan already has a SQL snippet that's the source of the bug, fix the snippet in place — don't expand it.
- **Recommend trims explicitly.** When a plan bullet is more granular than the plan's median, the right edit may be to *remove* detail, not add it. Write that as "Collapse bullet at line N to remove the SQL snippet" or similar.

**Format:**

```markdown
# Plan Update Checklist: <plan-basename>

[Created and submitted by AI: Claude]

Source: [`plan-review/synthesis.md`](plan-review/synthesis.md).
Each item references a cluster (F<n>) where you can read the evidence
and rationale.

Target plan: [`<plan-basename>`](<plan-basename>)

## How to use this checklist

You are updating the plan in-place.  For each item: read the cluster
in synthesis.md to understand the evidence, make the edit, tick the
box.

**Do NOT add explanations or justifications when porting items into
the plan.**  The plan is a high-level overview for humans;
parenthetical "(so that X)" annotations bloat it without adding
signal.  The action items here are deliberately terse -- match that
terseness in the plan.  If a reader genuinely needs the why, they can
read the synthesis.

If an item has already been addressed out-of-band, note it inline and
move on.

---

## Critical

### [ ] N. <terse title> (F<n>[, F<m>])
- **Where:** plan location (line number(s) or phase)
- **Edit:** one short sentence

[All PLAN-EDIT items with REAL-CRITICAL severity.]

## Major

[Same format. All PLAN-EDIT items with REAL-MAJOR severity.]

## Minor

[Same format. All PLAN-EDIT items with REAL-MINOR severity, including any trim recommendations.]
```

Omit any severity section that has no items (don't leave an empty `## Critical` header).

**If there are no PLAN-EDIT items at any severity** — i.e. the plan is structurally fine, and all real findings are IMPL-NOTEs the executor will handle — the action list says so plainly:

```markdown
# Plan Update Checklist: <plan-basename>

[Created and submitted by AI: Claude]

No plan changes recommended. The review identified concerns, but all
of them are implementation-time notes for the executor rather than
defects in the plan itself. See
[`plan-review/synthesis.md`](plan-review/synthesis.md) for the full
analysis.
```

## Important

- Don't trust report citations blindly. Verify load-bearing claims by reading the actual code or plan lines.
- Be calibrated about severity AND kind. Inflating MINOR to MAJOR, or PLAN-EDIT to where IMPL-NOTE was warranted, both reduce the checklist's signal-to-noise.
- The action list is for someone who wants to improve the plan with minimum bloat. Keep it focused: what's the edit, where to make it. Everything else lives in the synthesis.
- Do not edit any files except the two output files (`{SYNTHESIS_PATH}` and `{ACTION_LIST_PATH}`).
