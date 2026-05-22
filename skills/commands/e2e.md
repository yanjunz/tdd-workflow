---
name: "TDD: E2E"
description: Phase 3 E2E acceptance tests — derive test cases from usecases.md paths, enforce UC coverage
category: TDD Workflow
tags: [tdd, e2e, usecase]
---

Phase 3: E2E 验收测试。**E2E 用例不再凭空发明，而是从 `usecases.md` 自动派生**——每个 UC 的每条路径对应一个 E2E。

**Steps**

### 1. 检测项目 E2E 框架 + 设置 harness phase

```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=e2e/' "tdd-specs/$SPEC/.harness"
fi
```

读取 `tdd-specs/.verify/project.md` 的 `endpoints` 配置，确定项目有哪些端（backend API、web frontend、mobile app 等）以及每端的 E2E 框架和命令。如无 `endpoints` 配置则检测项目实际框架：

```bash
# 自动检测（fallback）
cat package.json 2>/dev/null | grep -E '"(playwright|cypress|selenium|puppeteer|supertest|jest)"' || true
ls tests/e2e/ e2e/ playwright.config.* cypress.config.* 2>/dev/null || true
```

Determine test command and test file location based on results.

### 2. Pre-check 服务运行状态

按 `endpoints` 配置**逐端**执行 readiness 检查：

```bash
# 对每个 endpoint 执行其 readiness 命令
# 示例输出：
#   ✓ backend:     readiness passed
#   ✓ web-admin:   readiness passed
#   ✗ miniprogram: readiness failed — connection refused
```

**逐端输出结果**，明确列出每端状态。

**任何端 readiness 失败时，必须用 AskUserQuestion**（不能自行决定降级或跳过）：
> "`<endpoint>` 服务未就绪：`<错误信息>`。如何处理？"
> - [A] 我来启动，等我说好了继续
> - [B] 跳过此端 E2E（降级为 `fallback_cmd` 如有配置）
> - [C] 中止 /tdd:e2e

**全部端都失败** → 不要继续写测试，中止并提示用户启动服务。
**部分端失败** → 对失败的端逐个询问，通过的端正常继续。

### 3. 读取 usecases.md

```bash
cat tdd-specs/$SPEC/usecases.md
```

**如果 usecases.md 不存在** — 这是异常情况（应该是 `/tdd:ff` 产出的）：
- 询问用户：`[A] 先跑 /tdd:ff 生成 usecases.md` `[B] 降级为从 tasks.md Phase 3 派生（不推荐）`

### 4. 从 UseCase 派生 E2E 测试清单

**按端分组**：读取 `tdd-specs/.verify/project.md` 的 `endpoints` 配置。每个 UC 的步骤按涉及的端分组生成测试。

`endpoints` 配置示例（在 project.md 中定义，此处仅说明格式）：

```yaml
endpoints:
  <endpoint-name-1>:
    type: api          # api | browser | device
    framework: <项目选择的框架>
    test_dir: <测试文件目录>
    test_cmd: <运行命令>
  <endpoint-name-2>:
    type: browser
    framework: <项目选择的框架>
    test_dir: <测试文件目录>
    test_cmd: <运行命令>
  <endpoint-name-3>:
    type: device
    framework: <项目选择的框架>
    test_dir: <测试文件目录>
    test_cmd: <运行命令>
```

**如无 `endpoints` 配置**，默认只生成后端 API 端的 E2E 测试。

**按端分组规则**：

| UC 步骤涉及的端 | 测试类型 | 框架来源 |
|----------------|---------|---------|
| 后端服务（service/controller/API） | API E2E | `endpoints.<name>.framework`（type=api） |
| Web 页面（展示/交互） | 浏览器 E2E | `endpoints.<name>.framework`（type=browser） |
| 移动端/设备页面（展示/交互） | 设备 E2E | `endpoints.<name>.framework`（type=device） |

遍历每个 UC，为每条路径生成 E2E 测试，并标注属于哪个端：

| UC 路径 | E2E 测试 |
|---------|---------|
| UC-01 成功路径 | `UC-01: 用户发表评论（成功路径）` |
| UC-01 备选 3a | `UC-01: 发表评论 - 内容为空校验` |
| UC-01 备选 3b | `UC-01: 发表评论 - 内容超长校验` |
| UC-01 备选 4a | `UC-01: 发表评论 - 数据库失败恢复` |
| UC-02 成功路径 | `UC-02: 作者删除评论（成功路径）` |

**测试命名规则**：`UC-<N>: <路径简述>` — 方便从测试结果反查是哪个 UC 的哪条路径。

输出派生后的测试清单给用户确认（按端分组展示）：

```
从 usecases.md 派生 E2E 测试（按端分组）：

━━ <endpoint-1 名称>（<framework>） ━━
  UC-01: 成功路径 — <简述>
  UC-01: 备选 3a — <简述>
  UC-02: 成功路径 — <简述>

━━ <endpoint-2 名称>（<framework>） ━━
  UC-01: 成功路径 — <展示类步骤验证>
  UC-01: 备选 3b — <UI 错误提示验证>

━━ <endpoint-3 名称>（<framework>） ━━
  UC-03: 成功路径 — <设备端展示验证>

是否继续编写？ [Y/n]
```

### 5. UC 覆盖检查（mandatory，cannot skip）

对比 usecases.md 和生成的 E2E 清单：

- 每个 UC 的**成功路径**必须有 E2E
- 每个 UC 的**关键备选路径**（权限、校验、错误恢复）必须有 E2E
- 允许跳过的备选路径：纯内部错误（如"数据库偶发错误"）可以在单测覆盖，不必 E2E
- **展示类步骤必须有对应端的 E2E**（type=browser 或 type=device），不能只有 API E2E

如果有 UC 路径没 E2E 覆盖，**主动补上**，不要静默跳过。

### 6. 编写 E2E 测试

**按端分别编写**，遵循项目现有的测试结构和 `endpoints` 配置中指定的框架。

#### 6a. API 端 E2E（type=api）

- 文件位置：`endpoints.<name>.test_dir/<feature>.e2e-spec.*`
- 框架：由项目 `endpoints` 配置指定
- 验证：API 请求 → 响应结构 → 数据库/状态变化
- 适用：UC 中的业务逻辑、数据流转、错误处理

#### 6b. 浏览器端 E2E（type=browser）

- 文件位置：`endpoints.<name>.test_dir/<feature>.spec.*`
- 框架：由项目 `endpoints` 配置指定
- 验证：页面渲染、用户交互、UI 状态变化
- 适用：UC 中"用户在页面上看到 X""用户点击 Y 后出现 Z"的展示类步骤
- **必须覆盖展示类步骤**（不能只靠 API E2E 声称"前端也验证了"）

```javascript
// 示例：浏览器端 E2E（通用模式）
test('UC-03: 成功路径 — 列表展示特定列', async ({ page }) => {
  await loginAs(page, 'merchant');
  await page.goto('/orders');
  // 展示类步骤：验证 UI 元素可见
  await expect(page.locator('th:has-text("目标列名")')).toBeVisible();
  await expect(page.locator('td >> text=/预期格式/')).toBeVisible();
});
```

#### 6c. 设备端 E2E（type=device）

- 文件位置：`endpoints.<name>.test_dir/<feature>.*`
- 框架：由项目 `endpoints` 配置指定
- 验证：页面数据绑定、条件渲染、用户操作响应
- 适用：UC 中涉及移动端/设备页面的步骤
- 如设备端 E2E 环境不可用，降级为单元测试验证逻辑层

**通用编写规则**（所有端）：
- 使用项目的 E2E 框架（由 `endpoints` 配置确定）
- 测试描述用 `UC-<N>: <路径>` 格式
- 每个测试对应 usecases.md 里的一条路径
- 在测试注释里引用对应的 UC 步骤

示例（通用模式）：

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

  // UC-01 备选 3b 触发: 输入超过限制
  const longContent = 'x'.repeat(501);
  await page.fill('[data-testid="comment-input"]', longContent);
  await page.click('[data-testid="submit-btn"]');

  // UC-01 备选 3b 预期: 错误提示 + 保留输入
  await expect(page.locator('[data-testid="error-msg"]'))
    .toHaveText('最多 500 字');
  await expect(page.locator('[data-testid="comment-input"]'))
    .toHaveValue(longContent);
});
```

### 7. 运行 E2E 测试

**必须跑全量 E2E 套件（全端）**——按 `endpoints` 配置逐端执行 `test_cmd`，不只跑新增的，不只跑一个端。

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
| UseCase 路径 | 端 | E2E 测试文件:测试名 |
|--------------|---|---------------------|
| UC-01 成功路径 | backend | tests/e2e/comments.e2e-spec.ts: UC-01: 成功路径 |
| UC-01 成功路径 | web | tests/comments.spec.ts: UC-01: 提交后列表更新 |
| UC-01 备选 3b | web | tests/comments.spec.ts: UC-01: 内容超长校验 |
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

### Rule 5: Test name must reference UC

每个 E2E 测试的描述必须以 `UC-<N>: <路径>` 开头，便于追溯。未引用 UC 的测试视为违规，要求修正。

### Rule 6: Display steps must have browser/device E2E

UC 中涉及"用户看到 X""页面展示 Y""列表显示 Z"的展示类步骤，必须有对应的 browser 或 device 端 E2E 测试。不能仅靠 API E2E 断言返回值来声称"展示已验证"。

---

## Guardrails

- **usecases.md 是 E2E 的唯一来源** — 不从 tasks.md Phase 3 凭空展开
- **UC 路径覆盖不能跳过** — 每个 UC 的成功路径 + 关键备选都要有 E2E
- **按端分组生成** — UC 涉及多端时，每端都要有对应 E2E（按 `endpoints` 配置）
- **展示类步骤必须有浏览器/设备 E2E** — 不能只有 API E2E（Rule 6）
- **测试名必须引用 UC** — 方便从失败反查规范
- **服务没起来不写测试** — 避免测试本身失败
- **降级必须经用户同意** — 不能在 readiness 失败时自行决定"降级为 jest"或"跳过此端"，必须 AskUserQuestion
- **E2E 选择器优先用 `[data-testid]`** — 避免文本匹配脆弱
- **必须跑全量 E2E 套件（全端）** — 不只跑新增的，不只跑一个端
- **跳过的测试必须写 UC 引用的原因** — 方便后续补齐
- **框架和命令从 project.md 配置读取** — skill 本身不绑定任何特定框架
