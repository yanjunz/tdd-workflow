#!/usr/bin/env bash
# TDD Harness — PreToolUse (Write|Edit) hook
# RED phase: blocks writing to src/ files, only allows test files and tdd-specs/

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then exit 0; fi
. "$H" 2>/dev/null

FILE="$CLAUDE_FILE_PATH"
if [ -z "$FILE" ]; then exit 0; fi

if [ "$phase" = "red" ]; then
  # Allow test files
  if echo "$FILE" | grep -qE '(test|spec|__tests__|\.test\.|\.spec\.|_test\.go|_test\.py|Test\.java)'; then
    exit 0
  fi
  # Allow tdd-specs/ files
  if echo "$FILE" | grep -q 'tdd-specs/'; then
    exit 0
  fi
  echo "BLOCKED: RED phase — write a failing test first, not implementation code. File: $FILE" >&2
  exit 2
fi

exit 0
