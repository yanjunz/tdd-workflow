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

SPEC=$(cat tdd-specs/.current 2>/dev/null | tr -d '\r\n')
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

if [ "${phase:-}" = "e2e" ]; then
  # In Stage 4, main agent MUST spawn Tester via Task tool. Tester (sub-agent)
  # has agent_id set; main agent does not. Block main-agent direct writes
  # outside tdd-specs/ to enforce the spawn structurally — file-level docs
  # and self-checks (auto.md / e2e.md / SKILL.md) are advisory and were
  # empirically ignored when context was cached (see v3.13.0 yunyin run:
  # 0 Task calls despite the rule being installed).
  AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
  if [ -n "$AGENT_ID" ]; then
    log "E2E + sub-agent (agent_id=$AGENT_ID type=$(printf '%s' "$INPUT" | jq -r '.agent_type // "?"' 2>/dev/null)) → allow (Tester writes)"
    exit 0
  fi
  # Main agent updating tasks.md / report / harness etc. is legitimate
  if echo "$FILE" | grep -q 'tdd-specs/'; then
    log "E2E + main agent + tdd-specs/ → allow (Orchestrator)"
    exit 0
  fi
  log "E2E + main agent + non-spec file ($FILE) → BLOCK(2)"
  echo "BLOCKED: phase=e2e — main agent must spawn Tester via Task tool, not Write/Edit files directly.
File: $FILE
Hint: in /tdd:auto Stage 4, call the Agent tool (subagent_type='general-purpose') to spawn Tester. See .claude/skills/tdd-workflow/commands/auto.md Stage 4 for the exact prompt template." >&2
  exit 2
fi

log "phase=${phase:-?} → allow"
exit 0
