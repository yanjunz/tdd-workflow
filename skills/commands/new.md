---
name: "TDD: New"
description: Start new feature TDD workflow — interactive requirements gathering, create spec directory
category: TDD Workflow
tags: [tdd, workflow, new-feature]
---

Start new feature TDD workflow.

**Input**: Parameter after `/tdd:new` is the feature name (kebab-case), or a description of the feature.

**Steps**

1. **If no parameter, ask user what they want to build**

   Use **AskUserQuestion** tool (open-ended, no preset options):
   > "What feature do you want to implement? Please describe your requirements."

   Derive kebab-case name from description (e.g., "refund retry fix" -> `refund-retry-fix`).

   **Important**: Do not proceed until user's requirements are understood.

2. **Interactive requirements gathering (all dimensions must be completed)**

   Ask questions round by round, reflecting understanding back to user for confirmation after each round:

   | Dimension | Question |
   |-----------|----------|
   | Target users | Who will use this? (based on actual project roles) |
   | Core scenarios | Top 1-3 most important use cases? |
   | Input/Output | What is input? What is returned? |
   | Error handling | What situations fail? Expected error behavior? |
   | Scope boundaries | What is explicitly NOT in scope? |
   | Acceptance criteria | How do we know it's done? |

3. **After scope is confirmed, create spec directory**

   ```bash
   mkdir -p tdd-specs/<name>
   echo "<name>" > tdd-specs/.current
   printf 'phase=requirements\ntask=\nstrikes=0\nlast_test_time=0\nlast_edit_time=0\nverify_stage=0\nverify_local_ok=false\nverify_staging_ok=false\n' > tdd-specs/<name>/.harness
   ```

4. **Feature-level verification (optional but recommended)**

   Check if project has verification config:

   ```bash
   if [ -f tdd-specs/.verify/project.md ]; then
     # Read common_flows names from project.md
     grep -E '^\s+\w+:' tdd-specs/.verify/project.md | head -10
     echo "Project has verification config. Asking about feature-specific verify..."
   else
     echo "Project has no verification config yet."
     echo "→ Consider running /tdd:verify-setup first for structured verification."
     echo "→ You can skip this for now; /tdd:done will fall back to generic checks."
   fi
   ```

   Use **AskUserQuestion**:
   > "项目级验证覆盖了这些流程（列出 common_flows）。这个 feature 有什么项目级**没覆盖**的独有验证需求？"
   > - [A] 有特殊验证需求（描述）
   > - [B] 没有，完全用项目级
   > - [C] 项目还没配置，跳过

   If user chose [A]:
   - 收集用户描述的验证需求
   - 生成 `tdd-specs/<name>/verify.md` 草稿（参考 `templates/verify-feature.md`）
   - 用户确认后保存

   If [B]: 创建空的 verify.md（只包含 `depends_on_project_verify: []`）
   If [C]: 不创建 verify.md，留给后续

5. **Stop, wait for user direction**

**Output**

- Feature name and path: `tdd-specs/<name>/`
- Requirements confirmation summary (user stories + acceptance criteria)
- Prompt:
  > "Requirements confirmed! Run `/tdd:ff` to generate all spec docs at once, or `/tdd:spec` for step-by-step confirmation."

**Guardrails**
- Do not create any spec files, only create directory
- Scope must be confirmed by user before proceeding
- If feature name already exists, suggest using `/tdd:continue` to resume
