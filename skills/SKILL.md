---
name: tdd-workflow
description: >
  Spec-driven TDD full-cycle skill. Triggered when implementing features:
  Interactive requirements gathering -> UseCase documentation -> Test plan -> TDD implementation (unit -> integration -> E2E) -> Regression verification -> Issue tracking -> Delivery.
  Trigger words: implement, new feature, develop, add, build, I want to, help me build
user-invocable: true
allowed-tools: "Read, Write, Edit, Bash, Glob, Grep, Agent"
metadata:
  version: "2.2.0"
  compatible: "claude-code, codebuddy, cursor"
  hooks: "Installed to .claude/hooks/tdd/ via tdd-workflow init. See .claude/settings.json for registration."
---

# TDD Workflow — Spec-Driven Full-Cycle Development

## Command Overview

| Command | Purpose |
|---------|---------|
| `/tdd:new <name>` | Start new feature, interactive requirements gathering (collects UC framework) |
| `/tdd:ff <name>` | **UseCase-first**: generate usecases.md as primary output, then derive requirements → design → tasks from it |
| `/tdd:change` | **Mid-course requirement change**: analyze impact (UseCase dimension first), sync all 4 docs |
| `/tdd:spec` | Generate/update spec documents individually |
| `/tdd:red` | Write a failing test (RED) |
| `/tdd:green` | Write minimum code to pass (GREEN) |
| `/tdd:refactor` | Refactor, keep all green |
| `/tdd:loop` | Auto-cycle red -> green -> refactor until Phase 2 complete |
| `/tdd:e2e` | **Derive E2E tests from usecases.md paths** (each UC path → one E2E) |
| `/tdd:verify-setup` | Interactive project-level verify config (tdd-specs/.verify/project.md) |
| `/tdd:verify-local` | Interactive personal verify params (tdd-specs/.verify/project.local.md, gitignored) |
| `/tdd:cleanup [env]` | Manual cleanup — run pre_verify_cleanup without running verification itself |
| `/tdd:done` | **4-stage verification**: code checks → local E2E → staging → delivery (includes UC sync to docs/usecases/) |
| `/tdd:notes` | Generate TDD practice notes — record decisions, pitfalls, lessons learned |
| `/tdd:bug` | Bug fix workflow: report -> analyze -> test -> fix -> verify |
| `/tdd:continue <name>` | Resume in-progress feature |
| `/tdd:archive` | Archive completed specs (warns if usecases.md not synced to docs/) |

---

## Project Context Detection

**Before starting any feature, detect project structure to determine test framework and directory conventions:**

```bash
# Detect package management and test framework
ls package.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle 2>/dev/null | head -5
grep -E '"test"|"jest"|"vitest"|"pytest"|"mocha"' package.json 2>/dev/null || true

# Detect source and test directories
ls -d src/ app/ lib/ tests/ test/ spec/ __tests__/ 2>/dev/null || true
```

Adapt all subsequent commands based on detection results:
- **Test commands**: `npm test` / `npx jest` / `npx vitest` / `pytest` / `go test ./...` / `mvn test` / `cargo test` etc.
- **Test directories**: `test/` / `tests/` / `__tests__/` / `spec/` etc.
- **Source directories**: `src/` / `app/` / `lib/` etc.

---

## `/tdd:new <name>`

**Start a new feature.**

1. If no `<name>`, ask user what they want to build; derive kebab-case name from description
2. Create `tdd-specs/<name>/` directory, write to `tdd-specs/.current`
3. Enter requirements gathering (**cannot be skipped**)

**Requirements gathering — all dimensions must be covered:**

| Dimension | Question |
|-----------|----------|
| Target users | Who will use this? (based on actual project roles) |
| Core scenarios | Top 1-3 most important use cases? |
| Input/Output | What does the user input? What does the system return? |
| Error handling | What situations cause failure? Expected error behavior? |
| Scope boundaries | What is explicitly out of scope? |
| Acceptance criteria | How do we know it's done? |

After each round of Q&A, reflect understanding back to user for confirmation. **Scope must be confirmed before proceeding.**

Output after collection:
- Feature name and path: `tdd-specs/<name>/`
- Confirmation summary (user stories + acceptance criteria)
- Prompt: Run `/tdd:ff` to generate all spec docs at once, or `/tdd:spec` for step-by-step

---

## `/tdd:ff <name>`

**Fast-forward: generate requirements -> design -> tasks in one shot.**

1. If `tdd-specs/<name>/` doesn't exist, first run `/tdd:new` requirements gathering
2. **Step 1: Review known Issues** (if project has issues directory)
   ```bash
   ls docs/issues/*.md 2>/dev/null | grep -v README || echo "No issues directory, skipping"
   grep -rl "<feature-keywords>" docs/issues/ 2>/dev/null || true
   ```
3. **Step 2: Update UseCase docs** (if project has `docs/usecases/`, otherwise skip)
4. **Step 3: Generate `tdd-specs/<name>/requirements.md`**
5. **Step 4: Generate `tdd-specs/<name>/design.md`** (incorporating actual project tech stack)
6. **Step 5: Generate `tdd-specs/<name>/tasks.md`** (using actual project test commands and paths)
7. **Step 6: Test coverage check (mandatory, cannot skip)**

   After generating tasks.md, immediately verify all 3 test layers have tasks. If any layer has 0, **proactively add** before continuing:

   | Layer | Check | Gap-fill direction |
   |-------|-------|-------------------|
   | Unit tests | tasks.md has tasks with "unit test:" prefix | Add pure function unit tests for core business logic |
   | Integration tests | tasks.md has "integration test:" prefix tasks covering key HTTP endpoint chains + DB write verification | Add: `POST /api/xxx` full chain (request -> response -> DB state); concurrency safety; permission boundaries (4xx for unauthorized roles) |
   | E2E | Phase 3 has E2E tasks | Add key user flow end-to-end verification |

8. **Show summary, wait for confirmation**

Output format:
```
OK requirements.md — N requirements, N acceptance criteria
OK design.md       — N modules, N interfaces
OK tasks.md        — Phase 2: N items / Phase 3: N items / Phase 4: N items
Issues reviewed: <related IDs or "none">

Ready! Run /tdd:loop to start TDD implementation.
```

---

## `/tdd:spec`

**Generate or update spec documents individually.** Same as `/tdd:ff` Steps 1-6, but checks existing files and asks whether to overwrite.

---

## `/tdd:red`

**Write a failing test (TDD Red phase).**

1. Pick next `[ ]` Phase 2 task from `tasks.md`
2. Write test file (rules: one test at a time, test behavior not mocks, name describes behavior)
3. Run immediately to verify it actually fails (using project's actual test command)
4. Confirm failure reason is "feature not implemented" not syntax error
5. Mark task as `[~]`

**Failure verification triple-check:**
- The test fails (not errors out)
- Failure message matches expectation
- Failure is due to missing functionality, not typo

---

## `/tdd:green`

**Write minimum code to pass current test (TDD Green phase).**

**Step 0 (mandatory): Check Issues first** (if project has issues tracking)
```bash
grep -rl "<error-keywords>" docs/issues/ 2>/dev/null || echo "No existing records"
```

1. Write only the minimum code to pass the test — no premature abstraction
2. Run tests (using project's actual command)
3. All green (including existing tests, no regressions allowed) to mark complete
4. Mark task as `[x]`

**Three-Strike Protocol — triggered when same test fails 3 times:**
```
WARNING: Three-Strike Protocol

Test: <test-name>
Attempt history:
  1. <approach> -> <error>
  2. <approach> -> <error>
  3. <approach> -> <error>

Issues search result: <found/none>

Please choose:
  A. Try a different approach (describe your idea)
  B. Split into smaller test granularity
  C. Mark [!] skip, move to next
  D. Need more context
```

---

## `/tdd:refactor`

**Refactor (only when all tests are green).**

- Eliminate duplication, improve naming, extract shared logic
- Run tests after each small change
- Follow project's existing conventions (reference lint/style config and issues prevention notes)

---

## `/tdd:loop`

**Auto-cycle until tasks.md Phase 2 is fully complete.**

```
WHILE tasks.md has [ ] or [~] Phase 2 tasks:
  /tdd:red      -> Write failing test
  /tdd:green    -> Implement to pass (with issues lookup)
  /tdd:refactor -> Refactor

  IF same test fails 3 times:
    STOP -> Three-Strike Protocol -> Await decision

IF Phase 2 all green:
  Run full test suite (project's actual command)
  Output: Phase 2 completion report (N tests, Xs elapsed)
  Prompt: Run /tdd:e2e for E2E acceptance
```

**Task completeness scan (runs once at loop start, cannot skip):**

| Scenario Type | Check | Prompt |
|--------------|-------|--------|
| Error response parsing | Tests for "response structure doesn't match expected"? | Missing error response parsing test, suggest adding |
| Crash/restart recovery | Tests for "state recovery after process restart"? | Missing crash recovery test, suggest adding |
| External URL/Host changes | Tests for "external resource URL host mismatch"? | Missing URL host rewrite test, suggest adding |
| Network timeout | Tests for "return False/empty instead of throwing on timeout"? | Missing timeout handling test, suggest adding |
| **Integration tests (HTTP chain)** | **tasks.md has "integration test:" tasks covering key endpoint HTTP request -> response -> DB write chain?** | Missing integration test tasks, suggest adding: key endpoint e2e chain (with DB state verification), concurrency safety, permission boundaries |

---

## `/tdd:e2e`

**Phase 3: E2E acceptance tests.**

Pre-check (based on project's actual service address):
```bash
curl -s http://localhost:<PORT>/health 2>/dev/null || echo "WARNING: Service not running, please start dev server first"
```

1. Detect project's E2E framework (Playwright, Cypress, Selenium, etc.)
2. Add acceptance test cases in project's E2E test directory (following existing test structure)
3. Run E2E tests (using project's actual command)
4. Fix failures (Three-Strike Protocol applies)
5. Update tasks.md Phase 3 status

**E2E Hard Rules:**

### Rule 1: Must cover real network layer
```javascript
// WRONG: Bypasses network layer entirely, API errors invisible
page.evaluate(() => { window.__store__.state.status = 'done' })

// CORRECT: Trigger real user action, let API calls happen
await page.click('[data-testid="submit-btn"]')
await expect(page.locator('[data-testid="success-msg"]')).toBeVisible()
```

### Rule 2: Skipped tests must have documented reasons
```javascript
// WRONG: Silent skip, no tracking
test.skip('env not supported')

// CORRECT: Document skip reason for follow-up
test.skip('Step N: [specific reason], restore after resolution')
```
**If accumulated skips exceed 3, must establish mock/stub environment to resolve — no more skip stacking.**

### Rule 3: Assert results after every key action
### Rule 4: Assert specific values for critical business fields

---

## `/tdd:done`

**Phase 4: Delivery. Every check must pass before continuing.**

0. **Compilation verification** (mandatory for compiled languages: TypeScript, Java, Go, Rust, etc.)
1. **Full unit tests** with coverage (project's actual command) — coverage >= 80% (or project target)
2. **Full regression** (if project has regression scripts)
3. **E2E** (if applicable)
4. **Issue tracking judgment** — must create Issue document if ANY:
   - Bug fix took > 5 minutes
   - Same type of error occurred more than once
   - Fix spans 2+ files
5. **Delivery checklist:**
   ```
   [ ] Compilation clean (if applicable)
   [ ] All tests passing, coverage >= 80% (or project target)
   [ ] Full regression passing (if project has regression scripts)
   [ ] E2E tests passing (if applicable)
   [ ] Feature docs updated (if project has usecases/docs directory)
   [ ] Issues logged (if qualifying bugs found)
   [ ] Environment variable examples synced (if new env vars added)
   [ ] tdd-specs/<name>/tasks.md all [x]
   ```
6. **Output delivery report**
7. Prompt to run `/tdd:notes` to capture practice notes, then `/tdd:archive`

---

## `/tdd:notes`

**Generate TDD practice notes — record the full development story.**

When to use: after `/tdd:done`, or at any point you want to capture the development journey.

1. Read `requirements.md`, `design.md`, `tasks.md` from current spec
2. Scan git history for feature-related commits, reverts, fix iterations
3. Generate `tdd-specs/<name>/tdd-practice-notes.md` covering:
   - **需求背景**: what the user wanted
   - **TDD 流程**: Phase 1-4 record, each behavior chain's RED/GREEN/接入
   - **踩坑记录**: real problems encountered (from git history, not hypothetical)
   - **文件清单**: new/modified files + test coverage numbers
   - **核心经验**: 3-5 actionable lessons learned
4. Cross-check: pitfalls ≥ 1, lessons ≥ 3, file list matches git diff

**Guardrails:**
- Must read spec docs first — don't fabricate from memory
- Pitfalls must reference actual problems (git reverts, fix commits, user reports)
- Lessons must be actionable ("do X" / "avoid Y"), not vague ("testing is important")

---

## `/tdd:bug`

**Bug fix full workflow: traceable from problem description to Issue archive.**

1. **Collect bug info** (symptoms, module, reproduction steps, severity)
2. **Create Issue document** (status: "investigating")
3. **Root cause analysis** — no guessing, find root cause first; check existing issues to avoid duplicate work
4. **Write reproduction test (RED)** — choose test layer based on bug type:
   - Business logic error -> Unit test
   - API error -> Integration test
   - UI/interaction issue -> E2E
5. **Fix code (GREEN)** — minimum code to pass, then full regression
6. **Complete Issue documentation** (root cause, fix, verification steps, prevention measures)
7. **Run E2E verification** (if UI/end-to-end flow involved)

**Three-Strike Protocol applies if reproduction test fails 3 times.**

---

## `/tdd:change`

**Mid-course requirement change flow.**

1. Confirm current spec
2. Collect change description (interactive if not provided)
3. Analyze impact across all 3 spec docs

   Output impact assessment:
   ```
   ## Change Impact Assessment
   ### Affected spec entries
   | Document | Entry | Impact Type | Description |
   ### Affected tasks
   | Task | Current Status | Action Needed |
   ### Risk notes
   - Completed tasks affected: N
   - Estimated additional work: small / medium / large
   ```

4. **Wait for user confirmation** before modifying anything
5. Execute updates (requirements.md, design.md, tasks.md, UseCases if applicable)
   - Completed but affected tasks: revert to `[ ]` with note `<- needs redo due to requirement change`
6. Output change summary

**Guardrail**: If change causes 10+ task reverts, suggest considering a fresh `/tdd:ff`

---

## `/tdd:continue <name>`

**Resume in-progress feature.**

1. Read `tdd-specs/<name>/tasks.md`
2. Find first `[ ]`, `[~]`, or `[!]` task
3. Write to `tdd-specs/.current`, resume from corresponding phase
4. Output recovery summary (completed N/M tasks, current phase, next step)

---

## `/tdd:archive`

**Archive completed specs.**

1. Verify all tasks are `[x]` — if not, stop and prompt to complete `/tdd:done` first
2. Check for `tdd-practice-notes.md` — if missing, prompt to run `/tdd:notes` first (recommend, don't block)
3. Move to `tdd-specs/archive/<YYYY-MM>/`
4. Clear `tdd-specs/.current`

---

## File Structure Convention

```
tdd-specs/
+-- .current                    <- Currently active spec name
+-- <feature-name>/
|   +-- requirements.md         <- Requirements (EARS format)
|   +-- design.md               <- Technical design
|   +-- tasks.md                <- Implementation checklist (live-updated)
|   +-- tdd-practice-notes.md   <- Practice record (generated by /tdd:notes)
+-- archive/
    +-- YYYY-MM/
        +-- <completed-feature>/
```

## Task Status Markers

| Marker | Meaning |
|--------|---------|
| `- [ ]` | Not started |
| `- [~]` | In progress (RED written, GREEN incomplete) |
| `- [x]` | Completed |
| `- [!]` | Blocked (Three-Strike Protocol, awaiting decision) |

## Mandatory Issues Lookup Timing

| Timing | Method |
|--------|--------|
| Before `/tdd:ff` or `/tdd:spec` | Browse project issues directory (if exists) |
| Before each `/tdd:green` | `grep -rl "<error-keywords>" <issues-dir>/` |
| After Three-Strike Protocol triggers | Full-text search + module filter |

## Not Applicable For

- Single-line typo fixes
- Pure documentation/configuration changes
- Simple style adjustments

Use direct `git commit` for these instead.
