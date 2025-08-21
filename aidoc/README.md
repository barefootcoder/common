# AI Documentation Directory

This directory contains documentation and instructions specifically designed for AI coding assistants. **These files are not intended for human consumption** (except this README): they are written in a format optimized for AI agents to understand context, follow instructions, and maintain consistency across development sessions.

## File Types (in order of typical usage)

### Scenario Files (`scenario:<kebab-case-descriptor>.md`)

**What it is:** A self-contained instruction file that provides context and guidance for a specific development scenario.

**When to use:** At the beginning of an AI session to set up context for a specific task or workflow. Scenarios are invoked with the `/scenario` command.

**Contains:**
- Step-by-step procedures for common tasks
- Environment setup for specific types of work
- Troubleshooting guides for recurring issues
- Context and background for the task at hand

Example: `scenario:catalyst-server-debugging.md`, `scenario:config-troubleshooting.md`

### Project Directories (`projects/<project-name>/`)

**What it is:** A comprehensive documentation directory for a specific functional domain or area of the codebase.

**When to use:** At the beginning of a session when working on a larger, multi-faceted area of the codebase that requires extensive context. Like scenarios but with broader scope and multiple supporting files.

**Contains:**
- `README.md` with AI instructions tailored to that domain
- File path mappings showing which source files belong to the project
- Project-specific testing, troubleshooting, and development patterns
- Architecture diagrams and domain-specific resources
- Related Jira tickets and business context

Example: `projects/aurora-cluster-launching/`, `projects/web-report/`

### Agent Instructions (`agent:<kebab-case-name>.md`)

**What it is:** Instructions for specialized subagents that operate in a separate context from the main AI session.

**When to use:** During or at the end of a session when you need specialized expertise or want to isolate a complex task. Subagents are invoked through the Task tool and maintain their own context, making them reusable across different scenarios and projects.

**Contains:**
- Prerequisites and validation steps the agent must perform
- Information to be passed from the main session
- The specific role and expertise the agent should adopt
- Scope of work (what's in and out of bounds)
- Working process and methodology

Example: `agent:claude-code-expert.md`, `agent:database-migration-specialist.md`

### Guides Directory (`guides/`)

**What it is:** Shared technical reference documents that provide detailed guidance on specific topics.

**When to use:** Never directly invoked by developers - these are automatically referenced by scenarios, projects, and agents when they need specific technical knowledge. These exist to avoid duplicating complex instructions across multiple files.

**Contains:**
- Navigation strategies for complex files or systems
- Reusable technical patterns and best practices
- Cross-cutting concerns that apply to multiple projects
- Consolidated knowledge that would otherwise be duplicated

Example: `guides/database-config-navigation.md`, `guides/testing-strategies.md`

### Session Summaries (`summary:<kebab-case-descriptor>.md`)

**What it is:** A distilled record of a previous AI session's work and decisions.

**When to use:** When resuming interrupted work, transferring context between different AI models (e.g., Claude to ChatGPT), or switching interfaces (e.g., Claude Code to Claude.ai web). These are often temporary and may be deleted once no longer needed.

**Contains:**
- What was accomplished in the previous session
- Current state of work in progress
- Key decisions made and rationale
- Outstanding issues or blockers
- Next steps or follow-up tasks

Example: `summary:new-db-for-env.md`, `summary:puppet-srcroot-override-investigation.md`

## Best Practices

1. **Start with scenarios or projects** to establish context at the beginning of a session
2. **Use agents** when you need specialized expertise or want to isolate complex tasks
3. **Create summaries** when stopping work that will need to be resumed later
4. **Never reference guides directly** - let scenarios, projects, and agents pull them in as needed

## File Naming Conventions

- All files use Markdown formatting (`.md` extension)
- File names use kebab-case after the type prefix
- Strict naming patterns enable AI agent recognition:
  - `scenario:*.md` - Scenario files
  - `projects/*/` - Project directories
  - `agent:*.md` - Agent instruction files
  - `guides/*.md` - Shared guide files
  - `summary:*.md` - Session summaries

## For Human Developers

This README is the **only file in this directory intended for human reading**. All other files are optimized for AI parsing and instruction-following. For human-readable documentation about the codebase, please refer to the standard documentation in the `doc/` directory.

[Created and submitted by AI: Claude]
