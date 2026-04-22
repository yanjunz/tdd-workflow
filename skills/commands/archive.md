---
name: "TDD: Archive"
description: Archive completed specs to tdd-specs/archive/
category: TDD Workflow
tags: [tdd, workflow, archive]
---

Archive completed specs.

**Steps**

1. **Verify all tasks are completed**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   grep -E "^\- \[( |~|!)\]" tdd-specs/$SPEC/tasks.md && echo "WARNING: Incomplete tasks remain" || echo "OK All complete"
   ```
   If incomplete tasks exist, stop and prompt to complete `/tdd:done` first.

2. **Check for practice notes**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   if [ ! -f "tdd-specs/$SPEC/tdd-practice-notes.md" ]; then
     echo "WARNING: No practice notes found. Run /tdd:notes first to capture lessons learned."
   else
     echo "OK Practice notes exist"
   fi
   ```
   If no notes, prompt to run `/tdd:notes` first. Do not block archival, but strongly recommend.

3. **Check UseCase sync status**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   if [ -f "tdd-specs/$SPEC/usecases.md" ] && [ ! -f "tdd-specs/$SPEC/usecases.synced.md" ]; then
     echo "WARNING: usecases.md 存在但未同步到 docs/usecases/"
     echo "→ 归档后 feature 内部的 UC 会埋在 archive/，PM/QA 看不到"
   fi
   ```

   如果 `usecases.md` 存在但 `usecases.synced.md` 不存在，用 **AskUserQuestion**：
   > "该 feature 的 UseCase 尚未同步到 docs/usecases/（项目长期文档）。如何处理？"
   > - [A] 先跑 /tdd:done Stage 4.2 同步，再归档（推荐）
   > - [B] 直接跳到同步步骤（不做完整 /tdd:done）
   > - [C] 跳过同步，归档时仅保留在 tdd-specs/archive/（UC 仅存在于归档目录）

   选 [A]：提示用户 `/tdd:done` 后再回来归档，本次归档中止。
   选 [B]：调用 `/tdd:done` 的 Stage 4.2 同步逻辑（或提示用户手动操作后再归档）。
   选 [C]：记录到 usecases.synced.md：
   ```markdown
   # UseCase Sync Log — <feature>

   ## YYYY-MM-DD HH:MM
   - Decision: SKIPPED sync at archive time
   - Reason: User chose to keep UCs only in archive
   ```

4. **Archive**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   MONTH=$(date +%Y-%m)
   mkdir -p tdd-specs/archive/$MONTH
   mv tdd-specs/$SPEC tdd-specs/archive/$MONTH/
   echo "" > tdd-specs/.current
   echo "OK Archived to tdd-specs/archive/$MONTH/$SPEC/"
   ```
   **注意**：`docs/usecases/*.md` 保持不动（是项目长期文档，不随 feature 归档），feature 目录下的 `usecases.md`、`usecases.synced.md` 会随目录一起归档到 `tdd-specs/archive/`。

5. **Output**
   ```
   OK Archived: tdd-specs/archive/<YYYY-MM>/<name>/
   UC Sync: <synced to docs/usecases/comments.md | skipped>
   tdd-specs/.current cleared, ready for next feature.
   Run /tdd:new <next-feature> to begin.
   ```
