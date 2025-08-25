# Scenario: Creating New Project Documentation

## Purpose
Create focused project documentation for a specific utility, tool, or functional domain within the common repository. This scenario guides AI agents through collecting project information and organizing it for future development sessions.

## Initial Approach

### 1. Determine Project Name
- If not provided as parameter, ask the user for the project name
- Convert to kebab-case for directory naming (e.g., "Perl Testing" → "perl-testing")
- Create directory: `aidoc/projects/{kebab-case-name}/`

### 2. Collect Project Components
Gather two major components from the user:

#### A. Repository Files
- Ask user to list repo files that belong to this project domain
- Include full paths from repo root (e.g., `perl/myperl/Script.pm`, `bin/t`)
- This constitutes the file mapping for AI agents
- Start with obvious files; expect to grow over time

#### B. Outside Files
- Ask user to list any external files needed for project context
- Copy each file into the `projects/{project-name}/` directory
- Examples: documentation, configuration examples, data samples, notes

### 3. Create Project Structure

#### Required: README.md
Use this template structure:

```markdown
# {Project Name}

## Overview
[Brief description of project domain and purpose]

## Repository Files
### Core Modules
- perl/myperl/[relevant modules]

### Scripts/Binaries
- bin/[relevant scripts]

### Tests
- perl/myperl/t/[relevant test files]

### Configuration
- rc/[relevant config files]
- conf/[relevant configs]

### Local/Machine-Specific
- local/[relevant host-specific files]

### Other
- [other relevant files]

## Key Concepts
[Domain-specific concepts, utilities, or architectural patterns]

## Development Patterns
[Common code patterns, conventions, or approaches for this domain]

## Testing Approach
[How to test changes in this domain]
- Specific test commands (e.g., `t myperl`, `t specific-test.t`)
- Key test files to run
- Environment considerations

## Dependencies
[Required CPAN modules or system dependencies]
- Installation commands (e.g., `bin/myperl-cpm feature-name`)
- Feature groups from cpanfile if applicable

## Troubleshooting
[Common issues and solutions specific to this domain]

[Created and submitted by AI: Claude]
```

#### Optional Additional Files
- `testing-guide.md` - Detailed testing procedures if complex
- `troubleshooting.md` - Extended troubleshooting if needed
- Copied external files with their original names

## Step-by-Step Workflow

### Step 1: Setup
1. Ask for project name if not provided
2. Convert to kebab-case
3. Create `aidoc/projects/{kebab-case-name}/` directory

### Step 2: Gather Information
Ask user for each component separately:

**"Which repository files belong to this project domain?"**
- Start with main files; expect this list to grow
- Organize by type (modules, scripts, tests, configs, etc.)

**"Are there any external files (docs, examples, notes) I should copy into the project directory?"**
- Copy each file into the project directory
- Maintain original filenames

### Step 3: Create Documentation
1. Create `README.md` using the template above
2. Fill in all collected information
3. Add domain-specific sections as needed
4. Include AI attribution footer

### Step 4: Verification
1. Confirm directory structure is correct
2. Verify all external files copied successfully
3. Check README.md contains all required sections
4. Ask user if anything is missing

## Anti-Patterns to Avoid

- **Don't over-engineer**: Start minimal; projects grow organically
- **Don't duplicate existing docs**: Reference existing documentation rather than copying
- **Don't assume file relevance**: Let the user identify which files belong
- **Don't create empty optional files**: Only create additional `.md` files if there's substantial content
- **Don't mix unrelated utilities**: Keep projects focused on a single domain or tool

## Integration Notes

- Projects complement global instructions (`CLAUDE.md`)
- Projects work alongside existing scenarios and summaries
- File mappings help future AI agents focus on relevant code areas
- Utility projects may reference the myperl framework for common functionality

## Common Project Types in Common Repository

Examples of typical projects:
- **Utility Scripts**: Focused on a specific bin/ script and its supporting modules
- **myperl Extensions**: New modules or features for the myperl framework
- **Configuration Management**: Tools for managing rc/ and conf/ files
- **Test Frameworks**: Testing utilities and helpers
- **Host-Specific Tools**: Machine-specific utilities in local/ directories

[Created and submitted by AI: Claude]