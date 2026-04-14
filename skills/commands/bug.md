---
name: "TDD: Bug"
description: Bug report -> Issue tracking -> reproduction test -> fix -> verify -> archive
category: TDD Workflow
tags: [tdd, bug, issue, debug]
---

Bug fix full workflow: traceable from problem description to Issue archive.

---

## Steps

### 1. Collect Bug Information

Ask user (if description is incomplete):
- What is the symptom (error message, screenshot description, reproduction steps)
- Which module / which endpoint
- Consistent or intermittent
- Environment (development/production/other)

### 2. Assign Issue Number (if project uses issues directory)

```bash
ls docs/issues/*.md 2>/dev/null | grep -v README | sort | tail -1
# Increment from last number, 3-digit format
```
If project has no issues directory, use git issues / GitHub Issues or other tracking — same principles apply.

### 3. Create Issue Draft

Create document at `docs/issues/<NNN>-<module>-<keyword>.md`, **status: "investigating"**:

```markdown
# Issue #NNN — <one-line description>

## Basic Info
| Field | Content |
|-------|---------|
| Discovered | YYYY-MM-DD |
| Module | `<module-path>` |
| Severity | Low / Medium / High / Critical |
| Status | Investigating |

## Symptoms
<user-reported error / logs / screenshot description>

## Root Cause Analysis
> Pending investigation
```

Update `docs/issues/README.md` table (status: Investigating).

### 4. Root Cause Analysis

Follow `systematic-debugging` principles: **no guessing, find root cause first.**

```bash
# Check existing Issues to avoid duplicate investigation (if project has issues directory)
grep -rl "<error-keywords>" docs/issues/ 2>/dev/null || echo "No issues directory"

# Locate code (adjust based on actual project directory structure)
grep -rn "<keyword>" src/ 2>/dev/null || grep -rn "<keyword>" . --include="*.ts" --include="*.js" --include="*.py"
```

After finding root cause, update Issue document's "Root Cause Analysis" section.

### 5. Write Reproduction Test (RED)

Set harness to RED phase:
```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=red/' "tdd-specs/$SPEC/.harness"
fi
```

Choose test layer based on bug type:

| Bug Type | Preferred Test Layer |
|----------|---------------------|
| Business logic error | Unit test (pure function/service layer) |
| API error | Integration test (HTTP chain) |
| UI/interaction issue | E2E (end-to-end flow) |

Run using project's actual test command to verify test fails (RED).
Confirm failure is because "bug exists" not "test is wrong".

### 6. Fix Code (GREEN)

Set harness to GREEN phase:
```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=green/' "tdd-specs/$SPEC/.harness"
fi
```

Write minimum code to pass, following project's existing conventions:

```bash
# Verify fix passes (using project's actual test command)
<TEST_COMMAND> --testPathPattern="<file>"

# Full regression, confirm no side effects
<TEST_COMMAND>
```

### 7. Complete Issue Documentation

Fill in remaining sections:
- **Root Cause Analysis**: Complete cause chain (code + arrow diagram)
- **Fix**: File change table + core diff
- **Verification Steps**: Executable commands
- **Status**: Change to `Fixed`

Update `docs/issues/README.md` status column.

### 8. Retrospective (mandatory — cannot skip)

Every bug deserves a "why did this happen" analysis, not just a fix. Complete the **Prevention** section of the Issue document:

**8.1 Classify the root cause:**

| Category | Example | Typical Action |
|----------|---------|----------------|
| Design gap | No idempotency considered | Update design.md, add architectural constraint |
| Missing test | Boundary value not tested | Add test case category to tasks.md template |
| Code pattern | Used `>` instead of `>=` | Add lint rule or code review checklist item |
| Knowledge gap | Didn't know DB has VARCHAR limit | Document in project knowledge base |
| Process gap | Skipped regression before merge | Update CI pipeline or delivery checklist |

**8.2 Write concrete prevention measures** (at least one per bug):

```markdown
## Prevention

### Root Cause Category
<one of: design gap / missing test / code pattern / knowledge gap / process gap>

### Why It Happened
<2-3 sentences: what assumption was wrong, what was overlooked, why existing tests didn't catch it>

### Prevention Actions
- [ ] <concrete action 1 — e.g., "Add boundary value tests for all field length limits">
- [ ] <concrete action 2 — e.g., "Add eslint rule: no bare > comparison for length checks">

### Applied To
<where the prevention was actually implemented — file paths, rule names, checklist items>
```

**8.3 Execute at least one prevention action immediately:**
- If it's a test gap → add the test right now (not "later")
- If it's a lint rule → add the rule right now
- If it's a design pattern → document it in project docs right now
- If it's a checklist item → add it to `/tdd:done` checklist or CI config

**8.4 Search for similar patterns in codebase:**
```bash
# Look for the same mistake elsewhere
grep -rn "<buggy-pattern>" src/ --include="*.ts" --include="*.js" --include="*.py" 2>/dev/null | grep -v test
```
If found, fix them now or create tasks for each occurrence.

### 9. Run E2E Verification (if feature involves UI or end-to-end flow)

Run related test suite using project's actual E2E command.

---

## Output Format

Output status line after each phase:

```
[Analysis]    Root cause: <one-liner>
[RED]         Test written, failure reason: <error message>
[GREEN]       Fix complete, tests passing
[Retro]       Category: <category> | Prevention: <action summary> | Similar: <N found>
[Done]        Issue #NNN archived, docs/issues/<filename>.md
```

If same test fails 3 times during fix, trigger **Three-Strike Protocol** (same as `/tdd:loop`).

---

## Guardrails

- Issue document must be created BEFORE starting fix (status "investigating"), not retroactively
- Cannot write implementation code without seeing RED test failure
- Must run full regression after fix, not just single test
- UI/end-to-end flow bugs must run E2E, not just unit tests
- **Retrospective is mandatory for ALL bugs, not just High/Critical**
- **At least one prevention action must be executed immediately, not deferred**
- **Must search for similar patterns in codebase — do not assume the bug is isolated**
