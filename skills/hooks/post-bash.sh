#!/usr/bin/env bash
# TDD Harness — PostToolUse (Bash) hook
#
# Silent on stdout (Claude doesn't read PostToolUse stdout). All diagnostics
# and harness notes go to /tmp/tdd-hook-post-bash.log.
#
# Note: we read hook JSON from stdin via jq streaming (not $(cat)) to handle
# large tool_response payloads (e.g. multi-MB test output) without buffering
# everything through shell string variables.

set +e

LOG=${TDD_HOOK_LOG_POST_BASH:-/tmp/tdd-hook-post-bash.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ PostToolUse/Bash ==="

# Buffer stdin to a tempfile so we can extract individual fields without
# keeping megabytes in shell memory.
TMP=$(mktemp /tmp/tdd-hook-post-bash.XXXXXX 2>/dev/null) || TMP=/tmp/tdd-hook-post-bash.$$
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" 2>/dev/null || true
INPUT_BYTES=$(wc -c < "$TMP" 2>/dev/null | tr -d ' ')
log "stdin_bytes=${INPUT_BYTES:-0}"

jq_field() { jq -r "$1 // empty" < "$TMP" 2>/dev/null; }

CWD=$(jq_field '.cwd')
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null | tr -d '\r\n')
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then
  log "no spec/harness (spec=${SPEC:-<empty>})"
  exit 0
fi

COMMAND=$(jq_field '.tool_input.command')
log "spec=$SPEC cmd=$(printf '%s' "$COMMAND" | head -c 120)"

case "$COMMAND" in
  *test*|*jest*|*vitest*|*pytest*|*"go test"*|*"cargo test"*|*mocha*) log "detected test-like command" ;;
  *) log "non-test cmd, skip" ; exit 0 ;;
esac

# For test commands, we need to inspect tool_response for FAIL markers.
# Use jq to pipe the output straight into grep — no intermediate $OUTPUT var.
FAILED=0
jq -r '.tool_response | if type=="string" then . else tostring end' < "$TMP" 2>/dev/null \
  | grep -qiE 'FAIL|FAILED|ERROR|failures' && FAILED=1

TS=$(date +%s)
if grep -q "last_test_time=" "$H"; then
  sed -i '' "s/last_test_time=.*/last_test_time=$TS/" "$H" 2>/dev/null || \
    sed -i "s/last_test_time=.*/last_test_time=$TS/" "$H" 2>/dev/null
  log "updated last_test_time=$TS"
else
  echo "last_test_time=$TS" >> "$H"
  log "appended last_test_time=$TS"
fi

# shellcheck disable=SC1090
. "$H" 2>/dev/null || true

if [ "$FAILED" -eq 1 ]; then
  log "[tests] FAILED (phase=${phase:-?})"
  if [ "${phase:-}" = "green" ]; then
    strikes=$(( ${strikes:-0} + 1 ))
    if grep -q "strikes=" "$H"; then
      sed -i '' "s/strikes=.*/strikes=$strikes/" "$H" 2>/dev/null || \
        sed -i "s/strikes=.*/strikes=$strikes/" "$H" 2>/dev/null
    else
      echo "strikes=$strikes" >> "$H"
    fi
    log "strike counter → $strikes"
    [ "$strikes" -ge 3 ] && log "[THREE-STRIKE] same test failed $strikes times — HALT and ask user"
  else
    log "phase=${phase:-?}, not green — strike counter not incremented"
  fi
else
  log "[tests] PASSED (phase=${phase:-?})"
  if grep -q "strikes=" "$H"; then
    sed -i '' "s/strikes=.*/strikes=0/" "$H" 2>/dev/null || \
      sed -i "s/strikes=.*/strikes=0/" "$H" 2>/dev/null
    log "strike counter reset to 0"
  fi
fi

log "reached end, exit 0"
exit 0
