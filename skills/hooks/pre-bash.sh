#!/usr/bin/env bash
# TDD Harness — PreToolUse (Bash) hook
#
# Hook events other than UserPromptSubmit/SessionStart do NOT surface stdout
# to Claude — it only goes into the debug log. So we intentionally stay silent
# on stdout to avoid any SIGPIPE / broken-pipe noise.
#
# All diagnostics go to /tmp/tdd-hook-pre-bash.log.
# Set TDD_HOOK_DEBUG=0 in env to disable logging.

set +e

LOG=${TDD_HOOK_LOG_PRE_BASH:-/tmp/tdd-hook-pre-bash.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ PreToolUse/Bash ==="

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null | tr -d '\r\n')
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then
  log "no spec/harness"
  exit 0
fi

# shellcheck disable=SC1090
. "$H" 2>/dev/null || true

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
log "spec=$SPEC phase=${phase:-?} cmd=$(printf '%s' "$COMMAND" | head -c 120)"

# Reminder only goes to log (Claude doesn't read PreToolUse stdout anyway).
if [ -n "${last_edit_time:-}" ] && [ -n "${last_test_time:-}" ]; then
  case "${last_edit_time}${last_test_time}" in
    *[!0-9]*) log "non-numeric timestamps, skip compare" ;;
    *)
      if [ "$last_edit_time" -gt "$last_test_time" ]; then
        log "[reminder] code changed since last test run (edit=$last_edit_time test=$last_test_time)"
      fi
      ;;
  esac
fi

log "reached end, exit 0"
exit 0
