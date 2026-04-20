---
# Feature 级验证配置
# 只写项目级 (tdd-specs/.verify/project.md) 没覆盖的部分
# 由 /tdd:new 生成草稿，用户确认后保存到 tdd-specs/<feature-name>/verify.md

# ============ Feature 特有的参数 ============
feature_params:
  # 例: TEST_POST_ID: "${MY_TEST_POST_ID:-100}"

# ============ Feature 特有的验证流程 ============
# 这些是项目级 common_flows 无法覆盖的、这个 feature 独有的验证
feature_specific_flows:
  # - name: "<流程名>"
  #   reason: "<为什么项目级没覆盖>"
  #   steps:
  #     - "<步骤 1>"
  #     - "<步骤 2>"
  #     - "断言：<预期结果>"

# ============ 依赖的项目级验证 ============
# 声明这个 feature 运行前必须先通过的项目级检查项
depends_on_project_verify:
  # 例:
  # - "common_flows.login"
  # - "api_health: POST /api/auth/login"

# ============ 跳过的项目级检查 ============
# 如果某个 feature 需要跳过某个项目级检查，在这里声明原因
# 尽量避免使用——如果频繁 skip 说明项目级配置需要调整
skip_project_checks: []
  # 例:
  # - check: "common_flows.payment"
  #   reason: "这个 feature 不涉及支付模块"
---

# Feature 验证手册：{{FEATURE_NAME}}

这个 feature 独有的验证需求。在 `/tdd:done` Stage 2/3 会与项目级 `common_flows` 一起执行。

## 填写原则

- **只写项目级没覆盖的部分** —— 不要重复写"登录流程"等通用验证
- **描述行为，不描述实现** —— 例："评论在 2 秒内出现"而不是"检查 Redis pub/sub"
- **包含可验证的断言** —— 每个 flow 最后要有"断言：xxx"明确预期
- **参数引用项目级** —— 用 `${env.url}` 和 `${env.test_account}` 复用项目级参数
