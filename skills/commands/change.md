---
name: "TDD: Change"
description: Mid-course requirement change — interactive collection, impact analysis, sync all 3 spec docs and tasks.md
category: TDD Workflow
tags: [tdd, workflow, change, requirements]
---

Mid-course requirement change flow. Safely modify requirements during Phase 2 or Phase 3 and sync all spec documents.

**Input**: Change description (optional, interactive collection if not provided)

**Steps**

1. **Confirm current spec**
   ```bash
   SPEC=$(cat tdd-specs/.current 2>/dev/null || echo "")
   if [ -z "$SPEC" ]; then echo "ERROR: No active spec, run /tdd:new first"; exit 1; fi
   echo "Current spec: $SPEC"
   # Pause harness during change analysis
   if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
     sed -i '' 's/phase=.*/phase=spec/' "tdd-specs/$SPEC/.harness"
   fi
   cat tdd-specs/$SPEC/tasks.md
   ```

2. **Collect change description (if not passed as parameter)**

   Use **AskUserQuestion** tool:
   > "What do you want to change? Describe the requirement change (can be adding features, removing features, modifying behavior, adjusting acceptance criteria, etc.)."

   After collecting, rephrase the change in your own words for user confirmation before proceeding.

3. **Analyze impact**

   Read all four documents, analyze item by item:
   ```bash
   cat tdd-specs/$SPEC/usecases.md    # UseCase 是主文档，先看
   cat tdd-specs/$SPEC/requirements.md
   cat tdd-specs/$SPEC/design.md
   cat tdd-specs/$SPEC/tasks.md
   # 检查是否已同步到 docs/usecases/
   cat tdd-specs/$SPEC/usecases.synced.md 2>/dev/null || echo "(未同步到 docs/)"
   ```

   Output impact assessment（**UseCase 维度放最前面**）：

   ```
   ## Change Impact Assessment

   ### Change Description
   <one-line summary>

   ### Affected UseCases（主维度）
   | UseCase | Affected Step/Path | Impact Type | Description |
   |---------|-------------------|-------------|-------------|
   | UC-01 | step 2, step 6 | Modify | 评论输入改为 Markdown 编辑器 |
   | UC-01 | 新增 3c 备选 | Add | Markdown 语法错误提示 |

   ### Affected Requirements (从 UC 推导)
   | Document | Entry | Impact Type | Description |
   |----------|-------|-------------|-------------|
   | requirements.md | REQ-XX (来源 UC-01) | Modify/Add/Delete | ... |
   | design.md | Interface/Module | Modify/Add/Delete | ... |

   ### Affected Tasks
   | Task | Current Status | UC 路径 | Action Needed |
   |------|---------------|---------|---------------|
   | 2.X xxx | [x] Completed | Covers UC-01 step 2 | WARNING: needs revert and redo |
   | 2.Y yyy | [ ] Not started | Covers UC-01 step 6 | Modify description |
   | 2.Z zzz | — | Covers UC-01 备选 3c | New task |

   ### UC 同步状态（影响后续动作）
   - usecases.synced.md 记录: <日期 + target> 或 "从未同步"
   - 受影响 UC 是否已同步 docs/: <Yes/No>
   - 推荐同步策略: <见 Step 4>

   ### Risk Notes
   - Completed tasks affected: N
   - Estimated additional work: small / medium / large
   ```

4. **Wait for user confirmation**

   Use **AskUserQuestion** tool:
   > "Above is the impact scope of this change. Confirm to proceed?"
   - Option A: Confirm, start updating documents
   - Option B: Adjust change description (return to step 2)
   - Option C: Cancel, no modifications

   **如果影响的 UC 已同步到 docs/**（usecases.synced.md 有记录），额外询问同步策略：
   > "UC-01 之前已同步到 docs/usecases/comments.md (commit abc123)。本次变更如何处理同步？"
   - [A] 标记为"待同步"，本次只改 tdd-specs，交付时（/tdd:done Stage 4.2）再同步 docs/（推荐）
   - [B] 立即同步到 docs/usecases/comments.md（保持实时一致）
   - [C] 只改 tdd-specs，不动 docs（不推荐，会偏离权威文档）

5. **Execute updates (after user confirmation)**

   **5.0 先更新 usecases.md（主文档，先于其他所有文档）**
   - 修改受影响的 UC 步骤
   - 新增/删除 UC 或备选路径
   - 在 usecases.md 顶部"变更记录"区追加日期 + 变更点
   - 如果选了 [A]（标记待同步），在 usecases.md 顶部加一个标记：
     ```markdown
     > ⚠ Pending sync to docs/usecases/comments.md
     > Changed since last sync: UC-01 step 2/6, new UC-01 备选 3c
     ```

   **5.1 Update requirements.md（从 UC cascade）**
   - Modify/add/delete 对应 REQ 条目（依据 UC 变更）
   - Update acceptance criteria (AC) 的 UC 引用
   - Append change record at top or in change history:
     ```markdown
     > Change [date]: <one-line description of change>
     > Affected UCs: UC-01 (step 2, step 6, new 3c)
     ```

   **5.2 Update design.md（从 UC cascade）**
   - Modify 受影响的 interface definitions, data structures
   - Update 每个接口的 "支持的 UseCase" 标注
   - Keep consistent with requirements.md

   **5.3 Update tasks.md（从 UC cascade）**
   - Completed but affected tasks: mark back to `[ ]`, append note `<- needs redo due to UC-01 step 2 change`
   - Incomplete tasks needing description changes: modify directly
   - New tasks: append to corresponding Phase，标注 "Covers UC-01 备选 3c"

   **5.4 Update docs/usecases/ 权威文档（仅选 [B] 时执行）**
   - 如果用户选了 [B]（立即同步），复制 usecases.md 变更到 docs/usecases/ 对应文件
   - 处理 UC 编号映射（feature 内 UC-01 → 项目级 UC-025）
   - 更新 usecases.synced.md 追加同步记录

   **5.5 保留执行 UseCase 草稿/其他项目文档变化检查**（原有步骤保留）

6. **Output change summary**

   ```
   OK Requirement change synced

   Change: <one-line>
   Updated documents:
     OK usecases.md     — modified 2 UCs, added 1 alternative path
     OK requirements.md — modified N, added N
     OK design.md       — modified N entries
     OK tasks.md        — reverted N completed tasks, added N new tasks

   UC Sync Status:
     - Strategy: <A 待同步 / B 已同步 / C 仅 tdd-specs>
     - usecases.md 顶部标记: <Pending sync / 已同步 / N/A>

   Remaining tasks: N (including reverts)

   Next: Run /tdd:loop to continue implementation
   ```

**Guardrails**
- Do not modify any files before step 4 user confirmation
- **usecases.md 必须最先更新**，其他文档从 UC cascade
- Completed tasks must be reverted if affected — no "good enough" shortcuts
- Change records must be written to usecases.md AND requirements.md for traceability
- **已同步到 docs/ 的 UC 变更必须询问同步策略** — 不能默默让 docs/ 偏离
- UseCase docs must be updated if visible behavior changes
- If change causes 10+ task reverts, additionally prompt user to consider a fresh `/tdd:ff`
