---
name: "TDD: Cleanup"
description: 手动触发 cleanup，不跑验证本身——用于验证跑崩后清理环境、或开始验证前手动清理
category: TDD Workflow
tags: [tdd, verify, cleanup]
---

手动执行 cleanup。不跑验证本身，只跑 `tdd-specs/.verify/project.md` 里 `environments.{env}.pre_verify_cleanup` 定义的清理步骤。

**使用场景**：
- 上次 `/tdd:done` 跑崩，留下了僵尸进程、占用的端口、未关的 Docker
- 手动切换测试任务前，想先清理环境
- 调试 cleanup 配置是否正确

**输入**：环境名（dev / staging / 自定义），默认 `dev`

---

## Steps

### 1. 前置检查

```bash
if [ ! -f tdd-specs/.verify/project.md ]; then
  echo "ERROR: 项目未配置验证"
  echo "请先跑 /tdd:verify-setup"
  exit 1
fi
```

### 2. 解析环境名

- 如果命令参数提供了环境名，用参数
- 否则默认 `dev`
- 验证该环境在 `project.md` 中存在，否则列出可用环境

### 3. 加载配置与参数

读取：
- `tdd-specs/.verify/project.md` — 获取 `environments.{env}.pre_verify_cleanup`
- `tdd-specs/.verify/project.local.md` — 个人参数
- Shell env — 敏感参数

在 AI 上下文中完成 `${VAR}` 替换。

### 4. 选择 cleanup 范围

用 **AskUserQuestion**：
> "要跑哪个 cleanup？"
> - [A] `pre_verify_cleanup` —— 验证前清理（推荐，完整清理）
> - [B] `post_verify_cleanup` —— 验证后清理
> - [C] 两个都跑

### 5. Dry-run 预览

如果命令带 `--dry-run`，只打印将执行的命令，不真跑：

```
[DRY RUN] 将执行 5 个 cleanup 步骤（dev 环境）:
  1. kill_port(3000) → lsof -ti:3000 | xargs kill -9 2>/dev/null || true
  2. kill_node_process("npm run dev") → pkill -f 'npm run dev' 2>/dev/null || true
  3. docker_compose_down("docker-compose.dev.yml", volumes=true) → docker compose -f docker-compose.dev.yml down -v
  4. reset_db → npm run db:reset
  5. clean_tmp_files("/tmp/myapp-*") → rm -rf /tmp/myapp-* 2>/dev/null || true
```

### 6. 执行 cleanup

按 `project.md` 中 `pre_verify_cleanup` 列表顺序执行：

```
[Cleanup] dev 环境 (5 步骤)

  [1/5] kill_port(3000)
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        ✓ 完成 (0.3s，杀掉 PID 12345)

  [2/5] kill_node_process("npm run dev")
        pkill -f 'npm run dev' 2>/dev/null || true
        ✓ 完成 (0.2s，杀掉 2 个进程)

  [3/5] docker_compose_down
        docker compose -f docker-compose.dev.yml down -v
        ✓ 完成 (4.5s，停止 3 容器，清理 volumes)

  [4/5] reset_db
        npm run db:reset
        ✗ 失败（on_fail: abort）
        
  错误: Database 'myapp_test' is being used by other processes
```

### 7. 失败处理

每个步骤按 `on_fail` 处理：

| on_fail | 行为 |
|---------|------|
| `continue` | 失败也继续下一步 |
| `abort` | 中止整个 cleanup |
| `ask` | 用 AskUserQuestion 问用户 |

`abort` 失败时：
```
🤖 步骤 reset_db 失败（on_fail: abort）
   [A] 诊断占用（自动查询数据库连接）
   [B] 重试该步骤
   [C] 跳过继续（不推荐）
   [D] 中止 cleanup
```

### 8. 输出总结

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Cleanup 完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ 成功: 5
⚠ 跳过: 0
✗ 失败: 0

耗时: 5.3s
```

---

## Guardrails

- **不做验证** — 这是纯清理命令，不启动服务、不跑测试
- **参数替换** — 执行前必须把 `${VAR}` 替换为实际值
- **幂等保证** — 所有 cleanup 命令必须可重复运行，不存在的资源不应报错
- **敏感参数不泄露** — 日志中 `${TOKEN}` 等敏感值显示为 `***`
- **失败处理遵循 on_fail** — 不擅自决定继续还是中止
