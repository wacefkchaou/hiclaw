#!/bin/bash
# verify.sh - Verification script for project collaboration test
#
# Checks that the multi-worker git collaboration project completed correctly:
#   1. Project room created and all roles have messages
#   2. All workers have messages in project room (@mention pattern)
#   3. Git commits present from each role (developer, reviewer, tester)
#   4. At least 2 reviewer commits to review.md (multi-round review)
#   5. Developer has >=2 commits (initial + fix after first review)
#   6. plan.md shows all tasks [x] completed
#
# Usage:
#   ./tests/project-collaboration/verify.sh [options]
#
# Options:
#   --state-file <path>      State file from run-test.sh
#   --chat-log <path>        Chat log file from run-test.sh
#   --project-id <id>        Project ID (e.g. proj-20240101-120000)
#   --project-room <room-id> Matrix project room ID
#   --github-repo <repo>     GitHub repo (e.g. org/repo)
#   --github-token <token>   GitHub PAT for API calls
#
# Required env (if not in state file):
#   HICLAW_ADMIN_USER        Admin username
#   HICLAW_ADMIN_PASSWORD    Admin password
#   HICLAW_MATRIX_DOMAIN     Matrix domain

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TESTS_DIR}/lib/test-helpers.sh"
source "${TESTS_DIR}/lib/matrix-client.sh"
source "${TESTS_DIR}/lib/minio-client.sh"

# ============================================================
# Arg parsing
# ============================================================

STATE_FILE=""
CHAT_LOG=""
PROJECT_ID=""
PROJECT_ROOM_ID=""
GITHUB_REPO=""
GITHUB_TOKEN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --state-file)   STATE_FILE="$2"; shift 2 ;;
        --chat-log)     CHAT_LOG="$2"; shift 2 ;;
        --project-id)   PROJECT_ID="$2"; shift 2 ;;
        --project-room) PROJECT_ROOM_ID="$2"; shift 2 ;;
        --github-repo)  GITHUB_REPO="$2"; shift 2 ;;
        --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Load state file if provided
if [ -n "${STATE_FILE}" ] && [ -f "${STATE_FILE}" ]; then
    source "${STATE_FILE}"
fi

ADMIN_USER="${HICLAW_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${HICLAW_ADMIN_PASSWORD:-}"
MATRIX_DOMAIN="${HICLAW_MATRIX_DOMAIN:-matrix-local.hiclaw.io:8080}"
MATRIX_DIRECT_URL="${TEST_MATRIX_DIRECT_URL:-http://127.0.0.1:6167}"

test_setup "verify-project-collaboration"

# ============================================================
# Helper: get room messages (all of them for analysis)
# ============================================================

get_all_room_messages() {
    local token="$1"
    local room_id="$2"
    local limit="${3:-500}"
    curl -sf "${MATRIX_DIRECT_URL}/_matrix/client/v3/rooms/${room_id}/messages?dir=b&limit=${limit}" \
        -H "Authorization: Bearer ${token}" 2>/dev/null || echo '{}'
}

count_messages_from_sender() {
    local messages_json="$1"
    local sender_prefix="$2"
    echo "${messages_json}" | jq --arg s "${sender_prefix}" \
        '[.chunk[] | select(.sender | startswith($s)) | select(.content.body != null)] | length' 2>/dev/null || echo "0"
}

# ============================================================
# Login
# ============================================================

log_section "Authentication"

if [ -z "${ADMIN_TOKEN:-}" ]; then
    ADMIN_LOGIN=$(matrix_login "${ADMIN_USER}" "${ADMIN_PASSWORD}")
    ADMIN_TOKEN=$(echo "${ADMIN_LOGIN}" | jq -r '.access_token // empty')
fi
assert_not_empty "${ADMIN_TOKEN}" "Admin token available for verification"

# ============================================================
# CHECK 1: Project room exists
# ============================================================

log_section "Check 1: Project Room Exists"

if [ -z "${PROJECT_ROOM_ID}" ]; then
    log_info "Project room ID not provided, searching..."
    ALL_ROOMS=$(matrix_joined_rooms "${ADMIN_TOKEN}" 2>/dev/null | jq -r '.joined_rooms[]' 2>/dev/null || true)
    for room_id in ${ALL_ROOMS}; do
        ROOM_NAME=$(curl -sf "${MATRIX_DIRECT_URL}/_matrix/client/v3/rooms/${room_id}/state/m.room.name" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" 2>/dev/null | jq -r '.name // empty' 2>/dev/null || true)
        if echo "${ROOM_NAME}" | grep -qi "^Project:"; then
            PROJECT_ROOM_ID="${room_id}"
            log_info "Found project room: ${ROOM_NAME}"
            break
        fi
    done
fi

assert_not_empty "${PROJECT_ROOM_ID}" "Project room exists (found by name 'Project: ...')"

# Check room members include all workers
if [ -n "${PROJECT_ROOM_ID}" ]; then
    ROOM_MEMBERS=$(curl -sf "${MATRIX_DIRECT_URL}/_matrix/client/v3/rooms/${PROJECT_ROOM_ID}/members" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" 2>/dev/null | jq -r '.chunk[].state_key' 2>/dev/null || true)

    for worker in developer reviewer tester; do
        if echo "${ROOM_MEMBERS}" | grep -q "@${worker}:"; then
            log_pass "Worker @${worker} is member of project room"
        else
            log_fail "Worker @${worker} NOT found in project room members"
        fi
    done

    if echo "${ROOM_MEMBERS}" | grep -q "@manager:"; then
        log_pass "@manager is member of project room"
    else
        log_fail "@manager NOT found in project room members"
    fi
fi

# ============================================================
# CHECK 2: All roles have messages in project room
# ============================================================

log_section "Check 2: All Roles Have Messages in Project Room"

if [ -n "${PROJECT_ROOM_ID}" ]; then
    PROJ_MESSAGES=$(get_all_room_messages "${ADMIN_TOKEN}" "${PROJECT_ROOM_ID}" 500)

    MANAGER_MSG_COUNT=$(count_messages_from_sender "${PROJ_MESSAGES}" "@manager")
    DEV_MSG_COUNT=$(count_messages_from_sender "${PROJ_MESSAGES}" "@developer")
    REVIEWER_MSG_COUNT=$(count_messages_from_sender "${PROJ_MESSAGES}" "@reviewer")
    TESTER_MSG_COUNT=$(count_messages_from_sender "${PROJ_MESSAGES}" "@tester")

    log_info "Message counts — manager: ${MANAGER_MSG_COUNT}, developer: ${DEV_MSG_COUNT}, reviewer: ${REVIEWER_MSG_COUNT}, tester: ${TESTER_MSG_COUNT}"

    if [ "${MANAGER_MSG_COUNT}" -ge 4 ]; then
        log_pass "@manager has ≥4 messages in project room (assignments + confirmations)"
    else
        log_fail "@manager has only ${MANAGER_MSG_COUNT} messages in project room (expected ≥4)"
    fi

    if [ "${DEV_MSG_COUNT}" -ge 2 ]; then
        log_pass "@developer has ≥2 messages in project room (initial work + fix round)"
    else
        log_fail "@developer has only ${DEV_MSG_COUNT} messages in project room (expected ≥2)"
    fi

    if [ "${REVIEWER_MSG_COUNT}" -ge 2 ]; then
        log_pass "@reviewer has ≥2 messages in project room (round 1 + round 2 review)"
    else
        log_fail "@reviewer has only ${REVIEWER_MSG_COUNT} messages in project room (expected ≥2)"
    fi

    if [ "${TESTER_MSG_COUNT}" -ge 1 ]; then
        log_pass "@tester has ≥1 message in project room"
    else
        log_fail "@tester has 0 messages in project room (expected ≥1)"
    fi

    # Check that @mentions appear in messages (confirming mention-only protocol was followed)
    MENTION_COUNT=$(echo "${PROJ_MESSAGES}" | jq -r '[.chunk[].content.body // ""] | join("\n")' 2>/dev/null | \
        grep -c '@manager\|@developer\|@reviewer\|@tester' 2>/dev/null || echo "0")
    if [ "${MENTION_COUNT}" -ge 5 ]; then
        log_pass "@mention protocol used (${MENTION_COUNT} mentions found in project room)"
    else
        log_fail "Too few @mentions in project room (found ${MENTION_COUNT}, expected ≥5) — mention protocol may not be followed"
    fi
else
    log_fail "Cannot check messages: project room ID not found"
fi

# ============================================================
# CHECK 3: Chat log analysis (from file if available)
# ============================================================

log_section "Check 3: Chat Log Analysis"

if [ -n "${CHAT_LOG}" ] && [ -f "${CHAT_LOG}" ]; then
    log_pass "Chat log file exists: ${CHAT_LOG}"

    # Verify all roles appear in chat log
    for role in manager developer reviewer tester; do
        if grep -qi "^.*${role}:" "${CHAT_LOG}" 2>/dev/null; then
            log_pass "Role '${role}' appears in chat log"
        else
            log_fail "Role '${role}' NOT found in chat log"
        fi
    done

    # Check that developer mentions task completion at least twice
    DEV_COMPLETE=$(grep -ci "developer.*complet\|task.*complet.*developer\|已完成" "${CHAT_LOG}" 2>/dev/null || echo "0")
    log_info "Developer completion reports in log: ${DEV_COMPLETE}"

    # Check for review rounds
    REVIEW_MENTIONS=$(grep -ci "review\|审查\|意见" "${CHAT_LOG}" 2>/dev/null || echo "0")
    if [ "${REVIEW_MENTIONS}" -ge 2 ]; then
        log_pass "Review activity mentioned ≥2 times in chat log (multi-round review)"
    else
        log_fail "Too few review mentions in chat log (found ${REVIEW_MENTIONS}, expected ≥2)"
    fi
else
    log_info "SKIP: No chat log file provided"
fi

# ============================================================
# CHECK 4: Git commits — each role has commits
# ============================================================

log_section "Check 4: Git Commits by Role"

if [ -n "${GITHUB_REPO}" ] && [ -n "${GITHUB_TOKEN}" ]; then
    log_info "Checking GitHub repo: ${GITHUB_REPO}"

    # Get commits from GitHub API
    GH_API_URL="https://api.github.com/repos/${GITHUB_REPO}/commits?per_page=100"
    GH_COMMITS=$(curl -sf "${GH_API_URL}" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" 2>/dev/null || echo '[]')

    COMMIT_COUNT=$(echo "${GH_COMMITS}" | jq 'length' 2>/dev/null || echo "0")
    log_info "Total commits found: ${COMMIT_COUNT}"

    if [ "${COMMIT_COUNT}" -gt 0 ]; then
        # Check commits by developer
        DEV_COMMITS=$(echo "${GH_COMMITS}" | jq '[.[] | select(.commit.author.name | test("developer"; "i"))] | length' 2>/dev/null || echo "0")
        if [ "${DEV_COMMITS}" -ge 2 ]; then
            log_pass "Developer has ≥2 git commits (initial + fix after review): ${DEV_COMMITS}"
        else
            log_fail "Developer has only ${DEV_COMMITS} git commits (expected ≥2 for initial + fix after review)"
        fi

        # Check commits by reviewer
        REVIEWER_COMMITS=$(echo "${GH_COMMITS}" | jq '[.[] | select(.commit.author.name | test("reviewer"; "i"))] | length' 2>/dev/null || echo "0")
        if [ "${REVIEWER_COMMITS}" -ge 1 ]; then
            log_pass "Reviewer has ≥1 git commit (review.md): ${REVIEWER_COMMITS}"
        else
            log_fail "Reviewer has 0 git commits (expected ≥1 for review.md)"
        fi

        # Check commits by tester
        TESTER_COMMITS=$(echo "${GH_COMMITS}" | jq '[.[] | select(.commit.author.name | test("tester"; "i"))] | length' 2>/dev/null || echo "0")
        if [ "${TESTER_COMMITS}" -ge 1 ]; then
            log_pass "Tester has ≥1 git commit (test results): ${TESTER_COMMITS}"
        else
            log_fail "Tester has 0 git commits (expected ≥1 for test results)"
        fi

        # Check for review.md in commits (multi-round)
        REVIEW_MD_COMMITS=$(echo "${GH_COMMITS}" | jq '[.[] | select(.commit.message | test("review"; "i"))] | length' 2>/dev/null || echo "0")
        if [ "${REVIEW_MD_COMMITS}" -ge 2 ]; then
            log_pass "At least 2 review-related commits (multi-round review confirmed): ${REVIEW_MD_COMMITS}"
        else
            log_fail "Only ${REVIEW_MD_COMMITS} review-related commit(s) (expected ≥2 for multi-round review)"
        fi

        # Print commit summary
        log_info "Commit author summary:"
        echo "${GH_COMMITS}" | jq -r '.[] | "\(.commit.author.name): \(.commit.message | split("\n")[0])"' 2>/dev/null | head -20 | while read -r line; do
            log_info "  ${line}"
        done
    else
        log_fail "No commits found in GitHub repo ${GITHUB_REPO}"
    fi

    # Check review.md exists in the repo
    REVIEW_MD_CHECK=$(curl -sf "https://api.github.com/repos/${GITHUB_REPO}/contents/review.md" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" 2>/dev/null | jq -r '.name // empty' 2>/dev/null || true)
    if [ "${REVIEW_MD_CHECK}" = "review.md" ]; then
        log_pass "review.md exists in repository"
    else
        log_fail "review.md NOT found in repository root"
    fi

    # Check git history for review.md specifically
    REVIEW_MD_HISTORY=$(curl -sf "https://api.github.com/repos/${GITHUB_REPO}/commits?path=review.md&per_page=20" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    if [ "${REVIEW_MD_HISTORY}" -ge 2 ]; then
        log_pass "review.md has ≥2 commits in git history (multi-round review verified): ${REVIEW_MD_HISTORY}"
    else
        log_fail "review.md has only ${REVIEW_MD_HISTORY} commit(s) in git history (expected ≥2 for multi-round)"
    fi

else
    log_info "No GitHub token/repo configured — checking for local git evidence in MinIO task results"

    # Fallback: check task result files for git commit mentions
    if [ -n "${PROJECT_ID}" ]; then
        TASK_DIRS=$(mc ls "hiclaw/hiclaw-storage/shared/tasks/" 2>/dev/null | awk '{print $NF}' | tr -d '/' || true)
        FOUND_DEV_COMMIT=false
        FOUND_REVIEWER_COMMIT=false
        FOUND_TESTER_COMMIT=false

        for task_dir in ${TASK_DIRS}; do
            RESULT=$(mc cat "hiclaw/hiclaw-storage/shared/tasks/${task_dir}/result.md" 2>/dev/null || true)
            META=$(mc cat "hiclaw/hiclaw-storage/shared/tasks/${task_dir}/meta.json" 2>/dev/null || true)
            ASSIGNED_TO=$(echo "${META}" | jq -r '.assigned_to // empty' 2>/dev/null || true)

            if echo "${RESULT}" | grep -qi "commit\|push\|git"; then
                case "${ASSIGNED_TO}" in
                    developer) FOUND_DEV_COMMIT=true ;;
                    reviewer)  FOUND_REVIEWER_COMMIT=true ;;
                    tester)    FOUND_TESTER_COMMIT=true ;;
                esac
            fi
        done

        [ "${FOUND_DEV_COMMIT}" = "true" ] && log_pass "Developer task result mentions git commit" || log_fail "Developer task result has no git commit mention"
        [ "${FOUND_REVIEWER_COMMIT}" = "true" ] && log_pass "Reviewer task result mentions git commit (review.md)" || log_fail "Reviewer task result has no git commit mention"
        [ "${FOUND_TESTER_COMMIT}" = "true" ] && log_pass "Tester task result mentions git commit" || log_fail "Tester task result has no git commit mention"
    else
        log_info "SKIP: No GitHub token and no project ID — cannot verify git commits"
    fi
fi

# ============================================================
# CHECK 5: plan.md completion
# ============================================================

log_section "Check 5: plan.md All Tasks Completed"

if [ -n "${PROJECT_ID}" ]; then
    PLAN_MD=$(mc cat "hiclaw/hiclaw-storage/shared/projects/${PROJECT_ID}/plan.md" 2>/dev/null || true)

    if [ -n "${PLAN_MD}" ]; then
        log_pass "plan.md exists in MinIO"

        TOTAL_TASKS=$(echo "${PLAN_MD}" | grep -c '^\- \[' 2>/dev/null || echo "0")
        DONE_TASKS=$(echo "${PLAN_MD}" | grep -c '^\- \[x\]' 2>/dev/null || echo "0")
        PENDING_TASKS=$(echo "${PLAN_MD}" | grep -c '^\- \[ \]' 2>/dev/null || echo "0")
        INPROG_TASKS=$(echo "${PLAN_MD}" | grep -c '^\- \[~\]' 2>/dev/null || echo "0")
        BLOCKED_TASKS=$(echo "${PLAN_MD}" | grep -c '^\- \[!\]' 2>/dev/null || echo "0")

        log_info "plan.md task summary: total=${TOTAL_TASKS}, done=${DONE_TASKS}, pending=${PENDING_TASKS}, in-progress=${INPROG_TASKS}, blocked=${BLOCKED_TASKS}"

        if [ "${TOTAL_TASKS}" -gt 0 ] && [ "${DONE_TASKS}" -eq "${TOTAL_TASKS}" ]; then
            log_pass "All ${TOTAL_TASKS} tasks in plan.md are [x] completed"
        elif [ "${DONE_TASKS}" -gt 0 ] && [ "${PENDING_TASKS}" -eq 0 ] && [ "${INPROG_TASKS}" -eq 0 ]; then
            log_pass "All tracked tasks completed (${DONE_TASKS} done, none pending/in-progress)"
        else
            log_fail "plan.md not fully complete: ${DONE_TASKS}/${TOTAL_TASKS} done, ${PENDING_TASKS} pending, ${INPROG_TASKS} in-progress"
        fi

        # Verify plan has entries for all 3 roles
        for role in developer reviewer tester; do
            if echo "${PLAN_MD}" | grep -qi "@${role}\|assigned:.*${role}"; then
                log_pass "plan.md includes tasks for role: ${role}"
            else
                log_fail "plan.md has no tasks mentioning role: ${role}"
            fi
        done

        # Verify Change Log exists
        if echo "${PLAN_MD}" | grep -qi "Change Log\|变更记录"; then
            log_pass "plan.md has Change Log section"
        else
            log_fail "plan.md missing Change Log section"
        fi
    else
        log_fail "plan.md not found in MinIO for project ${PROJECT_ID}"
    fi
else
    log_fail "Cannot check plan.md: project ID not found"
fi

# ============================================================
# CHECK 6: Multi-round review evidence
# ============================================================

log_section "Check 6: Multi-Round Review Evidence"

if [ -n "${PROJECT_ID}" ]; then
    # Count how many tasks have "reviewer" as assigned_to
    TASK_DIRS=$(mc ls "hiclaw/hiclaw-storage/shared/tasks/" 2>/dev/null | awk '{print $NF}' | tr -d '/' || true)
    REVIEWER_TASK_COUNT=0

    for task_dir in ${TASK_DIRS}; do
        META=$(mc cat "hiclaw/hiclaw-storage/shared/tasks/${task_dir}/meta.json" 2>/dev/null || true)
        ASSIGNED_TO=$(echo "${META}" | jq -r '.assigned_to // empty' 2>/dev/null || true)
        PROJECT=$(echo "${META}" | jq -r '.project_id // empty' 2>/dev/null || true)

        if [ "${ASSIGNED_TO}" = "reviewer" ] && [ "${PROJECT}" = "${PROJECT_ID}" ]; then
            REVIEWER_TASK_COUNT=$((REVIEWER_TASK_COUNT + 1))
        fi
    done

    log_info "Reviewer task count in project: ${REVIEWER_TASK_COUNT}"

    if [ "${REVIEWER_TASK_COUNT}" -ge 2 ]; then
        log_pass "Reviewer has ≥2 tasks in project (multi-round review: initial + approval after fix)"
    else
        log_fail "Reviewer has only ${REVIEWER_TASK_COUNT} task(s) in project (expected ≥2 for multi-round)"
    fi

    # Similarly check developer (initial code + fix round)
    DEV_TASK_COUNT=0
    for task_dir in ${TASK_DIRS}; do
        META=$(mc cat "hiclaw/hiclaw-storage/shared/tasks/${task_dir}/meta.json" 2>/dev/null || true)
        ASSIGNED_TO=$(echo "${META}" | jq -r '.assigned_to // empty' 2>/dev/null || true)
        PROJECT=$(echo "${META}" | jq -r '.project_id // empty' 2>/dev/null || true)

        if [ "${ASSIGNED_TO}" = "developer" ] && [ "${PROJECT}" = "${PROJECT_ID}" ]; then
            DEV_TASK_COUNT=$((DEV_TASK_COUNT + 1))
        fi
    done

    log_info "Developer task count in project: ${DEV_TASK_COUNT}"

    if [ "${DEV_TASK_COUNT}" -ge 2 ]; then
        log_pass "Developer has ≥2 tasks in project (initial code + fix after review)"
    else
        log_fail "Developer has only ${DEV_TASK_COUNT} task(s) in project (expected ≥2)"
    fi
fi

# ============================================================
# CHECK 7: Project meta.json status
# ============================================================

log_section "Check 7: Project Meta Status"

if [ -n "${PROJECT_ID}" ]; then
    META_JSON=$(mc cat "hiclaw/hiclaw-storage/shared/projects/${PROJECT_ID}/meta.json" 2>/dev/null || true)

    if [ -n "${META_JSON}" ]; then
        log_pass "Project meta.json exists"

        STATUS=$(echo "${META_JSON}" | jq -r '.status // empty' 2>/dev/null || true)
        CONFIRMED_AT=$(echo "${META_JSON}" | jq -r '.confirmed_at // empty' 2>/dev/null || true)
        WORKERS=$(echo "${META_JSON}" | jq -r '.workers // [] | join(", ")' 2>/dev/null || true)

        log_info "Project status: ${STATUS}, confirmed_at: ${CONFIRMED_AT}, workers: ${WORKERS}"

        if [ "${STATUS}" = "completed" ]; then
            log_pass "Project status is 'completed'"
        elif [ "${STATUS}" = "active" ]; then
            log_info "Project status is 'active' (may still be in progress)"
        else
            log_fail "Unexpected project status: '${STATUS}' (expected 'completed')"
        fi

        if [ -n "${CONFIRMED_AT}" ] && [ "${CONFIRMED_AT}" != "null" ]; then
            log_pass "Project was confirmed by human (confirmed_at: ${CONFIRMED_AT})"
        else
            log_fail "Project confirmed_at is null — human confirmation may not have been recorded"
        fi

        for worker in developer reviewer tester; do
            if echo "${WORKERS}" | grep -q "${worker}"; then
                log_pass "Worker '${worker}' listed in project meta"
            else
                log_fail "Worker '${worker}' NOT listed in project meta"
            fi
        done
    else
        log_fail "Project meta.json not found in MinIO"
    fi
fi

# ============================================================
# Final summary
# ============================================================

test_teardown "verify-project-collaboration"
test_summary
