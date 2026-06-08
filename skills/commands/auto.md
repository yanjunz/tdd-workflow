---
name: "TDD: Auto"
description: One-shot full-cycle TDD — chains new → ff → loop → e2e → done with checkpoint confirmations between stages. Add --yolo to skip inter-stage prompts.
category: TDD Workflow
tags: [tdd, workflow, auto, full-cycle]
---

Run the full TDD cycle in one command, with confirmation checkpoints between stages.

**Input**
- `<name>` — feature name (kebab-case) or description; same parsing as `/tdd:new`
- `--yolo` (optional flag) — skip the 4 inter-stage confirmation prompts. **Real failures and the Tester Agent boundary still apply** (see Guardrails).

**Modes**

| Mode | Inter-stage prompts | Three-Strike | Completeness scan | Real failures |
|------|---------------------|--------------|-------------------|---------------|
| Default (semi-auto) | 4 × `AskUserQuestion` | Halt + ask A/B/C/D | Ask user to accept | Always halt |
| `--yolo` | Skipped | Auto-pick C: mark `[!]`, continue | Auto-accept all suggestions | Always halt |

**`.harness yolo=1` persistence**

`--yolo` is a flag at first-turn, but the loop runs over many turns — context can be compacted, the user can type "继续". So `/tdd:auto` writes `yolo=1` into `tdd-specs/<NAME>/.harness` and the `user-prompt-submit.sh` hook injects `| Mode: yolo` into every subsequent prompt. That's how main agent stays aware of yolo across turns.

**When you see `Mode: yolo` in the `[tdd-harness]` line, follow these 3 rules** (in addition to the table above):

1. **No mid-loop checkpoint** — finishing one UC's vertical slice is NOT a stop point. Do **not** write a "本轮 /tdd:loop 完成报告" and ask "commit or continue UC-02?". Just proceed straight to the next UC. Issue a single completion report only when all Phase 1+2 tasks are `[x]`.
2. **Three-Strike → auto-pick C** — when a test fails 3× in a row, mark the task `[!]` with the last failure message as the reason, log it, continue to the next task. Do not present the A/B/C/D dialog.
3. **`/tdd:done` real failures still halt** — coverage gap, compile error, regression red, missing checklist item are NOT bypassable. yolo only suppresses *advisory* stops, never delivery gates.

To exit yolo mid-flow: delete the `yolo=1` line from `.harness` manually, or run `/tdd:continue` (which does not propagate yolo forward).

**Steps**

1. **Parse args & detect resume point**

   ```
   if "--yolo" in args: YOLO=1, NAME = remaining args
   else:                YOLO=0, NAME = args (may be empty)
   ```

   **Resume detection** — scan `tdd-specs/<NAME>/` and pick the first incomplete stage:

   | Project state | Resume from |
   |---|---|
   | No `tdd-specs/<NAME>/` directory | Stage 1 (`/tdd:new`) |
   | `.harness` + `usecases.draft.md` exist, but no `tasks.md` | Stage 2 (`/tdd:ff`) |
   | `tasks.md` has any `[ ]` / `[~]` in Phase 1 or 2 | Stage 3 (`/tdd:loop`) |
   | Phase 1+2 fully done (`[x]` or `[!]`), Phase 3 has any `[ ]` / `[~]` | Stage 4 (`/tdd:e2e`) |
   | All phases done, `.harness` `phase != deliver` | Stage 5 (`/tdd:done`) |
   | All phases done AND `phase=deliver` | Already shipped — suggest `/tdd:notes` then `/tdd:archive`, stop |

   Print resume decision before executing any stage:

   ```
   /tdd:auto: resuming from Stage <N> (/tdd:<command>) — <reason>
   ```

   **`[!]` tasks** count as "user-escalated, not blocking next stage": Stage 3 won't retry them, Stage 4+ proceeds, and the final report surfaces them along with any new ones.

   **`<NAME>` resolution when omitted**: if user runs `/tdd:auto` (no name), check `tdd-specs/.current` first. If set, use that name and resume. If not set, fall through to Stage 1's interactive intake.

   **Persist YOLO to `.harness`** — if `YOLO=1` and `tdd-specs/<NAME>/.harness` already exists (i.e. resume from Stage 2+):

   ```bash
   H="tdd-specs/<NAME>/.harness"
   grep -q '^yolo=' "$H" \
     && sed -i'' 's/^yolo=.*/yolo=1/' "$H" \
     || echo 'yolo=1' >> "$H"
   ```

   If resume from Stage 1 (no `.harness` yet), this write happens at the end of Stage 1 instead.

2. **Stage 1 — delegate to `/tdd:new`** (requirements gathering)

   **Skip if**: `tdd-specs/<NAME>/.harness` already exists (resume detection placed us past Stage 1).

   Run `/tdd:new` exactly as documented (6-dimension intake). **Even in `--yolo` mode**, intake cannot be fully skipped — user input is needed to know what to build. YOLO behavior here:
   - If `<NAME>` is a description (not just a kebab-case name): derive the UC draft from it without round-by-round reflection, show full draft once at the end
   - If `<NAME>` is empty or just a kebab name: still ask the 6-dimension questions — there's no shortcut

   Output: `tdd-specs/<NAME>/.harness` + `usecases.draft.md`

   **Persist YOLO to `.harness`** — if `YOLO=1`:

   ```bash
   echo 'yolo=1' >> "tdd-specs/<NAME>/.harness"
   ```

   **Checkpoint** (skip if `--yolo`):

   ```
   AskUserQuestion:
     "Requirements draft ready (N user stories, N acceptance criteria). Continue?"
     [A] Continue to /tdd:ff
     [B] Edit usecases.draft.md first (stop, resume with /tdd:auto --resume)
     [C] Stop here
   ```

3. **Stage 2 — delegate to `/tdd:ff`** (spec generation)

   **Skip if**: `tdd-specs/<NAME>/tasks.md` already exists (resume detection placed us past Stage 2).

   Run `/tdd:ff` exactly as documented:
   - Step 1 Issues review → Step 2 UseCases → Step 3-5 generate requirements/design/tasks
   - Step 6 mandatory 3-layer test coverage check (unit / integration / E2E) — **cannot skip even in YOLO**

   **Checkpoint** (skip if `--yolo`):

   ```
   AskUserQuestion:
     "Spec docs generated: N requirements / N design modules / Phase 2 = N tasks. Continue?"
     [A] Continue to /tdd:loop
     [B] Review tasks.md first
     [C] Stop here
   ```

4. **Stage 3 — delegate to `/tdd:loop`** (RED → GREEN → REFACTOR)

   **Skip if**: `tasks.md` Phase 1 + Phase 2 are all `[x]` or `[!]` (no `[ ]` / `[~]` left). `[!]` tasks are NOT re-attempted — they were already escalated in a prior run.

   Run `/tdd:loop` exactly as documented (Mode A parallel if host supports, else Mode B sequential).

   **Internal stop handling — `--yolo` flag changes these defaults:**

   | Stop reason | Default mode | YOLO mode |
   |-------------|--------------|-----------|
   | Three-Strike Protocol (same test 3× fail) | Halt + ask A/B/C/D | **Auto-pick C**: mark `[!]` with reason from last failure, continue to next task |
   | Task completeness scan suggestions | Ask user to accept | **Auto-accept all** suggestions, append tasks |
   | Reviewer fails Coder output 2× in a row | Escalate to user | Mark task `[!]` with review feedback, continue |
   | DB migration failure | **Always halt** (real error, no auto-fallback) | **Always halt** |
   | Test command not found / project misconfigured | **Always halt** | **Always halt** |

   On loop exit, collect ALL `[!]` tasks into a summary list (task ID + reason).

   **Checkpoint** (skip if `--yolo`):

   ```
   AskUserQuestion:
     "Loop done. N [x] / N [!] / N [ ]. Blocked: <list of [!] task IDs>. Continue?"
     [A] Continue to /tdd:e2e (carry [!] forward to final report)
     [B] Address [!] first (return to /tdd:loop)
     [C] Stop here
   ```

5. **Stage 4 — Orchestrator spawns Tester directly (do NOT delegate via main agent reading e2e.md)**

   **Skip if**: `tasks.md` Phase 3 (E2E) is all `[x]` or `[!]` (no `[ ]` / `[~]` left).

   **Why Stage 4 is different from Stages 1-3**: Stages 1-3 delegate to their stage commands and let main agent execute the steps. Stage 4 does **NOT**. Empirically (v3.12.x yunyin transcript: 0 Task calls, 73 e2e files self-written, 53 src_dirs reads), main agent reads e2e.md and writes the tests itself, violating the Tester information boundary. Stage 4 instead **fans out a Task call from the Orchestrator** so the Tester runs in its own sub-agent context, with no path for main agent to "just write the tests".

   **Steps:**

   a. Mark phase:
      ```bash
      sed -i '' 's/phase=.*/phase=e2e/' "tdd-specs/$NAME/.harness"
      ```

   b. **Call the Task tool** (this is the main agent's only direct action in Stage 4 — do NOT read e2e.md yourself):

      ```
      Agent(
        subagent_type: "general-purpose",
        isolation: "worktree",   # if host supports it (Claude Code); omit otherwise
        prompt: """
          You are the Tester Agent for /tdd:auto Stage 4 on feature <NAME>.

          1. Read the project-installed e2e.md, e.g.
             .claude/skills/tdd-workflow/commands/e2e.md
             (or .cursor/... / .codex/... per host). Execute its Steps 1-N.

          2. The MANDATORY FIRST STEP self-check at the top of e2e.md asks
             "are you a Task sub-agent?" — YES, you are. Do NOT nest-spawn
             another Tester; you ARE the Tester. Proceed to Steps 1-N.

          3. Information boundary you MUST enforce on yourself:
             ALLOWED:
               - tdd-specs/<NAME>/usecases.md
               - tdd-specs/<NAME>/requirements.md
               - API route definitions / interface signatures (route files only)
               - DB schema files (table structure only)
               - Existing E2E test files (helpers / project structure)
               - tdd-specs/.verify/project.md
             FORBIDDEN (paths from paths.src_dirs in project.md):
               - Any implementation code under src_dirs
               - Any unit test files from Phase 2
             If you feel you must read implementation to understand behavior,
             STOP — the spec is incomplete; report what's unclear instead of
             reading the implementation.

          4. If `.harness` shows `yolo=1`, follow YOLO Mode rules from
             SKILL.md (Three-Strike → mark task [!] and continue, no
             checkpoint per UC, etc.).

          5. Final report MUST contain:
             - <N passed> / <N failed> / <N skipped> (with skip reasons + UC reference)
             - For each failure: test name, error, file:line
             - Files written/modified
             - Explicit line: "I did not read any path under paths.src_dirs"
        """
      )
      ```

   c. When Tester returns, run the **Phase 3 Enforcement Checklist** (Orchestrator side):

      | Check | Pass condition |
      |-------|---------------|
      | Tester was called | Task tool call appears in this turn's log |
      | Skip count ≤ 3 | From Tester report; default mode escalates, yolo marks `[!]` |
      | No src_dirs reads | Tester's "I did not read..." line is present and credible (spot-check one written test if doubtful) |
      | Tests start from real entry points | Spot-check 1 test file Tester wrote |

      Any check failing → mark Phase 3 tasks `[!]` with reason; do not silently pass.

   YOLO-specific behavior:
   - Skip count > 3 → mark `[!]`, continue (don't escalate)
   - Test failures → mark each `[!]` with error, continue (do NOT re-spawn Tester unless user explicitly asks)

   **Checkpoint** (skip if `--yolo`):

   ```
   AskUserQuestion:
     "E2E: N passed / N failed / N skipped. Continue?"
     [A] Continue to /tdd:done
     [B] Fix failures first (re-spawn Tester)
     [C] Stop here
   ```

   Manual `/tdd:e2e` (user invokes it directly without /tdd:auto) still falls back to the e2e.md MANDATORY FIRST STEP self-check — that path is the advisory layer for non-auto flows. Stage 4 here is the structural layer for /tdd:auto.

6. **Stage 5 — delegate to `/tdd:done`** (4-stage delivery verification)

   **Skip if**: `.harness` shows `phase=deliver` (already passed `/tdd:done` in a prior run). In that case, jump directly to the "Suggested next" prompt below — do NOT re-run delivery checks unnecessarily.

   Run `/tdd:done` exactly as documented. **`--yolo` does NOT bypass real failures**:

   | Check | YOLO behavior |
   |-------|---------------|
   | Compilation (TS/Go/Rust/Java) | Halt on error |
   | Full unit tests with coverage | Halt if below threshold |
   | Regression suite | Halt on red |
   | E2E run | Halt on failure |
   | Delivery checklist items | Halt if unmet |

   On any failure: stop, report what's missing, do **NOT** auto-fix.

   On full pass: do NOT auto-chain `/tdd:notes` or `/tdd:archive` — these are user-decision points (notes is reflective; archive is destructive). Just prompt:

   ```
   ✓ /tdd:done passed.
     Suggested next: /tdd:notes (capture practice notes), then /tdd:archive when ready.
   ```

**Final output (after Stage 5 or any earlier stop)**

```
TDD Auto cycle: <NAME>           Mode: <semi-auto | yolo>
  Stage 1 (/tdd:new)   — ✓ done
  Stage 2 (/tdd:ff)    — ✓ N tasks generated
  Stage 3 (/tdd:loop)  — ✓ N [x] / N [!] / N [ ]
  Stage 4 (/tdd:e2e)   — ✓ N passed / N failed / N skipped
  Stage 5 (/tdd:done)  — ✓ passed | ✗ failed: <reason>

Blocked tasks (if any):
  - [!] <task ID> — <reason>

Suggested next:
  - /tdd:notes
  - /tdd:archive
```

**Guardrails**

- `auto.md` is a **thin orchestrator** — each stage MUST delegate to its dedicated command. Do not re-implement stage logic here. If `/tdd:loop` changes its rules, `/tdd:auto` automatically inherits them.
- `--yolo` is **not a kill switch for safety checks**. It bypasses ONLY:
  - 4 inter-stage `AskUserQuestion` prompts
  - Three-Strike interactive choice (auto-picks C: mark `[!]`, continue)
  - Task completeness scan opt-in (auto-accepts)
  - Reviewer 2-strike escalation (marks `[!]`, continues)
- `--yolo` does **NOT** bypass:
  - Real test/compile/coverage failures in `/tdd:done` (always halt)
  - DB migration failures (always halt)
  - Tester Agent boundary in `/tdd:e2e` (always spawned)
  - Initial requirements intake in `/tdd:new` (need user input to know what to build)
- All `[!]` tasks carried through stages MUST appear in the final report — never silently dropped.
- If a stage delegate stops or fails, `/tdd:auto` stops too — do NOT skip ahead to the next stage.
- **Resume is non-destructive**: when an existing `tdd-specs/<NAME>/` is detected, `/tdd:auto` only adds work — it never re-runs `/tdd:new` (would overwrite intake), `/tdd:ff` (would overwrite spec docs), or `/tdd:done` (would re-run gates needlessly). `/tdd:loop` and `/tdd:e2e` only ever pick up `[ ]` / `[~]` tasks, so re-entry is safe.
- `/tdd:continue` is still the right command when the user wants to **manually** resume from a specific phase or inspect state first; `/tdd:auto` resume is for "just keep going" intent.
- For production features, prefer the default semi-auto mode. `--yolo` is intended for throwaway prototypes and exploration, not deliverable work.
