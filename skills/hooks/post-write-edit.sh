#!/usr/bin/env bash
# TDD Harness — PostToolUse (Write|Edit) hook
# Updates last_edit_time timestamp and reminds to sync tasks.md

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -n "$SPEC" ] && [ -f "$H" ]; then
  TS=$(date +%s)
  if grep -q "last_edit_time=" "$H"; then
    sed -i'' "s/last_edit_time=.*/last_edit_time=$TS/" "$H"
  else
    echo "last_edit_time=$TS" >> "$H"
  fi
fi
if [ -n "$SPEC" ]; then
  echo "[tdd-harness] Sync tdd-specs/$SPEC/tasks.md"
fi
