---
name: "TDD: E2E"
description: Phase 3 E2E acceptance tests — derive test cases from usecases.md paths, enforce UC coverage
category: TDD Workflow
tags: [tdd, e2e, usecase, playwright, cypress]
---

Phase 3: E2E 验收测试。**E2E 用例不再凭空发明，而是从 `usecases.md` 自动派生**——每个 UC 的每条路径对应一个 E2E。

**Steps**

### 1. 检测项目 E2E 框架 + 设置 harness phase

```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=e2e/' "tdd-specs/$SPEC/.harness"
fi
grep -E '"playwright"|"cypress"|"selenium"|"puppeteer"' package.json 2>/dev/null || true
ls tests/e2e/ e2e/ playwright.config.* cypress.config.* 2>/dev/null || true
```

Determine test command and test file location based on results.

### 2. Pre-check 服务运行状态

```bash
curl -s http://localhost:<PORT>/health 2>/dev/null && echo "OK Service online" || echo "WARNING: Service not running, please start dev server first"
```

**服务没起来就停** — 不要继续写测试。

### 3. 读取 usecases.md

```bash
cat tdd-specs/$SPEC/usecases.md
```

**如果 usecases.md 不存在** — 这是异常情况（应该是 `/tdd:ff` 产出的）：
- 询问用户：`[A] 先跑 /tdd:ff 生成 usecases.md` `[B] 降级为从 tasks.md Phase 3 派生（不推荐）`

### 4. 从 UseCase 派生 E2E 测试清单

遍历每个 UC，为每条路径生成一个 E2E 测试：

| UC 路径 | E2E 测试 |
|---------|---------|
| UC-01 成功路径 | `UC-01: 用户发表评论（成功路径）` |
| UC-01 备选 3a | `UC-01: 发表评论 - 内容为空校验` |
| UC-01 备选 3b | `UC-01: 发表评论 - 内容超长校验` |
| UC-01 备选 4a | `UC-01: 发表评论 - 数据库失败恢复` |
| UC-02 成功路径 | `UC-02: 作者删除评论（成功路径）` |

**测试命名规则**：`UC-<N>: <路径简述>` — 方便从测试结果反查是哪个 UC 的哪条路径。

输出派生后的测试清单给用户确认：

```
从 usecases.md 派生 8 个 E2E 测试：

UC-01 用户发表评论 (4 个)
  ✓ UC-01: 成功路径
  ✓ UC-01: 内容为空校验 (备选 3a)
  ✓ UC-01: 内容超长校验 (备选 3b)
  ✓ UC-01: DB 失败恢复 (备选 4a)

UC-02 作者删除评论 (3 个)
  ✓ UC-02: 成功路径
  ✓ UC-02: 非作者无权限 (备选 3a)
  ✓ UC-02: 已删除再次删除 (备选 4a)

UC-03 访客查看评论列表 (1 个)
  ✓ UC-03: 成功路径

是否继续编写？ [Y/n]
```

### 5. UC 覆盖检查（mandatory，cannot skip）

对比 usecases.md 和生成的 E2E 清单：

- 每个 UC 的**成功路径**必须有 E2E
- 每个 UC 的**关键备选路径**（权限、校验、错误恢复）必须有 E2E
- 允许跳过的备选路径：纯内部错误（如"数据库偶发错误"）可以在单测覆盖，不必 E2E

如果有 UC 路径没 E2E 覆盖，**主动补上**，不要静默跳过。

### 6. 编写 E2E 测试

遵循项目现有的测试结构：
- 使用项目的 E2E 框架（Playwright/Cypress 等）
- 测试描述用 `UC-<N>: <路径>` 格式
- 每个测试对应 usecases.md 里的一条路径
- 在测试注释里引用对应的 UC 步骤

示例（Playwright）：

```javascript
// UC-01 用户发表评论 - 成功路径
test('UC-01: 成功路径 - 用户发表评论', async ({ page }) => {
  // UC-01 前置条件: 用户已登录
  await login(page, 'test@test.com', 'pwd');
  await page.goto('/posts/1');

  // UC-01 step 1-2: 用户输入内容
  await page.fill('[data-testid="comment-input"]', '这是一条测试评论');
  
  // UC-01 step 3: 用户点击"发表"
  await page.click('[data-testid="submit-btn"]');

  // UC-01 step 5 + 后置条件: 评论出现在列表
  await expect(page.locator('[data-testid="comment-list"]'))
    .toContainText('这是一条测试评论');
});

// UC-01 备选 3b - 内容超长校验
test('UC-01: 内容超长校验 (备选 3b)', async ({ page }) => {
  await login(page, 'test@test.com', 'pwd');
  await page.goto('/posts/1');

  // UC-01 备选 3b 触发: 输入超过 500 字
  const longContent = 'x'.repeat(501);
  await page.fill('[data-testid="comment-input"]', longContent);
  await page.click('[data-testid="submit-btn"]');

  // UC-01 备选 3b 预期: 提示"最多 500 字"，保留输入
  await expect(page.locator('[data-testid="error-msg"]'))
    .toHaveText('最多 500 字');
  await expect(page.locator('[data-testid="comment-input"]'))
    .toHaveValue(longContent);
});
```

### 7. 运行 E2E 测试

Expected: 全部通过（包括新增用例）。

### 8. 修复失败（Three-Strike Protocol 适用）

E2E 失败时的排查优先级：
1. **实现 bug** — 代码和 UC 描述不符
2. **UC 描述错误** — UC 本身描述的行为不对（需要 `/tdd:change` 先改 UC）
3. **测试问题** — 选择器、时序、环境等

Three-Strike 触发时，优先考虑 UC 本身是否正确（回到 `/tdd:change` 修改 UC）。

### 9. 更新 tasks.md Phase 3 状态

每个完成的 E2E 测试对应 Phase 3 里的一个 task，标记为 `[x]`。

### 10. 更新 usecases.md 映射表

在 usecases.md 的 "UC → E2E 映射" 表里记录每个测试的实际位置：

```markdown
| UseCase 路径 | E2E 测试文件:测试名 |
|--------------|---------------------|
| UC-01 成功路径 | tests/e2e/comments.spec.ts: UC-01: 成功路径 |
| UC-01 备选 3b | tests/e2e/comments.spec.ts: UC-01: 内容超长校验 |
```

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

Allow mocking: **外部设备或第三方服务 only**。**核心业务 API 必须真实调用**。

### Rule 2: Skipped tests must have documented reasons

```javascript
// WRONG: Silent skip
test.skip('env not supported')

// CORRECT: Document reason with UC reference
test.skip('UC-01 备选 4a: DB 失败恢复 - 本地环境无法模拟 DB 故障，需要在 staging 用故障注入测试')
```

**如果累计跳过超过 3 个，必须搭建 mock/stub 环境解决** — 不再累积跳过。

### Rule 3: Assert results after every key action

每个关键动作后必须断言结果，不能只点击不验证。

### Rule 4: Assert specific values for critical business fields

关键业务字段断言具体值（不只是 truthy/存在）。

### Rule 5: Test name must reference UC (新增)

每个 E2E 测试的描述必须以 `UC-<N>: <路径>` 开头，便于追溯。未引用 UC 的测试视为违规，要求修正。

---

## Guardrails

- **usecases.md 是 E2E 的唯一来源** — 不从 tasks.md Phase 3 凭空展开
- **UC 路径覆盖不能跳过** — 每个 UC 的成功路径 + 关键备选都要有 E2E
- **测试名必须引用 UC** — 方便从失败反查规范
- **服务没起来不写测试** — 避免测试本身失败
- **E2E 选择器优先用 `[data-testid]`** — 避免文本匹配脆弱
- **必须跑全量 E2E 套件** — 不只跑新增的
- **跳过的测试必须写 UC 引用的原因** — 方便后续补齐
