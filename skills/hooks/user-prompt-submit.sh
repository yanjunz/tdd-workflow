#!/usr/bin/env bash
# TDD Harness — UserPromptSubmit hook
#
# Injects current harness state and task status into Claude's context.
# UserPromptSubmit is one of the three events where stdout is surfaced to
# Claude as additional context — so unlike Pre/PostToolUse hooks, this one
# INTENTIONALLY writes to stdout.
#
# Diagnostics go to /tmp/tdd-hook-user-prompt-submit.log (set TDD_HOOK_DEBUG=0 to disable).

set +e

LOG=${TDD_HOOK_LOG_USER_PROMPT_SUBMIT:-/tmp/tdd-hook-user-prompt-submit.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ UserPromptSubmit ==="

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null | tr -d '\r\n')

if [ -z "$SPEC" ]; then
  log "no active spec (tdd-specs/.current empty)"
  exit 0
fi

if [ -f "tdd-specs/$SPEC/.harness" ]; then
  # shellcheck disable=SC1090
  . "tdd-specs/$SPEC/.harness" 2>/dev/null || true
  echo "[tdd-harness] Phase: ${phase:-idle} | Task: ${task:-none} | Strikes: ${strikes:-0}"
  log "spec=$SPEC phase=${phase:-idle} task=${task:-none} strikes=${strikes:-0}"
else
  log "spec=$SPEC (no .harness file)"
fi

if [ -d "tdd-specs/$SPEC" ]; then
  echo "[tdd-workflow] Active spec: $SPEC"
  if [ -f "tdd-specs/$SPEC/tasks.md" ]; then
    TASK_LINES=$(grep -cE "^(##|\- \[)" "tdd-specs/$SPEC/tasks.md" 2>/dev/null)
    log "tasks.md has $TASK_LINES matching lines (headings + task items)"
    grep -E "^(##|\- \[)" "tdd-specs/$SPEC/tasks.md" 2>/dev/null | head -20 || true
  else
    log "no tasks.md for $SPEC"
  fi
fi

log "reached end, exit 0"
exit 0
