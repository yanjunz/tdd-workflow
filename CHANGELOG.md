# Changelog

All notable changes to this project will be documented in this file.

## [2.3.0] — 2026-04-21

### Added

- **Verification System** — 项目级 + Feature 级分层验证，解决「AI 自述验证」问题
  - `/tdd:verify-setup` — 交互式生成 `tdd-specs/.verify/project.md`（团队共享配置）
    - 检测项目技术栈自动推荐 commands、cleanup、environments
    - **帮用户生成 staging 部署脚本骨架**（SSH/K8s/Vercel/Docker/CI 等方案）
    - 识别 `${VAR}` 占位符，区分个人参数/敏感参数/团队共享
  - `/tdd:verify-local` — 交互式填写 `tdd-specs/.verify/project.local.md`（gitignored）
    - 敏感参数优先引导用 shell env / 1Password CLI，不写入文件
    - 基础值验证（URL、端口、邮箱格式）
  - `/tdd:cleanup [env]` — 手动触发环境清理，不跑验证本身
    - 支持 dry-run 预览
    - 按 on_fail 策略处理失败（continue/abort/ask）
- **`/tdd:done` 重写为 4 阶段验证**
  - Stage 1: 本地代码验证（typecheck/lint/build/unit/integration/coverage，全自动）
  - Stage 2: 本地 E2E（pre-cleanup → 启动 dev server → 执行 common_flows + feature flows → 用户逐个确认 → post-cleanup）
  - Stage 3: 测试环境（可选，deploy → readiness → smoke tests）
  - Stage 4: 交付确认 + 生成 `verification-report.md`
  - 混合交互：Stage 之间用 AskUserQuestion（Y/N/Skip），Stage 内用自由回复
  - 支持 `--skip-stage 2,3` 和 `--dry-run`
- **Cleanup 预设库** — `skills/verify-presets/cleanup.md`
  - 8 个内置预设：kill_port、kill_node_process、docker_compose_down、docker_container_rm、reset_db、clean_tmp_files、clear_redis、git_clean
  - 支持 on_fail、timeout、condition、parallel 字段
  - 幂等性要求
- **Feature 级 verify.md** — 每个 feature 可以定义独有的验证流程
  - `/tdd:new` 需求收集最后一步询问 feature 特有的验证需求
  - 只写项目级 `common_flows` 没覆盖的部分，避免重复
  - 支持 `depends_on_project_verify` 和 `skip_project_checks`
- **`.harness` 新增字段**
  - `verify_stage` (0-5) — 当前验证阶段
  - `verify_local_ok` / `verify_staging_ok` — 各阶段通过状态
- **installer.ts** 自动复制 `skills/verify-presets/`，创建 `tdd-specs/.verify/`，自动把 `project.local.md` 加入 `.gitignore`

### Changed

- SKILL.md 命令表新增 `verify-setup`、`verify-local`、`cleanup`
- `/tdd:new` 需求收集维度增加「feature 特有验证」

## [1.2.0] — 2026-04-16

### Added

- **Multi-Agent Architecture (Phase 1)** — Coder/Reviewer 分离
  - `/tdd:loop`: RED 和 GREEN 阶段通过 Agent 工具 spawn Coder 子 agent 写代码，主 agent 作为 Reviewer 独立评审
  - `/tdd:bug`: Step 5 (RED) 和 Step 6 (GREEN) 同样使用 Coder sub-agent
  - `/tdd:ff`: 新增 Step 8 Specification Review，生成规范后 Reviewer 自检质量
  - `templates/review-checklist.md`: Reviewer 评审标准文档（测试评审、实现评审、规范评审、bug 修复评审）
- Coder Agent 的上下文不包含评审标准，只知道任务描述，无法自我放水
- Coder 产出如果两次评审不通过，升级给用户决策
- **跨工具兼容降级** — 非 Claude Code 工具（Cursor、CodeBuddy、Cline 等）自动降级为单 Agent + 强制 self-review，输出 `[Review:RED]` `[Review:GREEN]` checklist 结果
- **Hooks 迁移至 settings.json** — SKILL.md frontmatter hooks 不被 Claude Code 执行，改为独立 shell 脚本 + `.claude/settings.json` 注册
  - 5 个 hook 脚本安装到 `.claude/hooks/tdd/`
  - `init` 时自动 merge hooks 配置到 settings.json，不覆盖用户已有设置
  - `sed -i''` 兼容 macOS 和 Linux

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
