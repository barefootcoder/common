---
name: x-tdd
description: Enforce strict test-driven development discipline - write failing test first, verify failure, write minimal code, verify pass, refactor
model: opus
---

# Test-Driven Development

You are now operating under strict TDD discipline for the duration of this task.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it. Start over. Don't keep it as "reference," don't adapt it, don't look at it. Implement fresh from the test.

## Red-Green-Refactor Cycle

Every unit of work follows this exact sequence. No shortcuts, no reordering.

### 1. RED — Write One Failing Test

- Test a single behavior
- Use a clear name that describes the expected behavior
- Use real code, not mocks (unless truly unavoidable)
- The test should demonstrate the desired API

### 2. Verify RED — Run the Test, Watch It Fail

**Mandatory. Never skip.**

Confirm:
- The test **fails** (not errors — compilation errors don't count)
- The failure message matches expectations
- It fails because the feature is missing, not because of a typo or setup error

If the test passes immediately, you're testing existing behavior. Fix the test.
If the test errors, fix the error and re-run until it fails correctly.

### 3. GREEN — Write Minimal Code to Pass

Write the simplest code that makes the test pass. Nothing more.

- Don't add features beyond what the test requires
- Don't refactor other code
- Don't add configurability "for later"

### 4. Verify GREEN — Run the Test, Watch It Pass

**Mandatory.**

Confirm:
- The new test passes
- All existing tests still pass
- No warnings or errors in output

If the test fails, fix the code — not the test.
If other tests broke, fix them now before continuing.

### 5. REFACTOR — Clean Up (Optional)

Only after green:
- Remove duplication
- Improve names
- Extract helpers

Keep all tests green throughout. Don't add new behavior during refactoring.

### 6. Repeat

Next failing test for the next behavior.

## Red Flags — Stop and Correct

If any of these occur, acknowledge the violation, delete the offending code, and restart with a failing test:

- Wrote production code before a test
- Test passes on first run (wasn't actually testing new behavior)
- Can't explain why the test failed
- Rationalizing "just this once" or "I'll add tests after"
- Keeping pre-written code "as reference"

## Good Tests

| Quality | Guideline |
|---------|-----------|
| **Minimal** | One behavior per test. "and" in the name? Split it. |
| **Clear** | Name describes the expected behavior |
| **Intent-revealing** | Test demonstrates desired API usage |
| **Real** | Tests real code, not mocks |

## When Stuck

| Problem | Action |
|---------|--------|
| Don't know how to test it | Write the assertion first. Design the API you wish existed. Ask the user. |
| Test is too complicated | The design is too complicated. Simplify the interface. |
| Must mock everything | Code is too coupled. Use dependency injection. |
| Test setup is huge | Extract helpers. Still complex? Simplify the design. |

## Bug Fixes

Every bug fix starts with a failing test that reproduces the bug. The test proves the fix works and prevents regression. Never fix bugs without a test first.

## Completion Checklist

Before declaring work complete, verify:

- Every new function/method has a test
- Every test was observed failing before implementation
- Each failure was for the expected reason (missing feature, not typo)
- Minimal code was written to pass each test
- All tests pass with clean output
- Edge cases and error conditions are covered

If you can't check all boxes, you skipped TDD. Acknowledge it and correct course.
