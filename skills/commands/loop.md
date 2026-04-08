---
name: "TDD: Loop"
description: Auto-cycle red -> green -> refactor until tasks.md Phase 2 fully complete
category: TDD Workflow
tags: [tdd, workflow, loop]
---

Auto TDD cycle until `tasks.md` Phase 2 is all `[x]`.

**Steps**

1. **Read current task list**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   cat tdd-specs/$SPEC/tasks.md
   ```

2. **Task completeness scan (run once before loop starts)**

   After reading tasks.md, check for missing scenario types. If any type has 0 tasks, **proactively suggest adding**:

   | Scenario Type | Check | Prompt |
   |--------------|-------|--------|
   | Error response parsing | Tests for "response structure doesn't match expected"? | Missing error response parsing test, suggest adding |
   | Crash/restart recovery | Tests for "state recovery after process restart"? | Missing crash recovery test, suggest adding |
   | External URL/Host changes | Tests for "external resource URL host mismatch"? | Missing URL host rewrite test, suggest adding |
   | Network timeout | Tests for "return False/empty instead of throwing on timeout"? | Missing timeout handling test, suggest adding |
   | **Integration tests (HTTP chain)** | **tasks.md has integration test tasks covering key endpoint request -> response -> DB write chain?** | Missing integration test tasks, suggest adding |

3. **Loop: pick next `[ ]` or `[~]` Phase 2 task**

   **RED phase**:
   - Write one failing test (one at a time, test behavior not mocks)
   - Run immediately to verify failure (using project's actual test command)
   - Confirm failure is "feature not implemented", mark task `[~]`

   **GREEN phase**:
   - Check Issues first (if project has issues directory)
   - Write minimum code to pass
   - Run full suite to confirm no regressions
   - Mark task `[x]`

   **REFACTOR phase**:
   - Eliminate duplication, improve naming
   - Run tests after each change to stay green
   - Follow project's existing conventions

4. **Three-Strike Protocol — stop when same test fails 3 times**

   ```
   WARNING: Three-Strike Protocol

   Test: <test-name>
   Attempt history:
     1. <approach> -> <error>
     2. <approach> -> <error>
     3. <approach> -> <error>

   Issues search: <result>

   Please choose:
     A. Try a different approach (describe your idea)
     B. Split into smaller test granularity
     C. Mark [!] skip, move to next
     D. Need more context
   ```

5. **After Phase 2 all green**:

   Run full test suite (project's actual command).
   Output Phase 2 completion report, prompt to run `/tdd:e2e`.

**Guardrails**
- Step 2 task completeness scan runs at every loop start, cannot skip
- After each RED, must see test failure before continuing
- After each GREEN, must run full suite to confirm no regressions
- Cannot write implementation code without a failing test
