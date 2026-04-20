---
name: "TDD: Done"
description: Phase 4 交付验证——4 阶段验证执行（本地代码 → 本地 E2E → 测试环境 → 交付），基于项目级 + Feature 级 verify 配置
category: TDD Workflow
tags: [tdd, done, delivery, verify]
---

Phase 4: 交付验证。严格按 `tdd-specs/.verify/project.md` + `tdd-specs/<feature>/verify.md` 执行 4 阶段验证。

**核心原则**：
- **不自由发挥**——按 verify 配置执行，不随意增减步骤
- **混合交互**——Stage 之间关卡用 `AskUserQuestion`（Y/N/Skip），Stage 内详细验证让用户自由回复
- **参数化**——`${VAR}` 在执行前解析为实际值
- **Cleanup 保障**——Stage 2 前后自动清理，防止旧服务污染验证

---

## Steps

### 0. 前置检查 + 设置 harness

```bash
SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -z "$SPEC" ]; then
  echo "ERROR: 没有 active spec，先跑 /tdd:new"
  exit 1
fi

# 设置 harness phase
if [ -f "tdd-specs/$SPEC/.harness" ]; then
  sed -i '' 's/phase=.*/phase=deliver/' "tdd-specs/$SPEC/.harness"
fi
```

### 1. 加载验证配置

按优先级合并配置（在 AI 上下文里完成 `${VAR}` 替换，不在 shell 里做）：

```bash
# 检查配置存在性
if [ -f tdd-specs/.verify/project.md ]; then
  echo "✓ 项目级配置: tdd-specs/.verify/project.md"
  cat tdd-specs/.verify/project.md
fi
if [ -f tdd-specs/.verify/project.local.md ]; then
  echo "✓ 个人参数: tdd-specs/.verify/project.local.md"
  cat tdd-specs/.verify/project.local.md
fi
if [ -f "tdd-specs/$SPEC/verify.md" ]; then
  echo "✓ Feature 配置: tdd-specs/$SPEC/verify.md"
  cat "tdd-specs/$SPEC/verify.md"
fi
```

**参数解析优先级**（AI 在上下文里执行）：
1. 命令行 `--var VAR=value`
2. Shell 环境变量（提醒用户：`env | grep VAR_NAME`）
3. `project.local.md`
4. `project.md` 的 `${VAR:-default}` 默认值
5. 必填但未提供 → 报错并要求用户设置

**退化模式**：如果 `project.md` 不存在，提示：
> ⚠ 项目未配置验证（tdd-specs/.verify/project.md 不存在）
> 本次 /tdd:done 将用通用检查（unit test、build、回归）。
> 建议跑 /tdd:verify-setup 配置项目验证以获得完整的 4 阶段验证。

用 **AskUserQuestion**：`[A] 继续通用检查` `[B] 先跑 /tdd:verify-setup 再回来` `[C] 中止`

### 2. Stage 1: 本地代码验证（全自动）

**目标**：跑通所有命令类验证。AI 自己跑、看结果，不需要用户参与。

```bash
# 将 verify_stage 设为 1
sed -i '' 's/verify_stage=.*/verify_stage=1/' "tdd-specs/$SPEC/.harness"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stage 1: 本地代码验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

逐项执行 `commands` 中定义的（跳过 null）：

| 检查 | 命令来源 | 失败处理 |
|------|---------|---------|
| Typecheck | `commands.typecheck` | 失败 → 中止 |
| Lint | `commands.lint` | 失败 → 中止 |
| Build | `commands.build` | 失败 → 中止 |
| Unit tests | `commands.unit` | 失败 → 中止 |
| Integration | `commands.integration` | 失败 → 中止 |
| Coverage | `commands.unit` with coverage flag | 未达 `commands.coverage_target` → 警告（非中止） |

每步输出状态行：

```
[Stage 1/4]
  ✓ typecheck     (npm run typecheck)             2.3s
  ✓ lint          (npm run lint)                  1.1s
  ✓ build         (npm run build)                 8.7s
  ✓ unit          (npm run test:unit)            12.5s  142 pass, 0 fail
  ✓ integration   (npm run test:integration)     45.2s  23 pass, 0 fail
  ✓ coverage      87% (target: 85%)
  
  Stage 1 ✓ PASSED
```

**失败处理**：任一步失败 → 用 **AskUserQuestion**：
- `[A] 进入 /tdd:bug 流程修复`
- `[B] 查看详细日志`
- `[C] 中止验证`

### 3. Stage 1 → 2 关卡

用 **AskUserQuestion**：
> "Stage 1 全部通过。继续 Stage 2 本地 E2E 验证？"
> - [A] 继续
> - [B] 跳过 Stage 2-3，直接 Stage 4 交付（小改动适用）
> - [C] 中止

### 4. Stage 2: 本地 E2E 验证（人机交互）

```bash
sed -i '' 's/verify_stage=.*/verify_stage=2/' "tdd-specs/$SPEC/.harness"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stage 2: 本地 E2E 验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

#### 4.1 执行 pre_verify_cleanup

按 `environments.dev.pre_verify_cleanup` 逐步执行。对每个步骤：

1. 如果是 `preset:` → 从 `skills/verify-presets/cleanup.md` 展开为实际命令
2. 如果是 `command:` → 直接用
3. 执行 `${VAR}` 参数替换
4. 加超时保护（默认 30s）
5. 根据 `on_fail` 处理失败

输出：
```
[Cleanup] pre_verify_cleanup (dev)
  ✓ kill_port(3000): 释放端口（原占用 PID 12345）
  ✓ kill_node_process("npm run dev"): 杀掉 2 个进程
  ✓ docker_compose_down: 停止 3 容器，清理 volumes
  ⚠ clean_tmp_files: 跳过（没有匹配文件）
  ✓ reset_db: 数据库已重置
```

**关键失败处理**（`on_fail: abort`）：
```
✗ reset_db: 失败
  错误: Database is being used by other processes

🤖 reset_db 是必须成功的步骤（on_fail: abort）
   [A] 诊断占用（自动查询并提示处理）
   [B] 跳过此步（不推荐）
   [C] 中止验证
```

#### 4.2 启动 dev server + 等待 readiness

```bash
# 启动（后台跑）
<environments.dev.start> &
DEV_PID=$!
echo $DEV_PID > /tmp/tdd-dev-pid-$SPEC
```

Readiness 轮询（最多 60s）：
```bash
for i in $(seq 1 60); do
  if <environments.dev.readiness>; then
    echo "✓ dev server ready ($i seconds)"
    break
  fi
  sleep 1
done
```

Ready 失败 → 中止 Stage 2，进入失败处理。

#### 4.3 执行 common_flows（项目级）

逐个 flow 输出详细描述，**不用 AskUserQuestion**（让用户自由回复）：

```
━━ Common Flow: login ━━
描述: 用户登录

请按以下步骤在浏览器/终端验证：

1. 访问 http://localhost:3000/login
2. 输入 alice@test.com / alice-dev-pwd
3. 验证跳转到 /dashboard

⏳ 完成后告诉我结果（"通过" / "有问题：xxx"）
```

等待用户回复：
- "通过" / "pass" / "OK" → 记录 PASS，下一个 flow
- 描述问题 → 记录 FAIL，进入失败处理

#### 4.4 执行 feature_specific_flows

同样格式，把 feature 的验证流程逐个展示。用户自由回复。

**所有 flows 都通过**后：
```bash
sed -i '' 's/verify_local_ok=.*/verify_local_ok=true/' "tdd-specs/$SPEC/.harness"
```

#### 4.5 执行 post_verify_cleanup

同 4.1 格式，跑 `environments.dev.post_verify_cleanup`。

### 5. Stage 2 → 3 关卡

用 **AskUserQuestion**：
> "Stage 2 通过。是否部署到 staging 验证？"
> - [A] 是，部署 staging
> - [B] 跳过 staging，直接交付（小改动或无 staging 环境）
> - [C] 中止

### 6. Stage 3: 测试环境验证（可选）

```bash
sed -i '' 's/verify_stage=.*/verify_stage=3/' "tdd-specs/$SPEC/.harness"
```

#### 6.1 执行 deploy 命令

```bash
# 执行 environments.staging.deploy（参数替换后）
<staging.deploy>
DEPLOY_EXIT=$?

if [ $DEPLOY_EXIT -ne 0 ]; then
  echo "✗ 部署失败（exit $DEPLOY_EXIT）"
  # 进入失败处理
fi
```

#### 6.2 等待 staging readiness

同 4.2 格式，超时 120s（staging 启动可能更慢）。

#### 6.3 执行 post_deploy_smoke

逐个展示给用户，等自由回复。

#### 6.4 在 staging 上跑 feature flows（可选）

用 **AskUserQuestion**：
> "要在 staging 上复跑 feature_specific_flows 吗？"
> - [A] 是（完整验证）
> - [B] 否（smoke 通过就够）

所有通过后：
```bash
sed -i '' 's/verify_staging_ok=.*/verify_staging_ok=true/' "tdd-specs/$SPEC/.harness"
```

### 7. Stage 3 → 4 关卡

用 **AskUserQuestion**：
> "Staging 验证通过。准备最终交付？"
> - [A] 是，生成交付报告
> - [B] 还需要更多验证（描述）
> - [C] 中止

### 8. Stage 4: 交付确认

```bash
sed -i '' 's/verify_stage=.*/verify_stage=4/' "tdd-specs/$SPEC/.harness"
```

#### 8.1 生成 verification-report.md

写到 `tdd-specs/$SPEC/verification-report.md`：

```markdown
# Verification Report — <feature>

> Generated: YYYY-MM-DD HH:MM:SS
> Spec: tdd-specs/<feature>/

## Summary
- Stage 1: ✓ PASSED
- Stage 2: ✓ PASSED (local E2E + <N> flows)
- Stage 3: ✓ PASSED (staging deploy + smoke)
- Stage 4: ✓ DELIVERED

## Stage 1: 本地代码验证
| Check | Command | Result | Duration |
|-------|---------|--------|----------|
| typecheck | npm run typecheck | ✓ | 2.3s |
| ...

## Stage 2: 本地 E2E
### pre_verify_cleanup
<逐项结果>

### Flows Executed
| Flow | Type | Result | User Response |
|------|------|--------|---------------|
| login | common | ✓ | "通过" |
| 评论发布延迟 | feature | ✓ | "通过，1.3s 出现" |
| ...

### post_verify_cleanup
<逐项结果>

## Stage 3: Staging 验证
### Deploy
- Command: bash scripts/deploy-staging.sh
- Result: ✓ (exit 0, 45s)

### Readiness
- URL: https://staging-alice.example.com
- Ready after: 12s

### Smoke Tests
<逐项结果 + 用户反馈>

## 监控链接（交付后观察）
- Dashboard: https://grafana.example.com/xxx
- Logs: kubectl logs -n staging -l app=myapp

## Delivery Report
### 实现
- 新增文件: <list>
- 修改文件: <list>

### 测试统计
- 单元: N pass
- 集成: N pass
- E2E: N pass
- 覆盖率: N%

### Issues
- <IDs 或 none>
```

#### 8.2 最终提示

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Feature <name> 已完成 4 阶段验证
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

交付报告: tdd-specs/<name>/verification-report.md
监控链接: <从 project.md 读取>

下一步:
  /tdd:notes    — 生成 TDD 实践记录
  /tdd:archive  — 归档规范和报告
```

### 9. Skip 机制

支持命令参数：
- `/tdd:done --skip-stage 2,3` — 跳过 Stage 2-3，直接 Stage 4
- `/tdd:done --skip-stage 3` — 只跳过 staging
- `/tdd:done --dry-run` — 只打印会执行的命令，不真跑

跳过的 stage 在 verification-report.md 中标记：
```
- Stage 3: ⊘ SKIPPED (user chose: 小改动无需 staging)
```

### 10. 失败处理总则

任何阶段失败时，用 **AskUserQuestion**：
> "Stage X 失败。下一步？"
> - [A] 进入 /tdd:bug 流程（创建 Issue + 复现测试 + 修复）
> - [B] 手动修复（退出 /tdd:done，修复后重跑）
> - [C] 查看详细日志
> - [D] 标记为 waived（记录理由，不推荐）

---

## Guardrails

- **严格按 verify 配置执行** — 不发明未配置的检查，不跳过已配置的检查
- **参数替换要做** — 所有 `${VAR}` 必须在执行前替换为实际值，不能直接跑含占位符的命令
- **Cleanup 不能跳过** — Stage 2 的 pre_verify_cleanup 必须执行完才启动 dev server
- **用户回复不放过** — Stage 2/3 的每个 flow 必须得到用户 "通过" 或问题描述，不能自己说 OK
- **verification-report 必须生成** — 即使失败也生成（记录失败状态），便于复盘
- **退化模式要降级** — 没有 verify 配置时，不要假装做了 4 阶段验证
- **失败时不自动重试** — 交给用户决策，避免无限循环
