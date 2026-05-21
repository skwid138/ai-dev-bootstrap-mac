---
description: Audit opencode permission ask/deny decisions and recommend config changes
---

Use the `permission-audit` skill to audit opencode permission decisions.

Run with the default date range of today unless the user provides date range or
filter arguments. Accept optional `--start DATE`, `--end DATE`, `--action
ask|deny|all`, and `--agent AGENT` arguments and pass them through to the skill's
script workflow.

{{$arguments}}
