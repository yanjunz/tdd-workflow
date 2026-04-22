---
name: "TDD: Fast-Forward"
description: UseCase-first fast-forward — generate usecases.md as primary output, then derive requirements/design/tasks from it
category: TDD Workflow
tags: [tdd, workflow, spec, usecase]
---

UseCase-first 流程：先生成 `usecases.md`（主产出），然后从 UC 派生 requirements、design、tasks。

**关键变化**：usecases.md 是权威文档，其他三份都引用它。E2E 用例（`/tdd:e2e`）和 Stage 2 验证流程（`/tdd:done`）都从 usecases.md 派生。

**Input**: Feature name (optional, defaults to reading `tdd-specs/.current`)

---

## Steps

### 1. 确认 current feature + 设置 harness phase

```bash
cat tdd-specs/.current 2>/dev/null || echo "No active spec"
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=spec/' "tdd-specs/$SPEC/.harness"
fi
```

If no active spec, first run `/tdd:new`.

### 2. Review known Issues (if project has issues directory)

```bash
ls docs/issues/*.md 2>/dev/null | grep -v README || echo "No issues directory, skipping"
grep -rl "<feature-keywords>" docs/issues/ 2>/dev/null || true
```

If related records found, note issue IDs to reference in usecases.md / requirements.md.

### 3. 生成 `tdd-specs/<feature>/usecases.md`（主产出）

**这一步是整个流程的核心**。所有后续文档都引用 UseCase。

#### 3.1 读取 UC 草稿

```bash
cat tdd-specs/$SPEC/usecases.draft.md 2>/dev/null
```

这是 `/tdd:new` 从交互收集生成的 UC 框架草稿，作为生成 usecases.md 的输入。

#### 3.2 基于草稿生成完整 UseCase

参考 `templates/usecases.md` 模板，每个场景生成一个 UC，每个 UC **必须完整包含**：

| 字段 | 要求 |
|------|------|
| **主角色** (Actor) | 具体角色，不能用"用户"这种泛称 |
| **前置条件** (Precondition) | 执行该 UC 需要的状态 |
| **触发事件** (Trigger) | 什么动作启动这个 UC |
| **成功路径** (Success Path) | 至少 3 步，描述行为不描述实现 |
| **备选路径** (Alternative Paths) | 覆盖关键错误/校验失败/权限不足等 |
| **后置条件** (Postcondition) | 成功后的系统状态 |
| **相关数据** (Related Data) | 字段、约束、实体 |

#### 3.3 UC 内部编号

Feature 内部用 UC-01、UC-02 顺序编号。同步到项目级 `docs/usecases/` 时（`/tdd:done` Stage 4.2）会自动映射为全局编号。

#### 3.4 UC 覆盖度自检（mandatory）

生成后立即检查：
- 每个 `/tdd:new` 收集的核心场景都变成了至少一个 UC？
- 每个 UC 都有至少一个备选路径？（只有成功路径的 UC 说明错误处理考虑不足）
- 每个 Error handling 维度收集的错误都在某个 UC 的备选路径里？

缺失的主动补上，不向用户确认（补的是之前收集过的内容）。

### 4. 生成 `tdd-specs/<feature>/requirements.md`（从 UC 派生）

每个 REQ 必须**显式引用 UseCase**：

```markdown
### REQ-01 {{Requirement Name}}

**来源**: 由 UC-01, UC-02 派生

**User Story**: As a <role>, I want to <action>, so that <value>.

#### Acceptance Criteria (EARS Format)

1. When <trigger>, the system shall <response>.
   (对应 UC-01 成功路径步骤 2-4)
2. While <precondition>, when <trigger>, the system shall <response>.
   (对应 UC-01 备选 3b)
```

顶部维护 **UC → REQ 映射表**（放在 requirements.md 开头）：

```markdown
## UC → REQ 映射

| UseCase | Requirements |
|---------|-------------|
| UC-01 | REQ-01, REQ-02 |
| UC-02 | REQ-03 |
```

### 5. 生成 `tdd-specs/<feature>/design.md`（从 UC 派生）

每个接口/模块标注服务的 UC：

```markdown
### Interface: POST /api/comments

**支持的 UseCase**: UC-01 step 3 (系统写入评论), UC-01 备选 4a (写库失败处理)

**Request**: ...
**Response**: ...
```

Data flow 图要覆盖 UC 主路径（用箭头标注"对应 UC-01 step 2-5"）。

### 6. 生成 `tdd-specs/<feature>/tasks.md`（从 UC 派生）

Phase 2 **按 UC 分组**：

```markdown
## Phase 2: Unit Tests + Implementation

### UC-01 用户发表评论

#### 成功路径
- [ ] 2.1 comment-service: unit test — createComment happy path (Covers UC-01 step 3)
- [ ] 2.2 comment-service: implement createComment (Covers UC-01 step 3)
- [ ] 2.3 前端组件: 提交后追加到列表 (Covers UC-01 step 5)

#### 备选路径
- [ ] 2.4 comment-service: unit test — empty content validation (Covers UC-01 备选 3a)
- [ ] 2.5 comment-service: unit test — max length validation (Covers UC-01 备选 3b)
- [ ] 2.6 integration test: DB write failure handling (Covers UC-01 备选 4a)

### UC-02 作者删除评论

...
```

Phase 3 E2E 任务直接对应 UC 路径（下一步 `/tdd:e2e` 会自动从 usecases.md 派生具体测试）：

```markdown
## Phase 3: E2E Acceptance

- [ ] 3.1 E2E: UC-01 成功路径 (用户发表评论)
- [ ] 3.2 E2E: UC-01 备选 3b (评论超长校验)
- [ ] 3.3 E2E: UC-02 成功路径 (作者删除评论)
```

### 7. 测试覆盖检查（mandatory，cannot skip）

扩展检查：

| 层 | 原有检查 | 新增 UC 检查 |
|----|---------|------------|
| Unit tests | tasks.md 有单测任务 | 每个 UC 的主要步骤都有单测覆盖 |
| Integration tests | 有 HTTP 链路 + DB 写入测试 | 每个 UC 的成功路径有集成测试 |
| E2E | Phase 3 有 E2E 任务 | **每个 UC 的每条路径（成功+备选）都有 E2E 任务** |

如任何 UC 路径没有对应 task，**主动添加**。

### 8. Specification Review（Reviewer 自检）

在展示 summary 给用户前，按 `templates/review-checklist.md` 验证：

| 文档 | 检查 | 修复方向 |
|------|------|---------|
| usecases.md | 每个 UC 完整（主角色/前置/触发/成功/备选/后置） | 补全缺失字段 |
| usecases.md | 备选路径覆盖 Error handling 收集的所有错误 | 补备选路径 |
| requirements.md | 每个 REQ 有 UC 来源标注 | 补来源 |
| requirements.md | UC→REQ 映射表完整 | 补映射 |
| design.md | 每个接口标注支持的 UC | 补标注 |
| tasks.md | Phase 2 按 UC 分组 | 重组结构 |
| tasks.md | 每个 task 标注 "Covers UC-N ..." | 补标注 |
| 跨文档 | 每个 UC 都有对应的 REQ + tasks + E2E task | 补缺失项 |

有问题就修，不要直接给用户看有 bug 的产出。

### 9. Show summary, wait for confirmation

**Output format**（扩展）：

```
OK usecases.md     — N UseCases, M alternative paths (主产出)
OK requirements.md — N requirements (from UC), N acceptance criteria
OK design.md       — N modules, N interfaces (supporting UC-01..UC-N)
OK tasks.md        — Phase 2: N tasks / Phase 3: N E2E tasks
Issues reviewed: <IDs or "none">

UC Coverage:
  UC-01 用户发表评论 → REQ-01,02 | Tasks 2.1-2.6 | E2E 3.1-3.2
  UC-02 作者删除评论 → REQ-03 | Tasks 2.7-2.8 | E2E 3.3

Ready! Run /tdd:loop to start TDD implementation.
```

---

## Guardrails

- **usecases.md 必须先生成**，后续三份文档必须引用 UC
- **UC 内部编号**用 UC-01/UC-02（Feature 内部局部编号），不用项目级全局编号
- **Step 3 不能跳过** — 没有 usecases.md 就不能开始后续步骤
- **UC 必须完整** — 缺字段的 UC 会导致派生的文档也不完整
- **每个 UC 必须有至少一个备选路径** — 只有 happy path 的 UC 说明错误处理考虑不足
- **派生文档必须显式引用 UC** — 不能有"飞来"的 REQ 或 task（不知道对应哪个 UC）
- **文件已存在时询问是否覆盖** — 不要悄悄覆盖用户的修改
- **UseCase docs must be updated before code files if they exist** — 实现开始前必须冻结 UC
