# Implementation Plan — {{FEATURE_NAME}}

> Created: {{DATE}}
> Status: in-progress

## 任务拆分原则

> **按 UseCase 垂直切片，每个 UC 包含所有涉及的技术层。**
> 禁止将前端/后端/客户端拆成独立 Phase。
> 每个 UC 完成后应可独立演示和端到端验证。

## Phase 1: 基础设施搭建

<!-- 共享的基础设施：数据库迁移、模块骨架、依赖安装等 -->

- [ ] 1.1 数据库迁移：创建新表 + **执行到本地开发数据库**
- [ ] 1.2 创建模块骨架（空文件、Entity、Module 注册）
- [ ] 1.3 执行 schema:dump（如项目有此脚本）

## Phase 2: TDD Main Loop (按 UC 垂直切片)

<!-- 每个 UC 包含：后端测试+实现 → 前端页面 → 集成验证 -->

### UC-01 {{UC 标题}}

#### 后端
- [ ] 2.1.1 RED: unit test — {{service 行为描述}} (Covers UC-01 step N)
- [ ] 2.1.2 GREEN: implement {{service}} (Covers UC-01 step N)
- [ ] 2.1.3 RED: unit test — {{controller/route}} (Covers UC-01 step N)

#### 前端（如 UC 主角色是终端用户）
- [ ] 2.1.4 前端页面: {{page-name}} (js/wxml/wxss) (Covers UC-01)

#### 备选路径
- [ ] 2.1.5 RED: unit test — {{错误场景}} (Covers UC-01 备选 Na)

### UC-02 {{UC 标题}}

#### 后端
- [ ] 2.2.1 RED + GREEN ...

#### 前端
- [ ] 2.2.2 前端页面 ...

### 集成测试（跨 UC）
- [ ] 2.N Integration test: 验证真实 API 链路 + DB 状态
  - Test file: `{{test dir}}/integration/{{feature}}.test.{{ext}}`
  - Command: `{{TEST_COMMAND}}`

## Phase 3: E2E Acceptance

<!-- 从 usecases.md 派生，每个 UC 路径 → 一个 E2E -->

- [ ] 3.1 E2E: UC-01 成功路径
- [ ] 3.2 E2E: UC-01 备选 Na
- [ ] 3.3 E2E: UC-02 成功路径

## Phase 4: Delivery

- [ ] 4.1 Full unit tests: `{{TEST_COMMAND}} --coverage`
- [ ] 4.2 Full regression (if project has regression scripts)
- [ ] 4.3 Issue tracking (if qualifying bugs found)
- [ ] 4.4 Feature docs updated (if project has usecases/docs directory)
- [ ] 4.5 Environment variable examples synced (if new env vars added)

## Status Tracking

| Task | Status | Notes |
|------|--------|-------|
| Phase 1 | Pending | |
| Phase 2 | Pending | |
| Phase 3 | Pending | |
| Phase 4 | Pending | |

## Failure Log

| Test | Failure Count | Last Error | Resolution |
|------|--------------|------------|------------|
