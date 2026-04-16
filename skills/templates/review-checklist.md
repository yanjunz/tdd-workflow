# TDD Review Checklist

Reference document for the Reviewer (main agent) when evaluating Coder sub-agent output.

## Test Review (RED phase)

- [ ] Test describes **behavior**, not implementation (tests what it does, not how)
- [ ] Test name is readable: "should `<expected behavior>` when `<condition>`"
- [ ] Test covers the **specific scenario** described in the tasks.md task
- [ ] Boundary values tested (if task mentions limits, ranges, or edge cases)
- [ ] Error cases tested (if task mentions error handling or validation)
- [ ] Test **fails for the right reason** — "feature not implemented" or "function not found", NOT syntax error or import error
- [ ] Only **ONE test file** created per task (no src/ files modified)
- [ ] Test uses the project's existing test patterns and conventions

## Implementation Review (GREEN phase)

- [ ] **Minimum code** to pass the test — no premature abstraction or over-engineering
- [ ] No features added beyond what the failing test requires
- [ ] No test files modified (only src/ files)
- [ ] **Full test suite** passes — including all pre-existing tests (no regressions)
- [ ] Code follows the project's existing conventions (naming, file structure, patterns)
- [ ] No unrelated changes or refactoring (that belongs in REFACTOR phase)

## Specification Review (after /tdd:ff)

- [ ] Every requirement has **testable** acceptance criteria (not vague like "should work well")
- [ ] Every requirement maps to **at least one** Phase 2 task
- [ ] design.md references **actual project files and modules** (not generic placeholders)
- [ ] Each task has **single-responsibility** scope (one test per task)
- [ ] All **3 test layers** covered: unit tests, integration tests, E2E
- [ ] Task descriptions include: test file path, implementation file path, test command

## Bug Fix Review (after /tdd:bug)

- [ ] Reproduction test actually **reproduces the reported bug** (failure message matches symptoms)
- [ ] Fix is **minimal and targeted** at the root cause (no drive-by refactoring)
- [ ] Full regression passes after fix
- [ ] Retrospective completed with root cause category and prevention action
- [ ] At least one prevention action executed immediately
