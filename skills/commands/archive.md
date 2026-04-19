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

2. **Archive**
   ```bash
   SPEC=$(cat tdd-specs/.current)
   MONTH=$(date +%Y-%m)
   mkdir -p tdd-specs/archive/$MONTH
   mv tdd-specs/$SPEC tdd-specs/archive/$MONTH/
   echo "" > tdd-specs/.current
   echo "OK Archived to tdd-specs/archive/$MONTH/$SPEC/"
   ```

3. **Output**
   ```
   OK Archived: tdd-specs/archive/<YYYY-MM>/<name>/
   tdd-specs/.current cleared, ready for next feature.
   Run /tdd:new <next-feature> to begin.
   ```
