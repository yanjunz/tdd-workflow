# UseCases — {{FEATURE_NAME}}

> Created: {{DATE}}
> Status: draft
> Feature: {{FEATURE_NAME}}
> Synced to docs/: No (see usecases.synced.md when synced)

## 文档目的

这份 UseCase 文档是 `/tdd:ff` 的**主产出**，描述用户视角的完整交互故事。其他三份文档（requirements.md / design.md / tasks.md）都从这里派生。

Feature 内部使用 UC-01、UC-02 等局部编号；`/tdd:done` Stage 4.2 同步到项目级 UC 目录（由 `paths.usecases.dir` 配置，默认 `docs/usecases/`）时自动映射为项目全局编号。

---

## UC-01 {{UseCase 名称}}

**主角色** (Actor): {{role, e.g. 已登录用户}}
**前置条件** (Precondition): {{precondition, e.g. 用户已登录且在文章详情页}}
**触发事件** (Trigger): {{trigger, e.g. 用户点击"发表评论"按钮}}

### 成功路径 (Success Path)

1. {{actor}} {{action}}
2. {{system}} {{response}}
3. {{actor}} {{action}}
4. {{system}} {{response}}
5. {{system}} {{final outcome}}

### 备选路径 (Alternative Paths)

**3a.** {{condition, e.g. 内容为空}}
  → {{alternative outcome, e.g. 系统提示"请输入内容"，停留输入框}}

**3b.** {{condition, e.g. 内容超过 500 字}}
  → {{alternative outcome, e.g. 系统提示"最多 500 字"，高亮超出部分}}

**4a.** {{error scenario, e.g. 数据库写入失败}}
  → {{error handling, e.g. 显示"提交失败，请重试"，保留输入内容}}

### 后置条件 (Postcondition)

{{system state after success, e.g. 新评论已写入数据库，前端列表已更新}}

### 相关数据 (Related Data)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| {{field}} | {{type}} | {{constraint}} | {{description}} |

---

## UC-02 {{UseCase 名称}}

（重复上述结构）

---

## 派生映射（Derivation Mappings）

以下映射由 `/tdd:ff` 和 `/tdd:change` 自动维护，便于追溯每个 UseCase 的实现状态。

### UC → REQ 映射

| UseCase | Requirements |
|---------|-------------|
| UC-01 | REQ-01, REQ-02 |
| UC-02 | REQ-03 |

### UC → Phase 2 Tasks 映射

| UseCase 路径 | Tasks |
|--------------|-------|
| UC-01 成功路径 | 2.1, 2.2, 2.3 |
| UC-01 备选 3a | 2.4 |
| UC-01 备选 3b | 2.5 |
| UC-01 备选 4a | 2.6 |
| UC-02 成功路径 | 2.7, 2.8 |

### UC → E2E 映射（Phase 3）

| UseCase 路径 | E2E 测试 |
|--------------|----------|
| UC-01 成功路径 | 3.1 |
| UC-01 备选 3b | 3.2 |
| UC-02 成功路径 | 3.3 |

---

## 变更记录 (Change Log)

（由 `/tdd:change` 自动追加）

<!-- Example:
## 2026-04-25
- UC-01 step 6 修改：评论追加到列表时需要渲染 Markdown
- 新增 UC-01 备选 3c：Markdown 语法错误提示
- 影响 REQ-01, 任务 2.2, 2.5
-->

---

## 写作指南

### UseCase 质量标准

- **主角色必须明确**：用"已登录用户"而不是"用户"，用"管理员"而不是"角色"
- **成功路径至少 3 步**：少于 3 步说明场景过于简单，可能不需要独立 UC
- **备选路径覆盖关键错误**：校验失败、权限不足、外部依赖失败等
- **描述行为不描述实现**："系统校验长度" 而非 "调用 validateLength()"
- **每步都可观察**：用户或测试能确认"这一步发生了"

### 什么不该是 UseCase

- ❌ 纯内部过程（"数据库写入"——这是实现细节）
- ❌ 跨功能的通用流程（"登录"应放项目级 `docs/usecases/`，不在单个 feature 里重复）
- ❌ 太粗的粒度（"用户管理"——应拆成"创建用户"、"删除用户"等独立 UC）
