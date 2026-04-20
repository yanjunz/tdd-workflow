---
name: "TDD: Verify Local"
description: 交互式生成个人验证参数 tdd-specs/.verify/project.local.md（gitignore，每人不同）
category: TDD Workflow
tags: [tdd, verify, local, personal-params]
---

交互式填写**个人验证参数**。每个团队成员的参数可能不同（测试账号、端口、staging 域名等），这份文件不提交 git。

**前提**：已经跑过 `/tdd:verify-setup` 生成了 `tdd-specs/.verify/project.md`。

**产物**：
- `tdd-specs/.verify/project.local.md`（已 gitignore）

---

## Steps

### 1. 检查前置

```bash
if [ ! -f tdd-specs/.verify/project.md ]; then
  echo "ERROR: tdd-specs/.verify/project.md 不存在"
  echo "请先跑 /tdd:verify-setup"
  exit 1
fi

# 确认 .gitignore 已排除 project.local.md
grep -q "tdd-specs/.verify/project.local.md" .gitignore 2>/dev/null || {
  echo "WARNING: project.local.md 未在 .gitignore 中"
  echo "tdd-specs/.verify/project.local.md" >> .gitignore
  echo "✓ 已自动添加"
}
```

### 2. 扫描所有 ${VAR} 占位符

读取 `tdd-specs/.verify/project.md`，提取所有 `${VAR}` 和 `${VAR:-default}`。

分类标记：
- **个人参数** — 名字匹配 `MY_*` 或无默认值且不是敏感词的
- **敏感参数** — 名字包含 `TOKEN` / `PASSWORD` / `SECRET` / `KEY` / `COOKIE` / `API_KEY`
- **有默认值** — `${VAR:-default}` 格式，用户可选择覆盖或用默认

### 3. 检查已有 local.md

```bash
if [ -f tdd-specs/.verify/project.local.md ]; then
  echo "已有 project.local.md，现有值："
  cat tdd-specs/.verify/project.local.md
fi
```

如果已存在，用 **AskUserQuestion**：
- `[A] 只填未设置的参数，保留已有值`（推荐）
- `[B] 重新填所有参数（覆盖已有）`
- `[C] 退出`

### 4. 逐个询问参数

**个人参数**（无默认值必填，有默认值可选）：

```
🤖 参数 MY_USER（必填，用于你的 staging 子域名等）
   你的用户标识？建议用 git 用户名：
   > $(git config user.name 2>/dev/null || echo '自由输入')
👤 alice

🤖 参数 DEV_PORT（默认 3000，要覆盖吗？）
👤 4000

🤖 参数 MY_DEV_ACCOUNT（必填，用于本地开发登录）
👤 alice@test.com
```

**敏感参数**（三选一）：

```
🤖 参数 STAGING_API_TOKEN 是敏感参数，建议：
   [A] 从 shell 环境变量读（推荐）— 在 .zshrc/.bashrc 里 export STAGING_API_TOKEN=xxx
   [B] 从 1Password CLI 读 — op read "op://Personal/Staging/api_token"
   [C] 直接写到 project.local.md（不推荐，即使 gitignored 也有泄露风险）
👤 A

🤖 记录到 project.env.example 作为提示
```

### 5. 敏感参数合规检查

如果用户选了 [C] 直接写入，额外确认：

```
🤖 ⚠️  警告：即使 local.md 被 gitignore，你的参数仍然在明文文件中。
   可能的泄露途径：备份工具、云同步、编辑器 snapshot、SSH 传输。
   
   确认直接写入？
   [A] 我理解风险，继续写入
   [B] 改回方案 A（shell env）
👤 B
```

### 6. 参数值验证

对某些参数做合理性检查：

```bash
# URL 参数
if [[ "$var_name" == *URL* ]]; then
  if ! echo "$value" | grep -qE '^https?://'; then
    echo "WARNING: $var_name 不像 URL，确认吗？[Y/n]"
  fi
fi

# 端口参数
if [[ "$var_name" == *PORT* ]]; then
  if ! echo "$value" | grep -qE '^[0-9]+$'; then
    echo "ERROR: 端口必须是数字"
  fi
  if [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
    echo "ERROR: 端口范围 1-65535"
  fi
fi

# 邮箱参数
if [[ "$var_name" == *ACCOUNT* ]] || [[ "$var_name" == *EMAIL* ]]; then
  if ! echo "$value" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
    echo "WARNING: 不像邮箱格式，确认吗？[Y/n]"
  fi
fi
```

### 7. 写入 project.local.md

```markdown
---
# 个人参数 — 由 /tdd:verify-local 生成
# 此文件 gitignore，不要提交
# 更新日期: YYYY-MM-DD

# 个人参数
MY_USER: "alice"
DEV_PORT: 4000
MY_DEV_ACCOUNT: "alice@test.com"
MY_DEV_PASSWORD: "alice-dev-pwd"
MY_STAGING_ACCOUNT: "alice@staging.example.com"
STAGING_URL: "https://staging-alice.example.com"

# 敏感参数（不在这里写值，从 shell env 读）
# STAGING_API_TOKEN: 从 export STAGING_API_TOKEN=xxx 读
# DB_PASSWORD: 从 op read "op://..." 读
---
```

### 8. 检查 shell env

```bash
# 对选了 shell env 的敏感参数，检查当前 shell 是否已设置
for var in $SENSITIVE_VARS; do
  if [ -z "${!var}" ]; then
    echo "⚠  $var 尚未在当前 shell 设置"
    echo "   执行: export $var=xxx"
  else
    echo "✓ $var 已设置（值已隐藏）"
  fi
done
```

### 9. 输出 & 下一步

```
✓ tdd-specs/.verify/project.local.md 已生成（6 个个人参数）
✓ .gitignore 确认已排除该文件

敏感参数（2 个）需要在 shell env 设置：
  ⚠  STAGING_API_TOKEN — 未设置
  ✓  DB_PASSWORD — 已设置

设置方法：
  echo 'export STAGING_API_TOKEN=xxx' >> ~/.zshrc
  source ~/.zshrc

完成后可以：
  /tdd:done        # 执行完整 4 阶段验证
  /tdd:cleanup dev # 手动触发 dev 环境 cleanup
```

---

## Guardrails

- **文件必须 gitignore** — 写入前强制检查 .gitignore，不在就自动加
- **敏感参数默认不写入文件** — 优先 shell env / 1Password，强烈劝退直接写入
- **值做基本验证** — URL、端口、邮箱等格式错误要提示
- **不暴露值** — 敏感参数在输出中用 `***` 或 "已设置/未设置" 表示，不打印实际值
- **已有值保护** — 默认只填未设置的参数，不覆盖已有值
