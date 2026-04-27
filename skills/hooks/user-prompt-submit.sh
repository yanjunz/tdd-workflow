#!/usr/bin/env bash
# TDD Harness — UserPromptSubmit hook
# Injects current harness state and task status into Claude's context.
#
# Fail-safe: exits 0 on any internal error.

set +e

INPUT=$(cat 2>/dev/null || true)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || exit 0

SPEC=$(cat tdd-specs/.current 2>/dev/null)

if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  # shellcheck disable=SC1090
  . "tdd-specs/$SPEC/.harness" 2>/dev/null || true
  echo "[tdd-harness] Phase: ${phase:-idle} | Task: ${task:-none} | Strikes: ${strikes:-0}"
fi

if [ -n "$SPEC" ] && [ -d "tdd-specs/$SPEC" ]; then
  echo "[tdd-workflow] Active spec: $SPEC"
  grep -E "^(##|\- \[)" "tdd-specs/$SPEC/tasks.md" 2>/dev/null | head -20 || true
fi

exit 0
