# Implementation Plan — {{FEATURE_NAME}}

> Created: {{DATE}}
> Status: in-progress

## 任务拆分原则

> **按用户行为链路拆，不按测试层拆。**
> 每个任务 = 一个用户可感知的行为变化，GREEN 必须包含接入真实调用方。
> 如果接入代码无法单测，标注为独立的"接入"任务，不可省略。

## Phase 2: TDD Main Loop (按行为链路)

<!-- 模板示例：每个行为链路包含 RED + GREEN + 接入 -->

- [ ] 2.1 行为: {{用户做了什么 → 系统应该怎样响应}}
  - [ ] 2.1.1 RED: 测试 {{纯逻辑函数}}
    - Test file: `{{test dir}}/{{file}}.{{ext}}`
    - Covers: REQ-XX
  - [ ] 2.1.2 GREEN: 实现纯函数 + **接入 {{调用方文件}}**
    - Impl: `{{source dir}}/{{file}}.{{ext}}`
    - 接入: `{{framework file}}` 中调用上述函数
  - [ ] 2.1.3 REFACTOR (if needed)

- [ ] 2.2 行为: {{下一个用户行为}}
  - [ ] 2.2.1 RED
  - [ ] 2.2.2 GREEN + 接入
  - [ ] 2.2.3 REFACTOR

- [ ] 2.N Integration test: 验证真实 API 链路
  - Test file: `{{test dir}}/integration/{{feature}}.test.{{ext}}`
  - Command: `{{TEST_COMMAND}}`

## Phase 3: E2E Acceptance

- [ ] 3.1 E2E (前端 UI 实现后才写，不提前占位)
  - 前置条件: {{哪些前端页面/组件必须存在}}
  - Test file: `{{E2E test dir}}/{{feature}}.spec.{{ext}}`
  - Command: `{{E2E_COMMAND}}`

## Phase 4: Delivery

- [ ] 4.1 Full unit tests: `{{TEST_COMMAND}} --coverage`
- [ ] 4.2 Full regression (if project has regression scripts)
- [ ] 4.3 Issue tracking (if qualifying bugs found)
- [ ] 4.4 Feature docs updated (if project has usecases/docs directory)
- [ ] 4.5 Environment variable examples synced (if new env vars added)

## Status Tracking

| Task | Status | Notes |
|------|--------|-------|
| Phase 2 | In Progress | |
| Phase 3 | Pending | |
| Phase 4 | Pending | |

## Failure Log

| Test | Failure Count | Last Error | Resolution |
|------|--------------|------------|------------|
