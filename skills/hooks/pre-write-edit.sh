#!/usr/bin/env bash
# TDD Harness — PreToolUse (Write|Edit) hook
# RED phase: blocks writing to src/ files, only allows test files and tdd-specs/
#
# Fail-safe: internal errors exit 0 (never block). Only intentional RED-phase
# block uses exit 2.

set +e

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || exit 0

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then exit 0; fi

# shellcheck disable=SC1090
. "$H" 2>/dev/null || true

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -z "$FILE" ]; then exit 0; fi

if [ "${phase:-}" = "red" ]; then
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
