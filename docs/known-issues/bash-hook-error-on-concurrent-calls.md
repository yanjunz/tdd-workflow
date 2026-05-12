# Bash hook error 红字（并发调用时的 UI 误报）

> 状态：**已知问题，不影响功能**。Claude Code 上游 bug，tdd-workflow 侧无法彻底修复。
>
> 首次发现：2026-04-27（v2.4.2 诊断时怀疑过）
> 反复确认：2026-05-12（trace 探针证实并发是触发器）
> 适用版本：tdd-workflow 2.4.2 ~ 现在（行为与 hook 实现无关）

## 现象

在 Claude Code 中使用 tdd-workflow 时，UI 偶发出现：

```
⏺ Searching for 5 patterns, reading 2 files...
  ⎿  ~/path/to/some/file.ts
  ⎿  PreToolUse:Bash hook error
  ⎿  PostToolUse:Bash hook error
  ⎿  PreToolUse:Bash hook error
  ⎿  PostToolUse:Bash hook error
  ⎿  ...
```

**关键观察**：

- 报错总是成串出现（一次出 N 对 Pre/PostToolUse:Bash）
- 报错的同一时刻，Claude 通常正在**并发**跑多条 bash（grep + cat + find 一起跑）
- 实际功能（RED 阶段阻断写、Strike 计数、last_test_time 更新等）**全部正常生效**
- `/tmp/tdd-hook-pre-bash.log` 等日志显示每个 hook 进程都 `reached end, exit 0`
- 脚本手动用相同 stdin JSON 调用 → 100% 通过，无任何报错

## 根因

通过在脚本第 2 行（shebang 之后）注入"启动信号"探针 `echo "$(date) STARTED pid=$$ ppid=$PPID" >> /tmp/tdd-hook-trace2.log` 抓到铁证：

```
2026-05-12 16:33:16 pre-bash STARTED pid=29627 ppid=57242
2026-05-12 16:33:16 pre-bash STARTED pid=29626 ppid=57242   ← 同秒
2026-05-12 16:33:16 pre-bash STARTED pid=29625 ppid=57242   ← 同秒，3 个一起
2026-05-12 16:33:16 post-bash STARTED pid=30898 ppid=57242
2026-05-12 16:33:16 post-bash STARTED pid=30897 ppid=57242
2026-05-12 16:33:16 post-bash STARTED pid=30899 ppid=57242
```

同一秒钟同一父进程（ppid=57242，即 Claude Code 主进程）拉起 **3 个并发的 pre-bash + 3 个并发的 post-bash**。日志里 6 个进程全部 `reached end, exit 0`，但 UI 报了 6 次 hook error。

Claude Code 官方文档承认：

> Hooks execute in parallel when multiple tool calls run concurrently.
> There is no documented way to force sequential execution.

并未承诺并发场景下 stdin/stdout pipe 隔离。推断：Claude Code 内部分发 hook event JSON 到子进程 stdin、再读子进程 stdout 时，并发协调层（可能是 Node EventEmitter 的 pipe handling）出现 SIGPIPE / EPIPE / 提前 close pipe 等 IPC 异常，UI 把这个**调度层**错误显示为"hook error"——尽管子进程本身已经 exit 0。

## 影响范围

**❌ 不影响**：

| 功能 | 状态 |
|---|---|
| RED 阶段阻断 src/ 写入（pre-write-edit） | 正常。Write/Edit 工具不并发，每次单进程调用 |
| Strike 计数（post-bash） | 正常。计数器最终落到 .harness 文件 |
| Three-Strike Protocol 触发 | 正常。日志里能看到 `[THREE-STRIKE] same test failed N times` |
| last_test_time / last_edit_time 时间戳 | 正常 |
| UserPromptSubmit context 注入 Phase: 行 | 正常 |

**⚠ 影响**：

| 表现 | 说明 |
|---|---|
| UI 红字噪音 | 用户看到一堆 hook error，但实际全部成功。心理负担、用户怀疑 |
| 调试干扰 | 真正的 hook 错误（如未来引入新 bug）会被这堆假阳性淹没 |

## 触发条件

只在以下场景出现，单条单调用从不触发：

- Claude 单回合内**并发**多条 Bash 工具调用（最常见：grep + cat + find 同时启动搜文件）
- Claude 跑批量测试用例（`npm test --` 一次跑多个 spec）

## 解决方案

### 短期：**忽略红字**

只要 `/tmp/tdd-hook-{pre,post}-{bash,write-edit}.log` 里看到 `reached end, exit 0`，就是真的成功，不用管 UI 红字。

### 中期：上报 Claude Code 上游

在 https://github.com/anthropics/claude-code 提 issue，详见 `docs/known-issues/upstream-bash-hook-error.upstream-issue.md`。

### 终极规避（不推荐）

如果实在受不了红字，只能在 `.claude/settings.json` 里删掉整个 `hooks` 节、关闭 hooks。代价：

- ❌ RED 阶段不能阻断写实现文件
- ❌ Strike 计数器不工作
- ❌ UserPromptSubmit 不再注入 Phase 状态到 Claude context

不值得。

## 诊断方法（如未来需要复现）

在出问题的项目里加 trace beacon：

```bash
cd <project>/.claude/hooks/tdd
for f in pre-bash.sh post-bash.sh user-prompt-submit.sh; do
  cp "$f" "$f.bak"
  awk 'NR==1 {print; print "echo \"$(date +%F-%T) " "'"$f"'" " STARTED pid=$$ ppid=$PPID\" >> /tmp/tdd-hook-trace2.log 2>/dev/null"; next} {print}' "$f.bak" > "$f"
done
: > /tmp/tdd-hook-trace2.log
```

复现报错后：

```bash
cat /tmp/tdd-hook-trace2.log     # 看是否同秒钟有多个进程
tail -30 /tmp/tdd-hook-pre-bash.log  # 每个进程是否 reached end exit 0
```

诊断完恢复：

```bash
for f in pre-bash.sh post-bash.sh user-prompt-submit.sh; do
  mv "$f.bak" "$f"
done
rm /tmp/tdd-hook-trace2.log
```

## 相关历史

- v2.4.2: 诊断时**误判**已经修好（当时只验证了单调用场景）
- v2.4.3: 加详细日志（让本次诊断成为可能）
- v2.4.4: 修复 `.current` 含换行 bug + post-bash 大 payload 优化
- v2.5.0（feature/screen_verify 分支，未发布）: 截图能力，已搁置
- v2.5.1+: 持续观察上游修复
