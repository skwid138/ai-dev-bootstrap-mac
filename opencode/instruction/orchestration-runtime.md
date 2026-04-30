# Orchestration Runtime

Controls for long-running and delegated work.

## Core Controls

- `/continue` — enables continuous loop mode for the session.
- `/stop` — halts loop and queue processing immediately.
- `/tasks` — shows active/recent subagent tasks.
- `/task <id>` — shows one task record.
- `/diagnostics` — runs full orchestration diagnostics.

## Delegation Discipline

When delegating to subagents:

1. Provide a short, specific task title.
2. Include expected outcome and verification criteria.
3. Prefer bounded retries with backoff.
4. Keep updates concise and state-driven: started, retrying, completed, failed, stopped.

## Recovery

Startup recovery is enabled — queued/running tasks from prior sessions are moved back to queued state on restart.

## Long-Running Commands

Before running expensive commands (full test suites, mutation tests, broad scans, dependency installs):

1. Explain what would be run.
2. Provide the exact command.
3. Estimate why it may be expensive.
4. Ask whether to run it or let the user run it in a separate shell.
5. Prefer targeted tests/scans when possible.

For mutation testing and other multi-hour runs: strongly suggest the user run them separately unless the scope is clearly small.
