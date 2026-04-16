---
name: "TDD: Loop"
description: Auto-cycle red -> green -> refactor until tasks.md Phase 2 fully complete
category: TDD Workflow
tags: [tdd, workflow, loop, multi-agent]
---

Auto TDD cycle until `tasks.md` Phase 2 is all `[x]`.

**Architecture**: You are the **Reviewer/Coordinator**. If the Agent tool is available (Claude Code), spawn **Coder sub-agents** to write code and review their output independently. If the Agent tool is not available (Cursor, CodeBuddy, Cline, etc.), write code yourself then **switch to Reviewer role** and self-review against the checklist before proceeding.

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

   For each task, execute the **Coder → Reviewer** cycle:

   ---

   **RED phase — Write failing test:**

   Set harness phase:
   ```bash
   SPEC=$(cat tdd-specs/.current); sed -i'' 's/phase=.*/phase=red/' "tdd-specs/$SPEC/.harness"
   ```

   **If Agent tool is available** — spawn a Coder sub-agent:
   ```
   You are a TDD Coder. Your ONLY job is to write a failing test.

   Task: <paste exact task description from tasks.md>
   Test framework: <detected from project, e.g. jest/vitest/pytest>
   Test directory: <detected from project, e.g. test/ or __tests__/>

   Rules:
   - Write exactly ONE test file for this task
   - Test must describe BEHAVIOR, not implementation (test what it does, not how)
   - Test name format: "should <expected behavior> when <condition>"
   - Test must FAIL when run (the feature doesn't exist yet)
   - Do NOT write any implementation code
   - Do NOT modify any files in src/ or lib/ — only test files

   After writing the test, run it using the project's test command.
   Report back: (1) test file path, (2) test name, (3) exact failure message.
   ```

   **If Agent tool is NOT available** — write the test yourself, following the same rules above (one test, behavior-focused, must fail).

   **Reviewer step (mandatory in both modes):**

   Read the test file and check against `templates/review-checklist.md`:
   1. Does it cover the scenario described in the task?
   2. Does it test behavior (input → expected output), not implementation details?
   3. Are boundary/error cases included if the task mentions them?
   4. Is the test name descriptive and readable?
   5. Did the test actually FAIL for the right reason ("feature not implemented", not syntax error)?
   6. Was only ONE test file created (no src/ files modified)?

   Output your review findings:
   ```
   [Review:RED] ✓ covers task scenario | ✓ behavior test | ✓ fails correctly | Issues: <none or list>
   ```

   - **If issues found (Agent mode)**: provide specific feedback and spawn Coder again
   - **If issues found (self mode)**: fix the issues yourself, then re-review
   - **If review passes**: mark task `[~]`, proceed to GREEN

   ---

   **GREEN phase — Write implementation:**

   Set harness phase:
   ```bash
   SPEC=$(cat tdd-specs/.current); sed -i'' 's/phase=.*/phase=green/' "tdd-specs/$SPEC/.harness"
   ```

   **If Agent tool is available** — spawn a Coder sub-agent:
   ```
   You are a TDD Coder. Your ONLY job is to make the failing test pass.

   Failing test file: <path from RED phase>
   Failure message: <exact error from RED phase>

   Rules:
   - Write the MINIMUM code to make this specific test pass
   - Do NOT add features, optimizations, or abstractions beyond what the test requires
   - Do NOT refactor or reorganize existing code — that comes later
   - Do NOT modify any test files
   - Follow the project's existing code conventions and patterns

   After writing code, run the FULL test suite (not just the new test).
   Report back: (1) files created/modified, (2) full test suite result, (3) any regressions.
   ```

   **If Agent tool is NOT available** — write the implementation yourself, following the same rules above (minimum code, no test modifications, run full suite).

   **Reviewer step (mandatory in both modes):**

   Read the implementation code and check:
   1. Is this the minimum code needed to pass? Any premature abstraction or over-engineering?
   2. Were any test files modified? (Not allowed in GREEN)
   3. Did the **full test suite** pass, including all pre-existing tests (no regressions)?
   4. Does the code follow the project's existing conventions?

   Output your review findings:
   ```
   [Review:GREEN] ✓ minimum code | ✓ no test mods | ✓ full suite passes | Issues: <none or list>
   ```

   - **If issues found (Agent mode)**: provide specific feedback and spawn Coder again
   - **If issues found (self mode)**: fix the issues yourself, then re-review
   - **If all tests pass + review passes**: mark task `[x]`, reset strikes, proceed to REFACTOR

   ---

   **REFACTOR phase:**

   Set harness phase:
   ```bash
   SPEC=$(cat tdd-specs/.current); sed -i'' 's/phase=.*/phase=refactor/' "tdd-specs/$SPEC/.harness"
   ```

   Decide if refactoring is needed:
   - Eliminate duplication between new code and existing code
   - Improve naming for clarity
   - Extract shared logic if pattern repeated 3+ times
   - Run tests after each small refactoring change to stay green
   - Follow project's existing conventions

   ---

4. **Three-Strike Protocol — stop when same test fails 3 times**

   The harness automatically tracks strike count. When it reports `THREE-STRIKE PROTOCOL`, stop and present:

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
- **When Agent tool is available**: always use it for coding in RED/GREEN, never write code directly as the main agent
- **When Agent tool is NOT available**: write code yourself, but Reviewer step is still mandatory — you must output `[Review:RED]` and `[Review:GREEN]` lines with checklist results
- After each RED, verify test fails for the right reason before continuing
- After each GREEN, run full suite to confirm no regressions
- If Coder's output (or your own code in self mode) fails review twice in a row, escalate to user before third attempt
