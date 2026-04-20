---
name: "TDD: Verify Setup"
description: 交互式生成项目级验证配置 tdd-specs/.verify/project.md，包含 commands、environments、flows、cleanup 和部署脚本
category: TDD Workflow
tags: [tdd, verify, setup, project-config]
---

交互式配置**项目级验证**。所有 feature 共享这份配置，`/tdd:done` 会严格按此执行。

**什么时候跑**：项目第一次用 TDD Workflow，或者之前的 `project.md` 需要重做。

**产物**：
- `tdd-specs/.verify/project.md` — 验证配置（提交 git，团队共享）
- `tdd-specs/.verify/project.env.example` — 敏感参数文档（说明需要哪些 shell 环境变量）
- `scripts/deploy-staging.sh`（或类似）— 如果用户需要 staging 验证，生成部署脚本骨架
- 自动更新 `.gitignore` 排除 `tdd-specs/.verify/project.local.md`

---

## Steps

### 1. 检查是否已存在

```bash
if [ -f tdd-specs/.verify/project.md ]; then
  echo "WARNING: tdd-specs/.verify/project.md already exists"
fi
```

如果已存在，用 **AskUserQuestion**：
- `[A] 查看现有配置，不修改`
- `[B] 编辑特定章节（commands / environments / flows / cleanup）`
- `[C] 完全重做（覆盖现有）`
- `[D] 退出`

### 2. 检测项目技术栈

```bash
# 检测包管理与测试框架
ls package.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle 2>/dev/null
cat package.json 2>/dev/null | grep -E '"(jest|vitest|mocha|test|lint|build|typecheck)"' | head -20

# 检测容器化
ls docker-compose*.yml Dockerfile 2>/dev/null

# 检测部署平台线索
ls .github/workflows/ .gitlab-ci.yml vercel.json netlify.toml k8s/ charts/ 2>/dev/null
```

把发现的内容告诉用户，作为后续问题的上下文。

### 3. Phase A: Commands（命令类验证）

逐项询问（用 **AskUserQuestion** 给常见选项 + Other 自由输入）：

| 问题 | 默认值来源 |
|------|-----------|
| 单元测试命令？ | 从 package.json scripts 推测 |
| 集成测试命令？（skip 表示没有） | 同上 |
| E2E 测试命令？（skip 表示没有） | 同上 |
| Typecheck 命令？（skip 表示没有） | 根据 tsconfig.json / mypy.ini 推测 |
| Lint 命令？（skip 表示没有） | 根据 .eslintrc / .flake8 推测 |
| Build 命令？（skip 表示没有） | 同上 |
| 覆盖率目标？（默认 80） | 用户输入数字 |

### 4. Phase B: Dev 环境

询问：
- Dev server 启动命令？（默认从 `npm run dev` 等推测）
- Dev 服务端口？（检测 package.json / .env 里的 PORT）
- 健康检查 URL/命令？（默认 `curl -sf http://localhost:${DEV_PORT}/health`）
- 测试账号邮箱/密码？（告诉用户敏感值会放 local.md 而非 project.md）

**Cleanup 推荐**：根据检测结果自动推荐 pre_verify_cleanup 步骤：
- 有 package.json + dev server → `kill_port` + `kill_node_process`
- 有 docker-compose → `docker_compose_down`
- 有 DATABASE_URL → 问用户"需要重置数据库吗？重置命令是？"
- 有 Redis 依赖 → 问"需要清 Redis 吗？db 编号？"

每个推荐用 **AskUserQuestion** 确认：`[Y] 加入` `[N] 跳过` `[E] 编辑参数`。

### 5. Phase C: Staging 环境（可选）

先问：`是否需要 staging 环境验证？[Y] 需要 [N] 跳过 staging`

如果 Y，继续：
- Staging URL 模板？（例：`https://staging-${MY_USER}.example.com`，识别 `${MY_USER}` 是个人参数）
- 健康检查命令？

**部署脚本生成**（核心）：

```
🤖 Staging 部署方式？
   [A] SSH + rsync/scp 到服务器
   [B] Kubernetes (kubectl apply)
   [C] Vercel / Netlify / Cloudflare Pages
   [D] Docker push + registry
   [E] Git push 触发 CI (GitHub Actions / GitLab CI)
   [F] 已有脚本，只要配置路径
   [G] 其他（自由描述）
```

根据选择生成 `scripts/deploy-staging.sh` 骨架（或 workflow 文件），例如 SSH 方案：

```bash
#!/usr/bin/env bash
# Staging 部署脚本
# 生成于 /tdd:verify-setup
set -e

MY_USER="${MY_USER:?请在 project.local.md 或 shell env 设置 MY_USER}"
STAGING_HOST="${STAGING_HOST:?请设置 STAGING_HOST}"
STAGING_USER="${STAGING_USER:-deploy}"

echo "==> 构建..."
npm run build  # TODO: 按实际项目修改

echo "==> 打包..."
tar czf /tmp/deploy-${MY_USER}.tar.gz dist/ package.json

echo "==> 上传到 ${STAGING_HOST}..."
scp /tmp/deploy-${MY_USER}.tar.gz ${STAGING_USER}@${STAGING_HOST}:/tmp/

echo "==> 远程解压并重启服务..."
ssh ${STAGING_USER}@${STAGING_HOST} <<EOF
  cd /var/www/staging-${MY_USER}
  tar xzf /tmp/deploy-${MY_USER}.tar.gz
  # TODO: 重启服务（pm2/systemd/docker）
  pm2 restart staging-${MY_USER}
EOF

echo "✓ 部署完成"
```

**关键**：脚本是骨架，有 `TODO` 标记。生成后告诉用户：
> 我已生成 scripts/deploy-staging.sh 骨架。**请检查并完善 TODO 部分**，确认后这个脚本会被 /tdd:done 调用。

用 **AskUserQuestion**：`[A] 现在编辑脚本` `[B] 稍后自己改，先继续`

把 `bash scripts/deploy-staging.sh` 写入 `project.md` 的 `environments.staging.deploy`。

**Post-deploy smoke 步骤**：询问"部署完成后，如何确认服务正常？"—— 收集 3-5 个人工/自动检查步骤。

### 6. Phase D: Common Flows（项目通用流程）

询问：
- 这个项目有哪些**所有 feature 都会用到的流程**？
- 典型：登录、创建资源、查看列表、登出

让用户自由描述，AI 结构化成 YAML：
```yaml
common_flows:
  login:
    description: "用户登录"
    steps:
      - "访问 ${env.url}/login"
      - "输入 ${env.test_account} / ${env.test_password}"
      - "验证跳转到 /dashboard"
```

### 7. Phase E: 参数化识别与整理

扫描生成的 YAML，找出所有 `${VAR}` 占位符，分类：

| 类型 | 例子 | 存放位置 |
|------|------|---------|
| **个人参数** | `MY_USER`, `MY_DEV_ACCOUNT`, `DEV_PORT` | `project.local.md`（gitignore） |
| **敏感参数** | `STAGING_API_TOKEN`, `DB_PASSWORD` | shell env（不写入任何文件） |
| **团队共享参数** | `STAGING_DOMAIN`（如果全团队用同一个） | `project.md` 直接写值 |

输出整理表格给用户确认：

```
发现 5 个参数需要用户提供：
  个人参数（4 个）→ 提示下一步跑 /tdd:verify-local 填值
    - MY_USER
    - MY_DEV_ACCOUNT
    - DEV_PORT (默认 3000)
    - STAGING_URL
  敏感参数（1 个）→ 建议 shell env
    - STAGING_API_TOKEN
```

### 8. 写入文件

```bash
mkdir -p tdd-specs/.verify

# 1. 写 project.md（从 templates/verify-project.md 填充）
# 2. 写 project.env.example（说明需要哪些 shell 环境变量）
# 3. 更新 .gitignore

if [ -f .gitignore ]; then
  grep -q "tdd-specs/.verify/project.local.md" .gitignore || \
    echo "tdd-specs/.verify/project.local.md" >> .gitignore
else
  echo "tdd-specs/.verify/project.local.md" > .gitignore
fi
```

### 9. 输出 & 下一步提示

```
✓ tdd-specs/.verify/project.md 已生成（7 commands / 2 environments / 3 flows / 5 cleanup steps）
✓ scripts/deploy-staging.sh 骨架已生成（请完善 TODO 部分）
✓ tdd-specs/.verify/project.env.example 已生成（说明需要哪些 shell env）
✓ .gitignore 已更新

下一步：
  1. 跑 /tdd:verify-local 填你的个人参数
  2. 按 project.env.example 导出敏感参数到 shell
  3. 完善 scripts/deploy-staging.sh 的 TODO 部分
  4. 后续跑 /tdd:done 会按这份配置执行 4 阶段验证
```

---

## Guardrails

- **不要凭空生成配置** — 每个字段都要问过用户或从项目检测到的证据推测
- **cleanup 推荐要保守** — 宁愿少推荐也不要让用户跳过本来不必要的步骤
- **部署脚本是骨架** — 永远保留 `TODO` 注释，不假装能直接运行
- **敏感参数不进文件** — API token / password 必须从 shell env 读，违反时要警告
- **识别参数来源** — 每个 `${VAR}` 都要明确是个人参数/敏感参数/团队共享，避免用户混淆
- **已有文件不破坏** — 如果 project.md 已存在，必须先 AskUserQuestion 确认覆盖方式
