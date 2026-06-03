# TDD Workflow

Spec-driven TDD full-cycle skill for AI coding assistants. Install slash commands and skill files that drive AI through **requirements → spec docs → red/green/refactor → E2E acceptance → issue tracking → delivery checks** instead of letting it free-style code.

Supports **Claude Code** · **Cursor** · **Cline** · **Windsurf** · **CodeBuddy** · **GitHub Copilot**.

> 中文文档: [README.zh-CN.md](./README.zh-CN.md)

---

## Why

LLMs left to their own devices skip tests, invent fake APIs, and lose track of acceptance criteria. This skill installs a **harness**: every conversation runs through the same TDD pipeline with hooks that block premature implementation, enforce UC coverage, and force evidence-backed delivery.

Concretely, after `tdd-workflow init` your AI assistant can:

- Drive interactive requirement gathering and produce spec documents (`usecases.md`, `requirements.md`, `design.md`, `tasks.md`)
- Run a strict red→green→refactor loop with PreToolUse hooks that **block source edits during RED phase**
- Derive E2E tests from `usecases.md` paths (no hand-waved cases) and enforce browser/device screenshot evidence for UI endpoints
- Track every bug as an issue with reproducer test → fix → verification
- Run a multi-stage delivery check (`/tdd:done`) before declaring a feature done

---

## Quick start

```bash
# In your project root (@latest forces a fresh pull, no local cache)
npx tdd-workflow@latest init

# Then in your AI assistant (Claude Code, Cursor, etc.):
/tdd:new        # interactive requirement gathering
/tdd:ff         # generate spec docs (usecases / requirements / design / tasks)
/tdd:loop       # run TDD red→green→refactor across all tasks
/tdd:e2e        # derive E2E tests from usecases.md
/tdd:done       # multi-stage delivery checklist

# Or in one shot (semi-auto, with checkpoints between stages):
/tdd:auto <name>            # chains all 5 stages, asks once between each
/tdd:auto <name> --yolo     # skip inter-stage prompts (real failures still halt)
```

30 seconds to inject the workflow into your project.

---

## CLI

### `tdd-workflow init`

```bash
tdd-workflow init [options]
```

| Option | Description | Default |
|---|---|---|
| `--tools <tools>` | Comma-separated tool IDs (skip interactive selection) | auto-detect |
| `--delivery <mode>` | Install mode: `skills`, `commands`, or `both` | `both` |
| `--force` | Overwrite existing files | `false` |

What it installs (per detected tool):

| Type | Path |
|---|---|
| Skill doc | `.{tool}/skills/tdd-workflow/SKILL.md` |
| Spec templates | `.{tool}/skills/tdd-workflow/templates/` |
| Slash commands (13) | `.{tool}/commands/tdd/` |
| Hooks (Claude Code only) | `.claude/hooks/tdd/` + merged into `.claude/settings.json` |

Also creates a `tdd-specs/` directory for generated spec files.

### `tdd-workflow update`

Detects installed tools and force-updates all files to the latest version.

```bash
tdd-workflow update
tdd-workflow update --delivery commands   # only refresh slash commands
```

---

## Slash commands

| Command | Purpose |
|---|---|
| `/tdd:auto <name> [--yolo]` | **One-shot full cycle** — chains `new → ff → loop → e2e → done` with 4 inter-stage checkpoints. `--yolo` skips checkpoints. See [Full-cycle command](#full-cycle-command--tddauto) below for what `--yolo` cannot bypass. |
| `/tdd:new` | Interactive requirement gathering, scoping, and clarification |
| `/tdd:ff` | Fast-forward: generate `usecases.md` / `requirements.md` / `design.md` / `tasks.md` |
| `/tdd:change` | Change Impact Assessment for spec edits to in-flight features |
| `/tdd:loop` | Run TDD loop (red→green→refactor) over `tasks.md` with Orchestrator + Coder agents |
| `/tdd:e2e` | Derive E2E tests from `usecases.md` paths (per-endpoint, with screenshot evidence) |
| `/tdd:bug` | Track bug as issue + reproducer test → fix → verification |
| `/tdd:notes` | Record practice notes after a feature ships |
| `/tdd:retro` | 5-why analysis on TDD process failures, fix skills/principles |
| `/tdd:verify-setup` | Configure project-level verification (commands, endpoints, src_dirs) |
| `/tdd:verify-local` | Stage 2 manual verification with `manual_flows` |
| `/tdd:done` | Multi-stage delivery checklist (typecheck → tests → coverage → E2E → manual) |
| `/tdd:cleanup` | Cleanup checklist (logs, dead code, TODOs) before delivery |
| `/tdd:archive` | Archive a completed feature spec |
| `/tdd:continue` | Resume in-progress work after `/clear` or new session |

### Full-cycle command — `/tdd:auto`

`/tdd:auto` is a **thin orchestrator** — it doesn't re-implement TDD logic, it just delegates to the 5 stage commands in order. **If the project is already partway through, it auto-detects where to resume** — it never re-runs completed stages or overwrites existing spec docs.

**Resume detection** — at startup `/tdd:auto` scans `tdd-specs/<NAME>/` and picks the first incomplete stage:

| Project state | Resume from |
|---|---|
| No `tdd-specs/<NAME>/` directory | Stage 1 (`/tdd:new`) |
| `.harness` + `usecases.draft.md` exist, no `tasks.md` | Stage 2 (`/tdd:ff`) |
| `tasks.md` has any `[ ]` / `[~]` in Phase 1 or 2 | Stage 3 (`/tdd:loop`) |
| Phase 1+2 fully done (`[x]` or `[!]`), Phase 3 has any `[ ]` / `[~]` | Stage 4 (`/tdd:e2e`) |
| All phases done, `.harness` `phase != deliver` | Stage 5 (`/tdd:done`) |
| All phases done AND `phase=deliver` | Already shipped — suggest `/tdd:notes` / `/tdd:archive`, stop |

`[!]` tasks are **not auto-retried** — they were already escalated to the user. Stage 3 skips them and the final report still surfaces them. To redo them manually, edit them back to `[ ]` or run `/tdd:loop` directly.

`/tdd:continue` remains the right tool when you want to **manually** resume from a specific phase or inspect state first; `/tdd:auto` resume is for "just keep going" intent.

### Modes

| Mode | Inter-stage prompts | Three-Strike | Completeness scan | Reviewer 2-strike |
|---|---|---|---|---|
| Default (semi-auto) | 4 × `AskUserQuestion` between stages | Halt + ask A/B/C/D | Ask user to accept | Escalate to user |
| `--yolo` | Skipped | **Auto-pick C**: mark `[!]`, log reason, continue | **Auto-accept** all suggestions | Mark task `[!]`, continue |

**`--yolo` does NOT bypass** (these always halt the cycle, even in YOLO):

| Stop reason | Why it's not bypassable |
|---|---|
| Real test failures, compile errors, coverage gap in `/tdd:done` | These are the actual delivery gates — bypassing them would let broken code ship |
| DB migration failure during `/tdd:loop` | Real environment error; "skip and continue" silently drops the schema |
| Tester Agent boundary in `/tdd:e2e` | The whole point of the boundary is to catch the bias of "the writer also writes the test"; YOLO cannot remove it |
| Initial requirements intake in `/tdd:new` | If `<name>` is just a kebab-case name, the 6-dimension Q&A still runs — there's no shortcut for "knowing what to build" |
| Test command not found / project misconfigured | Real config error, not a process choice |

**What gets carried forward as `[!]` blocked tasks** in YOLO mode (these surface in the final report, never silently dropped):
- Tasks where Three-Strike triggered (with last failure reason)
- Tasks where Reviewer rejected Coder output 2× in a row (with feedback)
- Phase 3 E2E tasks where Tester reported >3 skips

**When to use which:**
- Default (semi-auto) — **recommended for production features**. The 4 prompts are 4 chances to catch a misaligned spec or wrong direction before it cascades.
- `--yolo` — throwaway prototypes, exploration, or replaying a feature you've already specced once. Not recommended for delivery work.

---

## Multi-Agent architecture (v3.0+)

```
Orchestrator (main agent)
  │  reads tasks.md → splits work → schedules → final review
  │
  ├── spawn Coder Agent ──→ only knows the current task description
  │   └── writes tests (RED) / implementation (GREEN) / refactors
  │   └── parallel UCs each get their own Coder (isolation:worktree)
  │
  ├── Orchestrator reviews Coder output:
  │   ✗ fail → specific feedback to Coder, retry (max 2)
  │   ✓ pass → mark [x], next task
  │   2 consecutive fails → escalate to user
  │
  └── spawn Tester Agent (/tdd:e2e)
      └── reads only usecases.md + spec, NOT implementation code
          → information isolation: tests derived from user perspective
          → real service stack first, mocks require justification
```

**Core principles:**

- **Coder doesn't know the review criteria** — those live only in the Orchestrator's `templates/review-checklist.md`
- **Tester doesn't see implementation details** — prevents tests from being shaped by what the code happens to do
- **Physical isolation** — `isolation:worktree` keeps parallel Coders from polluting each other

---

## UseCase-First workflow

E2E tests are **not invented from `tasks.md` Phase 3**. They are **derived from `usecases.md`** — every UC's main path and every critical alternate path becomes one E2E test, named `UC-<N>: <path>` so failures trace straight back to the spec.

```
usecases.md
  UC-01 User submits comment
    Main path → E2E "UC-01: success path"
    Alt 3a (empty content)  → E2E "UC-01: empty content validation"
    Alt 3b (over length limit) → E2E "UC-01: length validation"
    Alt 4a (DB failure)        → unit test (internal failure, not E2E-suitable)
```

The `/tdd:e2e` command auto-derives the test list and asks for confirmation before writing.

---

## Per-endpoint E2E (v3.4+)

`tdd-specs/.verify/project.md` declares each endpoint your project ships:

```yaml
endpoints:
  backend:
    type: api          # api | browser | device
    framework: <project's choice>
    test_dir: <path>
    test_cmd: <command>
    readiness: <health check command>
  web-admin:
    type: browser
    ...
  miniprogram:
    type: device
    ...
```

`/tdd:e2e` generates per-endpoint test suites; UC display steps ("user sees X on page") **must** have a `browser` or `device` E2E (Rule 6) — API E2E asserting return values does not count as "display verified".

For UI endpoints, screenshots are **mandatory evidence** (v3.6+). After tests pass, the AI proactively reads back 1–2 key screenshots so you can visually confirm the assertion really hit the right element, not just a green checkmark.

---

## Verification system

`/tdd:verify-setup` produces `tdd-specs/.verify/project.md` (project-level: commands, endpoints, src_dirs, tools) and per-feature `tdd-specs/<feature>/verify.md` (feature-specific: manual_flows, smoke checks).

`/tdd:done` reads both and runs:

| Stage | Content |
|---|---|
| **Stage 1** | typecheck → lint → build → unit → integration → per-endpoint E2E → coverage |
| **Stage 2** | Manual flows (auto-passes if Stage 1 covers all endpoints with no `manual_flows` defined, v3.4+) |
| **Stage 3** | Cleanup checklist (logs, dead code, TODOs) |
| **Stage 4** | Delivery report |

Smoke-test mandatory at setup time (v3.5+): every `readiness` and `test_cmd` is actually executed once before written into `project.md` — no doc-guessed commands.

---

## Hooks (Claude Code only)

Five PreToolUse / PostToolUse / UserPromptSubmit hooks that turn TDD discipline into an enforceable harness:

| Hook | What it enforces |
|---|---|
| `pre-bash.sh` | Block test runs that bypass the project test command |
| `pre-write-edit.sh` | **Block source-file edits during RED phase** (must write the failing test first) |
| `post-bash.sh` | Track Three-Strike protocol: 3 consecutive failures → escalate |
| `post-write-edit.sh` | Update `last_edit_time` for staleness checks |
| `user-prompt-submit.sh` | Inject current TDD phase into context on every user prompt |

State lives in `tdd-specs/<spec>/.harness` (current phase, strike counter).

---

## Three-Strike protocol

When a test fails 3 times in a row, the harness blocks further `Bash` test runs and escalates:

> Three consecutive failures on `<test command>`. Stop iterating. Likely options:
> 1. The test is wrong (misunderstood requirement) — go back to `/tdd:change`
> 2. The implementation approach is wrong — discuss with user before more attempts
> 3. The UC is wrong (impossible to satisfy as written) — revisit `usecases.md`

Forces the AI to think instead of brute-forcing through identical attempts.

---

## Supported AI tools

| Tool | ID | Skill location | Slash commands |
|---|---|---|---|
| Claude Code | `claude` | `.claude/skills/` | `.claude/commands/tdd/` |
| Cursor | `cursor` | `.cursor/skills/` | `.cursor/commands/tdd/` |
| Cline | `cline` | `.cline/skills/` | `.cline/commands/tdd/` |
| Windsurf | `windsurf` | `.windsurf/skills/` | `.windsurf/commands/tdd/` |
| CodeBuddy | `codebuddy` | `.codebuddy/skills/` | `.codebuddy/commands/tdd/` |
| GitHub Copilot | `github-copilot` | `.github/copilot/skills/` | `.github/copilot/commands/tdd/` |

Hooks are Claude-Code specific (other tools don't have an equivalent harness API yet).

---

## Documentation

- **[README.zh-CN.md](./README.zh-CN.md)** — Full documentation in Chinese (workflow examples, command details, FAQ, comparison with OpenSpec)
- **[CHANGELOG.md](./CHANGELOG.md)** — Release notes
- **[skills/SKILL.md](./skills/SKILL.md)** — The skill file itself, including delivery rules and post-delivery development guidance

---

## License

MIT © yjzhuang
