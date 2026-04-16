#!/usr/bin/env bash
# TDD Harness — UserPromptSubmit hook
# Injects current harness state and task status into Claude's context

SPEC=$(cat tdd-specs/.current 2>/dev/null)
if [ -n "$SPEC" ] && [ -f "tdd-specs/$SPEC/.harness" ]; then
  . "tdd-specs/$SPEC/.harness" 2>/dev/null
  echo "[tdd-harness] Phase: ${phase:-idle} | Task: ${task:-none} | Strikes: ${strikes:-0}"
fi
if [ -n "$SPEC" ] && [ -d "tdd-specs/$SPEC" ]; then
  echo "[tdd-workflow] Active spec: $SPEC"
  grep -E "^(##|\- \[)" "tdd-specs/$SPEC/tasks.md" 2>/dev/null | head -20 || true
fi
