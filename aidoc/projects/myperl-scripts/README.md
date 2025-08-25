# myperl Framework

## Overview
The myperl framework is a comprehensive Perl utility library that provides a modern, enhanced Perl environment with automatic imports of common modules, utility functions, and an advanced class system. It serves as the foundation for creating robust Perl scripts and modules with minimal boilerplate.

## Repository Files

### Core Module
- `perl/myperl.pm` - Main framework module providing enhanced Perl environment

### Framework Extensions
- `perl/myperl/Script.pm` - Base class for command-line scripts with option parsing
- `perl/myperl/Pxb.pm` - Process execution builder for safe command execution
- `perl/myperl/Classlet.pm` - Enhanced class system with keywords like `rw`, `via`, `by`
- `perl/myperl/Declare.pm` - Declarative syntax extensions
- `perl/myperl/Template.pm` - Template processing utilities
- `perl/myperl/Menu.pm` - Interactive menu system
- `perl/myperl/Google.pm` - Google API integration utilities

### Tests
- `perl/myperl/t/*.t` - Comprehensive test suite for all myperl functionality
- `perl/myperl/t/Test/myperl.pm` - Test helper module
- `perl/myperl/t/Test/redefine.pm` - Test module for redefine functionality

### Support Scripts
- `bin/t` - Test runner (use `t myperl` to run all myperl tests)
- `bin/myperl-cpm` - Dependency installer using App::cpm

## Key Concepts

### Core Features Provided by `use myperl`
- Automatic imports: strict, warnings, autodie, utf8, feature bundle
- Common modules: List::Util, Scalar::Util, Time::HiRes, Data::Dumper, etc.
- Utility functions: `title_case()`, `round()`, `expand()`, `prompt()`, `confirm()`
- Enhanced debugging with `debuggit()` at multiple verbosity levels
- Path manipulation utilities
- Date/time utilities via Date::Easy integration

### myperl::Script Framework
For creating command-line scripts:
- Automatic option parsing via Getopt::Long
- Built-in help/usage support
- Version handling
- Debug level management
- Proper exit code handling

### myperl::Pxb (Process Execution Builder)
Safe external command execution:
- Fluent interface for building commands
- Automatic shell escaping
- Output capture and streaming
- Error handling

### myperl::Classlet System
Enhanced OOP features:
- `rw` keyword for read/write attributes
- `via` for type coercion
- `by` for validation
- Integrates with Moose/CLASS

## Development Patterns

### Creating a New Script
```perl
#!/usr/bin/env perl
use myperl;
use myperl::Script;

# Script automatically gets:
# - All myperl utilities
# - Option parsing
# - Help system
# - Debug levels
```

### Creating a Script with Options
```perl
use myperl::Script {
    options => [
        'verbose|v' => 'Be more verbose',
        'input=s'   => 'Input file',
        'count=i'   => 'Number of iterations',
    ],
};
```

### Using myperl::Pxb for Safe Command Execution
```perl
my $output = Pxb->new($command)->args(@args)->capture->run;
```

### Extending myperl
New functionality should be added as modules under `perl/myperl/` with corresponding tests in `perl/myperl/t/`.

## Testing Approach

### Running Tests
- **All myperl tests**: `t myperl` (from any directory)
- **Specific test**: `t perl/myperl/t/specific.t`
- **With coverage**: `t --cover myperl`
- **Parallel execution**: `t -j4 myperl`

### Test Organization
- Each module has corresponding test file(s)
- Test files use `perl/myperl/t/Test/myperl.pm` for common test utilities
- Tests should cover both positive and negative cases
- Use Test::More, Test::Fatal, and other standard test modules

## Dependencies

### Core Dependencies (always installed)
- Moose/CLASS for OOP
- Try::Tiny for exception handling
- Path::Class for path manipulation
- Date::Easy for date operations
- Method::Signatures for function signatures

### Optional Features (via cpanfile)
Install with: `bin/myperl-cpm <feature>`
- Various feature groups defined in `/cpanfile`
- Check cpanfile for available feature groups

## Troubleshooting

### Common Issues
- **Module not found**: Run `bin/myperl-cpm myperl` to install dependencies
- **Test failures**: Check Perl version (requires 5.14+)
- **Encoding issues**: myperl automatically enables utf8, ensure files are UTF-8
- **autodie conflicts**: myperl uses autodie; avoid manual error checking on file operations

### Debug Levels
Use `debuggit()` with appropriate levels:
- 0: Fatal errors only
- 1: Warnings
- 2: Info messages
- 3: Debug output
- 4+: Verbose debug

### Best Practices
- Always `use myperl` instead of individual pragmas
- Use myperl::Script for command-line tools
- Leverage myperl::Pxb for external commands
- Write tests for new functionality
- Follow existing code style (Allman bracing, snake_case functions)

[Created and submitted by AI: Claude]