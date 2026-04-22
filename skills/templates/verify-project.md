---
# 项目验证配置模板
# 由 /tdd:verify-setup 生成，根据实际项目修改
# 参数用 ${VAR} 或 ${VAR:-default} 形式，值来自 project.local.md 或 shell 环境变量

# ============ 命令类验证（自动执行） ============
commands:
  unit: "{{UNIT_TEST_COMMAND}}"              # 例: "npm run test:unit"
  integration: "{{INTEGRATION_TEST_COMMAND}}" # 例: "npm run test:integration" 或 null
  e2e: "{{E2E_TEST_COMMAND}}"                # 例: "npm run test:e2e" 或 null
  typecheck: "{{TYPECHECK_COMMAND}}"          # 例: "npm run typecheck" 或 null
  lint: "{{LINT_COMMAND}}"                   # 例: "npm run lint" 或 null
  build: "{{BUILD_COMMAND}}"                 # 例: "npm run build" 或 null
  coverage_target: 80                         # 覆盖率目标百分比

# ============ 环境类验证（半自动） ============
environments:
  dev:
    url: "http://localhost:${DEV_PORT:-3000}"
    start: "{{DEV_START_COMMAND}}"            # 例: "npm run dev"
    readiness: "curl -sf http://localhost:${DEV_PORT:-3000}/health"
    test_account: "${MY_DEV_ACCOUNT:-test@test.com}"
    test_password: "${MY_DEV_PASSWORD}"
    # 验证前清理（确保干净环境）
    pre_verify_cleanup:
      - preset: "kill_port"
        port: "${DEV_PORT:-3000}"
      - preset: "kill_node_process"
        pattern: "{{DEV_PROCESS_PATTERN}}"    # 例: "npm run dev"
      # 如果用 Docker，取消注释：
      # - preset: "docker_compose_down"
      #   file: "docker-compose.dev.yml"
      #   volumes: true
      # 如果需要重置数据库：
      # - name: "重置测试数据库"
      #   command: "{{DB_RESET_COMMAND}}"
      #   on_fail: "abort"
    # 验证后清理（可选，也可以留着服务继续用）
    post_verify_cleanup:
      - preset: "kill_port"
        port: "${DEV_PORT:-3000}"

  staging:
    url: "${STAGING_URL}"
    deploy: "{{STAGING_DEPLOY_COMMAND}}"       # 例: "bash scripts/deploy-staging.sh"
    readiness: "curl -sf ${STAGING_URL}/health"
    test_account: "${MY_STAGING_ACCOUNT}"
    api_token: "${STAGING_API_TOKEN}"           # 敏感参数，从 shell env 读
    # 部署后的冒烟测试步骤（人工或脚本执行都可以）
    post_deploy_smoke:
      - "登录 ${STAGING_URL} 用 ${MY_STAGING_ACCOUNT}"
      - "创建一条测试数据"
      - "验证数据出现在列表"

# ============ 通用业务流程（所有 feature 都可能用到） ============
common_flows:
  login:
    description: "用户登录流程"
    steps:
      - "访问 ${env.url}/login"
      - "输入 ${env.test_account} / ${env.test_password}"
      - "验证跳转到 /dashboard"
  # 添加更多通用流程...

# ============ API/业务断言（项目通用的健康检查） ============
api_health:
  - "GET ${env.url}/api/health → 返回 200"
  - "POST ${env.url}/api/auth/login → 返回的 token 解码后包含 {uid, roles, exp}"

# ============ 监控/日志（用于交付后观察） ============
monitoring:
  dashboard_url: null                          # 例: "https://grafana.example.com/xxx"
  log_query: null                              # 例: "kubectl logs -n prod -l app=myapp"

# ============ 项目文档路径 ============
# 项目级文档目录。不配置时用下方默认值（向后兼容）。
paths:
  # UseCase 文档（PM/QA 查阅的用户流程权威文档）
  usecases:
    enabled: true                              # false = 不做本地同步（外部工具管理）
    dir: "docs/usecases"                        # 本地目录（默认 docs/usecases）
    index_file: "docs/usecases/README.md"       # 可选索引文件
    numbering: "auto"                           # auto 自动项目级递增 | feature_local 保留 UC-01/02 | manual 每次问
    # 如果用外部工具管理 UC，取消注释并设置 enabled=false：
    # external_tool: "Confluence"
    # external_url: "https://company.atlassian.net/wiki/spaces/PROD/pages/xxx"

  # Issue 归档（Bug 追踪文档）
  issues:
    enabled: true
    dir: "docs/issues"                          # 默认 docs/issues
    index_file: "docs/issues/README.md"         # 可选索引
    numbering: "auto"                           # auto 扫描现有最大编号 +1 | manual
    filename_pattern: "<NNN>-<module>-<keyword>.md"  # NNN 自动编号，<module>/<keyword> 由用户填
    # 如果用外部工具（Jira/GitHub Issues），取消注释并设置 enabled=false：
    # external_tool: "Jira"
    # external_url: "https://company.atlassian.net/jira/projects/PROJ"
---

# 项目验证手册

这份文件是 `/tdd:done` 的权威验证标准，AI 会严格按此执行，不自由发挥。

## 使用方式

1. 首次生成：`/tdd:verify-setup`（交互式收集）
2. 个人参数：`/tdd:verify-local`（生成 project.local.md，已加入 .gitignore）
3. 验证执行：`/tdd:done`（按本文件 4 阶段执行）
4. 手动清理：`/tdd:cleanup dev`

## 参数解析优先级

`${VAR}` 的值按以下顺序查找：

1. 命令行 `--var VAR=xxx`
2. Shell 环境变量
3. `tdd-specs/.verify/project.local.md`
4. 本文件的默认值 `${VAR:-default}`
5. 以上都没有 → 报错

## Cleanup 预设库

见 `skills/verify-presets/cleanup.md`，常用：
- `kill_port` — 杀掉占用端口的进程
- `kill_node_process` — 按模式杀进程
- `docker_compose_down` — 停 Docker Compose
- `reset_db` — 重置数据库（用户自定义命令）
- `clean_tmp_files` — 清理临时文件
- `clear_redis` — 清 Redis
