---
name: tdd-workflow
description: >
  Spec-driven TDD full-cycle skill. Triggered when implementing features:
  Interactive requirements gathering -> UseCase documentation -> Test plan -> TDD implementation (unit -> integration -> E2E) -> Regression verification -> Issue tracking -> Delivery.
  Trigger words: implement, new feature, develop, add, build, I want to, help me build
user-invocable: true
allowed-tools: "Read, Write, Edit, Bash, Glob, Grep, Agent, TeamCreate"
metadata:
  version: "3.10.1"
  compatible: "claude-code, codex, cursor, cline, windsurf, codebuddy, github-copilot"
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
| _RED / GREEN / REFACTOR phases_ | Phase markers used inside `/tdd:loop`; not separate slash commands. See "Loop-internal phases" below for the rules each phase enforces. |
| `/tdd:loop` | Auto-cycle red -> green -> refactor until Phase 2 complete |
| `/tdd:e2e` | **Derive E2E tests from usecases.md paths** (each UC path → one E2E) |
| `/tdd:verify-setup` | Interactive project-level verify config (tdd-specs/.verify/project.md) |
| `/tdd:verify-local` | Interactive personal verify params (tdd-specs/.verify/project.local.md, gitignored) |
| `/tdd:cleanup [env]` | Manual cleanup — run pre_verify_cleanup without running verification itself |
| `/tdd:done` | **4-stage verification**: code checks → local E2E → staging → delivery (includes UC sync to `paths.usecases.dir`, default `docs/usecases/`) |
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

# Detect source and test directories (monorepo-aware: check subdirs too)
find . -maxdepth 3 -name "package.json" -not -path "*/node_modules/*" \
  -exec sh -c 'echo "$(dirname {})/src $(dirname {})/lib $(dirname {})/app"' \; 2>/dev/null | \
  xargs -I{} sh -c 'ls -d {} 2>/dev/null' | sort -u | head -10
```

Adapt all subsequent commands based on detection results:
- **Test commands**: `npm test` / `npx jest` / `npx vitest` / `pytest` / `go test ./...` / `mvn test` / `cargo test` etc.
- **Test directories**: `test/` / `tests/` / `__tests__/` / `spec/` etc.
- **Source directories**: **read from `tdd-specs/.verify/project.md` → `paths.src_dirs`** (may be multiple paths for monorepos). Fall back to detection results if not configured.
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
2. **Step 1: Review known Issues** (if project uses issues directory; path from `paths.issues.dir` in `tdd-specs/.verify/project.md`, defaults to `docs/issues`)
   ```bash
   # ISSUES_DIR resolves to paths.issues.dir (default: docs/issues). External-tool mode: skip local scan.
   ls ${ISSUES_DIR}/*.md 2>/dev/null | grep -v README || echo "No issues directory, skipping"
   grep -rl "<feature-keywords>" ${ISSUES_DIR}/ 2>/dev/null || true
   ```
3. **Step 2: Update UseCase docs** (target dir from `paths.usecases.dir`, default `docs/usecases/`; external-tool mode prompts manual sync)
4. **Step 3: Generate `tdd-specs/<name>/requirements.md`**
5. **Step 4: Generate `tdd-specs/<name>/design.md`** (incorporating actual project tech stack)
6. **Step 5: Generate `tdd-specs/<name>/tasks.md`** (using actual project test commands and paths)

   **CRITICAL — Vertical Slice Rule (mandatory):**

   Phase 2 tasks MUST be organized by UC (vertical slice), and each UC MUST include tasks for ALL technical layers it touches:

   | Layer | Include when... | Example tasks |
   |-------|----------------|---------------|
   | Database migration | UC introduces new table/field | `CREATE TABLE`, execute migration to local DB |
   | Backend service | UC has business logic | service unit test + implementation |
   | Backend controller | UC has API endpoint | controller/route test |
   | Frontend page | UC actor is end-user (web/mobile/native app) | page JS/HTML/CSS implementation |
   | Client app | UC involves client-side processing | Python/native test + implementation |

   **FORBIDDEN:** Separating frontend into a standalone "Phase 4". All layers of a UC belong together in Phase 2.

   **Exception:** Pure infrastructure setup (Phase 1: creating directories, Entity skeletons, module registration) is allowed as a separate phase since it's shared across all UCs.

   **Database migration execution rule:** Phase 1 must include actually running the migration on local dev DB (not just writing the SQL file). After migration, run the project's schema dump command if one exists.

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
OK tasks.md        — Phase 1: N items / Phase 2: N items (by UC, all layers) / Phase 3: N E2E items
Issues reviewed: <related IDs or "none">

Ready! Run /tdd:loop to start TDD implementation.
```

---

## `/tdd:spec`

**Generate or update spec documents individually.** Same as `/tdd:ff` Steps 1-6, but checks existing files and asks whether to overwrite.

---

# Loop-internal phases

The three phases below are NOT standalone slash commands. They are **phase markers enforced inside `/tdd:loop`** (and inside `/tdd:bug` when fixing a bug). Users do not invoke `/tdd:red` directly — the loop transitions through these phases automatically for each Phase 2 task.

The rules in each phase are the contract between the loop and the Coder/Reviewer it spawns.

## RED phase

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

## GREEN phase

**Write minimum code to pass current test (TDD Green phase).**

**Step 0 (mandatory): Check Issues first** (if project has issues tracking; path from `paths.issues.dir`)
```bash
grep -rl "<error-keywords>" ${ISSUES_DIR}/ 2>/dev/null || echo "No existing records"
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

## REFACTOR phase

**Refactor (only when all tests are green).**

- Eliminate duplication, improve naming, extract shared logic
- Run tests after each small change
- Follow project's existing conventions (reference lint/style config and issues prevention notes)

---

## `/tdd:loop`

**Auto-cycle until all implementation tasks (Phase 1 + Phase 2) are fully complete.**

### Agent Team Design: Coder + Orchestrator separation

```
Orchestrator (main Claude session)
  ├── Assigns tasks to Coder Agent (subagent_type: general-purpose)
  │     Coder reads: tdd-specs/ + src/ + test/
  │     Coder writes: implementation + unit tests
  │
  ├── Runs tests independently (Orchestrator executes, not Coder)
  │     Independent judgment: green / red / regressed
  │
  └── For large features with parallel-safe UC modules:
        Spawn multiple Coder Agents simultaneously (one per UC module)
        Merge when all complete, run full test suite
```

**When to use parallel Coders:**
- Feature has 2+ independent UC modules (no shared state during implementation)
- Each module has distinct files (no write conflicts)

**When NOT to parallelize:**
- Shared DB schema changes (run Phase 1 migrations sequentially first)
- Dependent business logic (UC-B depends on UC-A's service)

```
WHILE tasks.md has ANY [ ] or [~] task (regardless of Phase):
  IF current task is Phase 1 (infrastructure):
    Execute directly (no RED/GREEN cycle needed for migrations, scaffolding)
    VERIFY then mark [x]
  ELSE (implementation task — any Phase):
    IF task is a "unit test" task:
      RED phase      -> Write failing test
    IF task is an "implement" task:
      GREEN phase    -> Implement to pass (with issues lookup)
    IF task is a frontend page task:
      Write page files directly (js/html/css or framework equivalent)
      VERIFY then mark [x]
    REFACTOR phase  -> Refactor (if applicable)

  IF same test fails 3 times:
    STOP -> Three-Strike Protocol -> Await decision

IF ALL tasks across ALL Phases are [x]:
  Run full test suite (project's actual command)
  Output: completion report (N tests, Xs elapsed)
  Prompt: Run /tdd:e2e for E2E acceptance
```

**Marking [x] Verification Protocol (MANDATORY — cannot bypass):**

Before marking ANY task `[x]`, you MUST verify with evidence:

| Task type | Required evidence before [x] |
|-----------|------------------------------|
| Unit test | Test file exists + test runner shows it passes |
| Implementation | Source file exists + related tests pass |
| Frontend page | All page files exist (framework-appropriate: tsx/vue/svelte/html+js+css) + registered in router/config |
| Database migration | Schema inspection confirms new tables/columns exist |
| Any task | **FORBIDDEN: marking [x] for incomplete work. Use [!] for blocked tasks.** |

If you cannot complete a task, you MUST either:
- Mark `[!]` with a documented blocker reason
- Keep as `[ ]` and ask user for guidance
- NEVER mark `[x]` for unfinished work

**Key behavior:** The loop processes ALL layers within each UC (backend test → backend impl → frontend page) before moving to the next UC. This ensures each UC is fully deliverable when its tasks complete.

**Task completeness scan (runs once at loop start, cannot skip):**

| Scenario Type | Check | Prompt |
|--------------|-------|--------|
| **DB migration executed** | **Phase 1 has migration task AND local DB has the new tables?** | Migration SQL exists but was never executed. Run it now and verify with `SHOW TABLES` or equivalent. |
| **Real DB integration test** | **At least 1 test in tasks.md connects to real DB (not all mocked)?** | All tests use mock repositories. Add at least 1 integration test that writes to real DB and reads back to verify schema correctness. |
| Error response parsing | Tests for "response structure doesn't match expected"? | Missing error response parsing test, suggest adding |
| Crash/restart recovery | Tests for "state recovery after process restart"? | Missing crash recovery test, suggest adding |
| External URL/Host changes | Tests for "external resource URL host mismatch"? | Missing URL host rewrite test, suggest adding |
| Network timeout | Tests for "return False/empty instead of throwing on timeout"? | Missing timeout handling test, suggest adding |
| **Integration tests (HTTP chain)** | **tasks.md has "integration test:" tasks covering key endpoint HTTP request -> response -> DB write chain?** | Missing integration test tasks, suggest adding: key endpoint e2e chain (with DB state verification), concurrency safety, permission boundaries |

**DB Migration Verification Protocol (mandatory when Phase 1 has migration tasks):**

When processing a Phase 1 migration task, the loop MUST:
1. Execute the SQL file against local dev DB
2. Verify tables/columns exist: `SHOW TABLES LIKE '<pattern>'` or equivalent
3. Run the project's schema dump command if one exists
4. Only mark task `[x]` after verification passes

If DB is not running or migration fails → STOP and ask user to fix DB before continuing. Do NOT proceed with mock-only tests and claim "verification passed".

---

## `/tdd:e2e`

**Phase 3: E2E acceptance tests.**

### E2E Type Selection (mandatory first decision)

Before writing any test, classify each target:

- **Type A — User-Flow E2E** (controlled dev/CI env, seedable, 3rd-party mockable):
  follow Hard Rules 1–5 in this file.
- **Type B — Staging Smoke** (real external deps, real credentials, uncontrolled
  data, cannot mock): **MUST read `STAGING_SMOKE.md` (sibling file)** and follow
  its Hard Rules B1–B4 + produce `tdd-specs/<feature>/staging-smoke-design.md`
  with the Negative-Proof Checklist filled in.

If a target involves real upstream dependencies that the dev/CI environment
cannot reach or mock (e.g. an external API only accessible from staging/prod
network, a vendor SDK requiring real credentials, a DB whose schema lives
outside your control), it is Type B by definition. Never write it as a Type A
test with weakened assertions like `status < 500` or `[200, 4xx]` — that
pattern silently passes when the real dependency is fully broken. See
`STAGING_SMOKE.md` Anti-Patterns.

When both types are needed for one feature, produce **two separate test
files** in the project's E2E directory. Do not merge.

### MANDATORY FIRST STEP — Spawn Tester Agent (cannot skip)

**Before writing a single line of test code**, you MUST call the `Agent` tool to spawn a Tester Agent. Writing E2E tests directly as the main agent is FORBIDDEN when the feature has 2+ UCs.

```
REQUIRED:
  Agent(
    subagent_type: "general-purpose",
    prompt: """
      You are an independent Tester. Your ONLY job is to write and run E2E tests
      for the feature described in tdd-specs/<feature>/usecases.md.

      ALLOWED to read:
        - tdd-specs/<feature>/usecases.md          (source of truth for test scenarios)
        - tdd-specs/<feature>/requirements.md      (acceptance criteria)
        - API route files (route definitions only, not service implementations)
        - DB schema files (table structure only)
        - Existing E2E test files (for project structure/helper patterns)
        - tdd-specs/.verify/project.md             (test commands, health check URL)

      FORBIDDEN to read (paths listed in tdd-specs/.verify/project.md → paths.src_dirs):
        - Any implementation code under src_dirs
        - Any unit test files created during Phase 2

      IF you feel the need to read implementation code to understand behavior,
      STOP — that means the spec is incomplete. Report back what is unclear
      instead of reading the implementation.

      STEPS:
        1. Read usecases.md — derive test scenarios (1 per UC path)
        2. Start services if needed (health check from project.md)
        3. Write E2E tests starting from real user entry points:
           - Navigate from home/index page, not direct URL injection
           - No state injection bypassing UI interactions
           - No mocking your own backend endpoints
        4. Run ALL tests. Fix failures (Three-Strike Protocol applies).
        5. Report: N passed / N failed / N skipped (with skip reasons)
    """
  )
```

**Exception — single-agent E2E is allowed only when:**
- Feature has exactly 1 UC with no alternative paths
- In that case, main agent writes tests but MUST commit in writing:
  > "I am writing this test from UC-only perspective. I have not read
  >  any src_dirs implementation files since starting /tdd:e2e."

**Enforcement checklist (Orchestrator runs AFTER Tester Agent reports back):**

| Check | Pass condition |
|-------|---------------|
| Agent tool was called | Tool call log shows Agent invocation |
| Tests start from real entry points | No direct deep-link navigation bypassing home/app entry |
| No bulk skips | Skipped count ≤ 3, each skip has documented reason |
| No src_dirs reads in Tester prompt | Tester did not read implementation files |

If any check fails → mark Phase 3 tasks `[!]` blocked and report to user before continuing.

### Why This Matters

When the Orchestrator writes E2E tests itself (without a separate Tester Agent), it tends to:
- Navigate directly to deep pages, bypassing real app entry flows
- Assume implementation correctness it just wrote (confirmation bias)
- Miss integration gaps that only appear when starting from a real user perspective

The Tester Agent boundary exists precisely to catch these integration gaps.

---

### Tester Agent Information Boundary

```
Tester Agent
  ✅ Can read: tdd-specs/<feature>/usecases.md
  ✅ Can read: tdd-specs/<feature>/requirements.md
  ✅ Can read: API route definitions / interface signatures
  ✅ Can read: DB schema (table structure only)
  ❌ Cannot read: any implementation code (paths from paths.src_dirs in project.md)
  ❌ Cannot read: unit test files written by Coder
```

> **paths.src_dirs** is the authoritative source for "what counts as implementation code".
> It may contain multiple paths for monorepos (e.g. `api/src`, `frontend/src`, `mobile/lib`).
> Do NOT assume implementation lives under `src/` — always check project.md first.

**⚠️ `isolation: "worktree"` does NOT achieve Tester blindness:**

`isolation: "worktree"` prevents write conflicts between parallel agents.
It does NOT prevent reading implementation files — the worktree is a full code copy.
Tester blindness is enforced via **prompt constraints only** (FORBIDDEN list above).

### E2E Mode: Real Stack First

Prefer running E2E against a real running service stack, not mocked responses.

```
REAL mode (default):
  1. Detect service port (use auto-discovery from project config first;
     only ask user if auto-discovery fails after 2 retries)
  2. Verify service stack is running (health check from project.md)
  3. Seed test data
  4. Run E2E — no API response mocking (no route intercepts for your own endpoints)
  5. Assert: UI state + API response + DB state (triple verification)
  6. Teardown test data

MOCK mode (opt-in, requires justification):
  - Acceptable for: 3rd-party payment APIs, SMS, email sends
  - Unacceptable for: your own backend endpoints
  - Each mock must have inline comment: // mocked because: <reason>
  - If accumulated mocks > 3, create a test environment stub instead
```

### Deriving E2E Test Cases from UseCases

```
For each UC in usecases.md:
  Success path    → 1 E2E test (full flow, verify postcondition)
  Each alt path   → 1 E2E test (verify error/boundary handling)

Each test must:
  - Start from real user entry point (home page or app launch)
  - Trigger via actual user action (tap/click/input)
  - Have explicit assertions (not just navigate to page)
  - Record function name in tasks.md (anti fake-checkoff rule)
```

**tasks.md E2E task format:**
```markdown
# CORRECT (function name recorded before checking off)
- [x] 3.1 UC-01 success path — user completes <action>, system shows <result>
      → test_function_name (tests/e2e/flow.spec.ts:L142)

# WRONG (fake checkoff, cannot trace)
- [x] 3.1 UC-01 E2E
```

**Hard Rules:**

### Rule 1: Must cover real network layer

Do not bypass the network layer with state injection or store manipulation.
Trigger real user actions that cause actual API calls.

### Rule 2: Skipped tests must have documented reasons

```
# WRONG: Silent skip
test.skip('env not supported')

# CORRECT: Document reason and reference UC
test.skip('UC-01 alt 4a: DB failure recovery — cannot simulate in local env, covered by unit test: <path>')
```

**If accumulated skips exceed 3, must establish mock/stub environment to resolve — no more skip stacking.**

### Rule 3: Assert results after every key action

### Rule 4: Assert specific values for critical business fields

### Rule 5: Success path must reach the postconditions stated in usecases.md

A "success path" E2E test MUST run all the way to the UC's **postconditions** — not stop at an intermediate step.

**WRONG — test stops before postcondition:**
```
test "order full flow":
  # Steps 1-3: inject uploaded state (OK to bypass file picker via test helpers)
  set_uploaded_state(page, files)
  assert page.data['allUploaded'] == True
  # ← stops here, never calls POST /api/orders
  # Named "full flow" but only covers half the UC
  # DB constraints, order creation logic: completely invisible
```

**CORRECT — must verify the postcondition:**
```
test "order full flow":
  # Steps 1-3: inject uploaded state (bypassing file picker is acceptable)
  set_uploaded_state(page, files)

  # Steps 4-5: proceed to confirmation, trigger the real write API
  navigate_to_preview(page)
  confirm_order(page)   # triggers POST /api/orders with real HTTP call

  # Assert postcondition from usecases.md:
  # "orders record created, status=pending_payment"
  wait_until(page, lambda d: d['orderId'] is not None)
  assert page.data['orderId'] is not None, 'Postcondition: order ID must be returned'
```

**Checklist before marking a success-path E2E as [x]:**
- [ ] Every UC step that triggers a **write operation** (POST/PUT/DELETE) is actually executed (not skipped)
- [ ] At least one **postcondition** from `usecases.md` is asserted (DB record created, status field, returned ID, etc.)
- [ ] Test name accurately reflects actual coverage depth — if it only covers setup steps, name it accordingly, not "full flow"

### Rule 6: Type B targets defer to STAGING_SMOKE.md

Rules 1–5 above govern **Type A** (user-flow E2E in controlled environments).
For any test target that hits real external dependencies which cannot be
mocked or seeded (Type B per the type selection at the top of this section):

- Hard Rules 1–5 are **not sufficient** — Rule 1 ("real network layer") is
  satisfied, but assertion strength rules don't translate (no postcondition,
  no UC path, no seedable data).
- Apply `STAGING_SMOKE.md` Hard Rules B1–B4 instead, and produce the required
  `staging-smoke-design.md` with Negative-Proof Checklist answers before
  marking the task `[x]`.

The Orchestrator enforcement checklist for Phase 3 gains one row when any
Type B test exists in the feature:

| Check | Pass condition |
|-------|---------------|
| Type B design doc | `tdd-specs/<feature>/staging-smoke-design.md` exists with B3 answers filled in |

Missing the design doc → Type B task stays `[!]` until produced.

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
   - **Background**: what the user wanted and why
   - **TDD process**: Phase 1-4 record, each RED/GREEN cycle
   - **Pitfalls**: real problems encountered (from git history, not hypothetical)
   - **File inventory**: new/modified files + test coverage numbers
   - **Key lessons**: 3-5 actionable lessons learned
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
| Before each GREEN phase (inside `/tdd:loop`) | `grep -rl "<error-keywords>" <issues-dir>/` |
| After Three-Strike Protocol triggers | Full-text search + module filter |

## Not Applicable For

- Single-line typo fixes
- Pure documentation/configuration changes
- Simple style adjustments

Use direct `git commit` for these instead.

---

## Post-Delivery Development

After `/tdd:done`, the harness enters `deliver` state. Any source code change after this point must follow these rules to prevent test debt accumulation.

### Scenario A: Bug found during integration testing

Never fix directly — always run `/tdd:bug`:

```
Bug found
  → /tdd:bug (write reproduction test RED → fix code GREEN → log Issue)
  → full regression passes → commit
```

Even for a one-line fix, a reproduction test must come first. Fixing without a test cannot confirm the fix scope or prevent regression.

### Scenario B: Adding functionality after spec delivery

```bash
# 1. Append tasks to tasks.md (annotate with: Post-delivery: <description>)
# 2. Reset harness back to green
sed -i 's/phase=deliver/phase=green/' tdd-specs/<spec>/.harness
# 3. Run normal loop → done flow
```

Modifying implementation code in `deliver` state without appending tests is not allowed.

### Scenario C: Pure style / UX / config changes

May be done directly, but:
- Annotate commit message with `[style]` / `[ux]` / `[config]`
- Run full test suite after the change to confirm no regressions

### `/tdd:done` check: post-delivery change audit

```bash
# Read paths.src_dirs config (fall back to common dirs if not configured)
SRC_DIRS=$(grep -A20 'src_dirs:' tdd-specs/.verify/project.md 2>/dev/null | \
  grep '^\s*-' | sed "s/.*- //;s/['\"]//g" | tr '\n' ' ')
[ -z "$SRC_DIRS" ] && SRC_DIRS="src app lib"

# List source files modified during this spec cycle
git log --oneline --name-only -- $(echo $SRC_DIRS | xargs -n1 printf "'%s/**' ") \
  | grep -v "^[a-f0-9]" | sort -u | head -30
```

Cross-check against tasks.md:
- Every new business method → has unit test coverage
- Every new/modified API endpoint → has E2E test coverage
- Every bug fix during integration → has corresponding Issue record

**Uncovered logic found → stop delivery, add tests, re-run `/tdd:done`.**

### Pre-commit self-check

```
□ Does every new business method have a unit test?
□ Does every new/modified API endpoint have an E2E test?
□ Any external service integrations? → mock/stub tests?
□ Full test suite run (not just single module)?
□ Any bug fixes? → Issue record and reproduction test?
```
