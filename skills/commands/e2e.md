---
name: "TDD: E2E"
description: Phase 3 E2E acceptance tests — detect project E2E framework and run acceptance tests
category: TDD Workflow
tags: [tdd, e2e, playwright, cypress]
---

Phase 3: E2E acceptance tests.

**Steps**

1. **Detect project E2E framework**
   ```bash
   # Set harness phase to e2e
   if [ -f tdd-specs/.harness ]; then
     sed -i '' 's/phase=.*/phase=e2e/' tdd-specs/.harness
   fi
   grep -E '"playwright"|"cypress"|"selenium"|"puppeteer"' package.json 2>/dev/null || true
   ls tests/e2e/ e2e/ playwright.config.* cypress.config.* 2>/dev/null || true
   ```
   Determine test command and test file location based on results.

2. **Pre-check** (based on project's actual service address)
   ```bash
   curl -s http://localhost:<PORT>/health 2>/dev/null && echo "OK Service online" || echo "WARNING: Service not running, please start dev server first"
   ```
   Stop if service not running — do not continue writing tests.

3. **Add E2E acceptance test cases** (following project's existing test structure)

4. **Run E2E tests** (using project's actual command)
   Expected: all passing (including new cases).

5. **Fix failures** (Three-Strike Protocol applies)

6. **Update tasks.md Phase 3 status**

**After completion** prompt to run `/tdd:done` for delivery checklist.

---

## E2E Hard Rules

### Rule 1: Must cover real network layer
```javascript
// WRONG: Bypasses network layer entirely
page.evaluate(() => { window.__store__.state.status = 'done' })

// CORRECT: Trigger real user action
await page.click('[data-testid="submit-btn"]')
await expect(page.locator('[data-testid="success-msg"]')).toBeVisible()
```
Allow mocking: external devices or third-party services only. **Core business APIs must be called for real.**

### Rule 2: Skipped tests must have documented reasons
```javascript
// WRONG: Silent skip
test.skip('env not supported')

// CORRECT: Document reason
test.skip('Step N: [specific reason], restore after resolution')
```
**If accumulated skips exceed 3, must establish mock/stub environment — no more skip stacking.**

### Rule 3: Assert results after every key action
### Rule 4: Assert specific values for critical business fields

---

## Guardrails
- Stop if service not running — do not write tests
- E2E selectors prefer `[data-testid]` semantic attributes, avoid pure text matching (brittle)
- Must run full suite, not just individual test cases
