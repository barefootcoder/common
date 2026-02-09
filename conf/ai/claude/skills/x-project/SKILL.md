---
name: x-project
description: Load project-specific context from aidoc/projects/ directory
argument-hint: <project-name>
model: sonnet
disable-model-invocation: true
allowed-tools: Bash(*), Read, Glob
---

# Load Project Context

Load project-specific instructions for a named project area.

**Input**: $ARGUMENTS (project name)

## Bundled Script

`scripts/aidoc-locate` - Locates aidoc files/projects in `./aidoc` and `~/common/aidoc`

## Workflow

1. **Locate project**: Run `~/.claude/skills/x-project/scripts/aidoc-locate project $ARGUMENTS`
   - If no argument provided, ask user for project name
   - If not found, run without the name arg to list available projects

2. **Load context**: Read the `README.md` in the returned directory
   - Also read any files the README references (dependencies, related docs)

3. **Confirm ready**: Brief confirmation that project context is loaded

Keep response concise - just confirm what was loaded and wait for the user's specific task.
