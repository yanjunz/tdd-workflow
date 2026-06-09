# Changelog

All notable changes to this project will be documented in this file.

## [3.13.1] — 2026-06-09

### Added

- **`SKILL.md` 新增 `## Test Output Frugality` 段** — 列出 jest/vitest/pytest/go test/cargo/mocha/maven 各自的 silent 默认 flag + 失败时只 re-run 失败测试的 verbose 模式 + cap > 100 行输出 + 禁止 cat 大日志 + 项目配置优先规则。整段是通用规则，所有 stage（RED/GREEN/REFACTOR/done 回归）都适用

### Changed

- **`loop.md` RED/GREEN/Phase 2 完成处加 frugality 引用** — Coder 跑测试时默认套 silent；失败时只 verbose re-run 失败 test；不要 verbose 跑全量
- **`done.md` Stage 1 commands 表后加 frugality 说明** — Stage 1 跑 `commands.unit` / `commands.integration` 时默认套 silent flag（具体框架的 flag 见 SKILL.md），回归输出从几百 KB 砍到几行 summary

### Rationale

v3.12.x 实测一个 feature 全周期 token 拆分（yunyin 3 天 1455 turn）：

```
cache_creation  $1812  65%   ← 最大头
cache_read       $846  30%
output           $140   5%
fresh input        ~0   0%
```

cache_creation 之所以占大头，主因是每次跑测试输出几百 KB 日志回到 context → cache 失效 → 下个 turn 重建 cache。一个典型 TDD 周期跑 200+ 次测试，verbose 输出每次累加，光这一块就 $300+。

本版把"默认 silent"写进规则，main agent / Coder / Tester 跑测试时第一次就走 silent flag，输出从 "全量 stack trace + 每个测试名" 砍到 "N passed, M failed, time" 一行。失败时只 verbose re-run 失败那一个 test 看 stack。预期下次 feature 周期 cache_creation 减半甚至更多

### Compatibility

向后兼容：旧 `tdd-specs/.verify/project.md` 里如果 `commands.unit` 已经写成 verbose 命令，main agent 应识别并按 SKILL.md 规则 1（自动加 silent flag）调整；如果用户显式偏好 verbose（少见），可在 project.md 里写明，main agent 会尊重显式配置（规则 5）。`npx tdd-workflow@3.13.1 update` 自动覆盖 SKILL.md / loop.md / done.md，无需手工编辑

## [3.13.0] — 2026-06-08

### Added

- **`.harness yolo=1` 字段** — `/tdd:auto --yolo` 启动时把 yolo 状态持久化到 `tdd-specs/<name>/.harness`，让 main agent 跨 turn 保持 yolo 意识。`user-prompt-submit.sh` hook 在每个 user prompt 注入 `[tdd-harness] ... | Mode: yolo`，context 压缩 / 用户回"继续"后状态都不丢
- **`SKILL.md` 新增 "YOLO Mode" 章节** — 列出 yolo 模式下 main agent 的 4 条行为变化（不开 UC checkpoint、Three-Strike 自动选 C、完整性扫描自动接受、Reviewer 2-strike 标 [!]）和 4 条**绝不绕过**的边界（done 真实失败、DB migration、Tester Agent 边界、初次需求收集）
- **`e2e.md` 顶部 MANDATORY 自检** — 文件第一行就是"main agent 进 e2e.md 必须先 Task spawn Tester、停下不继续读"。这是手动 `/tdd:e2e` 路径的 advisory 层防御。修复实测中 main agent 顺着 Steps 1-N 自己写 e2e 测试、违反 Tester 信息边界的问题（v3.12.x 实测 0 次 Task 调用、73 个 e2e 测试由 main agent 自写、53 次读 src 实现）
- **`auto.md` Stage 4 改为 Orchestrator 主动 Task spawn**（结构性修复，非 advisory）— 之前 Stage 4 是 "delegate to /tdd:e2e"，依赖 main agent 读 e2e.md 后自检自觉 spawn——实测不可靠。本版 Stage 4 直接由 auto.md 调用 Task 工具发起 Tester sub-agent，main agent 在 Stage 4 唯一动作是这次 Task 调用本身，**不读 e2e.md**。Tester 在自己的 context 里读 e2e.md（顶部自检识别"我是 sub-agent"不再嵌套 spawn），执行 Steps 1-N，报告回 Orchestrator。双层防御：auto 流程走结构性 Stage 4 spawn；手动 `/tdd:e2e` 走 e2e.md 顶部 advisory 自检
- **`pre-write-edit.sh` 加 phase=e2e 拦截（hook-enforced，不再 advisory）** — 上面 Stage 4 改造仍是 advisory（依赖 main agent 读 auto.md），实测 v3.13.0 第一次 yunyin 跑里 main agent 在长 session 里没重读 auto.md、Stage 4 没生效（0 次 Task 调用）。本拦截器靠数据层硬约束：main agent（hook input 里没 `agent_id` 字段）在 `phase=e2e` 时 Write/Edit 任何 `tdd-specs/` 之外的文件 → exit 2 阻止 + 提示用 Task 工具 spawn Tester。Tester sub-agent（hook input 含 `agent_id`）写测试文件正常允许。Orchestrator 更新 `tdd-specs/<name>/tasks.md`、写报告等也允许。`agent_id` 字段是 Claude Code hook 文档化的可靠 sub-agent 识别依据
- **hook 测试套件加 3 个 e2e 拦截 case** — `test/hooks-verify.sh` 新增：main agent + e2e + 写 src → block(2)；sub-agent (agent_id 设置) + e2e + 写测试 → allow；main agent + e2e + 写 tdd-specs/ → allow。共 21 个 hook 测试全绿

### Changed

- **`auto.md`** — Step 1 末尾 + Stage 1 末尾两处 sed 写 `yolo=1` 到 `.harness`；顶部新增 "Behavior when `Mode: yolo`" 段，列 3 条 main agent 行为规则（不 checkpoint / 自动 C / done 仍硬停）
- **`user-prompt-submit.sh`** — 注入 `[tdd-harness]` 行末追加 `| Mode: yolo`（仅当 `yolo=1` 时）

### Why this matters

3.12.x 实测发现 `/tdd:auto --yolo` 经常半路停下来写"本轮 /tdd:loop 完成报告"问用户 "commit or continue?"。根因是 `--yolo` 是命令参数、不是持久状态——首 turn 之后 main agent 看到的就是普通 prompt，"是不是 yolo"上下文丢失，模型回到默认本能"完成一个 UC 就 checkpoint"。

修复需要 yolo 状态可被注入到每个 turn 的 context。最小改动：`.harness` 加 1 字段（`yolo=1`），hook 多注入 1 行。`phase` 字段值域不动（仍是 red/green/refactor/e2e/deliver/requirements），yolo 是横跨 phase 的 mode 标记。

### Compatibility

向后兼容：未设置 `yolo=1` 的旧 `.harness` 行为完全不变。Hook 看到 `yolo=0` 或字段不存在都按 default 模式处理。`npx tdd-workflow@3.13.0 update` 自动更新 hook 脚本与 skill 文件，旧项目立即生效

## [3.12.1] — 2026-06-04

### Fixed

- **`installer.ts` 写入 `.claude/settings.json` 时 hook 命令使用相对路径** — 之前生成 `".claude/hooks/tdd/xxx.sh"`，Claude Code 在非项目根 cwd（子目录、worktree、某些 tool call 触发点）启动 hook 时会报 `No such file or directory`，后果是 `UserPromptSubmit` hook 失败 → harness 状态（phase / task / strikes / `auto_mode`）无法注入到 LLM context，LLM 不再知道自己处于 TDD 状态机的哪个阶段，等价于 hook 完全不存在。本版改为 `"$CLAUDE_PROJECT_DIR/.claude/hooks/tdd/xxx.sh"`，Claude Code 注入 `$CLAUDE_PROJECT_DIR` 环境变量后 shell 展开为项目根的绝对路径
- **既有项目修复路径**：`npx tdd-workflow@3.12.1 update` 会自动清理 `.claude/settings.json` 中的旧相对路径条目（旧的 filter 按 `hooks/tdd/` 子串匹配，新旧路径都包含此子串，清理一致）并写入新的 `$CLAUDE_PROJECT_DIR` 版本。无需手工编辑 settings

### Rationale

3.12.0 发布后用户在实战中触发 `UserPromptSubmit hook error: ... No such file or directory`，hook 本身存在且可执行，只是 Claude Code 启动它时的 cwd 不在项目根。这暴露了 installer 的相对路径假设——Claude Code 文档明确建议 hook command 用 `$CLAUDE_PROJECT_DIR` 前缀来避免 cwd 漂移问题。本版做最小修复

## [3.12.0] — 2026-06-03

### Added

- **`/tdd:auto` 一键全流程命令** — 薄编排器，按顺序代理 `/tdd:new` → `/tdd:ff` → `/tdd:loop` → `/tdd:e2e` → `/tdd:done`。**不重写 TDD 逻辑**，只串联现有 5 个 stage 命令。两种模式：
  - **默认（半自动）** — 阶段间 4 次 `AskUserQuestion` 确认，回车即过；适合生产 feature
  - **`--yolo`** — 跳过这 4 次确认；Three-Strike 自动选 C（标 `[!]` + 记录原因 + 继续）、任务完整性扫描建议自动接受、Reviewer 连续 2 次驳回 Coder 时标 `[!]` 继续；适合 throwaway 原型 / 探索
- **自动续跑（resume from incomplete stage）** — `/tdd:auto` 启动时扫描 `tdd-specs/<name>/`，根据 `.harness phase` + `tasks.md` 标记自动定位首个未完成 stage：
  - 无 `tdd-specs/<name>/` → Stage 1 (`/tdd:new`)
  - 有 `.harness` + `usecases.draft.md`，无 `tasks.md` → Stage 2 (`/tdd:ff`)
  - `tasks.md` Phase 1/2 还有 `[ ]` / `[~]` → Stage 3 (`/tdd:loop`)
  - Phase 1+2 全 `[x]`/`[!]`，Phase 3 还有 `[ ]` / `[~]` → Stage 4 (`/tdd:e2e`)
  - 全部 `[x]`/`[!]` 但 `phase != deliver` → Stage 5 (`/tdd:done`)
  - 全部 `[x]`/`[!]` 且 `phase=deliver` → 已交付，提示 `/tdd:notes` / `/tdd:archive`
- **README (en/zh-CN) 新增 Full-cycle 章节** — 含模式对比表、`--yolo` 不能绕过的安全边界表、`[!]` 任务报告示例、自动续跑表

### Safety floor (`--yolo` 也不能绕过)

`--yolo` 不是"无脑往下冲"——下列**真实失败 / 安全边界**始终触发停止：

- `/tdd:done` 真实失败：编译错误、测试失败、覆盖率不足
- `/tdd:loop` 中 DB migration 执行失败
- `/tdd:e2e` 的 Tester Agent 边界（始终 spawn 独立 Tester，禁止 yolo 绕过）
- `/tdd:new` 的初次需求收集（无用户输入无法决定要做什么）
- 测试命令找不到 / 项目配置错误

### Resume 是非破坏性的

续跑模式下永远不会：
- 重跑 `/tdd:new`（会覆盖已收集的需求）
- 重跑 `/tdd:ff`（会覆盖已生成的 spec 文档）
- 重跑 `/tdd:done`（已通过的交付门槛不重测）

`/tdd:loop` 和 `/tdd:e2e` 本来就只挑 `[ ]` / `[~]` 任务，重入安全。

`[!]` 任务**不会被自动重试** —— 它们之前已经升级给用户处理过；Stage 3 跳过它们继续，最终报告里仍然完整列出。手动重做用 `/tdd:loop` 直接跑，或先把它们改回 `[ ]`。

### Rationale

之前的工作流是分阶段命令（5 个独立 slash command），用户反馈每次新 feature 都要敲 5 次、且每次启动都要从 `tdd-specs/.current` 找上下文。`/tdd:auto` 给出"一键启动 / 中途接管"两个能力，**同时保留所有现有 stage 命令的硬约束**（Tester Agent 边界、DB migration 验证、Three-Strike Protocol 等）—— 是体验优化，不是规则放松。

`/tdd:continue` 仍然保留作为"手动恢复 / 先看状态再决定"的入口；`/tdd:auto` 是"直接接着干完"的意图。

## [3.11.1] — 2026-06-02

### Fixed (correction of 3.11.0)

- **撤回 3.11.0 中关于 Claude Code Agent 工具行为的错误判断**。3.11.0 假设"Claude Code 的 sub-agent 工具是同 turn 内串行/伪并行"，并据此把 `commands/loop.md` 限定为 sequential single-Coder、把"并行 Coder dispatch"的责任全部外推给 host 平台。事实校正：**Claude Code 的 Agent 工具支持同一 turn 内多个 tool call 真正并发执行**，配合 `isolation: "worktree"` 提供文件隔离，可在 skill 内部直接落地"一 UC 一 Coder 并行"。

### Changed

- **`commands/loop.md` 顶部执行模式声明重写** — 从单一的 "Sequential single-Coder" 改为 **Mode A（Parallel multi-Coder，host 支持时优先）/ Mode B（Sequential，fallback）二元分支**。同时撤回原来"不要在本命令内 fan out Coder"的警告（该警告基于 3.11.0 的错误前提）
- **`commands/loop.md` 新增 "Parallel dispatch flow (Mode A)" 段** — 给出参考执行流程：扫 Phase 2 → 按 UC 分组 → 列各 UC touched files → 计算独立性 → 取独立子集（cap 2–5 per turn）→ 同 turn 发 N 个 Agent tool call（带 `isolation: "worktree"`）→ 汇合 + 跑全量测试 → 递归处理依赖 UC。该流程是 Orchestrator 临场执行的指南，**不是机械固定步骤**——独立性检查 <2 时自动 fallback 到 Mode B
- **`SKILL.md` `/tdd:loop` Architecture 段重写** — 把 3.11.0 推给 host 平台的"并行 dispatch 责任"**收回到 skill 自己**。新结构：Mode A（在 Claude Code 等支持并发的 host 上由 loop.md 直接 spawn N 个 Coder）+ Mode B（其他 host 的 fallback）。"When parallel is safe / unsafe" 判定表保留，定位从"host 调度建议"改回"skill 内部判定"

### Rationale

3.11.0 的核心错误是误判了 Claude Code 的 Agent 工具能力（事实是支持真并发，且有 `isolation: "worktree"` 文件隔离机制）。该错判导致两个连锁问题：(1) loop.md 主动放弃了在 Claude Code 上能享受到的真并行加速；(2) SKILL.md 把本属于 skill 自己能兑现的并行能力外推为"host 平台责任"，对 Claude Code 用户构成误降级。本版本在保留 3.11.0 "按 host 能力分支"这一正确思路的前提下，把分支从"sequential-only + 外推 host"修正为"Mode A 优先 + Mode B fallback"，恢复 Claude Code 路径的并行能力。

对 Cursor / Cline / CodeBuddy / Codex / GitHub Copilot 等没有真并发 sub-agent 的 host，行为与 3.11.0 一致（走 Mode B sequential）—— 本次修正不会让这些 host 的体验回退。

### Out of scope (still planned)

- **tasks.md UC 依赖元数据**（"UC-X depends on: UC-Y / none" + "UC-X touches: <file paths>"）—— 让 Mode A 的独立性检查从"临场扫描 + 人脑判断"升级为"机械可消费的元数据"，由 `/tdd:ff` 在 spec 阶段就标注好。仍在下版规划中

## [3.11.0] — 2026-06-02

### Changed

- **修复 SKILL.md 与 commands/loop.md 之间的契约不一致** — SKILL.md `/tdd:loop` 段宣称"Spawn multiple Coder Agents simultaneously (one per UC module)"，但 `commands/loop.md` 实际只实现单 Coder 串行处理。本版本走分层契约方案：明确 `commands/loop.md` 的支持模式为 **sequential single-Coder**（最低能力底线，所有 host 平台都能跑），把"并行 dispatch"的责任**外推到 host 平台**（multi-agent squad runtime / 自建 orchestrator），由 host 读 tasks.md Phase 2 分组后自行决定是否一 UC 一 Coder 并行启动
- **SKILL.md `/tdd:loop` Architecture 段重写** — 移除"Spawn multiple Coder Agents simultaneously"承诺；改为分两段说明：(1) reference loop.md 是 sequential single-Coder 模式（适用所有 host）；(2) 新增 "Parallel dispatch (host-platform responsibility)" 小节，描述 host 平台如何基于 tasks.md UC 分组实现并行（含 parallel-safe / unsafe 判定表）。原"When to use parallel Coders"判定规则迁移至此节，定位从"loop 内部行为"改为"host 调度建议"
- **commands/loop.md 顶部声明执行模式** — 新增 "Execution mode: Sequential single-Coder" 显式说明；并增加一段 caveat 警告："不要在本命令内 fan out Coder——同 turn 串行 sub-agent 调用既无真实并行性，又会撑爆 turn 预算"

### Rationale

实测发现 Claude Code / Cursor / Codex / Cline 等主流 host 的 sub-agent 工具都是同 turn 串行（spawn 一个、等返回、再 spawn 下一个），并不是真正的并行执行。原 SKILL.md 的并行承诺无论在哪个 host 上都无法兑现，构成卖点虚假。本次修复把承诺降级到所有 host 都能保证的"单 Coder 串行"，同时为未来真正支持并行 spawn 的 host 平台（如 multi-agent squad）保留接口

### Out of scope (planned for next minor)

- **tasks.md UC 依赖元数据**（"UC-X depends on: UC-Y / none" + "UC-X touches: <file paths>"）—— 这是让 host 平台真正能消费的并行调度元数据，需要改 `/tdd:ff` 的 tasks.md 生成规则，工作量较大。本版本仅修复契约不一致，元数据落地另起 spec

## [3.10.1] — 2026-05-29

### Fixed

- **`init` 漏装 `STAGING_SMOKE.md`** — installer 之前硬编码只拷贝 `SKILL.md`，导致 v3.10.0 新增的 sibling 文件 `STAGING_SMOKE.md`（SKILL.md Rule 6 / Type B 路径会读取）在 `npx tdd-workflow init` 时未被安装，AI 跟到 staging smoke 步骤会找不到文件。改为扫描 `skills/` 根目录下所有 `*.md` 文件，未来再加 sibling 文档也不会漏
- **`init --tools codex` 报 Unknown tool** — v3.10.0 changelog 提到的 codex 支持实际未落地（`SUPPORTED_TOOLS` 里没有 codex 条目，`compatible` 子命令也不存在）。本版补齐项目级 codex 支持：`init --tools codex` 安装到 `.codex/skills/tdd-workflow/SKILL.md` + `.codex/commands/tdd/*.md`（与 cursor/cline 项目级模式一致）

### Known limitations

- **codex 全局 prompts（`~/.codex/prompts/`）暂不支持** — v3.10.0 changelog 中预告的 `compatible` 子命令（"装到 ~/.codex/prompts/ 作为全局 slash commands"）尚未实现，规划在 v3.11 单独提供。需要全局 codex prompts 的用户暂时只能手动从 `.codex/commands/tdd/` 复制

## [3.10.0] — 2026-05-29

### Added

- **`/tdd:e2e` Type Selection（Type A vs Type B）** — 在 Step 1 强制区分 E2E 目标类型：Type A = 用户流程验证（real user flow，端到端走完点击/输入/截图）；Type B = staging smoke 反向证据验证（API 层调用 + 后置条件断言，覆盖序列化/权限/过滤）。两类目标的产出与门禁不同，混用会让"通过"失去意义
- **`skills/STAGING_SMOKE.md`** — Type B 的硬规则手册：B1 必须以 staging 凭据登录、B2 必须断言后置条件实际值、B3 不能用 health check 替代业务断言、B4 凭据不可用必须 AskUserQuestion 阻塞；附 Negative-Proof Checklist（"如果 feature 坏掉，这个 smoke 会不会红？"）
- **`/tdd:e2e` Rule 6（Type B targets 必须产出 staging-smoke-design.md）** — 派生 E2E 清单时，凡是标注 Type B 的 target 必须先产出 design 文档（覆盖路径 / 凭据 / 断言点），design 文档缺失不能进入实现
- **`compatible` 子命令支持 codex** — `npx tdd-workflow compatible` 新增 codex 适配（与 claude-code / cursor / copilot 并列）

### Changed

- **`/tdd:e2e` Step 4 派生表新增 Type 列** — 每行测试必须标注 Type A / Type B；Type B 行额外列出"反向证据断言点"

## [3.8.0] — 2026-05-26


### Added

- **`/tdd:done` Stage 3 凭据就绪前置检查（mandatory）** — Stage 3 开始前必须确认 staging 登录凭据可用：读取 `project.local.md` 的 staging 凭据 + 实际调用 login 接口验证可获取 token；失败必须 AskUserQuestion 让用户决定（[A] 修复凭据 / [B] 降级仅 deploy+readiness / [C] 中止），不能跳过后继续
- **Stage 3 自动化 smoke 验证** — UI 端 feature 必须通过 API 登录 + 数据查询验证：调用 feature 相关 API 接口 → 验证返回数据与 usecases.md 后置条件预期一致；自动化验证之后才进入人工确认环节
- **验证层级规则** — API 层验证是最低要求（覆盖序列化、权限、过滤逻辑）；DB 直查只能作为补充证据，不能替代 API 层；API 不可用时 AskUserQuestion 阻塞，不能用更低层级替代后声称通过

### Changed

- **新增 guardrail "验证降级必须授权"** — 无法完成预定验证路径（登录不通、环境不可用）时必须 AskUserQuestion 让用户决定，不能自己找替代方案后声称"验证通过"；降级后报告必须明确标注"降级"而非"PASSED"
- **新增 guardrail "staging 凭据不可用时阻塞"** — Stage 3 开始前必须确认登录凭据可用，不可用则阻塞，不能跳过后继续

## [3.7.0] — 2026-05-25

### Added

- **`/tdd:e2e` Rule 7: Cross-UC data flow must assert actual values** — 当展示类 UC 的数据来源是另一个 UC（如"UC-01 心跳上报版本 → UC-05 页面展示版本"），E2E 不能只断言"有数据渲染"，必须断言"显示的值 = 上游实际值"；提供 WRONG/CORRECT 对比示例（仅断言存在 vs 断言 = 已知数据源/API 响应）；列出识别跨 UC 数据流的 3 个信号（"由 XX 上报"标注、"展示 XX 上报的 YY"步骤、数据不是本 UC 产生）
- **派生 E2E 清单跨 UC 标注** — Step 4 派生测试清单时，跨 UC 数据流场景标注 `[跨UC: UC-XX→UC-YY]`，提醒编写时必须验证值的正确性

### Changed

- **新增 guardrail "跨 UC 数据流必须断言实际值"** — 看到截图里有数据不等于数据正确；展示类 UC 如果数据来源是另一个 UC/端，不能只断言"有值"

## [3.6.1] — 2026-05-25

### Changed

- **README 中英分版** — 原 `README.md` 重命名为 `README.zh-CN.md`（中文完整版，国内用户阅读流畅），新增英文版 `README.md`（npmjs.com 默认渲染，面向国际用户的精简介绍 + Quick start + 命令表 + 架构概述）；两份相互链接

## [3.6.0] — 2026-05-25

### Added

- **`/tdd:e2e` Step 7.1: 证据留存（UI 端 mandatory）** — `type=browser` 和 `type=device` 端的 E2E 必须保留可视化截图证据，保存到 `tdd-specs/<feature>/evidence/`（随 feature 归档可追溯）；测试通过后主动用 Read tool 展示 1-2 张关键断言点截图给用户审计；`type=api` 端保留关键响应数据摘要
- **`/tdd:done` Stage 1 UI 端截图证据展示** — 全端 E2E 运行后，UI 端必须主动展示截图，让用户确认"AI 真的看到了页面上的目标元素"，避免只靠文字 pass/fail 声称已验证
- **新增 guardrail "有 UI 的端 E2E 必须留截图证据"** — browser + device 端跑完后主动向用户展示关键截图（Read tool 读图片），不能只靠文字声称验证过

## [3.5.1] — 2026-05-22

### Added

- **`/tdd:e2e` & `/tdd:verify-setup` 新增选项 [D] "服务确实在线，readiness 脚本可能有 bug"** — 此前用户只有"我来启动 / 跳过 / 中止 / 删配置"四选项，遇到 readiness 脚本本身有 bug 时只能选删除或跳过；新增 [D] 触发交叉验证（`lsof -i:<port>` / `curl` 直接访问），基础验证通过但脚本报失败 → 要求修复脚本后再继续，避免被错误脚本卡死

### Changed

- **新增原则 "readiness 脚本也需要验证正确性"** — 不是"能跑"就够了，还要"已知在线时返回 pass"；不能信任有 bug 的脚本写入 project.md

## [3.5.0] — 2026-05-22

### Added

- **`/tdd:retro` 新命令** — TDD workflow 自身回顾改进入口。5-why 根因分析 → 7 类根因分类（验证缺失/假设未校验/反馈延迟/覆盖盲区/Guardrail 失效/知识盲区/降级未授权）→ 文件级改进方案 → 写入 `tdd-specs/.retro/<date>-<keyword>.md`。与 `/tdd:bug`（修产品代码）和 `/tdd:notes`（纯记录）划清边界：retro 只改 skill .md / project.md / 原则文档
- **`/tdd:verify-setup` Step 9.5 Smoke-test 配置（mandatory）** — 写完 project.md 后逐项验证：每个 `endpoints.*.readiness` 实际执行一次、`test_cmd` 主命令存在性、`src_dirs` 路径存在性；失败不静默跳过，用 AskUserQuestion 让用户处理
- **`/tdd:e2e` 逐端 readiness 检查** — Pre-check 改为按 `endpoints` 配置逐端执行 readiness，输出每端状态；任何端失败必须 AskUserQuestion（[A] 我来启动 / [B] 跳过此端 / [C] 中止），不能自行降级

### Changed

- **新增 guardrail "降级必须经用户同意"** — `/tdd:e2e` 中 readiness 失败时不能自行决定"降级为 jest"或"跳过此端"，必须显式询问
- **新增 guardrail "动态值不能硬编码"** — `/tdd:verify-setup` 中如果配置值来源是动态的（端口在文件里、路径含时间戳），必须用检测命令读取，不能写死

## [3.4.0] — 2026-05-22

### Added

- **多端 E2E 支持** — `/tdd:e2e` 按 `tdd-specs/.verify/project.md` 的 `endpoints` 配置分端生成测试（type=api/browser/device），每端独立指定 `framework`/`test_dir`/`test_cmd`；测试清单按端分组展示供用户确认；UC → E2E 映射表新增"端"列
- **E2E Rule 6: Display steps must have browser/device E2E** — UC 中"用户看到 X / 页面展示 Y / 列表显示 Z"等展示类步骤必须有对应的 browser 或 device 端 E2E 测试，不能仅靠 API E2E 断言返回值声称"展示已验证"
- **`/tdd:done` Stage 1 全端 E2E** — 新增 `e2e_test.*` 逐端执行步骤，按 `endpoints` 配置遍历；某端环境不可用时标记 skipped 并记录原因

### Changed

- **`/tdd:done` Stage 2 自动判断** — Stage 1 全端 E2E 全绿且 feature 无 `manual_flows` 定义时自动 PASS Stage 2，直接进 Stage 4；仅在有 skip 端或 `manual_flows` 时才询问用户人工验证
- **`/tdd:e2e` 全文去框架硬编码** — 移除 Playwright/Cypress/supertest 等具体框架名，改为从 `endpoints` 配置读取；pre-check 健康检查改用 `environments.dev.readiness` 配置；tags 移除 `playwright, cypress`

## [3.3.0] — 2026-05-15

### Added

- **E2E Rule 5: success path must reach UC postconditions** — 成功路径 E2E 必须执行所有触发写操作（POST/PUT/DELETE）的 UC 步骤，并断言至少一项 `usecases.md` 后置条件（DB 记录、状态字段、返回 ID 等）；提供了 WRONG/CORRECT 对比示例和标 `[x]` 前的三项检查清单

### Changed

- **全文英文化** — SKILL.md 中文描述（场景 A/B/C、提交前自查清单、踩坑记录等）统一改为英文，消除语言混用；`/tdd:notes` 各字段名同步为英文
- **去框架绑定措辞** — `schema:dump` 改为"project's schema dump command"；`SHOW TABLES` 改为"SHOW TABLES or equivalent"；`page.evaluate()/setData()` 改为"state injection bypassing UI interactions"；`relaunch_to()` 改为"direct deep-link navigation bypassing home/app entry"；`_devtools_port.py` 改为"auto-discovery from project config"
- **Rule 1 精简** — 移除代码示例（保持文字描述），将 test-only runtime API 扩展段合并到 Rule 1 主体
- **Rule 2 示例** — 新增 WRONG/CORRECT skip 示例，明确 skip 需引用 UC 编号和替代覆盖路径
- **Why This Matters 改写** — 去除项目特定细节（`goToCopy`、`globalData.baseUrl`），改为通用原则描述

## [3.2.0] — 2026-05-14

### Added

- **E2E conventions 内置规范** — `skills/templates/verify-project.md` 新增 `e2e_conventions` 完整段落，涵盖 `selector_priority`（data-testid > role > text）、`testid_naming`（snake_case）、`data_state`（data-state attribute 约定）、`spec_requirements`（有 spec 的功能强制写 E2E）、`forbidden_in_e2e`（禁止 page.evaluate / fetch intercepts / direct store mutation）

### Changed

- **Rule 1 扩展：禁止 test-only runtime API** — `window.__test.*` / `globalThis.__e2e.*` / 隐藏 URL 参数等 test-only runtime command bus 与 `page.evaluate` 状态注入等价，在 E2E 中一律 FORBIDDEN；说明了这类"抽象"隐藏的集成 bug（路由入口丢失、click handler 未绑定、表单校验未触发、auth middleware 未命中）

## [3.1.1] — 2026-05-14

### Added

- **`/tdd:verify-setup` Phase F.5 `src_dirs` 交互配置** — 新增实现代码目录配置章节：自动检测 `src/` `app/` `lib/` 等常见目录，monorepo 进一步检测子包（`packages/*/src`、`apps/*/src`）；用 AskUserQuestion 让用户确认或自定义；写入 `paths.src_dirs`；两处用途：E2E Tester Agent FORBIDDEN 列表 + `/tdd:done` 交付后改动核查的 git log 扫描范围

## [3.1.0] — 2026-05-13

### Changed

- **`/tdd:e2e` Tester Agent 强制 spawn** — 有 2+ UC 的功能禁止主 Agent 直接写 E2E，必须先 `Agent()` spawn 独立 Tester；Tester 的 FORBIDDEN 列表从 `paths.src_dirs` 读取（不再硬假设 `src/`）；添加真实案例说明为何必须强制（绕过首页导航导致缺失 `goToCopy` 入口等 bug 被隐藏 2 轮）
- **`paths.src_dirs` 配置** — `tdd-specs/.verify/project.md` 新增 `src_dirs` 字段，支持 monorepo 多路径；两处用途：Tester Agent 的 FORBIDDEN 列表 + `/tdd:done` 交付后改动核查的 `git log` 扫描范围；未配置时 fallback 到自动检测（`src/ app/ lib/`）
- **澄清 `isolation:worktree` 误区** — 明确 worktree 只防写冲突，不防读取实现代码；Tester 盲区靠 prompt 约束，不靠 worktree 隔离
- **monorepo 感知目录检测** — 环境探测 snippet 改为 `find . -maxdepth 3 -name "package.json"` 多包扫描，替代原来的单层 `ls -d src/ app/ ...`
- **服务端口自动发现** — E2E REAL 模式优先用 `_devtools_port.py` 等自动发现脚本，失败 2 次后才询问用户；不再在 pre-check 里硬读 project.md health_check URL

## [3.0.0] — 2026-05-13

### Changed

- **Agent Team 三角分工**
  - `/tdd:loop`: 引入 Orchestrator + Coder Agent 分工；Orchestrator 负责任务拆解和评审，Coder Agent 专注实现；支持多 UC 并行 Coder（`isolation:worktree` 物理隔离）
  - `/tdd:e2e`: Tester Agent 信息隔离原则 — 只读 spec，不读实现代码，避免测试被实现细节污染；真实服务栈优先，mock 需注释理由

- **去项目强绑定** — 命令文档不再假设任何具体项目结构：
  - 移除 `backend/` / `web-admin/` / `miniprogram/` 硬编码路径
  - 移除 `jest` / `NestJS` / `auto-regression.sh` 硬编码命令
  - 移除微信 / 腾讯云 / COS 等项目特有外部服务引用
  - 前端页面文件格式改为 `tsx/vue/svelte/html+js+css`（框架无关）
  - src 目录扫描改为 `src/**`、`app/**`、`lib/**` 通用模式

## [2.4.7] — 2026-05-09

### Added

- **`SKILL.md` 新增"交付后继续开发规范" (Post-Delivery Development)** —— `/tdd:done` 后 harness 进入 `deliver` 状态时，明确三类后续改动的处理路径，避免测试债务在交付后悄悄堆积：
  - **场景 A 联调发现 bug**：禁止直接改代码，必须走 `/tdd:bug`（复现测试 RED → 修代码 GREEN → 记录 Issue），即使 bug 看起来只一行
  - **场景 B 交付后追加功能**（如支付对接、状态流转）：在 tasks.md 追加 task + 把 harness 改回 `green` + 走正常 red/green 循环 + 重跑 `/tdd:done`
  - **场景 C 纯样式/UX/配置调整**：可以直接改，但 commit message 用 `[style]` / `[ux]` / `[config]` 标注 + 全量跑测试确认无回归
- **`/tdd:done` 新增检查 8 "交付后改动核查"**：扫本 spec 周期内修改的 `backend/src/**` 和 `miniprogram/pages/**` 文件，对照 tasks.md 确认每个新增 service / API / bug 修复都有覆盖；发现未覆盖逻辑停止交付
- **提交前自查清单 (5 项)**：service 单元测试、API e2e 测试、外部服务 mock、全量 jest、bug Issue 记录

## [2.4.6] — 2026-05-06

### Fixed

- **`skills/SKILL.md` 的 `metadata.version` 停在 2.2.0** 已经三个大版本没同步（2.3.0 / 2.4.0 / 2.4.1-2.4.5 发包时都忘了 bump）。本次一并补齐到 2.4.6
- **`metadata.compatible` 字段过时**：只列 `claude-code, codebuddy, cursor`，实际 2.4.x 已全面支持 cline / windsurf / github-copilot，改为完整列表

### Added

- **`test/version-sync.sh`**：校验 `skills/SKILL.md` 的 `metadata.version` 与 `package.json` 的 `version` 一致
- **`npm test` 脚本**：串行跑 `hooks-verify.sh` + `version-sync.sh`
- **`prepublishOnly` 钩子**：`npm publish` 前自动 build + test，版本不一致或 hooks 测试失败会直接中断发布，避免再出现 SKILL.md 版本脱节的问题

## [2.4.5] — 2026-05-06

### Changed

- **`/tdd:loop` 范围扩大**：从"只跑 Phase 2"改为"遍历 Phase 1 + Phase 2 所有未完成 task"，按 UC 纵切处理（先把 UC-01 的 backend test → backend impl → frontend page 全跑完，再进 UC-02）
- **Vertical Slice Rule (mandatory)**：`tasks.md` Phase 2 必须按 UC 纵切组织，每个 UC 包含它触及的所有技术层（DB migration / backend service / backend controller / frontend page / client app）；**禁止单独的"Phase 4 前端"**；仅跨 UC 的基础设施（scaffolding）才放 Phase 1
- **DB Migration Verification Protocol**：Phase 1 的 migration task 必须真跑到本地 dev DB + 用 `SHOW TABLES` 验证新表存在（不是只写 SQL），有 `schema:dump` 的项目顺带跑；migration 失败停下问用户，不再接受"mock 跑过就算"
- **Marking [x] Verification Protocol (mandatory)**：标 `[x]` 前必须有证据 —— unit test 要跑过、implementation 要有源文件 + 相关测试通过、frontend page 要文件齐 + app config 注册、migration 要 `SHOW TABLES` 确认；**禁止**同行带"待后续 / TODO / skip" + `[x]`，阻塞的任务用 `[!]` + blocker 理由

### Fixed

- **`/tdd:red` / `/tdd:green` / `/tdd:refactor` 不是独立斜杠命令**：历史遗留误导，在 `skills/commands/` 里没有对应文件。SKILL.md 里这些章节改为 "Loop-internal phases" 明确标注；README 里 loop 伪代码改为 `RED phase` / `GREEN phase` / `REFACTOR phase` 阶段名；新增一行显式说明它们由 `/tdd:loop` 内部驱动不可手工触发。
- `skills/commands/continue.md` 里的 "Start from `/tdd:red`" 改为 "Resume via `/tdd:loop`（it will re-enter the RED phase）"

### Docs

- README "`/tdd:ff`" 章节重写：明确 usecases.md 是主产出（之前遗漏未提），其他三份从 UC 派生；列出 Vertical Slice Rule 和 DB migration 执行约束
- README "`/tdd:loop`" 章节重写：循环伪代码反映 Phase 1 + 2 的新行为；新增"标 [x] 必须有证据"协议表；任务完整性扫描加上 migration 执行、真实 DB 集成测试两项
- README "为什么 loop 和 e2e 分开"对比表：触发频率从"Phase 2 完成后一次"改为"Phase 1 + 2 都完成后一次"
- README tasks.md 示例：改为按 UC 纵切，前端 task 归到对应 UC 的 Phase 2（不再是独立 Phase 4）
- 完整工作流示例 `/tdd:loop` 完成时输出 "Phase 1 + 2 complete"

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
