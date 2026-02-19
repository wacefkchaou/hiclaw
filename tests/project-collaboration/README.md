# Project Collaboration Test

End-to-end test for the Manager's project management skill. Simulates a multi-worker git collaboration project with developer, reviewer, and tester roles.

## What This Tests

1. **Project room creation**: Manager creates a `Project: ...` Matrix room with Human + Manager + all workers
2. **Plan confirmation**: Manager proposes a plan.md to human; project starts only after human confirmation
3. **Task dispatch via @mention**: Manager @mentions workers to assign tasks; workers @mention manager to report completion
4. **Multi-round review**: Developer writes code → Reviewer reviews (commits review.md) → Developer fixes → Reviewer approves
5. **Project iteration**: Worker completion @mention immediately triggers next task assignment (not heartbeat-driven)
6. **plan.md tracking**: All tasks tracked with `[ ]`/`[~]`/`[x]` status throughout
7. **Git evidence**: Each role (developer, reviewer, tester) has their own git commits

## Verification Checks

| Check | Description | Pass Criteria |
|-------|-------------|---------------|
| 1 | Project room created | Room named `Project: ...` exists with all 4 members |
| 2 | All roles have messages | developer ≥2, reviewer ≥2, tester ≥1, manager ≥4 messages |
| 3 | @mention protocol | ≥5 @mentions in project room chat |
| 4 | Developer git commits | ≥2 commits (initial code + fix after review) |
| 5 | Reviewer git commits | ≥1 commit (review.md) + ≥2 review-related commits for multi-round |
| 6 | Tester git commits | ≥1 commit (test results) |
| 7 | Multi-round review | Reviewer has ≥2 tasks in project; review.md has ≥2 commits |
| 8 | plan.md completed | All tasks show `[x]` |
| 9 | Project meta confirmed | `confirmed_at` is set, `status` is `completed` |

## Running the Test

### Prerequisites

- HiClaw Manager running and healthy
- LLM API key configured
- GitHub repo and token for git operations (optional but recommended)

```bash
export HICLAW_ADMIN_USER=admin
export HICLAW_ADMIN_PASSWORD=<password>
export HICLAW_MATRIX_DOMAIN=matrix-local.hiclaw.io:8080
export HICLAW_LLM_API_KEY=<your-llm-key>

# Optional: for full git verification
export TEST_GITHUB_REPO=your-org/test-repo
export TEST_GITHUB_TOKEN=ghp_xxxxx

./tests/project-collaboration/run-test.sh
```

### Skip Worker Creation (if workers already exist)

```bash
./tests/project-collaboration/run-test.sh --skip-worker-creation
```

### Custom Timeout

Default is 3600 seconds (1 hour). For faster models:

```bash
./tests/project-collaboration/run-test.sh --timeout 1800
```

### Verify Only (from saved state)

```bash
./tests/project-collaboration/verify.sh \
  --state-file logs/project-collaboration/state-YYYYMMDD-HHMMSS.env \
  --chat-log logs/project-collaboration/chat-YYYYMMDD-HHMMSS.log \
  --project-id proj-YYYYMMDD-HHMMSS \
  --project-room "!abc:matrix-local.hiclaw.io:8080"
```

## Log Files

All logs are saved to `logs/project-collaboration/`:

- `run-YYYYMMDD-HHMMSS.log` — Full test run output
- `chat-YYYYMMDD-HHMMSS.log` — All room messages (DM + project room + worker rooms)
- `state-YYYYMMDD-HHMMSS.env` — State variables for re-running verify.sh

## Expected Flow

```
[Human] → Manager DM: "启动一个项目..."
[Manager] → Human DM: proposes plan.md
[Human] → Manager DM: "确认，开始执行"
[Manager] creates Project Room, invites developer + reviewer + tester
[Manager] → Project Room: @developer 你有新任务 task-001: 开发 Flask Hello World
[developer] → executes task, git commit, → Project Room: @manager task-001 completed
[Manager] updates plan.md [~]→[x], → Project Room: @reviewer 你有新任务 task-002: review 代码
[reviewer] → reviews code, commits review.md with issues, → Project Room: @manager task-002 completed (issues found)
[Manager] updates plan.md, → Project Room: @developer 你有新任务 task-003: 修复 review 意见
[developer] → fixes code, git commit, → Project Room: @manager task-003 completed
[Manager] → Project Room: @reviewer 你有新任务 task-004: 再次 review
[reviewer] → approves, updates review.md (2nd commit), → Project Room: @manager task-004 completed
[Manager] → Project Room: @tester 你有新任务 task-005: 编写并运行测试
[tester] → writes test_app.py, runs tests, git commit, → Project Room: @manager task-005 completed
[Manager] marks project completed, → Project Room: @admin 项目完成
```
