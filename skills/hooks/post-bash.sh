#!/usr/bin/env bash
# TDD Harness — PostToolUse (Bash) hook
# Tracks test results, updates timestamps, manages strike count

SPEC=$(cat tdd-specs/.current 2>/dev/null)
H="tdd-specs/$SPEC/.harness"
if [ -z "$SPEC" ] || [ ! -f "$H" ]; then exit 0; fi

# Detect test commands from CLAUDE_TOOL_INPUT
if echo "$CLAUDE_TOOL_INPUT" | grep -qE '"command".*\b(test|jest|vitest|pytest|go test|cargo test|mocha|npm test|npx test)\b'; then
  TS=$(date +%s)
  if grep -q "last_test_time=" "$H"; then
    sed -i'' "s/last_test_time=.*/last_test_time=$TS/" "$H"
  else
    echo "last_test_time=$TS" >> "$H"
  fi

  . "$H" 2>/dev/null

  # Check test output for failures
  if echo "$CLAUDE_TOOL_OUTPUT" | grep -qiE 'FAIL|FAILED|ERROR|failures'; then
    echo "[tdd-harness] Tests FAILED"
    if [ "$phase" = "red" ]; then
      echo "[tdd-harness] Good — test fails as expected (RED). Write implementation to make it pass (GREEN)."
    fi
    if [ "$phase" = "green" ]; then
      strikes=$((${strikes:-0} + 1))
      sed -i'' "s/strikes=.*/strikes=$strikes/" "$H"
      if [ "$strikes" -ge 3 ]; then
        echo "[tdd-harness] THREE-STRIKE PROTOCOL — same test failed 3 times. Stop and ask user for decision."
      fi
    fi
  else
    echo "[tdd-harness] Tests PASSED"
    sed -i'' "s/strikes=.*/strikes=0/" "$H"
  fi
fi
