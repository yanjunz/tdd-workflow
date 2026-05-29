# Staging Smoke Test Design Guide (Type B E2E)

> **When to read**: Whenever an E2E test runs against **real external dependencies** in
> a staging/prod-like environment that you cannot fully control (real credentials, real
> upstream APIs, real data that drifts over time).
>
> **Status**: Mandatory companion to `/tdd:e2e`. The base `/tdd:e2e` Hard Rules (Rule
> 1–5) target Type A E2E (controlled dev/CI environment with seeded data and mockable
> 3rd-party). This file defines the additional contract for Type B.

---

## E2E Type Decision Tree

Before writing any E2E test, decide which type:

```
┌─ E2E Type Selection ────────────────────────────────────────────┐
│                                                                  │
│  Type A: User-Flow E2E   (dev / CI environment)                  │
│   • Goal: verify user-visible behavior end-to-end                │
│   • Environment: controlled — can seed DB, mock 3rd-party        │
│   • Driven by: usecases.md success path / alt paths              │
│   • Rules: existing /tdd:e2e Hard Rules 1–5                      │
│                                                                  │
│  Type B: Staging Smoke   (real deps, zero env control)           │
│   • Goal: verify "real dependency wiring is alive"               │
│       (credentials valid, network reachable, schema match)       │
│   • Environment: uncontrolled — real upstream, real auth, real   │
│     data that drifts; cannot seed, cannot mock                   │
│   • NOT driven by usecases.md — driven by failure modes (see     │
│     "Why Type B is not driven by UCs" below)                     │
│   • Rules: Type B Hard Rules below (B1–B4)                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

If a single test file mixes both, **split it**. Type A and Type B have opposite
trade-offs — mixing them produces tests that pass under both real failures and
healthy state.

### Why Type B is not driven by UCs (and why this matters)

UCs and Type B smokes target **different failure models**. Driving a smoke
from a UC silently re-introduces every Type B anti-pattern:

| Aspect       | UC-driven (Type A)              | Failure-driven (Type B)                   |
|--------------|---------------------------------|--------------------------------------------|
| Question     | Does feature work for the user? | Is the real dependency wiring alive?       |
| Inputs       | "Any valid X" (placeholder)     | One pinned canary (X = `<known stable>`)   |
| `200 + warning + empty` | User-friendly degradation = pass | **The exact failure to catch** = fail |
| When red     | Fix business logic              | Page on-call (creds / net / schema)        |

> **Litmus test**: if your smoke would still pass when the real upstream is
> dead but your code falls back to a friendly `200 + warning`, you wrote
> a UC test, not a Type B smoke.

**Use UCs only to pick *which endpoint* to canary** (the most business-
critical real-dependency path). The canary inputs, the assertions, and the
failure modes all come from B1–B4 below — never from UC scenarios.

---

## Type B Hard Rules

### B1. Use canary inputs, never random/first-available inputs

**Why**: Type B environments have data that drifts day to day. `items[0]`,
`now()`, "first record returned" all produce different inputs across runs.
When the test fails, you cannot tell if the dependency broke or the input shifted.

```
# Pseudocode — adapt to your project's language/test framework

# ❌ WRONG — input drifts
items = fetch_items()
target = items[0]        # "first" can change between runs
date = today()           # today's data may not exist yet
date = format(today())   # looks deterministic but changes every day

# ✅ CORRECT — pin to a known-stable canary, declared as test-file constants
CANARY_RESOURCE_ID = "<pre-validated stable resource id>"
CANARY_DATE        = "<historical date with frozen data, e.g. 2025-10-15>"
```

**Picking a canary**:
- A service/resource that has been live for ≥ 30 days
- A historical date with confirmed non-empty data
- Document why this canary was chosen at the top of the test file

### B2. Assertions must distinguish "real path" from "degraded path"

The most common Type B failure mode: business code wraps every error in a
"return 200 + warning" fallback to keep the user-facing app alive. Your assertion
must explicitly reject that fallback shape, otherwise a fully-broken upstream
will still pass the smoke.

```
# Pseudocode — translate to your test framework's assertion syntax

# ❌ WRONG — passes under any degradation
assert res.status < 500
assert res.status in [200, 400]
assert res.body                       # {} / "" / 0 may still pass

# ❌ WRONG — passes even when API key is invalid (server returns 200 + empty data)
assert "items" in res.body            # presence != real-path success

# ✅ CORRECT — assert real-path-only signals
assert res.body.source == "real-api"            # explicit provenance flag
assert "warning" not in res.body                # reject degraded marker
assert "fallbackReason" not in res.body
assert len(res.body.items) > 0                  # canary is known to have data
# Even better when canary has a known exact count — locks query correctness:
assert len(res.body.items) == <expected_count>  # e.g. == 1 for a single-row canary
assert res.body.<numeric_field> > 0             # real upstream returns real values
```

**The provenance trick**: if the backend doesn't already expose a "source"
field, **add one as a debug header in non-prod**. Then the smoke can assert
provenance directly.

### B3. Negative-Proof Checklist (mandatory before marking [x])

Every Type B test MUST pass this self-interrogation. If any answer is "not
sure" or "no", the assertions are insufficient — strengthen them and re-check.

The five questions are phrased by **failure category**, not by dependency
technology, so they apply to any Type B target (real API, real DB, real
message queue, real file system, real vendor SDK, etc.). Each question gives
per-category translations — pick the one(s) that match your dependency.

```
For each Type B test, answer in writing:

□ Q1 (Auth / Identity failure):
   If the dependency rejects our identity, will my assertion fail?
     - API:  401/403 from upstream
     - DB:   wrong user / expired password / revoked grant
     - MQ:   invalid SASL credentials / expired token
     - FS:   permission denied / wrong IAM role
   → Expected: yes, because <which specific assertion catches it>

□ Q2 (Reachability failure):
   If the dependency is unreachable, will my assertion fail?
     - API:  DNS / firewall / TLS handshake error
     - DB:   connection refused / pool exhausted / VPN down
     - MQ:   broker unreachable / partition leader missing
     - FS:   mount point gone / network share offline
   → Expected: yes, because <which specific assertion catches it>
              (e.g. business-layer fallback sets a warning field that
              I explicitly reject)

□ Q3 (Empty / missing data):
   If the dependency responds successfully but returns nothing useful
   for our canary input (auth OK, reachable, but no data), will my
   assertion fail?
     - API:  200 with empty list / null payload
     - DB:   query returns 0 rows
     - MQ:   topic exists but no messages / wrong partition
     - FS:   directory exists but file missing
   → Expected: yes, because canary is known to have data and I assert
              specific cardinality / field presence (not just truthy).
              **When canary has a known exact count, assert the precise
              value (e.g. `len == 1`), not a range (`> 0` / `>= 1`) —
              otherwise a wrong filter / missing WHERE / wrong partition
              that returns *more* rows than expected will silently pass.**

□ Q4 (Contract drift):
   If the dependency's contract changed in a backwards-incompatible
   way, will my assertion fail?
     - API:  field renamed / type changed / new required field
     - DB:   column dropped / type narrowed / FK constraint added
     - MQ:   message schema evolved / header semantics changed
     - FS:   file format / encoding / path layout changed
   → Expected: yes, because I assert specific field types/values,
              not just presence-or-truthy

□ Q5 (Time invariance):
   If I run this smoke at 3 AM vs 3 PM, vs next month, does the
   result change?
   → Expected: NO — canary inputs are time-invariant. If yes, you
              violated B1; fix the input selection, not the assertion.
```

**Note**: If the dependency category falls outside the four listed above
(e.g. real hardware, real payment rail, real LLM inference, real DNS),
translate Q1–Q4 onto the four failure dimensions of that dependency:
**identity / reachability / data / contract**. These four dimensions are
the minimum coverage set for any staging smoke — none may be omitted.

### B4. Document the smoke's monitoring contract at file top

A Type B smoke is a **monitor**, not a feature test. Make its contract explicit
so future readers (and the on-call who gets paged) know what it does and
doesn't cover.

Use a comment block at the top of the test file (syntax adapted to your
language: `/** */`, `"""..."""`, `# ...`, etc.):

```
Staging Smoke: <feature> Real-Path Verification

MONITORS:
  - <upstream system> credential / auth is valid
  - Real <data pipeline / integration> is reachable end-to-end
  - Response schema matches what our parser expects

DOES NOT MONITOR:
  - UI rendering            (covered by Type A E2E)
  - Business logic          (covered by unit/integration tests)
  - <other excluded scope>  (covered by ...)

CANARY INPUTS:
  - <input-1>: <value> — <why this canary is stable>
  - <input-2>: <value> — <why this canary is stable>

ON FAILURE: <who to page>. Likely causes ranked by frequency:
  1. <cause-1> → <remediation>
  2. <cause-2> → <remediation>
  3. <cause-3> → <remediation>
```

---

## Anti-Patterns (Found in Past Retros)

```
❌ status < 500 / status in [200, 4xx]         // any degradation passes
❌ assert body is truthy                        // {} / "" / 0 may pass
❌ target = collection[0]                       // data drift between runs
❌ input = current_time / today                 // time-dependent results
❌ try { ... } catch { assert true }            // silent error swallow
❌ Mixing Type A and Type B assertions in one test
❌ Asserting on UI rendering and calling it a "smoke" — that's a Type A E2E

✅ Pinned canary input + explicit real-path field assertion + B3 checklist passed
```

---

## Required Artifact: `staging-smoke-design.md`

Every Type B test must have a corresponding design doc at:

```
tdd-specs/<feature>/staging-smoke-design.md
```

Template:

```markdown
# Staging Smoke Design — <feature>

## Smoke Inventory

| # | Test name | Monitors | Canary inputs |
|---|-----------|----------|---------------|
| 1 | <smoke-name> | <upstream creds + pipeline + ...> | <input-1> + <input-2> |

## Negative-Proof Verification (B3 checklist results)

### Smoke 1: <smoke-name>

Dependency category: <API | DB | MQ | FS | other>

- Q1 (auth/identity failure): YES will fail — asserts <which assertion catches this>
- Q2 (reachability failure):  YES will fail — asserts <which assertion catches this>
- Q3 (empty/missing data):    YES will fail — asserts <which assertion catches this>
- Q4 (contract drift):        YES will fail — asserts <which assertion catches this>
- Q5 (time invariance):       YES — uses pinned historical inputs

## Canary Selection Rationale

- <canary-1>: <why it is stable — uptime, traffic, ownership, archival policy>
- <canary-2>: <why it is stable — ...>
```

This doc is the auditable evidence that B3 was actually performed (not skipped).

---

## Integration with `/tdd:e2e` Workflow

When `/tdd:e2e` Tester Agent (or main agent) detects a test target involves
real external deps that can't be mocked in the dev/CI run:

1. **Split**: produce two separate test files in the project's E2E directory
   (location depends on project conventions — see `paths` in
   `tdd-specs/.verify/project.md`; common patterns: `e2e/`, `tests/e2e/`,
   `__tests__/e2e/`). Suggested names: `<feature>` (Type A) and
   `<feature>-staging-smoke` (Type B). Do not merge into one file.
2. **Type A** follows existing Hard Rules 1–5.
3. **Type B** follows this file's Hard Rules B1–B4.
4. **Before marking the Type B task `[x]`**:
   - Negative-Proof Checklist completed and recorded in
     `staging-smoke-design.md`
   - File header (B4) is present
   - No anti-patterns from the list above appear in the file

The Orchestrator's enforcement checklist gains one row when Type B tests exist:

| Check | Pass condition |
|-------|---------------|
| `staging-smoke-design.md` exists with B3 answers filled in | File present, all 5 questions answered with concrete reasoning |

If missing → Type B task stays `[!]` until the design doc is produced.
