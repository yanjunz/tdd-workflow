#!/usr/bin/env bash
# TDD Harness — PostToolUse (Bash) hook
#
# Silent on stdout (Claude doesn't read PostToolUse stdout). All diagnostics
# and harness notes go to /tmp/tdd-hook-post-bash.log.

set +e

LOG=${TDD_HOOK_LOG_POST_BASH:-/tmp/tdd-hook-post-bash.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ PostToolUse/Bash ==="

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then
  log "no spec/harness"
  exit 0
fi

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
OUTPUT=$(printf '%s' "$INPUT" | jq -r '.tool_response // empty | if type=="string" then . else tostring end' 2>/dev/null)

case "$COMMAND" in
  *test*|*jest*|*vitest*|*pytest*|*"go test"*|*"cargo test"*|*mocha*) ;;
  *) log "non-test cmd, skip"; exit 0 ;;
esac

TS=$(date +%s)
# macOS BSD sed needs empty-string suffix; GNU sed also accepts it.
if grep -q "last_test_time=" "$H"; then
  sed -i '' "s/last_test_time=.*/last_test_time=$TS/" "$H" 2>/dev/null || \
    sed -i "s/last_test_time=.*/last_test_time=$TS/" "$H" 2>/dev/null
else
  echo "last_test_time=$TS" >> "$H"
fi

# shellcheck disable=SC1090
. "$H" 2>/dev/null || true

if printf '%s' "$OUTPUT" | grep -qiE 'FAIL|FAILED|ERROR|failures'; then
  log "[tests] FAILED (phase=${phase:-?})"
  if [ "${phase:-}" = "green" ]; then
    strikes=$(( ${strikes:-0} + 1 ))
    if grep -q "strikes=" "$H"; then
      sed -i '' "s/strikes=.*/strikes=$strikes/" "$H" 2>/dev/null || \
        sed -i "s/strikes=.*/strikes=$strikes/" "$H" 2>/dev/null
    else
      echo "strikes=$strikes" >> "$H"
    fi
    [ "$strikes" -ge 3 ] && log "[THREE-STRIKE] same test failed $strikes times"
  fi
else
  log "[tests] PASSED"
  if grep -q "strikes=" "$H"; then
    sed -i '' "s/strikes=.*/strikes=0/" "$H" 2>/dev/null || \
      sed -i "s/strikes=.*/strikes=0/" "$H" 2>/dev/null
  fi
fi

log "reached end, exit 0"
exit 0
