#!/usr/bin/env bash
# TDD hooks verification harness
#
# Usage:
#   # run from tdd-workflow repo root — tests skills/hooks/ directly
#   bash test/hooks-verify.sh
#
#   # run inside an installed project — tests .claude/hooks/tdd/
#   bash test/hooks-verify.sh .claude/hooks/tdd
#
# The working directory MUST allow creating a temp tdd-specs/_verify_test/
# subdirectory (script cleans up afterwards).

set -u
PASS=0
FAIL=0
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

# Resolve hook directory: first arg, or auto-detect.
if [ $# -ge 1 ]; then
  H="$1"
elif [ -d "skills/hooks" ]; then
  H="skills/hooks"
elif [ -d ".claude/hooks/tdd" ]; then
  H=".claude/hooks/tdd"
else
  red "Cannot find hook directory. Pass it as the first argument."
  exit 2
fi
echo "Testing hooks in: $H"

check() {
  local name="$1" expected_exit="$2" actual_exit="$3"
  if [ "$expected_exit" = "$actual_exit" ]; then
    green "  ✓ $name (exit=$actual_exit)"; PASS=$((PASS+1))
  else
    red   "  ✗ $name (expected exit=$expected_exit, got $actual_exit)"; FAIL=$((FAIL+1))
  fi
}

run_hook() {
  local hook="$1" json="$2"
  printf '%s' "$json" | "$hook"
  echo $?
}

# Keep /tmp clean and stdout predictable during verification.
export TDD_HOOK_DEBUG=0

# Isolated tdd-specs; preserve existing .current.
BACKUP_CURRENT=""
if [ -f tdd-specs/.current ]; then
  BACKUP_CURRENT=$(mktemp)
  cp tdd-specs/.current "$BACKUP_CURRENT"
fi
mkdir -p tdd-specs/_verify_test
echo "_verify_test" > tdd-specs/.current

cleanup() {
  rm -rf tdd-specs/_verify_test 2>/dev/null
  if [ -n "$BACKUP_CURRENT" ] && [ -f "$BACKUP_CURRENT" ]; then
    mv "$BACKUP_CURRENT" tdd-specs/.current
  else
    rm -f tdd-specs/.current
  fi
}
trap cleanup EXIT

# Rewrite harness (macOS + Linux compatible).
write_harness() {
  cat > tdd-specs/_verify_test/.harness <<EOF
phase=$1
task=none
strikes=${2:-0}
EOF
}

echo "── PreToolUse/Bash ──"
j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
check "non-test cmd exits 0" 0 "$(run_hook "$H/pre-bash.sh" "$j")"

echo "── PreToolUse/Write|Edit ──"
rm -f tdd-specs/_verify_test/.harness
# Use a path that does NOT contain the word "test" to avoid false positives
# when CWD includes it (e.g. /tmp/test-xxx during CI).
SRC_FILE="/var/tmp/tdd_verify_src_file.ts"
TEST_FILE="/var/tmp/tdd_verify_src.spec.ts"
j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/var/tmp/tdd_verify_foo.ts","content":"x"}}'
check "no harness → allow" 0 "$(run_hook "$H/pre-write-edit.sh" "$j")"

write_harness red
j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"'"$SRC_FILE"'","old_string":"a","new_string":"b"}}'
check "RED + src file → block(2)" 2 "$(run_hook "$H/pre-write-edit.sh" "$j")"

j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"'"$TEST_FILE"'","old_string":"a","new_string":"b"}}'
check "RED + test file → allow" 0 "$(run_hook "$H/pre-write-edit.sh" "$j")"

write_harness green
j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"'"$SRC_FILE"'","old_string":"a","new_string":"b"}}'
check "GREEN + src file → allow" 0 "$(run_hook "$H/pre-write-edit.sh" "$j")"

echo "── PostToolUse/Bash ──"
write_harness green 0
j='{"cwd":"'"$PWD"'","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":"1 FAILED"}'
check "test FAIL → exit 0" 0 "$(run_hook "$H/post-bash.sh" "$j")"
STRIKES=$(grep '^strikes=' tdd-specs/_verify_test/.harness | cut -d= -f2)
check "strike counter incremented" 1 "$STRIKES"

j='{"cwd":"'"$PWD"'","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":"all green"}'
check "test PASS → exit 0" 0 "$(run_hook "$H/post-bash.sh" "$j")"
STRIKES=$(grep '^strikes=' tdd-specs/_verify_test/.harness | cut -d= -f2)
check "strike counter reset to 0" 0 "$STRIKES"

echo "── PostToolUse/Write|Edit ──"
BEFORE=$(grep '^last_edit_time=' tdd-specs/_verify_test/.harness 2>/dev/null | cut -d= -f2)
sleep 1
j='{"cwd":"'"$PWD"'","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x"},"tool_response":{"success":true}}'
check "post-write-edit exit 0" 0 "$(run_hook "$H/post-write-edit.sh" "$j")"
AFTER=$(grep '^last_edit_time=' tdd-specs/_verify_test/.harness | cut -d= -f2)
if [ -n "$AFTER" ] && [ "${BEFORE:-0}" -lt "$AFTER" ]; then
  green "  ✓ last_edit_time updated (${BEFORE:-none} → $AFTER)"; PASS=$((PASS+1))
else
  red   "  ✗ last_edit_time not updated (before=$BEFORE after=$AFTER)"; FAIL=$((FAIL+1))
fi

echo "── UserPromptSubmit ──"
j='{"cwd":"'"$PWD"'","hook_event_name":"UserPromptSubmit","prompt":"hi"}'
OUT=$(printf '%s' "$j" | "$H/user-prompt-submit.sh")
EC=$?
check "user-prompt-submit exit 0" 0 "$EC"
if echo "$OUT" | grep -q 'Phase:'; then
  green "  ✓ stdout contains Phase: line"; PASS=$((PASS+1))
else
  red   "  ✗ stdout missing Phase: line ($OUT)"; FAIL=$((FAIL+1))
fi

echo "── stdout silence (Pre/Post) ──"
j='{"cwd":"'"$PWD"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}'
OUT=$(printf '%s' "$j" | "$H/pre-bash.sh")
if [ -z "$OUT" ]; then
  green "  ✓ pre-bash silent on stdout"; PASS=$((PASS+1))
else
  red   "  ✗ pre-bash leaked stdout: $OUT"; FAIL=$((FAIL+1))
fi
j='{"cwd":"'"$PWD"'","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":"ok"}'
OUT=$(printf '%s' "$j" | "$H/post-bash.sh")
if [ -z "$OUT" ]; then
  green "  ✓ post-bash silent on stdout"; PASS=$((PASS+1))
else
  red   "  ✗ post-bash leaked stdout: $OUT"; FAIL=$((FAIL+1))
fi
j='{"cwd":"'"$PWD"'","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x"},"tool_response":{"success":true}}'
OUT=$(printf '%s' "$j" | "$H/post-write-edit.sh")
if [ -z "$OUT" ]; then
  green "  ✓ post-write-edit silent on stdout"; PASS=$((PASS+1))
else
  red   "  ✗ post-write-edit leaked stdout: $OUT"; FAIL=$((FAIL+1))
fi

echo
echo "Total: $((PASS+FAIL))  Pass: $PASS  Fail: $FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
