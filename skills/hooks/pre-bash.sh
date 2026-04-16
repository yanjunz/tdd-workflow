#!/usr/bin/env bash
# TDD Harness — PreToolUse (Bash) hook
# Reminds to run tests if code changed since last test run

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then exit 0; fi
. "$H" 2>/dev/null

if [ -n "$last_edit_time" ] && [ -n "$last_test_time" ]; then
  if [ "$last_edit_time" -gt "$last_test_time" ] 2>/dev/null; then
    echo "[tdd-harness] Reminder: code changed since last test run"
  fi
fi

exit 0
