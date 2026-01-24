---
name: x-convert-to-skill
description: Convert an existing instruction file (scenario, agent, command) into a proper Claude Code skill
argument-hint: <path-to-instruction-file>
model: opus
context: fork
disable-model-invocation: true
allowed-tools: Bash(*), Read, Write, Edit, Glob, Grep, mcp__google-sheets__*
---

# Convert Instruction File to Skill

You are converting an existing instruction file into a proper Claude Code skill. This is a multi-step process that involves analysis, user consultation, rewriting, and file organization.

**Input**: $ARGUMENTS (path to instruction file to convert)

If no path provided, ask the user which file to convert.

## Phase 1: Analysis

1. **Read the source file** and understand its purpose
2. **Identify dependencies**:
   - MCP servers used (especially `atlassian-remote` → convert to `jira` CLI)
   - External files referenced (workflows, configs, templates)
   - CLI tools required
3. **Detect private data references**:
   - Account IDs, email addresses, API keys
   - Hardcoded paths to private config files
   - Any PII that shouldn't be in a public repo
4. **Identify script candidates**:
   - Repeated bash command patterns
   - Complex multi-step CLI operations
   - Operations that fetch private config values

## Phase 2: User Consultation

Ask the user these questions (use AskUserQuestion tool):

1. **Skill name**: Suggest a name based on the source file. Recommend `/x-` prefix for custom skills to avoid namespace collisions with built-in commands.

2. **Scope**: User-scope (`~/.claude/skills/`) or project-scope (`.claude/skills/`)?
   - User-scope: Available in all projects
   - Project-scope: Only available in current project

3. **Invocation mode**: Should it be explicitly invoked only, or can Claude auto-trigger it?
   - Explicit only (`disable-model-invocation: true`): For commands like `/commit`, `/deploy`
   - Auto-trigger allowed: For contextual skills Claude might invoke when relevant

4. **Model preference**: Default is Opus in forked context. Ask if they want different.

5. **Private config handling**: If private data detected, confirm approach:
   - Create config-retrieval scripts that read from external private file
   - Reference private config location in instructions (user provides path)

## Phase 3: Skill Structure Design

Based on analysis, design the skill structure:

```
~/.claude/skills/<skill-name>/
├── SKILL.md           # Main instructions (required)
├── scripts/           # Helper scripts (if needed)
│   ├── <tool>-wrapper
│   └── config-getter
└── reference.md       # Detailed docs (if instructions too long)
```

**Frontmatter template**:
```yaml
---
name: <skill-name>
description: <one-line description>
argument-hint: <hint for arguments, if any>
model: opus
context: fork
disable-model-invocation: true  # or false
allowed-tools: <tool patterns>
---
```

## Phase 4: Content Rewriting

**IMPORTANT**: Modern models (Sonnet 4, Opus 4.5) are highly capable. Rewrite instructions to be concise and trust the model's knowledge. Don't teach basic skills.

### Rewriting Principles

1. **Assume competence**: The model knows how to use git, read files, write code, etc. Don't include step-by-step tutorials for common operations. Focus on what's *specific to this skill*.

2. **State conventions, not procedures**: Instead of "Run git status, then run git diff, then stage files with git add", just specify the commit message format and constraints. The model knows git workflow.

3. **Constraints over instructions**: Emphasize what NOT to do (safety rails) more than what to do. The model will figure out the "how" - it needs guardrails on the "what".

4. **Be terse**: If the original has 80 lines of instructions, aim for 20-30. Cut everything the model already knows. Keep only: conventions, constraints, edge cases, project-specific requirements.

5. **Remove redundant warnings**: Don't repeat "DO NOT do X" multiple times. State it once clearly.

### Structural Goals

- Use headers to organize, not to pad
- Prefer bullet points over paragraphs
- One clear section per concern (scope, format, constraints)

### Technical Conversions

**Replace MCP with CLI**: If using `atlassian-remote` MCP, convert to `jira` CLI:
   - `mcp__atlassian-remote__getJiraIssue` → `jira issue view --raw | jq`
   - `mcp__atlassian-remote__editJiraIssue` → `jira issue edit --custom`
   - `mcp__atlassian-remote__transitionJiraIssue` → `jira issue move`
   - Attachments: `curl -n -L` with `.netrc` auth
5. **Extract scripts**: Create standalone scripts for complex operations
6. **Security scrub**: Ensure NO PII, account IDs, emails, or secrets in skill files

## Phase 5: Script Creation

For each identified script:

1. Use consistent patterns:
   ```bash
   #!/usr/bin/env bash
   ME=$(basename "$0")
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   ```

2. For config retrieval, reference external private config:
   ```bash
   CONFIG_FILE="$HOME/path/to/private/config.md"
   ```

3. Include usage help and error handling

4. Make scripts executable

## Phase 6: File Operations

1. **Create skill directory** at chosen scope
2. **Write SKILL.md** with frontmatter and rewritten instructions
3. **Write scripts** to `scripts/` subdirectory
4. **Move/copy supporting files** if needed
5. **Remove or archive** the original instruction file (ask user preference)

## Phase 7: Validation

1. **Security review**: Grep all created files for potential PII patterns:
   - Email addresses: `@.*\.(com|org|net|edu)`
   - UUIDs: `[0-9a-f]{8}-[0-9a-f]{4}-`
   - Account IDs: Long alphanumeric strings
   - API keys/tokens

2. **Test scripts**: Run each script with `--help` or basic invocation

3. **Verify structure**: `ls -la` the skill directory

## Phase 8: Git Integration

1. **Stage new files**: `git add` the skill directory
2. **Stage removal**: If original file was removed, stage that too
3. **Offer to commit**: Ask user if they want to commit now
4. **Use /x-commit**: If yes, invoke the commit skill

## Reference: Claude Code Skill Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name (defaults to directory name) |
| `description` | Recommended | What skill does; Claude uses this for auto-trigger |
| `argument-hint` | No | Hint for autocomplete (e.g., `[ticket-number]`) |
| `model` | No | Override model (e.g., `opus`, `sonnet`) |
| `context` | No | Set to `fork` for isolated subagent |
| `disable-model-invocation` | No | `true` prevents auto-trigger |
| `allowed-tools` | No | Pre-authorize tools (e.g., `Bash(jira:*)`) |
| `user-invocable` | No | `false` hides from `/` menu |

## Reference: Jira CLI Equivalents

| MCP Operation | Jira CLI |
|---------------|----------|
| Get issue | `jira issue view TICKET --raw` |
| Get field | `jira issue view TICKET --raw \| jq '.fields.FIELD'` |
| Assign | `jira issue assign TICKET EMAIL` |
| Edit custom field | `jira issue edit TICKET --custom "field=value" --no-input` |
| Transition | `jira issue move TICKET "Status Name"` |
| List transitions | `jira issue move TICKET --help` (no direct equivalent, check API) |
| Download attachment | `curl -n -L -o FILE "ATTACHMENT_URL"` |
| Current user | `jira me` |

## Notes

- If you need to understand Claude Code skill conventions, invoke the `claude-code-guide` agent
- Always ask before making irreversible changes (file deletions)
- The goal is a clean, maintainable skill that's safe to commit to a public repo

[Created and submitted by AI: Claude]
