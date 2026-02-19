## Manager Heartbeat Checklist

### 1. 任务状态扫描与 Worker 问询

扫描 ~/hiclaw-fs/shared/tasks/ 下所有任务目录的 meta.json：

```bash
for meta in ~/hiclaw-fs/shared/tasks/*/meta.json; do
  cat "$meta"
done
```

- 筛选 `"status": "assigned"` 的任务（进行中、尚未完成）
- 从 meta.json 的 `assigned_to` 和 `room_id` 字段获取负责的 Worker 及对应 Room
- 对这些 Worker：
  - 在该 Worker 的 Room（或 project_room_id 若有）中 @mention Worker 询问进展："@{worker} 你当前的任务进展如何？有没有遇到阻塞？"
  - （人类管理员在 Room 中全程可见，可随时补充指令或纠正）
  - 根据 Worker 回复判断是否正常推进
- 如果 Worker 未回复（超过一个 heartbeat 周期无响应），在 Room 中标记异常并提醒人类管理员
- 如果 Worker 已回复完成但 meta.json 未更新，主动更新 meta.json：status → completed，填写 completed_at

### 2. 项目进展监控

扫描 ~/hiclaw-fs/shared/projects/ 下所有活跃项目的 meta.json 和 plan.md：

```bash
for meta in ~/hiclaw-fs/shared/projects/*/meta.json; do
  cat "$meta"
done
```

- 筛选 `"status": "active"` 的项目
- 对每个活跃项目，读取 plan.md，找出标记为 `[~]`（进行中）的任务
- 对每个 `[~]` 任务：
  - 在项目群（project_room_id）中检查该 Worker 最近是否有 @mention 汇报
  - 如果该 Worker 在本 heartbeat 周期内没有活动：在项目群中 @mention 该 Worker 询问进展
    ```
    @{worker}:{domain} 你正在执行的任务 {task-id}「{title}」有进展吗？有遇到阻塞请告知。
    ```
- 如果项目群中有某个 Worker 汇报了任务完成但 plan.md 还没更新，立即处理（见 AGENTS.md 项目管理部分）

### 3. 凭证检查
- 检查各 Worker 凭证是否即将过期
- 如需轮转，执行双凭证滑动窗口轮转流程

### 4. 容量评估
- 统计 `"status": "assigned"` 的任务数量（进行中）和没有分配任务的空闲 Worker
- 如果 Worker 不足，准备创建命令给人类管理员
- 如果有 Worker 空闲，建议重新分配任务

### 5. 回复
- 如果所有 Worker 正常且无待处理事项：HEARTBEAT_OK
- 否则：汇总发现和建议的操作，通知人类管理员
