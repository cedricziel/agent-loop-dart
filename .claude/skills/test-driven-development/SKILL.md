---
name: test-driven-development
description: Force test-driven development for code changes. Use when implementing a feature, fixing a bug, changing behavior, refactoring logic, or when the user asks for TDD, test-first, red-green-refactor, or to write a failing test before code. Require the agent to start with the smallest failing automated test or executable characterization check, then make the minimum production change to pass, rerun focused verification, and only then broaden validation.
user-invocable: false
---

# Test-Driven Development

This skill turns TDD into a hard gate for code changes. When active, the agent must not change production code until it has created or updated the smallest failing automated check that captures the intended behavior.

In repos with weak or missing test coverage, do not skip TDD. Instead, create the smallest executable seam possible first: a unit test, characterization test, smoke test, or narrowly scoped harness that fails before the code change.

## Core Rules

1. Start by identifying the narrowest behavior change.
2. Write or update a test that fails for that behavior before touching production code.
3. Run the smallest command that proves the test is failing.
4. Make the minimum production change required to pass.
5. Re-run the focused test until it passes.
6. Refactor only while keeping the test suite green.
7. Run broader verification that matches repo conventions before finishing.

## Hard Gate

- Do not implement behavior first and “add tests after”.
- Do not bundle unrelated production changes into the same red-green cycle.
- Do not weaken assertions just to make the test pass.
- Do not skip the failing-test step unless an automated check is truly impossible.

If an automated failing check is truly impossible, stop and explain exactly why. Then add the closest executable characterization coverage available before making the change.

## Repo Workflow

For this repository, prefer this loop:

1. Add or update the smallest test or harness for the target behavior.
2. Run the narrowest command that demonstrates failure.
3. Change production code.
4. Re-run the narrow command until it passes.
5. Finish with repository verification commands:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart run packages/agent_loop_cli/bin/agent_loop.dart "what time is it?"
```

If the repository does not yet have a test suite for the affected area, add the smallest one that makes the behavior executable instead of silently falling back to code-first development.

## Examples

### Bug fix

Bad sequence:

1. Edit `agent_loop.dart`
2. Run analyzer
3. Add a test later

Required sequence:

1. Add or update a failing test for the bug.
2. Run that test and confirm failure.
3. Edit `agent_loop.dart` minimally.
4. Re-run the same test until green.
5. Run broader repo verification.

### No test harness exists yet

Bad response:

```text
There are no tests here, so I implemented the feature directly.
```

Required response:

```text
There is no existing focused test harness for this behavior, so I will add the smallest executable regression check first and make it fail before changing production code.
```

## Best Practices

- Keep each red-green-refactor loop scoped to one behavior.
- Prefer focused tests over broad end-to-end coverage for the first failing check.
- When fixing a regression, write the regression test to reproduce the current bug, not the hoped-for implementation.
- State explicitly which command demonstrated failure and which command demonstrated success.
- If you must add a harness before the real test, keep that harness minimal and leave the repo in a more testable state than you found it.
