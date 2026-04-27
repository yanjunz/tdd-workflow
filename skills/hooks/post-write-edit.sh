#!/usr/bin/env bash
# TDD Harness — PostToolUse (Write|Edit) hook
# Silent on stdout. All diagnostics go to /tmp/tdd-hook-post-write-edit.log.

set +e

LOG=${TDD_HOOK_LOG_POST_WRITE:-/tmp/tdd-hook-post-write-edit.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ PostToolUse/Write|Edit ==="

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null | tr -d '\r\n')
H="tdd-specs/$SPEC/.harness"

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
SUCCESS=$(printf '%s' "$INPUT" | jq -r '.tool_response.success // empty' 2>/dev/null)
log "tool=$TOOL file=$FILE success=${SUCCESS:-?} spec=${SPEC:-none}"

if [ -z "$SPEC" ]; then
  log "no active spec, skip"
  exit 0
fi

if [ ! -f "$H" ]; then
  log "no .harness at $H, skip"
  exit 0
fi

TS=$(date +%s)
if grep -q "last_edit_time=" "$H"; then
  sed -i '' "s/last_edit_time=.*/last_edit_time=$TS/" "$H" 2>/dev/null || \
    sed -i "s/last_edit_time=.*/last_edit_time=$TS/" "$H" 2>/dev/null
  log "updated last_edit_time=$TS for $SPEC"
else
  echo "last_edit_time=$TS" >> "$H"
  log "appended last_edit_time=$TS for $SPEC"
fi

log "reached end, exit 0"
exit 0
