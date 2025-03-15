# Claude Helper Guide for Common Repository

## Testing & Development (for `myperl` subtree)
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
