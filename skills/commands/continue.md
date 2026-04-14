---
name: "TDD: Continue"
description: Resume in-progress feature from last checkpoint
category: TDD Workflow
tags: [tdd, workflow, continue]
---

Resume in-progress feature.

**Input**: Feature name (optional, defaults to reading `tdd-specs/.current`)

**Steps**

1. **Determine which spec to resume**
   ```bash
   # Check current active spec
   cat tdd-specs/.current 2>/dev/null

   # Or list all in-progress specs
   ls tdd-specs/ | grep -v "^archive$\|^\.current$"
   ```

2. **Read task progress**
   ```bash
   SPEC=<name>
   echo "$SPEC" > tdd-specs/.current
   cat tdd-specs/$SPEC/tasks.md
   ```

3. **Find first incomplete task and set harness phase**
   - `[ ]` -> Set phase to red: `SPEC=$(cat tdd-specs/.current); sed -i '' 's/phase=.*/phase=red/' "tdd-specs/$SPEC/.harness"` -> Start from `/tdd:red`
   - `[~]` -> Set phase to green: `SPEC=$(cat tdd-specs/.current); sed -i '' 's/phase=.*/phase=green/' "tdd-specs/$SPEC/.harness"` -> Start from `/tdd:green` (test written, implementation incomplete)
   - `[!]` -> Start from blocked decision (Three-Strike Protocol pending)

4. **Output recovery summary**
   ```
   Resumed: tdd-specs/<name>/
   Completed: N/M tasks
   Current phase: Phase X
   Next step: <task description>
   Run /tdd:loop to continue implementation.
   ```
