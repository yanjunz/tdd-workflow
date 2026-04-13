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
   if [ -f tdd-specs/.harness ]; then
     sed -i '' 's/phase=.*/phase=spec/' tdd-specs/.harness
   fi
   cat tdd-specs/$SPEC/tasks.md
   ```

2. **Collect change description (if not passed as parameter)**

   Use **AskUserQuestion** tool:
   > "What do you want to change? Describe the requirement change (can be adding features, removing features, modifying behavior, adjusting acceptance criteria, etc.)."

   After collecting, rephrase the change in your own words for user confirmation before proceeding.

3. **Analyze impact**

   Read all three documents, analyze item by item:
   ```bash
   cat tdd-specs/$SPEC/requirements.md
   cat tdd-specs/$SPEC/design.md
   cat tdd-specs/$SPEC/tasks.md
   ```

   Output impact assessment:

   ```
   ## Change Impact Assessment

   ### Change Description
   <one-line summary>

   ### Affected Spec Entries
   | Document | Entry | Impact Type | Description |
   |----------|-------|-------------|-------------|
   | requirements.md | REQ-XX | Modify/Add/Delete | ... |
   | design.md | Interface/Module | Modify/Add/Delete | ... |

   ### Affected Tasks
   | Task | Current Status | Action Needed |
   |------|---------------|---------------|
   | 2.X xxx | [x] Completed | WARNING: needs revert and redo |
   | 2.Y yyy | [ ] Not started | Modify description |
   | 2.Z zzz | — | New task |

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

5. **Execute updates (after user confirmation)**

   **5.1 Update requirements.md**
   - Modify/add/delete corresponding REQ entries
   - Update acceptance criteria (AC)
   - Append change record at top or in change history:
     ```markdown
     > Change [date]: <one-line description of change>
     ```

   **5.2 Update design.md**
   - Modify affected interface definitions, data structures, module descriptions
   - Keep consistent with requirements.md

   **5.3 Update tasks.md**
   - Completed but affected tasks: mark back to `[ ]`, append note `<- needs redo due to requirement change`
   - Incomplete tasks needing description changes: modify directly
   - New tasks: append to corresponding Phase following existing format

   **5.4 Update UseCase docs (if project has usecases directory and behavior changes involved)**

6. **Output change summary**

   ```
   OK Requirement change synced

   Change: <one-line>
   Updated documents:
     OK requirements.md — modified N, added N
     OK design.md       — modified N entries
     OK tasks.md        — reverted N completed tasks, added N new tasks

   Remaining tasks: N (including reverts)

   Next: Run /tdd:loop to continue implementation
   ```

**Guardrails**
- Do not modify any files before step 4 user confirmation
- Completed tasks must be reverted if affected — no "good enough" shortcuts
- Change records must be written to requirements.md for traceability
- UseCase docs must be updated if visible behavior changes and project has usecases directory
- If change causes 10+ task reverts, additionally prompt user to consider a fresh `/tdd:ff`
