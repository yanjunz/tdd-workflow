# TDD Workflow

规范驱动的 TDD 全流程工具，为 AI 编程助手安装 TDD 技能和斜杠命令。

一条命令把完整的 **需求收集 → 规范文档 → TDD 循环（red → green → refactor） → E2E 验收 → Issue 追踪 → 交付检查** 工作流装进你的项目，让 AI 助手按流程驱动开发，而不是随意写代码。

支持 **Claude Code** · **Cursor** · **Cline** · **Windsurf** · **CodeBuddy** · **GitHub Copilot**。

---

## 目录

- [快速开始](#快速开始)
- [安装方式](#安装方式)
- [CLI 命令参考](#cli-命令参考)
- [Multi-Agent 架构](#multi-agent-架构)
- [完整工作流示例](#完整工作流示例)
- [斜杠命令详解](#斜杠命令详解)
- [Harness Hooks](#harness-hooks)
- [Issue 追踪机制](#issue-追踪机制)
- [Three-Strike Protocol](#three-strike-protocol)
- [目录结构约定](#目录结构约定)
- [支持的工具](#支持的工具)
- [与 OpenSpec 的对比](#与-openspec-的对比)
- [常见问题](#常见问题)

---

## 快速开始

```bash
# 在项目根目录运行
npx tdd-workflow init

# 打开你的 AI 编程助手（如 Claude Code），输入：
/tdd:new
# 按提示完成需求收集后：
/tdd:ff
# 开始 TDD 循环：
/tdd:loop
```

30 秒即可把 TDD 工作流注入项目。

---

## 安装方式

### 方式一：npx 直接运行（推荐）

无需全局安装，在项目根目录下直接运行：

```bash
npx tdd-workflow init
```

CLI 会自动扫描项目中的 `.claude/`、`.cursor/` 等目录，弹出交互式多选让你确认要安装到哪些工具。

### 方式二：全局安装

```bash
npm install -g tdd-workflow
tdd-workflow init
```

### 方式三：从源码构建

```bash
git clone <repo-url>
cd tdd
npm install && npm run build
```

然后在目标项目中运行：

```bash
node /path/to/tdd/bin/tdd.js init
```

> **要求**: Node.js >= 18

---

## CLI 命令参考

### `tdd-workflow init`

在当前项目安装 TDD workflow 技能文件和斜杠命令。

```bash
tdd-workflow init [options]
```

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--tools <tools>` | 逗号分隔的工具 ID（跳过交互选择） | 自动检测 |
| `--delivery <mode>` | 安装模式：`skills`、`commands` 或 `both` | `both` |
| `--force` | 覆盖已有文件 | `false` |

#### 示例

```bash
# 只为 Claude Code 安装
tdd-workflow init --tools claude

# 同时为 Claude Code 和 Cursor 安装
tdd-workflow init --tools claude,cursor

# 只安装斜杠命令（不安装 SKILL.md 和模板）
tdd-workflow init --delivery commands

# 只安装技能文件（不安装斜杠命令）
tdd-workflow init --delivery skills

# 覆盖已有文件
tdd-workflow init --force
```

#### 安装内容

| 类型 | 文件 | 安装位置 |
|------|------|----------|
| 技能文档 | `SKILL.md` | `.{tool}/skills/tdd-workflow/SKILL.md` |
| 规范模板 | `requirements.md`、`design.md`、`tasks.md`、`review-checklist.md` | `.{tool}/skills/tdd-workflow/templates/` |
| 斜杠命令 | 9 个命令（见下方详解） | `.{tool}/commands/tdd/` |
| Hooks 脚本 | 5 个 shell 脚本（仅 Claude Code） | `.claude/hooks/tdd/` |
| Hooks 配置 | 自动合并到 settings.json（仅 Claude Code） | `.claude/settings.json` |

同时会自动创建 `tdd-specs/` 目录（带 `.gitkeep`），用于存放生成的规范文件。

### `tdd-workflow update`

检测项目中已安装 TDD workflow 的工具，强制更新所有文件到最新版本：

```bash
tdd-workflow update
tdd-workflow update --delivery commands   # 只更新命令文件
```

---

## Multi-Agent 架构

TDD Workflow 1.2.0 引入了 **Coder/Reviewer 分离**，解决「AI 自己写代码、自己 review、自己打分」的自我放水问题。

### 工作原理

```
主 Agent (Reviewer/Coordinator)
  │
  ├── 读 tasks.md，确定下一个任务
  │
  ├── spawn Coder Agent ──→ 只知道任务描述，不知道评审标准
  │   └── 写测试 / 写实现代码
  │
  ├── Reviewer 独立评审 Coder 的产出：
  │   - 测试覆盖了任务描述的场景吗？
  │   - 实现是最小代码吗？有没有过度设计？
  │   - 全量回归通过了吗？
  │   ✗ 不通过 → 给 Coder 具体反馈，重试
  │   ✓ 通过 → 标 [x]，下一个任务
  │
  └── 连续两次评审不通过 → 升级给用户
```

**关键点**：Coder Agent 的 prompt 里 **没有** 评审标准——它只知道「写一个测试让它失败」或「写最少代码让测试通过」。评审标准在 `templates/review-checklist.md` 里，只有 Reviewer（主 Agent）能看到。

### 跨工具兼容

| 工具 | 模式 | 代码由谁写 | 评审由谁做 |
|------|------|-----------|-----------|
| Claude Code | Multi-Agent | Coder 子 agent | 主 Agent 独立评审 |
| CodeBuddy / Cursor / Cline / 其他 | Single-Agent + Self-Review | 自己写 | **强制 self-review**，输出 checklist 结果 |

非 Claude Code 工具没有 Agent tool，会自动降级为单 Agent 模式。但 Reviewer 步骤仍然是强制的——必须输出 `[Review:RED]` 和 `[Review:GREEN]` 评审结果才能继续：

```
[Review:RED]   ✓ covers task scenario | ✓ behavior test | ✓ fails correctly | Issues: none
[Review:GREEN] ✓ minimum code | ✓ no test mods | ✓ full suite passes | Issues: none
```

### Review Checklist

Reviewer 按 `templates/review-checklist.md` 评审，主要检查项：

**测试评审（RED 阶段）：**
- 测试描述行为而非实现
- 测试名可读：`should <行为> when <条件>`
- 覆盖 tasks.md 中描述的场景
- 测试因「功能未实现」而失败，而非语法错误

**实现评审（GREEN 阶段）：**
- 最小代码——无提前抽象或过度设计
- 未修改测试文件
- 全量测试通过（无回归）

---

## 完整工作流示例

下面用一个「给博客系统添加评论功能」的例子，演示从零到交付的完整流程。

### 第 1 步：启动新功能

```
> /tdd:new blog-comments
```

AI 助手会逐步问你 6 个维度的问题：

```
🤖 谁会使用这个功能？
👤 已登录用户可以发表评论，文章作者可以删除评论

🤖 最重要的 1-3 个使用场景？
👤 1. 用户在文章底部提交评论  2. 作者删除不当评论  3. 访客查看评论列表

🤖 输入和输出分别是什么？
👤 输入：评论文本（最长 500 字）、文章 ID。输出：评论对象（含作者、时间、内容）

🤖 哪些情况会失败？
👤 未登录提交、文章不存在、评论内容为空或超长

🤖 什么明确不做？
👤 不做嵌套回复、不做评论编辑、不做点赞

🤖 怎样算完成？
👤 能发评论、能看列表、能删评论、有权限控制
```

确认后，AI 创建 `tdd-specs/blog-comments/` 目录。

### 第 2 步：一键生成规范文档

```
> /tdd:ff
```

AI 自动生成三份文档：

```
OK requirements.md — 4 requirements, 8 acceptance criteria
OK design.md       — 3 modules, 5 interfaces
OK tasks.md        — Phase 2: 12 items / Phase 3: 3 items / Phase 4: 5 items
Issues reviewed: none

Ready! Run /tdd:loop to start TDD implementation.
```

生成的 `tasks.md` 包含分层任务：

```markdown
## Phase 2: Unit Tests + Implementation

- [ ] 2.1 comment-service: unit test — createComment happy path
- [ ] 2.2 comment-service: implement createComment
- [ ] 2.3 comment-service: unit test — validation errors (empty, too long)
- [ ] 2.4 comment-service: implement validation
- [ ] 2.5 comment-service: unit test — deleteComment by author
- [ ] 2.6 comment-service: implement deleteComment
- [ ] 2.7 integration test: POST /api/comments full chain
- [ ] 2.8 integration test: DELETE /api/comments/:id permission check
- [ ] 2.9 integration test: GET /api/posts/:id/comments pagination
...

## Phase 3: E2E Acceptance

- [ ] 3.1 E2E: user submits comment and sees it in list
- [ ] 3.2 E2E: author deletes comment
- [ ] 3.3 E2E: unauthenticated user sees comments but cannot post
```

### 第 3 步：TDD 自动循环

```
> /tdd:loop
```

AI 自动循环执行（Claude Code 中会 spawn Coder 子 agent）：

1. **RED** — Coder 写一个失败的测试 → Reviewer 评审测试质量
2. **GREEN** — Coder 写最少代码让测试通过 → Reviewer 评审实现 + 跑全量回归
3. **REFACTOR** — 消除重复、改善命名

```
[Coder]        writing test: comment-service.test.ts: createComment
[Review:RED]   ✓ covers task scenario | ✓ behavior test | ✓ fails correctly
[Coder]        writing impl: comment-service.ts: createComment
[Review:GREEN] ✓ minimum code | ✓ no test mods | ✓ 5/5 tests pass
[REFACTOR]     extracted validateComment() — 5/5 tests PASS ✓
...
Phase 2 complete: 12/12 tasks, 28 tests, 3.2s elapsed
Run /tdd:e2e for E2E acceptance.
```

如果某个测试连续失败 3 次，触发 [Three-Strike Protocol](#three-strike-protocol)，暂停并等你决策。

### 第 4 步：E2E 验收

```
> /tdd:e2e
```

AI 检测项目的 E2E 框架（Playwright / Cypress 等），编写并运行端到端测试。

### 第 5 步：交付

```
> /tdd:done
```

AI 执行完整交付检查清单：

```
✓ Compilation clean
✓ All tests passing (28 unit + 3 integration + 3 E2E), coverage 91%
✓ Full regression passing
✓ Issues logged: #012-comment-validation-edge-case
✓ tdd-specs/blog-comments/tasks.md all [x]

## Delivery Report — blog-comments
- Added: src/services/comment-service.ts, src/routes/comments.ts, ...
- Modified: src/routes/index.ts
- Tests: 28 unit PASS, 3 integration PASS, 3 E2E PASS
- Issues: #012

Run /tdd:archive to archive specs.
```

### 第 6 步：归档

```
> /tdd:archive
```

将已完成的规范移入 `tdd-specs/archive/2026-04/blog-comments/`，清空 `.current`。

---

## 斜杠命令详解

### `/tdd:new <name>` — 启动新功能

交互式收集需求，覆盖 6 个维度：目标用户、核心场景、输入输出、错误处理、范围边界、验收标准。

```
> /tdd:new payment-retry
```

只创建目录 `tdd-specs/payment-retry/`，不生成文档——确保需求确认后再动笔。

### `/tdd:ff` — 快速前进

一次性生成 `requirements.md`（EARS 格式）、`design.md`、`tasks.md` 三份规范。

自动执行 **测试覆盖检查**：如果单元测试、集成测试、E2E 三层中任何一层任务为 0，会主动补充。

### `/tdd:loop` — TDD 自动循环

自动循环 red → green → refactor，直到 `tasks.md` Phase 2 全部 `[x]`。

每轮循环开始前执行 **任务完整性扫描**，检查是否遗漏了错误响应解析、崩溃恢复、超时处理、集成测试等场景。

### `/tdd:bug` — Bug 修复流程

完整的 bug 修复链路：

```
> /tdd:bug

🤖 请描述 bug 症状：
👤 提交评论时偶尔返回 500，日志显示 "duplicate key"

[Analysis]  Root cause: race condition in comment-service.ts, no idempotency key
[RED]       duplicate-comment.test.ts — FAIL ✗ (bug reproduced)
[GREEN]     Added idempotency check — 29/29 tests PASS ✓
[Done]      Issue #013 archived, docs/issues/013-comment-duplicate-key.md
```

自动创建 Issue 文档，包含：症状、根因分析、修复方案、验证步骤、预防措施。

### `/tdd:change` — 中途变更需求

安全地修改进行中的需求，自动分析影响范围：

```
> /tdd:change

🤖 请描述变更内容：
👤 评论需要支持 Markdown 格式

## Change Impact Assessment

### Affected Spec Entries
| Document | Entry | Impact Type | Description |
|----------|-------|-------------|-------------|
| requirements.md | REQ-01 | Modify | Comment input supports Markdown |
| design.md | CommentService | Modify | Add markdown parsing step |

### Affected Tasks
| Task | Current Status | Action Needed |
|------|---------------|---------------|
| 2.1 createComment test | [x] Completed | WARNING: needs redo |
| 2.2 createComment impl | [x] Completed | WARNING: needs redo |
| 2.N markdown parsing | — | New task |

### Risk Notes
- Completed tasks affected: 2
- Estimated additional work: medium

Confirm to proceed? [A] Confirm  [B] Adjust  [C] Cancel
```

**安全机制**：如果变更导致 10+ 个已完成任务需要回退，建议重新跑 `/tdd:ff`。

### `/tdd:continue` — 恢复进度

从上次中断处继续。自动定位第一个未完成的任务：

```
> /tdd:continue blog-comments

Resumed: tdd-specs/blog-comments/
Completed: 8/12 tasks
Current phase: Phase 2
Next step: 2.9 integration test — GET /api/posts/:id/comments pagination
Run /tdd:loop to continue.
```

### `/tdd:e2e` — E2E 验收测试

自动检测项目的 E2E 框架，编写并运行端到端测试。

**硬规则**：
- 必须经过真实网络层（不允许直接操作 store）
- 跳过的测试必须写明原因（累计超过 3 个必须搭建 mock 环境解决）
- 每个关键动作后必须断言结果
- 关键业务字段必须断言具体值

### `/tdd:done` — 交付检查

每一项检查必须通过才能继续：

```
[ ] 编译通过（编译型语言必检）
[ ] 全量测试通过，覆盖率 >= 80%
[ ] 全量回归通过
[ ] E2E 通过
[ ] 功能文档已更新
[ ] Issue 已记录（如有符合条件的 bug）
[ ] 环境变量示例已同步
[ ] tasks.md 全部 [x]
```

### `/tdd:archive` — 归档规范

验证所有任务完成后，移入 `tdd-specs/archive/YYYY-MM/`。

---

## Harness Hooks

> 仅 Claude Code 支持。其他工具的质量约束靠 Prompt 层 + self-review。

`tdd-workflow init --tools claude` 会自动安装 5 个 hook 脚本到 `.claude/hooks/tdd/` 并注入 `.claude/settings.json`：

| Hook | 触发时机 | 作用 |
|------|---------|------|
| `pre-write-edit.sh` | 写/编辑文件前 | **RED 阶段阻止写 src/ 文件**（exit 2），只允许写测试文件 |
| `pre-bash.sh` | 执行命令前 | 代码变更后未跑测试时提醒 |
| `post-write-edit.sh` | 写/编辑文件后 | 记录 `last_edit_time` 到 `.harness` |
| `post-bash.sh` | 执行命令后 | 检测测试命令结果，追踪 strikes，3 次失败触发 Three-Strike |
| `user-prompt-submit.sh` | 用户发消息时 | 注入当前 phase/task/strikes 状态到 Claude 上下文 |

### `.harness` 状态文件

每个功能目录下有独立的 `.harness` 文件（`tdd-specs/<name>/.harness`），记录：

```
phase=red              # 当前阶段 (requirements/spec/red/green/refactor/e2e/deliver)
task=2.3               # 当前任务
strikes=0              # GREEN 阶段连续失败次数
last_test_time=1713234567    # 上次跑测试的时间戳
last_edit_time=1713234500    # 上次编辑代码的时间戳
```

多功能并行开发时，每个功能的状态独立——切换 `.current` 就切换了 harness 上下文。

### 注意事项

- **init 后需要重启 Claude Code session**，hooks 才会被加载（settings.json 只在启动时读取）
- 已有的 `.claude/settings.json` 不会被覆盖，TDD hooks 是追加合并的
- hooks 使用 `sed -i''` 语法，兼容 macOS 和 Linux

---

## Issue 追踪机制

TDD Workflow 内置轻量级 Issue 追踪，确保每个有价值的 bug 都被记录和追溯。

### 何时必须创建 Issue

满足以下**任一条件**即必须创建：

- Bug 修复耗时超过 5 分钟
- 同类错误出现 2 次以上
- 修复涉及 2 个以上文件

### Issue 文档格式

Issue 存放在 `docs/issues/` 目录（如果项目有该目录）：

```markdown
# Issue #012 — 评论验证边界条件未处理

## Basic Info
| Field | Content |
|-------|---------|
| Discovered | 2026-04-08 |
| Module | `src/services/comment-service.ts` |
| Severity | Medium |
| Status | Fixed |

## Symptoms
提交 501 字评论时返回 500 而非 400

## Root Cause Analysis
validateComment() 使用 > 而非 >= 比较，500 字恰好绕过校验，
导致数据库 VARCHAR(500) 约束抛出未处理异常。

## Fix
| File | Change |
|------|--------|
| src/services/comment-service.ts | `> 500` → `>= 500` |
| test/comment-service.test.ts | Added boundary test for 500/501 chars |

## Verification Steps
npm test -- --testPathPattern="comment-service"

## Prevention Measures
- 数值边界检查统一使用 >= 比较
- 所有字段长度限制必须有边界值测试
```

### Issue 何时被查阅

| 时机 | 方式 |
|------|------|
| `/tdd:ff` 生成规范前 | 浏览项目 issues 目录，关联已知问题 |
| 每次 `/tdd:green` 写实现前 | 搜索相关错误关键词，避免重复踩坑 |
| Three-Strike Protocol 触发后 | 全文搜索 + 模块过滤 |

---

## Three-Strike Protocol

当同一个测试连续失败 3 次时，自动触发暂停机制：

```
⚠️ WARNING: Three-Strike Protocol

Test: comment-service.createComment.should-handle-concurrent-requests
Attempt history:
  1. Added mutex lock -> "deadlock detected"
  2. Switched to optimistic locking -> "version conflict not handled"
  3. Added retry logic -> "max retries exceeded in test"

Issues search: found #009-database-connection-pool (similar concurrency issue)

Please choose:
  A. Try a different approach (describe your idea)
  B. Split into smaller test granularity
  C. Mark [!] skip, move to next task
  D. Need more context
```

这个机制防止 AI 在同一个问题上无限循环，把决策权交还给你。

---

## 目录结构约定

安装后，项目中会出现以下结构：

```
your-project/
├── .claude/                          # (或 .cursor/ .cline/ 等)
│   ├── settings.json                 # hooks 配置（仅 Claude Code，自动合并）
│   ├── hooks/tdd/                    # harness hook 脚本（仅 Claude Code）
│   │   ├── pre-write-edit.sh
│   │   ├── pre-bash.sh
│   │   ├── post-write-edit.sh
│   │   ├── post-bash.sh
│   │   └── user-prompt-submit.sh
│   ├── skills/tdd-workflow/
│   │   ├── SKILL.md                  # 完整技能定义
│   │   └── templates/                # 规范文档模板
│   │       ├── requirements.md
│   │       ├── design.md
│   │       ├── tasks.md
│   │       └── review-checklist.md   # Reviewer 评审标准
│   └── commands/tdd/
│       ├── new.md                    # /tdd:new
│       ├── ff.md                     # /tdd:ff
│       ├── loop.md                   # /tdd:loop
│       ├── bug.md                    # /tdd:bug
│       ├── change.md                 # /tdd:change
│       ├── continue.md              # /tdd:continue
│       ├── e2e.md                    # /tdd:e2e
│       ├── done.md                   # /tdd:done
│       └── archive.md               # /tdd:archive
└── tdd-specs/                        # 规范文件存放目录
    ├── .current                      # 当前活跃的功能名
    ├── blog-comments/                # 进行中的功能
    │   ├── .harness                  # harness 状态（phase/strikes/时间戳）
    │   ├── requirements.md
    │   ├── design.md
    │   └── tasks.md
    └── archive/                      # 已完成的功能
        └── 2026-04/
            └── user-auth/
```

### 任务状态标记

| 标记 | 含义 |
|------|------|
| `- [ ]` | 未开始 |
| `- [~]` | 进行中（RED 已写，GREEN 未完成） |
| `- [x]` | 已完成 |
| `- [!]` | 阻塞（Three-Strike Protocol 触发，等待决策） |

---

## 支持的工具

| 工具 | ID | 技能目录 | 命令目录 |
|------|----|----------|----------|
| Claude Code | `claude` | `.claude/skills/tdd-workflow/` | `.claude/commands/tdd/` |
| Cursor | `cursor` | `.cursor/skills/tdd-workflow/` | `.cursor/commands/tdd/` |
| Cline | `cline` | `.cline/skills/tdd-workflow/` | `.cline/commands/tdd/` |
| Windsurf | `windsurf` | `.windsurf/skills/tdd-workflow/` | `.windsurf/commands/tdd/` |
| CodeBuddy | `codebuddy` | `.codebuddy/skills/tdd-workflow/` | `.codebuddy/commands/tdd/` |
| GitHub Copilot | `copilot` | `.github/skills/tdd-workflow/` | `.github/commands/tdd/` |

工具检测逻辑：扫描项目根目录下是否存在对应的配置目录（`.claude/`、`.cursor/` 等）。

---

## 与 OpenSpec 的对比

[OpenSpec](https://github.com/SilentOverflow03/OpenSpec) 是另一个流行的规范驱动开发工具。两者解决的问题不同：

> **OpenSpec 解决「AI 不知道该做什么」——让 AI 按规范写代码。**
>
> **TDD Workflow 解决「AI 写的代码不靠谱」——用测试驱动 + 质量门禁确保代码真正能用。**

### 流程对比

```
OpenSpec:    Propose → Review specs → Apply (AI 自由发挥写代码) → Archive
TDD Workflow: 需求收集 → 规范生成 → RED → GREEN → REFACTOR → E2E → 交付检查 → 归档
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                     OpenSpec 没有覆盖的部分
```

OpenSpec 的 Apply 就是一句 `/opsx:apply`——怎么写代码、怎么测试、质量如何，全靠 AI 自由发挥。TDD Workflow 的规范生成只是起点，重点在后面整个 TDD 循环和质量门禁。

### TDD Workflow 有而 OpenSpec 没有的

| 能力 | TDD Workflow | OpenSpec |
|------|-------------|---------|
| **强制测试先行** | RED 必须先看到测试失败才能写实现代码 | 无测试约束，Apply 直接生成代码 |
| **自动 TDD 循环** | `/tdd:loop` 自动 red→green→refactor 直到完成 | 无对应机制 |
| **Three-Strike Protocol** | 同一测试失败 3 次自动暂停，等人决策 | 无失败熔断，AI 可能无限循环 |
| **测试覆盖检查** | 生成 tasks 后自动检查单元/集成/E2E 三层是否都有任务，缺了自动补 | 不关心测试分层 |
| **回归保护** | 每次 GREEN 都跑全量回归，不只跑单个测试 | 无回归机制 |
| **Issue 追踪** | 内置 Issue 文档生成，修复超 5 分钟/跨文件/重复出现必须记录 | 无 |
| **Bug 修复流程** | `/tdd:bug` 完整链路：报告→Issue→复现测试→修复→验证→归档 | 无专门 bug 流程 |
| **交付门禁** | `/tdd:done` 8 项检查必须全过才能交付 | 无交付验证 |
| **中途变更管理** | `/tdd:change` 自动影响分析 + 已完成任务自动回退 | 可以改规范但没有影响分析和任务回退 |
| **任务状态跟踪** | `[ ]` `[~]` `[x]` `[!]` 四种状态实时更新 | tasks.md 有 checklist 但无进行中/阻塞状态 |
| **Multi-Agent** | Coder/Reviewer 分离，写代码和评审代码是不同 Agent | 单 Agent 自写自审 |
| **Bug 回顾机制** | 每个 bug 强制分类根因 + 立即执行预防措施 + 搜索同类问题 | 无 |

### OpenSpec 有而 TDD Workflow 没有的

| 能力 | OpenSpec | TDD Workflow |
|------|---------|-------------|
| **系统级规范** | `specs/` 维护「当前系统全貌」活文档，变更是 delta | 只有功能级规范，没有系统全貌 |
| **Delta 规范格式** | ADDED/MODIFIED/REMOVED 结构化标记 | 无 delta 格式 |
| **CLI 管理命令** | `list`、`view`、`validate`、`show` 等 | 只有 `init` 和 `update` |
| **支持工具数量** | 17+（含 Codex、Amazon Q、Augment 等） | 6 个 |
| **Brownfield 优化** | 专门为改造存量项目设计 | 更偏新功能开发 |

### 实际场景对比

用一个例子说明区别——「给 API 添加分页功能」：

**OpenSpec 的做法：**

```
/opsx:propose add-pagination
→ 生成 proposal.md、design.md、tasks.md（delta spec 标记哪些接口要改）
→ 人工 review 规范
/opsx:apply
→ AI 按规范写代码（怎么测试？不知道。写对了吗？希望吧。）
/opsx:archive
→ 完成
```

**TDD Workflow 的做法：**

```
/tdd:new add-pagination
→ 交互式收集：分页参数格式？默认每页几条？总数怎么算？超出范围返回什么？
/tdd:ff
→ 生成三份规范，自动检查：单元测试有吗？集成测试覆盖 HTTP 链路了吗？E2E 有吗？缺了自动补
/tdd:loop
→ RED:  写测试 — GET /api/posts?page=2&limit=10 应返回第 11-20 条 — 运行，失败 ✓
→ GREEN: 写最少实现 — 跑全量回归确认没有破坏已有功能 ✓
→ RED:  写测试 — page=0 应返回 400 — 运行，失败 ✓
→ GREEN: 加参数校验 — 全量回归 ✓
→ RED:  写测试 — page 超出总页数应返回空数组 — 运行，失败 ✓
→ GREEN: 加边界处理 — 全量回归 ✓
  （某个测试连续失败 3 次 → Three-Strike Protocol 暂停，你来决定怎么办）
→ ... 12 轮后 Phase 2 全部 [x]
/tdd:e2e
→ 用 Playwright 写端到端测试，跑真实网络请求
/tdd:done
→ 8 项检查：编译 ✓ 覆盖率 92% ✓ 回归 ✓ E2E ✓ Issue 记录 ✓ ...
→ 全过才算交付
```

### 能组合使用吗？

可以。两者不冲突：

- 用 **OpenSpec** 管理系统级规范（`specs/` 描述系统全貌）
- 用 **TDD Workflow** 管理每个功能的实现质量（测试驱动 + 质量门禁）

但如果只选一个：**规范写得再好，没有测试验证就只是「希望 AI 做对」**。TDD Workflow 确保每一行代码都有测试背书。

---

## 常见问题

### 这个工具适合什么项目？

任何需要 TDD 流程的项目——前端、后端、CLI 工具、库。支持的语言和测试框架不受限制，AI 助手会根据项目实际的 `package.json` / `pyproject.toml` / `go.mod` 等自动适配。

### 什么不适合用 TDD Workflow？

- 单行 typo 修复
- 纯文档 / 配置修改
- 简单样式调整

这些直接 `git commit` 就好。

### 我只用 Claude Code，需要装其他工具的文件吗？

不需要。`--tools claude` 只安装 Claude Code 对应的文件。交互模式下也可以只勾选一个工具。

### 文件已存在会覆盖吗？

默认不会。已存在的文件会跳过，CLI 会提示 `⚠ N files skipped (use --force to overwrite)`。加 `--force` 覆盖。

### 如何更新到新版本？

```bash
npx tdd-workflow@latest update
```

自动检测已安装的工具并更新所有文件。

### init 后 hooks 没有生效？

Claude Code 的 `settings.json` 只在 session 启动时加载。`tdd-workflow init` 之后需要 **退出并重新进入 Claude Code**，hooks 才会生效。

### Multi-Agent 在 Cursor/CodeBuddy 里能用吗？

会自动降级为单 Agent + 强制 self-review。Coder/Reviewer 分离是 Claude Code 特有的（依赖 Agent tool），其他工具写完代码后会强制按 review-checklist.md 自检，输出 `[Review:RED]` / `[Review:GREEN]` 评审结果。

### Hooks 会影响我已有的 settings.json 吗？

不会覆盖。TDD hooks 是追加合并的——你已有的 permissions、env、其他 hooks 都会保留。重复 init 会先移除旧的 TDD hooks 再写入新的，不会重复。
