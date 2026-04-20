# Cleanup Presets Library

验证前后的 cleanup 预设库。`/tdd:verify-setup` 会根据检测到的项目技术栈推荐合适的预设；`/tdd:done` 执行时把预设展开为实际 shell 命令。

## 使用方式

在 `tdd-specs/.verify/project.md` 的 `environments.{env}.pre_verify_cleanup` 或 `post_verify_cleanup` 中引用：

```yaml
pre_verify_cleanup:
  - preset: "kill_port"
    port: "${DEV_PORT:-3000}"
  - preset: "docker_compose_down"
    file: "docker-compose.dev.yml"
    volumes: true
```

或写自定义命令：

```yaml
pre_verify_cleanup:
  - name: "清理自定义临时目录"
    command: "rm -rf /var/lib/myapp/tmp/*"
    on_fail: "continue"
```

## 通用字段

每个 cleanup 步骤支持以下字段：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | 自定义命令必填 | 人类可读描述 |
| `preset` | string | 二选一 | 预设名 |
| `command` | string | 二选一 | 自定义 shell 命令 |
| `on_fail` | enum | 否 | `continue`（默认）/ `abort` / `ask` |
| `timeout` | number | 否 | 秒，默认 30 |
| `condition` | string | 否 | 满足此 shell 条件才执行 |
| `parallel` | bool | 否 | 是否可与上一步并行 |

## 预设列表

### `kill_port`

杀掉占用指定端口的进程。

**参数**：
- `port`（必填）— 端口号

**等价命令**：
```bash
lsof -ti:${port} | xargs kill -9 2>/dev/null || true
```

**示例**：
```yaml
- preset: "kill_port"
  port: "${DEV_PORT:-3000}"
```

---

### `kill_node_process`

按命令模式杀掉进程（不限于 Node.js，名字是历史遗留）。

**参数**：
- `pattern`（必填）— 命令匹配模式

**等价命令**：
```bash
pkill -f "${pattern}" 2>/dev/null || true
```

**示例**：
```yaml
- preset: "kill_node_process"
  pattern: "npm run dev"
```

---

### `docker_compose_down`

停止 Docker Compose 项目。

**参数**：
- `file`（必填）— docker-compose 文件路径
- `volumes`（可选，默认 false）— 是否删除 volumes

**等价命令**：
```bash
docker compose -f ${file} down ${volumes ? '-v' : ''}
```

**示例**：
```yaml
- preset: "docker_compose_down"
  file: "docker-compose.dev.yml"
  volumes: true
```

---

### `docker_container_rm`

删除匹配名称模式的 Docker 容器。

**参数**：
- `pattern`（必填）— 容器名称模式

**等价命令**：
```bash
docker rm -f $(docker ps -aq -f name=${pattern}) 2>/dev/null || true
```

**示例**：
```yaml
- preset: "docker_container_rm"
  pattern: "myapp-test-"
```

---

### `reset_db`

重置数据库（直接执行用户提供的命令，只是给这类操作一个语义化名字）。

**参数**：
- `command`（必填）— 实际的重置命令

**等价命令**：直接执行 `command`

**示例**：
```yaml
- preset: "reset_db"
  command: "npm run db:reset"
  on_fail: "abort"  # 数据库状态是验证的基础，失败必须中止
```

---

### `clean_tmp_files`

清理临时文件。

**参数**：
- `pattern`（必填）— 文件路径模式（glob）

**等价命令**：
```bash
rm -rf ${pattern} 2>/dev/null || true
```

**示例**：
```yaml
- preset: "clean_tmp_files"
  pattern: "/tmp/myapp-*"
```

---

### `clear_redis`

清空 Redis 指定数据库。

**参数**：
- `db`（可选，默认 0）— Redis db 编号
- `url`（可选）— Redis 连接 URL

**等价命令**：
```bash
redis-cli ${url ? `-u ${url}` : ''} -n ${db} FLUSHDB
```

**示例**：
```yaml
- preset: "clear_redis"
  db: 1
```

---

### `git_clean`

清理 git 未跟踪的文件。

**参数**：
- `path`（可选，默认 `.`）— 清理范围

**等价命令**：
```bash
git clean -fd ${path}
```

**示例**：
```yaml
- preset: "git_clean"
  path: "dist/"
```

## 幂等性要求

所有 cleanup 命令必须是**幂等**的——运行多次结果一样，不存在的东西也不报错。

**错误示例**（进程不存在会报错）：
```bash
kill -9 $(cat pid.txt)
```

**正确示例**：
```bash
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
pkill -f 'npm run dev' 2>/dev/null || true
```

`/tdd:verify-setup` 会自动检查自定义命令的幂等性，不幂等会给出警告。

## 失败处理策略

`on_fail` 三种策略：

- **`continue`**（默认）— 失败也继续执行后续步骤。用于"尽力清理"的场景，比如 kill 一个可能不存在的进程。
- **`abort`** — 必须成功，否则中止整个验证流程。用于关键依赖，比如数据库 reset 失败就意味着后续测试结果不可信。
- **`ask`** — 失败时交互式问用户怎么办。适合不确定的情况。

## 并行执行

独立的 cleanup 步骤可以并行（加速）：

```yaml
pre_verify_cleanup:
  - preset: "kill_port"      # 第 1 步
    port: 3000
  - preset: "clean_tmp_files" # 第 2 步，与第 1 步无依赖
    pattern: "/tmp/myapp-*"
    parallel: true            # 标记可与上一步并行
  - preset: "reset_db"        # 第 3 步，依赖前面都完成
    command: "npm run db:reset"
```

默认串行执行，有依赖的必须串行。Docker 相关操作建议串行避免冲突。

## 超时保护

每个 cleanup 默认 30 秒超时，防止卡死。

```yaml
- preset: "docker_compose_down"
  file: "docker-compose.dev.yml"
  timeout: 60   # Docker 操作给 60 秒
```
