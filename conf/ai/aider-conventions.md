# Policies to Follow When Collaborating on Coding Projects

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

## Workflow Considerations
- Don't commit code until instructed to do so
