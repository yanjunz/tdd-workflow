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

   | Dimension | Question | 用途 |
   |-----------|----------|------|
   | Target users | Who will use this? (based on actual project roles) | UC 主角色 |
   | **Core scenarios** | **Top 1-3 use cases. 每个场景收集：触发事件 + 成功路径关键步骤**（例：用户点击"发表"→ 系统校验 → 系统写库 → 前端追加到列表） | **UC 框架草稿** |
   | Input/Output | What is input? What is returned? | UC 相关数据 |
   | Error handling | What situations fail? Expected error behavior? | **UC 备选路径（3a/3b/4a 等）** |
   | Scope boundaries | What is explicitly NOT in scope? | 避免过度生成 UC |
   | Acceptance criteria | How do we know it's done? | UC 后置条件 |

   **关键**：Core scenarios 要收集到足够生成 UC 的粒度——不只是"用户能发评论"，而是"用户点 X → 系统做 Y → 用户看到 Z"的步骤序列。

3. **After scope is confirmed, create spec directory**

   ```bash
   mkdir -p tdd-specs/<name>
   echo "<name>" > tdd-specs/.current
   printf 'phase=requirements\ntask=\nstrikes=0\nlast_test_time=0\nlast_edit_time=0\nverify_stage=0\nverify_local_ok=false\nverify_staging_ok=false\n' > tdd-specs/<name>/.harness
   ```

   同时创建 **UC 草稿占位文件**，作为 `/tdd:ff` 的输入参考：

   ```bash
   cat > tdd-specs/<name>/usecases.draft.md <<EOF
   # UseCase Draft — <name>

   > 由 /tdd:new 从交互收集生成的 UC 框架草稿
   > 待 /tdd:ff 正式生成 usecases.md 时填充完整

   ## 场景列表

   <根据 Core scenarios 维度收集的场景，每个场景包含：
   - UC 建议名称（例：UC-01 用户发表评论）
   - 主角色（从 Target users 维度）
   - 触发事件（从场景描述提取）
   - 关键步骤（3-5 步，来自场景描述）
   - 可能的备选/错误路径（从 Error handling 维度）
   >

   ## 待确认问题

   <在 /tdd:ff 时需要用户进一步明确的点，例如：
   - 场景 X 的第 N 步在失败时如何处理？
   - 场景 Y 是否需要权限校验？
   >
   EOF
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
- 创建的文件：
  - `tdd-specs/<name>/.harness` (状态追踪)
  - `tdd-specs/<name>/usecases.draft.md` (UC 框架草稿)
  - `tdd-specs/<name>/verify.md` (如用户选择 [A]/[B])
- Requirements confirmation summary (user stories + acceptance criteria)
- Prompt:
  > "Requirements confirmed! Run `/tdd:ff` to generate all spec docs (usecases.md as primary output, then requirements/design/tasks derived from it)."

**Guardrails**
- Do not create any spec files other than `.harness`, `usecases.draft.md`, and optional `verify.md`
- `usecases.md` itself is NOT created here — it's the main output of `/tdd:ff`
- Scope must be confirmed by user before proceeding
- If feature name already exists, suggest using `/tdd:continue` to resume
- **Core scenarios 维度必须收集到步骤粒度**，否则 `/tdd:ff` 无法生成有价值的 UC
