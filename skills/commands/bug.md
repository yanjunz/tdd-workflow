---
name: "TDD: Bug"
description: Bug report -> Issue tracking -> reproduction test -> fix -> verify -> archive
category: TDD Workflow
tags: [tdd, bug, issue, debug]
---

Bug fix full workflow: traceable from problem description to Issue archive.

---

## Config Loading (run at start)

读取 `tdd-specs/.verify/project.md` 的 `paths.issues:` 节：
- `enabled` — true = 本地目录管理；false = 外部工具管理
- `dir` — 本地目录路径（默认 `docs/issues`）
- `index_file` — README 索引文件路径
- `numbering` — `auto` | `manual`
- `filename_pattern` — 文件名模板（默认 `<NNN>-<module>-<keyword>.md`）
- `external_tool` / `external_url` — 外部工具名和链接（仅 enabled=false 时）

**回退**：project.md 不存在或缺 paths → 默认 `docs/issues/`, enabled=true, auto 编号。

**外部工具模式（enabled=false）**：下面所有"创建文件"步骤改为"输出内容 + 提示用户去 `external_url` 创建"，并把用户返回的外部 Issue ID（如 PROJ-1234）记录到追溯链。

---

## Steps

### 1. Collect Bug Information

Ask user (if description is incomplete):
- What is the symptom (error message, screenshot description, reproduction steps)
- Which module / which endpoint
- Consistent or intermittent
- Environment (development/production/other)

### 2. Assign Issue Number (if project uses issues directory)

**本地模式（paths.issues.enabled=true）**：
```bash
# Replace ${ISSUES_DIR} with paths.issues.dir from project.md (default docs/issues)
ls ${ISSUES_DIR}/*.md 2>/dev/null | grep -v README | sort | tail -1
# Increment from last number per paths.issues.numbering
```

**外部工具模式（enabled=false）**：
```
🤖 Issue 由 ${paths.issues.external_tool} 管理。
   请在 ${paths.issues.external_url} 创建 Issue（内容见下一步），完成后告诉我 Issue ID。
```

### 3. Create Issue Draft

**本地模式**：在 `${paths.issues.dir}/<filename-per-pattern>.md` 创建，**status: "investigating"**:

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

**外部工具模式**：把上述内容粘贴到 `${paths.issues.external_url}` 并记录返回的外部 Issue ID。

Update `${paths.issues.index_file}` table (status: Investigating)（仅本地模式）。

### 4. Root Cause Analysis

Follow `systematic-debugging` principles: **no guessing, find root cause first.**

```bash
# Check existing Issues to avoid duplicate investigation (if paths.issues.enabled=true)
grep -rl "<error-keywords>" ${ISSUES_DIR}/ 2>/dev/null || echo "No issues directory"

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

**If Agent tool is available** — spawn a Coder sub-agent:
```
You are a TDD Coder. Write a test that reproduces this bug.

Bug symptoms: <from Step 1>
Root cause: <from Step 4>
Module: <affected module path>
Test framework: <detected from project>

Rules:
- The test must FAIL with the current code (proving the bug exists)
- Do NOT fix the bug — only write the reproduction test
- Do NOT modify any src/ files
- Choose test layer based on bug type:
  - Business logic error -> Unit test
  - API error -> Integration test
  - UI/interaction issue -> E2E

After writing, run the test and report: file path, test name, failure message.
```

**If Agent tool is NOT available** — write the reproduction test yourself, following the same rules.

**Reviewer step (mandatory):** Does the test actually reproduce the reported bug? Is the failure message related to the symptoms from Step 1?
```
[Review:RED] ✓ reproduces bug | ✓ correct test layer | Issues: <none or list>
```

- If test doesn't reproduce the bug: fix (or re-prompt Coder) with more specific reproduction steps
- If test passes review: proceed to GREEN

### 6. Fix Code (GREEN)

Set harness to GREEN phase:
```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=green/' "tdd-specs/$SPEC/.harness"
fi
```

**If Agent tool is available** — spawn a Coder sub-agent:
```
You are a TDD Coder. Fix the bug to make the reproduction test pass.

Failing test: <file path from Step 5>
Failure message: <exact error>
Root cause: <from Step 4>

Rules:
- Write the MINIMUM fix — do NOT refactor unrelated code
- Do NOT modify any test files
- Follow the project's existing code conventions

After fixing, run the FULL test suite (not just the new test).
Report: files modified, full suite result, any regressions.
```

**If Agent tool is NOT available** — write the fix yourself, following the same rules.

**Reviewer step (mandatory):** Is the fix minimal and targeted at the root cause? Did full regression pass?
```
[Review:GREEN] ✓ minimal fix | ✓ targets root cause | ✓ full suite passes | Issues: <none or list>
```

### 7. Complete Issue Documentation

Fill in remaining sections:
- **Root Cause Analysis**: Complete cause chain (code + arrow diagram)
- **Fix**: File change table + core diff
- **Verification Steps**: Executable commands
- **Status**: Change to `Fixed`

Update `${paths.issues.index_file}` status column（本地模式；外部工具模式下更新外部 Issue 状态）。

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
[Done]        Issue #NNN archived, ${paths.issues.dir}/<filename>.md (or external: ${paths.issues.external_tool})
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
