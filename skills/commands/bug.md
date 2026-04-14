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
- **Prevention Measures**: Principles to avoid similar issues (consider adding to project docs)
- **Status**: Change to `Fixed`

Update `docs/issues/README.md` status column.

### 8. Run E2E Verification (if feature involves UI or end-to-end flow)

Run related test suite using project's actual E2E command.

---

## Output Format

Output status line after each phase:

```
[Analysis] Root cause: <one-liner>
[RED]      Test written, failure reason: <error message>
[GREEN]    Fix complete, tests passing
[Done]     Issue #NNN archived, docs/issues/<filename>.md
```

If same test fails 3 times during fix, trigger **Three-Strike Protocol** (same as `/tdd:loop`).

---

## Guardrails

- Issue document must be created BEFORE starting fix (status "investigating"), not retroactively
- Cannot write implementation code without seeing RED test failure
- Must run full regression after fix, not just single test
- UI/end-to-end flow bugs must run E2E, not just unit tests
- High/Critical severity bugs: prevention measures should be recorded in project docs
