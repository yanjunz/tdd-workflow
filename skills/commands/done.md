---
name: "TDD: Done"
description: Phase 4 delivery — full regression + Issue tracking + delivery checklist
category: TDD Workflow
tags: [tdd, done, delivery]
---

Phase 4: Delivery verification. Every check must pass before continuing.

**Steps**

0. **Compilation verification (mandatory for compiled languages)**

   If project has compilation step (TypeScript, Java, Go, Rust, etc.), check if source is newer than artifacts:
   ```bash
   # TypeScript example:
   find src -name "*.ts" -newer dist/main.js 2>/dev/null
   # Output exists -> must recompile and verify clean before continuing
   # No output -> skip
   ```

1. **Full unit tests** (using project's actual command)
   ```bash
   <TEST_COMMAND> --coverage 2>&1 | tail -30
   ```
   Expected: all passing, new feature coverage >= 80% (or project target).

2. **Full regression** (if project has regression scripts)

3. **E2E** (if applicable, using project's actual E2E command)

4. **Issue tracking judgment**

   Must create Issue document if ANY of:
   - Bug fix took > 5 minutes
   - Same type of error occurred more than once
   - Fix spans 2+ files

5. **Delivery checklist**
   ```
   [ ] Compilation clean (if applicable)
   [ ] All tests passing, coverage >= 80% (or project target)
   [ ] Full regression passing (if project has regression scripts)
   [ ] E2E tests passing (if applicable)
   [ ] Feature docs updated (if project has usecases/docs directory)
   [ ] Issues logged (if qualifying bugs found)
   [ ] Environment variable examples synced (if new env vars added)
   [ ] tdd-specs/<name>/tasks.md all [x]
   ```

6. **Output delivery report**

   ```markdown
   ## Delivery Report — <feature-name>

   ### Implementation
   - Added: <file list>
   - Modified: <file list>

   ### Tests
   - New unit tests: N PASS
   - New integration tests: N PASS
   - New E2E: N PASS (if applicable)
   - Full regression: PASS

   ### Documentation
   - Specs: tdd-specs/<name>/ OK
   - Issues: <IDs or "none this time">
   ```

7. **Prompt to run `/tdd:archive` to archive specs**

**Guardrails**
- Compilation verification cannot be skipped for compiled languages with build artifacts
- Stop if any check fails — do not output delivery report
- Issue tracking is mandatory, cannot skip
