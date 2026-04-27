# Changelog

All notable changes to this project will be documented in this file.

## [2.4.4] — 2026-04-28

### Fixed

- **严重 bug**: `.current` 文件含前导或尾部换行（比如被编辑器自动加换行、或 /tdd:new 写入时误加）时，`SPEC` 被读成 `\nfoo` 或 `foo\n`，拼出的 harness 路径含换行符 → `[ ! -f "$H" ]` 判定 "无 harness" → hook 完全静默放行。相当于 RED 阻断、Strike 计数全部失效。
  - 修复：所有 5 个脚本的 `SPEC=$(cat tdd-specs/.current)` 统一加 `| tr -d '\r\n'`
  - 这也顺便修了日志里出现的 "spec=\nbackend-test-coverage" 多行显示
- **post-bash 大 payload 处理**：原实现 `INPUT=$(cat)` + `printf '%s' "$INPUT" | jq` 把整个 tool_response（可能是 MB 级的 `lsof` / `grep` 输出）装入 shell 字符串变量再 fork 给 jq，慢且占内存。改为**先 buffer 到临时文件**，jq 直接从文件读。1MB payload 从未测数据 → 0.13s 完成。
  - `INPUT_BYTES` 也记入日志，方便诊断"是不是 payload 太大"

### Changed

- post-bash.sh 重构：用临时文件 + `jq < $TMP` 替代内存字符串；trap 清理；保持功能等价。其他 4 个脚本维持 `INPUT=$(cat)` 方案（它们的 payload 小，不需要）

## [2.4.3] — 2026-04-27

### Changed

- Hook 诊断日志覆盖全部 5 个脚本，每条记录都包含足够的上下文定位问题：
  - `pre-bash.sh`: 记录 `spec / phase / cmd`（命令头 120 字符）
  - `post-bash.sh`: 记录 `cmd / output_len / 是否识别为 test-like / sed 操作（updated/appended）/ strike 计数变化 / THREE-STRIKE 提醒`
  - `pre-write-edit.sh`（新增日志）: 记录 `tool / phase / file_path / 分支决策（RED+test-like/RED+tdd-specs/BLOCK(2)/allow）`
  - `post-write-edit.sh`: 记录 `tool / file / success / spec / last_edit_time 操作`
  - `user-prompt-submit.sh`（新增日志）: 记录 `spec / phase / task / strikes / tasks.md 状态`
- 日志文件 `/tmp/tdd-hook-{pre,post}-{bash,write-edit}.log` 和新增的 `/tmp/tdd-hook-pre-write-edit.log`、`/tmp/tdd-hook-user-prompt-submit.log`
- 仍可通过 `TDD_HOOK_DEBUG=0` 关闭日志（`test/hooks-verify.sh` 默认关闭）

### Fixed

- `test/hooks-verify.sh`: 测试用的 src/test 文件路径不再依赖 `$PWD`，改用固定的 `/var/tmp/tdd_verify_*`，避免 CWD 里含 "test" 子串时 pre-write-edit RED 分支被误判为测试文件

## [2.4.2] — 2026-04-27

### Fixed

- **Hook scripts 不再触发 "PreToolUse/PostToolUse:Bash hook error" 噪音**
  - 根因 1：旧脚本读 `$CLAUDE_TOOL_INPUT` / `$CLAUDE_FILE_PATH` 环境变量，Claude Code 实际把 hook 事件 JSON 从 **stdin** 传入，这些变量根本不存在；改为 `jq -r '.tool_input.command'` 从 stdin 读
  - 根因 2：Pre/PostToolUse hook 往 stdout `echo` 提醒文字，而 Claude Code 只对 `UserPromptSubmit` / `SessionStart` / `UserPromptExpansion` 事件读 stdout。其他事件的 stdout 在某些执行路径上会触发 SIGPIPE / EPIPE，被 UI 渲染成 "hook error"。现在 Pre/PostToolUse hook 完全静默，提醒信息只写到 `/tmp/tdd-hook-*.log` 诊断文件
  - 根因 3：`sed -i''`（无空格）在 macOS BSD sed 上报错；改为 `sed -i ''` 形式，并加 GNU sed 的 fallback
- `pre-write-edit.sh` 的 RED 阻断逻辑保留（`exit 2` + stderr 反馈是合法的通道）
- 所有 hook 脚本统一：`set +e` + stdin JSON 读取 + 失败路径 `exit 0` 不阻断 Claude

### Added

- `test/hooks-verify.sh` — hook 脚本单元测试 (16 assertions)：覆盖 non-test cmd、RED 阻断、GREEN 放行、strike 计数递增/重置、`last_edit_time` 更新、UserPromptSubmit stdout context 输出、Pre/Post stdout 静默
  - 源仓库开发时跑：`bash test/hooks-verify.sh`
  - 已安装项目跑：`bash test/hooks-verify.sh .claude/hooks/tdd`
- 诊断日志：默认写 `/tmp/tdd-hook-{pre,post}-{bash,write-edit}.log`，通过 `TDD_HOOK_DEBUG=0` 关闭

### Changed

- Hook 脚本约定：Pre/PostToolUse 事件**不得**往 stdout 写入任何字符，所有诊断/提醒改走日志文件
- SKILL.md / 命令文档不改动

## [2.4.1] — 2026-04-20

### Added

- **项目文档路径可配置** — `docs/usecases/` 和 `docs/issues/` 不再硬编码，改由 `tdd-specs/.verify/project.md` 的 `paths:` 节统一管理
  - 新增 `paths.usecases`：`enabled` / `dir` / `index_file` / `numbering`（`auto` | `feature_local` | `manual`） / `external_tool` / `external_url`
  - 新增 `paths.issues`：`enabled` / `dir` / `index_file` / `numbering`（`auto` | `manual`） / `filename_pattern` / `external_tool` / `external_url`
  - 没有 `project.md` 或缺 `paths:` 节时自动回退到默认 `docs/usecases/` 与 `docs/issues/`（向后兼容，现有项目无需改动）
- **外部工具模式** — 当 `enabled: false` 时，`/tdd:bug` / `/tdd:done` / `/tdd:change` 会改为输出内容 + 提示用户去 `external_url` 手动同步（适合 Jira、Confluence、Notion、飞书等由外部工具管理的项目）
- **`/tdd:verify-setup` Phase F** — 交互式收集 UC/Issue 目录、编号策略、外部工具链接

### Changed

- `/tdd:ff` Step 2 读取 `paths.issues.dir` 查找 Issue，外部工具模式改为提示搜索链接
- `/tdd:bug` 开头新增 "Config Loading"，Issue 创建路径和 index_file 路径从 paths 读，外部工具模式只输出内容等用户手动创建
- `/tdd:done` Stage 4.2 同步目标从 `paths.usecases.dir` 读，外部工具模式输出 UC 内容提示手动更新
- `/tdd:change` 同步策略提示按 `paths.usecases.enabled` 分支，外部模式默认走"待同步"
- `/tdd:archive` UC 同步状态检查按 paths 配置提示
- `skills/SKILL.md` 所有硬编码 `docs/issues/` / `docs/usecases/` 改为从 paths 读，保留 fallback 默认值说明

### Fixed

- 文档目录不是 `docs/` 的项目（如用 `documentation/`、`spec/`）之前无法配置，现在通过 `paths:` 节可以任意指定

## [2.4.0] — 2026-04-22

### Added

- **UseCase-First 工作流** — 把 UseCase 提升为 `/tdd:ff` 的主产出，其他三份从 UC 派生
  - `templates/usecases.md` — UseCase 文档模板（主角色/前置/触发/成功路径/备选路径/后置/相关数据 + UC→REQ/Tasks/E2E 映射表）
  - `/tdd:new`：第 2 维度"核心场景"扩展为收集 UC 框架（角色/触发/关键步骤），创建 `usecases.draft.md` 作为 `/tdd:ff` 的输入
  - `/tdd:ff` 重写为 UseCase-first：
    - Step 3 生成 `usecases.md`（主产出），每个 UC 必须完整 6 字段
    - Step 4-6 的 requirements.md / design.md / tasks.md 从 UC 派生，显式引用 UC 编号
    - tasks.md 按 UC 分组，每个 task 标注 `Covers UC-N step M`
    - Step 7 覆盖检查扩展：每个 UC 的每条路径（成功+备选）必须有 Phase 2/3 task
- **`/tdd:e2e` 从 UseCase 派生 E2E**
  - 不再让 AI 凭空发明 E2E 用例，直接从 `usecases.md` 的每条路径派生一个 E2E
  - 测试命名强制格式：`UC-<N>: <路径描述>`，便于从测试结果反查 UC
  - 新增 Rule 5：测试名必须引用 UC
  - 完成后自动更新 usecases.md 的 "UC → E2E 映射" 表
- **`/tdd:change` 影响分析加 UseCase 维度**
  - 影响分析输出中 "Affected UseCases" 放最前面，然后 cascade 到 requirements / design / tasks
  - Step 5 执行变更时先改 `usecases.md`，再 cascade 到其他文档
  - 检测 `usecases.synced.md` 判断 UC 是否已同步到 `docs/usecases/`，给出同步策略选项（标记待同步/立即同步/只改 tdd-specs）
- **`/tdd:done` Stage 4.2 交互式同步 UseCase 到 docs/usecases/**
  - 新增 Stage 4.2：检查 `docs/usecases/` 现状，用 AskUserQuestion 询问同步方式（创建新文件/追加/拆分/跳过）
  - 处理 UC 编号映射：Feature 内 UC-01 → 项目级 UC-025（根据 docs/ 现有最大编号自动递增）
  - 生成 `tdd-specs/<feature>/usecases.synced.md` 记录每次同步（target、UC 映射、commit、触发来源）
  - 提示用户单独 commit UC 同步改动，便于追溯
- **`/tdd:archive` 归档前 UC 同步检查**
  - 如果 `usecases.md` 存在但 `usecases.synced.md` 不存在，提示用户选择：先同步再归档 / 直接跳到同步步骤 / 跳过同步
  - 归档时 `docs/usecases/*.md` 保持不动（项目长期文档），`usecases.md` 随 feature 目录归档

### Changed

- `/tdd:new` 创建 `tdd-specs/<name>/usecases.draft.md`（之前无 UC 产出）
- SKILL.md 命令表标注 `/tdd:ff` 为 UseCase-first、`/tdd:e2e` 从 UC 派生、`/tdd:done` 包含 UC 同步、`/tdd:archive` 检查同步状态
- README 新增 "UseCase-First 工作流" 章节说明

### Decisions

- **UC 编号规则**：Feature 内部 UC-01/02/03（局部编号），同步到 `docs/usecases/` 时自动映射为项目级连续编号
- **同步时机**：`/tdd:done` Stage 4.2 交互式同步（不引入独立 sync 命令，保持命令数量最小）
- **文档语言**：混合风格（字段名英文、描述中文），与现有 requirements/design/tasks 一致
- **归档边界**：`docs/usecases/` 是项目长期文档不动，`tdd-specs/` 整体归档

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
