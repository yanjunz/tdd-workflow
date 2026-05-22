---
name: "TDD: Retro"
description: Workflow self-improvement — 5-why analysis on TDD process failures, fix skills and principles
category: TDD Workflow
tags: [tdd, retro, kaizen, improvement]
---

对 TDD workflow **自身**的回顾改进。不是改产品代码（那是 `/tdd:bug`），而是改 skill 文件、guardrail、流程步骤。

**定位区分**：
- `/tdd:bug` → 产品代码有 bug → 修代码 + 写复现测试
- `/tdd:notes` → feature 完成 → 记录实践（纯记录，不改流程）
- `/tdd:retro` → **TDD workflow 自身有问题** → 修 skill .md / 原则 / 配置

**触发时机**：
- 流程中发现了 skill 本身的设计缺陷（步骤不够、guardrail 失效）
- 某个步骤产出了错误结果但无人发现，直到下游暴露
- AI 犯了系统性错误（不是偶发 typo，而是模式性的判断失误）
- 想分析"为什么这个问题没被更早拦住"

**Input**: 问题描述（可选，交互收集）

---

## Steps

### 1. 收集问题

如无参数，用 **AskUserQuestion**：
> "什么地方出了问题？描述你观察到的现象（AI 做了什么错事、哪个步骤产出了错误结果、或者哪里本该拦住但没拦住）。"

收集后用一句话复述确认。

### 2. 5-Why 分析

逐层追问根因。AI 自己分析完整 5 层后，输出给用户确认：

```
## 5-Why 分析

1. 直接原因：<什么行为产生了错误结果>
   ↓ 为什么会这样做？
2. 行为原因：<是哪个 skill step 的产出 / 哪个判断逻辑>
   ↓ 为什么 skill 没拦住？
3. 防护缺失：<缺少什么检查/验证步骤>
   ↓ 为什么设计时没加这个防护？
4. 设计假设：<什么假设是错的 / 什么场景没被考虑>
   ↓ 系统层面缺什么？
5. 系统缺陷：<反馈环路在哪里断了 / 什么机制能从根本上防止>
```

用 **AskUserQuestion**：
> "以上 5-Why 分析是否准确？"
> - [A] 准确，继续
> - [B] 某层不对（告诉我哪层、正确原因是什么）

### 3. 分类根因

| 分类 | 描述 | 典型改进方向 |
|------|------|------------|
| **验证缺失** | 生成了配置/代码但没验证就交付 | 加 smoke-test / dry-run 步骤 |
| **假设未校验** | 用文档推测代替实际执行 | 加"必须执行确认"guardrail |
| **反馈延迟** | 错误在下游才暴露，上游无感知 | 加即时验证或前后一致性检查 |
| **覆盖盲区** | 某类场景完全没有对应步骤 | 新增 skill step 或新命令 |
| **Guardrail 失效** | 规则存在但没被遵守 | 改为强制执行（mandatory check） |
| **知识盲区** | 不了解某技术细节导致错误假设 | 加检测逻辑 + 不确定时必须问用户 |
| **降级未授权** | AI 自行决定了降级/跳过，没问用户 | 加"必须 AskUserQuestion"约束 |

输出分类结果。

### 4. 提出改进方案

每个改进必须明确：

```markdown
### 改进 N: <标题>

**改哪个文件**: <skill .md 路径 或 project.md>
**改什么内容**: <新增步骤 / 追加 guardrail / 修改判断逻辑>
**为什么能防止复发**: <描述新流程遇到原问题时会怎样拦住>
```

用 **AskUserQuestion**：
> "以下 N 项改进，哪些执行？"
> - [A] 全部执行（推荐）
> - [B] 只执行部分（告诉我编号）
> - [C] 只记录到 retro log，不改 skill（先观察一段时间）

### 5. 执行改进

根据用户选择修改文件：
- 修改 skill .md 文件（新增步骤 / guardrail）
- 修改 `tdd-specs/.verify/project.md`（如果是项目配置问题）
- 如果是新原则，写入项目的 `docs/guides/code-rules.md` 或类似文档

**执行后立即验证**：如果改进涉及新增检查步骤，对当前问题场景 dry-run 一次，确认新逻辑能拦住。

### 6. 记录回顾

```bash
mkdir -p tdd-specs/.retro
```

写入 `tdd-specs/.retro/<YYYY-MM-DD>-<keyword>.md`：

```markdown
# TDD Retro — <one-line title>

> Date: YYYY-MM-DD
> Triggered by: <什么事件触发了本次回顾>
> Category: <根因分类>

## 问题描述
<用户观察到的现象>

## 5-Why
1. <why-1>
2. <why-2>
3. <why-3>
4. <why-4>
5. <why-5>

## Root Cause Category
<验证缺失 / 假设未校验 / 反馈延迟 / 覆盖盲区 / Guardrail 失效 / 知识盲区 / 降级未授权>

## Improvement Actions
- [x] <action-1>: <file modified> — <what changed>
- [x] <action-2>: <file modified> — <what changed>
- [ ] <action-3>: <deferred, reason>

## Verification
<如何确认改进有效——描述下次遇到类似情况时，新流程的预期行为>

## Related
- Issue: <如有关联的 docs/issues/ 编号>
- Feature: <如有关联的 tdd-specs/ feature>
```

### 7. 输出

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /tdd:retro 完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

根因: <category> — <one-line>
改进: <N> 项已执行, <M> 项 deferred
记录: tdd-specs/.retro/<filename>.md
修改的 skill 文件: <list>

下次遇到类似问题时的预期行为:
  <描述新流程如何不同>
```

---

## Guardrails

- **5-why 必须做完 5 层** — 不能在 1-2 层就下结论。如果某层确实是终极原因，需明确说"到此为止，因为 X 是不可拆分的原子原因"
- **改进必须是文件级别的改动** — 不能写"以后注意""下次小心"这种虚话。必须指向具体的 .md 文件 + 具体修改内容
- **至少执行一项改进** — 如果用户选 [C] 只记录，追加 `## Deferred Review` 节，标注"下次 /tdd:retro 时复查此项是否仍需执行"
- **不改业务代码** — 这个命令只改 skill 文件、project.md 配置、原则文档。产品 bug 用 `/tdd:bug`
- **skill 改动必须保持通用** — 与 `/tdd:e2e` 改动同理，不能绑定项目特定信息（框架名、端口号、路径等）
- **改进后必须验证** — 如果改进是"新增检查步骤"，立即对原问题场景做一次 dry-run 确认新逻辑生效
- **retro 记录不归档** — `tdd-specs/.retro/` 不随 feature archive 一起移动，是项目级长期累积的改进日志
