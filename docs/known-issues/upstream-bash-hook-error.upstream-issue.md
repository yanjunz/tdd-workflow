# [Bug] PreToolUse/PostToolUse:Bash hook errors shown in UI when hooks run concurrently, even though all hook processes exit 0

> Draft for upstream filing at https://github.com/anthropics/claude-code/issues
> Status: ready to file
> Author context: surfaced via the [tdd-workflow](https://www.npmjs.com/package/tdd-workflow) hook suite

## Summary

When Claude Code dispatches multiple `Bash` tool calls in the same turn (e.g. parallel `grep` + `cat` + `find`), the UI repeatedly prints

```
⎿  PreToolUse:Bash hook error
⎿  PostToolUse:Bash hook error
```

— **one Pre/Post pair per concurrent call** — even though every hook child process actually completes successfully (`exit 0`). This appears to be a false-positive in the IPC / pipe-coordination layer between the Claude Code main process and parallel hook subprocesses, not a genuine hook failure.

## Environment

- Claude Code: (please fill in your version, e.g. via `claude --version`)
- macOS 14.x (also reported on macOS 13)
- Hook scripts: POSIX `bash` + `jq`, all reading event JSON from stdin
- Hooks configured in `.claude/settings.json` for `PreToolUse`, `PostToolUse`, `UserPromptSubmit`

## Symptom

A single user turn that triggers Claude to run multiple Bash tool invocations in parallel produces a burst of hook-error lines in the UI:

```
⏺ Searching for 5 patterns, reading 2 files...
  ⎿  ~/path/to/some/file.ts
  ⎿  PreToolUse:Bash hook error
  ⎿  PostToolUse:Bash hook error
  ⎿  PreToolUse:Bash hook error
  ⎿  PostToolUse:Bash hook error
  ⎿  ...
```

Crucially:

- The errors only appear when multiple Bash calls run **concurrently** in the same turn.
- Single Bash calls — even the *exact same command* — never trigger the error.
- All side effects of the hooks (file edits, log writes, exit codes) are correct.
- Manually invoking each hook script with the same stdin JSON via shell never reproduces the error.

## Reproduction

1. Add a trivial hook to `.claude/settings.json`:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/path/to/pre-bash.sh" }] }
       ],
       "PostToolUse": [
         { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/path/to/post-bash.sh" }] }
       ]
     }
   }
   ```

   Where `pre-bash.sh` / `post-bash.sh` simply read stdin, append a line to a log, and `exit 0`.

2. Inject a "process started" beacon at the very top of each script (line 2, right after the shebang) so we can prove the hook process actually launched and finished:

   ```bash
   #!/usr/bin/env bash
   echo "$(date '+%F %T') $0 STARTED pid=$$ ppid=$PPID" >> /tmp/hook-trace.log

   # ... rest of hook body ...
   echo "reached end, exit 0" >> /tmp/hook-body.log
   exit 0
   ```

3. In Claude Code, ask a question that causes parallel Bash tool calls, e.g.:

   > "Find all TODO comments and also count the lines of `package.json` and also list `node_modules`"

   Claude will fan out 3+ parallel Bash invocations.

4. Observe the UI: a burst of `PreToolUse:Bash hook error` / `PostToolUse:Bash hook error` lines.

## Evidence: hook processes succeeded

The beacon log shows multiple hook PIDs spawned the **same second** under the same Claude Code parent PID:

```
2026-05-12 16:33:16 pre-bash STARTED pid=29627 ppid=57242
2026-05-12 16:33:16 pre-bash STARTED pid=29626 ppid=57242
2026-05-12 16:33:16 pre-bash STARTED pid=29625 ppid=57242
2026-05-12 16:33:16 post-bash STARTED pid=30898 ppid=57242
2026-05-12 16:33:16 post-bash STARTED pid=30897 ppid=57242
2026-05-12 16:33:16 post-bash STARTED pid=30899 ppid=57242
```

Every one of those 6 PIDs reaches its `reached end, exit 0` log line before exiting. The kernel-side exit codes are 0. Yet the UI prints 6 hook-error entries.

## Hypothesis

Claude Code's documentation already states:

> Hooks execute in parallel when multiple tool calls run concurrently.

But it does **not** specify how stdin/stdout pipes are managed when several hook subprocesses are launched simultaneously. The most likely culprit is a race in the Node-side pipe handling — e.g.

- writing the event JSON to a child's stdin and closing the pipe before the child opens it,
- reading from a child's stdout that has already been EOF'd,
- a SIGPIPE / EPIPE during high-concurrency dispatch,

— any of which would surface in Claude Code's IPC layer as a "hook error" *for the dispatch*, even though the **child process itself** ran cleanly to completion.

In other words: the hook script succeeds, but Claude Code's bookkeeping for the dispatch loses track of the success and labels it as an error.

## Impact

- Functionality: **none observed.** All hook side effects (file writes, exit-code-2 blocks, etc.) work correctly.
- UX: significant. Users see what looks like cascading failure messages (often 6–10+ in a single turn) and lose trust in their hook setup.
- Debuggability: real hook errors get drowned in false positives, making this a foot-gun for any non-trivial hook author.

## Workarounds users currently rely on

1. Tell users to ignore the red lines and check the hook's own log file instead.
2. Disable hooks entirely.

Neither is satisfactory.

## Suggested fixes

In rough order of effort:

1. **Make hook errors include diagnostic detail.** Today the UI just says `PreToolUse:Bash hook error` with no exit code, no stderr, no command name. If the message included exit code + stderr tail, false positives like this would be self-evident (the exit code would still be 0).
2. **Distinguish "child exited non-zero" from "internal IPC error".** They are very different failure modes and should not share a UI string.
3. **Add an opt-in serial-execution mode** (e.g. `"hookConcurrency": 1` in settings) for users who prefer reliability over speed. This would side-step the IPC race entirely.
4. **Audit the parallel hook dispatcher** for stdin/stdout pipe lifecycle bugs — particularly around EPIPE handling and concurrent writes to N children's stdin.

## Related files in the affected user project

- Hook scripts (POSIX bash, all stdin/jq based, all silent on stdout for Pre/PostToolUse, all `exit 0` on the success path):
  - `pre-bash.sh`
  - `post-bash.sh`
  - `user-prompt-submit.sh`
  - `pre-write-edit.sh`
  - `post-write-edit.sh`
- Self-test that proves hooks behave correctly when invoked outside Claude Code: `test/hooks-verify.sh` (18/18 pass)

I'm happy to share the full hook scripts, settings.json, and trace-log artifacts if useful.

---

*Filed by a `tdd-workflow` user. Internal cross-reference: `docs/known-issues/bash-hook-error-on-concurrent-calls.md`.*
