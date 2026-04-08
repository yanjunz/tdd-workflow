---
name: "TDD: Fast-Forward"
description: Fast-forward — generate requirements, design, tasks spec docs in one shot
category: TDD Workflow
tags: [tdd, workflow, spec]
---

Fast-forward: generate requirements -> design -> tasks in one shot.

**Input**: Feature name (optional, defaults to reading `tdd-specs/.current`)

**Steps**

1. **Confirm current feature**
   ```bash
   cat tdd-specs/.current 2>/dev/null || echo "No active spec"
   ```
   If no active spec, first run `/tdd:new`.

2. **Step 1: Review known Issues (if project has issues directory)**
   ```bash
   ls docs/issues/*.md 2>/dev/null | grep -v README || echo "No issues directory, skipping"
   grep -rl "<feature-keywords>" docs/issues/ 2>/dev/null || true
   ```
   If related records found, note issue IDs in requirements.md.

3. **Step 2: Update UseCase docs (if project has `docs/usecases/`, otherwise skip)**

   Add UseCase entries using EARS format:
   ```
   When <trigger>, the system shall <response>.
   While <precondition>, when <trigger>, the system shall <response>.
   ```

4. **Step 3: Generate `tdd-specs/<name>/requirements.md`** (reference template)

5. **Step 4: Generate `tdd-specs/<name>/design.md`** (reference template)

6. **Step 5: Generate `tdd-specs/<name>/tasks.md`** (reference template)

7. **Step 6: Test coverage check (mandatory, cannot skip)**

   After generating tasks.md, immediately verify all 3 test layers have tasks. If any layer has 0, **proactively add** before continuing:

   | Layer | Check | Gap-fill direction |
   |-------|-------|-------------------|
   | Unit tests | tasks.md has unit test tasks | Add pure function unit tests for core business logic |
   | Integration tests | tasks.md has integration test tasks covering key HTTP endpoint chains + DB write verification | Add: full chain (request -> response -> DB state); concurrency safety; permission boundaries |
   | E2E | Phase 3 has E2E tasks | Add key user flow end-to-end verification |

8. **Show summary, wait for confirmation**

**Output format**

```
OK requirements.md — N requirements, N acceptance criteria
OK design.md       — N modules, N interfaces
OK tasks.md        — Phase 2: N items / Phase 3: N items / Phase 4: N items
Issues reviewed: <related IDs or "none">

Ready! Run /tdd:loop to start TDD implementation.
```

**Guardrails**
- Verify each document file exists before continuing
- If file already exists, ask whether to overwrite
- UseCase docs must be updated before code files if they exist
