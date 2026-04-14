# Changelog

All notable changes to this project will be documented in this file.

## [1.1.1] — 2026-04-14 (unreleased)

### Changed

- **`/tdd:bug` 新增 Step 8 Retrospective（mandatory）** — 每个 bug 修复后强制反思：
  - 分类根因（5 种：设计缺陷 / 测试遗漏 / 代码模式 / 知识盲区 / 流程缺失）
  - 写具体防护措施（带 checkbox 的 action item）
  - 立即执行至少一项（不允许"以后再做"）
  - 搜索代码库中的同类问题，发现就一起修
- Bug 输出新增 `[Retro]` 状态行
- Guardrails 强化：回顾对所有 bug 强制，不限 High/Critical

## [1.1.0] — 2026-04-14 (unreleased)

### Added

- **TDD Harness hooks** — 从「建议」升级为「强制」
  - `PreToolUse (Write|Edit)`: RED 阶段写 src/ 文件会被 **exit 2 阻止**，只允许写测试文件和 tdd-specs/
  - `PreToolUse (Bash)`: 代码变更后未跑测试时输出提醒
  - `PostToolUse (Bash)`: 检测测试命令，自动追踪 PASS/FAIL，GREEN 阶段连续 3 次失败触发 Three-Strike Protocol
  - `PostToolUse (Write|Edit)`: 记录 last_edit_time 时间戳
  - `UserPromptSubmit`: 注入当前 phase / task / strikes 上下文
- **`.harness` 状态文件** — 每个功能目录独立一份（`tdd-specs/<name>/.harness`），记录 phase、task、strikes、时间戳
- 所有 9 个命令在适当位置设置 harness phase：
  - `new` → `requirements`（初始化 .harness）
  - `ff` → `spec`
  - `loop` → `red` / `green` / `refactor`（循环切换）
  - `bug` → `red`（复现测试）/ `green`（修复）
  - `e2e` → `e2e`
  - `done` → `deliver`
  - `continue` → 根据任务状态恢复 `red` 或 `green`
  - `change` → `spec`（暂停拦截）
  - `archive` → .harness 随功能目录一起归档

### Changed

- `.harness` 从全局单文件（`tdd-specs/.harness`）改为按功能隔离（`tdd-specs/<name>/.harness`），支持多功能并行开发
- SKILL.md hooks 全部重写，所有 hook 先读 `.current` 再定位对应功能的 `.harness`

## [1.0.0] — 2026-04-13

### Added

- 初始发布
- CLI 工具：`tdd-workflow init` 和 `tdd-workflow update`
- 支持 6 个 AI 工具：Claude Code、Cursor、Cline、Windsurf、CodeBuddy、GitHub Copilot
- 安装内容：SKILL.md + 3 个模板（requirements.md、design.md、tasks.md）+ 9 个斜杠命令
- `--tools`、`--delivery`、`--force` CLI 选项
- 交互式工具选择（自动检测已有工具目录）
- 自动创建 `tdd-specs/` 目录
