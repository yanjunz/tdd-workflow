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

  # 实现代码目录（两处用途）：
  #   1. Tester Agent 的 FORBIDDEN 列表——写 E2E 测试时禁止读取这些目录
  #   2. /tdd:done 交付后改动核查——git log 只扫描这些目录下的改动
  # 对于 monorepo，列出所有包含实现代码的子目录。
  # 不配置时 /tdd:done 会 fallback 到自动检测（src/ app/ lib/）。
  src_dirs:
    - "src"                                     # 单仓库典型路径
    # monorepo 示例（取消注释并按实际修改）：
    # - "backend/src"
    # - "frontend/src"
    # - "mobile/lib"
    # - "packages/core/src"

# ============ E2E 测试约定（项目无关的通用规范） ============
# 这段是 tdd-workflow 内置的 E2E 测试规范，与 SKILL.md Rule 1 对齐。
# Tester Agent 只读 spec 不读实现，因此关键元素的 testid 必须作为 spec 契约。
# 项目特定的 scope 列表可在 testid_naming.scopes 里配置（默认空，由模块名自然推导）。
e2e_conventions:
  # 选择器优先级：从上到下依次尝试，越靠后越脆弱
  selector_priority:
    - "role + accessible name"                  # 例: getByRole('button', { name: '提交' })
    - "data-testid"                             # 关键交互元素必须标，命名遵循下方规范
    - "data-state"                              # 状态查询专用：data-state="idle|loading|done|error"
    - "text content"                            # 仅用于稳定的文案断言
    - "css selector"                            # 兜底，避免依赖结构层级

  # testid 命名规范（kebab-case，自顶向下定位）
  testid_naming:
    pattern: "<scope>-<element>[-<identifier>]"
    rules:
      - "scope 用模块名（与 UC 模块命名对齐），项目可在 scopes 字段列出已用 scope"
      - "element 用语义名（card / btn / input / tab / list / item ...），不写技术细节"
      - "identifier 用业务键（资源 name / msg id），动态拼接时统一 kebab-case"
      - "禁止把状态写进 testid（如 xxx-card-installed）——状态用 data-state 表达"
    examples:
      - "<module>-tab-<name>                       # 模块内 tab，例: settings-tab-general"
      - "<module>-search-input                     # 搜索框，例: user-search-input"
      - "<module>-card-<id>                        # 卡片，例: order-card-1001"
      - "<module>-<action>-btn-<id>                # 卡片内动作按钮，例: order-cancel-btn-1001"
      - "<module>-list / <module>-item-<id>        # 列表 + 条目"
    # 项目实际使用的 scope（可选，由 /tdd:verify-setup 询问填入）
    scopes: []                                  # 例: ["skill", "chat", "settings"]

  # data-state 约定（运行时状态查询，避免 testid 状态污染）
  data_state:
    where: "标在卡片/按钮等会随业务状态变化的容器上"
    values: "kebab-case 状态枚举（如 idle / loading / installed / error）"
    example: '<div data-testid="order-card-1001" data-state="paid">'

  # spec 编写要求
  spec_requirements:
    - "usecases.md 在描述每条 UC 时，列出涉及的关键元素 testid（成功路径 + 主要异常路径）"
    - "新增 UI 元素时，先在 spec 里登记 testid，再在实现中标注；Tester 据此写测试"
    - "遇到 spec 未定义的 testid 需求，Tester 应回报给主 agent 补 spec，而非自己猜"

  # 禁止事项（与 .claude/skills/tdd-workflow/SKILL.md Rule 1 对齐）
  forbidden_in_e2e:
    - "page.evaluate 注入 store / 状态（绕过视图层）"
    - "window.__test.* 等测试专用全局 API（等同状态注入，属集成测试层）"
    - "mock 自家后端接口（mock 第三方接口需在测试代码内联说明原因）"
    - "直接路由跳过首页入口（必须从真实入口走）"
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
