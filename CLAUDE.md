# Claude Helper Guide for Common Repository

## Testing & Development (for `myperl` subtree)
- Use Test Driven Development (TDD):
  1. Write tests first that verify the expected behavior
  2. Run tests to confirm they fail (validating the tests themselves)
  3. Implement the code to make tests pass
  4. Run tests again to verify implementation
  5. Refactor as needed while keeping tests passing
- Run test suite: `t myperl`
- Run specific unit test: `t perl/myperl/t/<test_file>.t`
- Install dependencies: `bin/myperl-cpm myperl`

## Code Style Guidelines
- **Languages**: Primarily Perl and Bash
- **Perl Style**:
  - Use Allman style
  - Use modern Perl features (5.14+)
  - Classes: CamelCase (Moose/CLASS)
  - Functions/variables: snake_case
  - Constants: ALL_CAPS
  - Error handling: die/fatal or try/catch (Syntax::Keyword::Try)
  - Imports: group by purpose, core first
- **Bash Style**:
  - Use Allman style
  - Define $ME for error reporting
  - Use functions for code organization
  - Document options with usage()
  - Use kebab-case for functions/commands
  - Use snake_case for variables

## Repository Organization
- `/bin/`: Executable scripts
- `/perl/`: Perl modules (myperl framework)
- `/rc/`: Configuration files
- `/local/`: Machine-specific code

Follow existing patterns when adding new code.

## Git Commit Format
When committing changes, use this format:
```
brief summary line (imperative mood, lowercase)

- Bullet point description of key changes
- Use descriptive bullets focusing on "what" and "why"
- Keep lines under 72 characters when possible

🤖 Generated with [Claude Code](https://claude.ai/code) (<model_name>)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Note:** Replace `<model_name>` with the actual Claude model being used (e.g., "Sonnet 4", "Sonnet 4.1", etc.)
