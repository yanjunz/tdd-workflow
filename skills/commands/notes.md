---
name: "TDD: Notes"
description: Generate TDD practice notes — record decisions, pitfalls, and lessons learned
category: TDD Workflow
tags: [tdd, notes, retrospective, practice]
---

Generate a TDD practice notes document for the current (or specified) feature. Records the full development story: what was planned, what actually happened, what went wrong, and what was learned.

**When to use**: After `/tdd:done` or at any point you want to capture the development journey.

**Input**: Feature name (optional, defaults to `tdd-specs/.current`)

**Steps**

1. **Gather context**

   ```bash
   SPEC=$(cat tdd-specs/.current 2>/dev/null)
   if [ -z "$SPEC" ]; then
     echo "ERROR: No active spec. Provide feature name as argument."
     exit 1
   fi
   echo "Generating notes for: $SPEC"

   # Read the three spec documents
   cat tdd-specs/$SPEC/requirements.md 2>/dev/null
   cat tdd-specs/$SPEC/design.md 2>/dev/null
   cat tdd-specs/$SPEC/tasks.md 2>/dev/null
   ```

2. **Scan implementation artifacts**

   ```bash
   SPEC=$(cat tdd-specs/.current)

   # Find all test files created for this feature
   echo "=== Test files ==="
   grep -rl "$SPEC\|$(echo $SPEC | tr '-' '.')" testing/ apps/*/src/__tests__/ 2>/dev/null || echo "(scan by git)"
   git log --oneline --diff-filter=A --name-only | head -60

   # Find modified source files
   echo "=== Source files ==="
   git log --oneline --diff-filter=M --name-only | head -60

   # Count test results
   echo "=== Test counts ==="
   grep -r "it('\|it(\"\\|test('" apps/*/src/__tests__/ testing/integration/ 2>/dev/null | wc -l
   ```

3. **Review git history for the feature's commits**

   ```bash
   # Find commits related to this feature
   git log --oneline --all | grep -i "$(echo $SPEC | tr '-' ' ')" | head -20
   ```

4. **Generate `tdd-specs/<name>/tdd-practice-notes.md`** following this structure:

   ```markdown
   # TDD 实践记录：<feature-name>

   > <one-line description>

   ## 一、需求背景

   <2-3 sentences: what the user wanted, why it matters>

   ## 二、TDD 流程总览

   <which /tdd: commands were used, in what order>

   ### Phase 1: 需求分析与设计

   <key design decisions and why>

   ### Phase 2: TDD 主循环

   For each behavior chain in tasks.md:

   #### 2.N 行为：<user behavior description>

   **RED** — <N> 个单测（`<test-file>`）：
   <bullet list of key test scenarios>

   **GREEN** — 实现 <function/module>
   <what was implemented, key design choices>

   **接入** — <which framework file was modified to call the new code>

   ### Phase 3: 集成/E2E 测试

   <what was tested at integration level>

   ### Phase 4: 交付

   <delivery artifacts: scripts, configs, docs>

   ## 三、踩坑记录与修复

   For each significant problem encountered:

   ### 坑 N：<short title>

   **问题**：<what went wrong>
   **发现方式**：<how it was discovered — test failure, user report, manual testing>
   **修复**：<what was changed>

   ## 四、最终文件清单

   ### 新增文件
   | 文件 | 说明 |
   |------|------|

   ### 修改文件
   | 文件 | 说明 |
   |------|------|

   ### 测试覆盖
   | 层级 | 用例数 | 通过 |
   |------|--------|------|

   ## 五、核心经验

   <3-5 bullet points: most important lessons learned>
   <focus on what would help the next developer working on a similar feature>
   ```

5. **Cross-check completeness**

   | Section | Check | Fix if missing |
   |---------|-------|----------------|
   | 踩坑记录 | At least 1 entry? | Review git history for reverts, fix commits, or amended approaches |
   | 核心经验 | At least 3 points? | Distill from pitfalls + design decisions |
   | 文件清单 | Matches actual git diff? | Run `git diff --stat` against base branch |
   | 测试覆盖 | Numbers match actual test count? | Run test suite and verify |

6. **Output summary**

   ```
   OK tdd-specs/<name>/tdd-practice-notes.md generated

   Sections:
   - 需求背景: ✓
   - TDD 流程 (Phase 1-4): ✓
   - 踩坑记录: N entries
   - 文件清单: N new + M modified
   - 核心经验: N points

   This document is auto-included when /tdd:archive runs.
   ```

**Guardrails**
- Must read requirements.md, design.md, tasks.md before writing — don't fabricate from memory
- 踩坑记录 must reference actual problems (git reverts, fix commits, user-reported bugs), not hypothetical risks
- 核心经验 must be actionable ("do X" / "avoid Y"), not vague ("testing is important")
- File list must be verified against actual git history, not guessed
- If the feature is still in progress, mark incomplete sections with `> ⏳ Pending — feature in progress`
