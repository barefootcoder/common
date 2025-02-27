# Claude Helper Guide for Common Repository

## Testing & Development
- Run Perl tests: `prove -l perl/myperl/t/<test_file>.t`
- Run specific test: `perl -Ilib -Iperl perl/myperl/t/<test_file>.t`
- Verify tabs: `bin/checktabs <file_path>`
- Install dependencies: `bin/myperl-cpm`

## Code Style Guidelines
- **Languages**: Primarily Perl and Bash
- **Perl Style**:
  - Use modern Perl features (5.14+)
  - Classes: CamelCase (Moose/CLASS)
  - Functions/variables: snake_case
  - Constants: ALL_CAPS
  - Error handling: die/fatal or try/catch (Syntax::Keyword::Try)
  - Imports: group by purpose, core first
- **Bash Style**:
  - Define $ME for error reporting
  - Use functions for code organization
  - Document options with usage()
  - Use snake_case for functions/variables

## Repository Organization
- `/bin/`: Executable scripts
- `/perl/`: Perl modules (myperl framework)
- `/rc/`: Configuration files
- `/local/`: Machine-specific code

Follow existing patterns when adding new code.