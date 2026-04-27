#!/usr/bin/env bash
# TDD Harness — PreToolUse (Write|Edit) hook
#
# RED phase: blocks writing to implementation files — only allows test files
# and anything under tdd-specs/. The block is the only intentional non-zero
# exit (exit 2 + stderr, per Claude Code hook contract); everything else
# exits 0 and stays silent on stdout to avoid UI "hook error" noise.
#
# Diagnostics go to /tmp/tdd-hook-pre-write-edit.log (set TDD_HOOK_DEBUG=0 to disable).

set +e

LOG=${TDD_HOOK_LOG_PRE_WRITE_EDIT:-/tmp/tdd-hook-pre-write-edit.log}
log() { [ "${TDD_HOOK_DEBUG:-1}" = "1" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
log "=== $(date '+%F %T') pid=$$ PreToolUse/Write|Edit ==="

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || { log "cannot cd $CWD"; exit 0; }

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then
  log "no spec/harness → allow"
  exit 0
fi

# shellcheck disable=SC1090
. "$H" 2>/dev/null || true

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -z "$FILE" ]; then
  log "no file_path in tool_input → allow"
  exit 0
fi

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
log "tool=$TOOL phase=${phase:-?} file=$FILE"

if [ "${phase:-}" = "red" ]; then
  # Allow test files
  if echo "$FILE" | grep -qE '(test|spec|__tests__|\.test\.|\.spec\.|_test\.go|_test\.py|Test\.java)'; then
    log "RED + test-like path → allow"
    exit 0
  fi
  # Allow tdd-specs/ files (specs, harness, notes, etc.)
  if echo "$FILE" | grep -q 'tdd-specs/'; then
    log "RED + tdd-specs/ → allow"
    exit 0
  fi
  log "RED + implementation file → BLOCK(2)"
  echo "BLOCKED: RED phase — write a failing test first, not implementation code. File: $FILE" >&2
  exit 2
fi

log "phase=${phase:-?} → allow"
exit 0
