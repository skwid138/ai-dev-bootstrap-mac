/**
 * Lightweight Orchestration Plugin
 *
 * Provides task tracking and timeout enforcement for subagent tasks.
 * Stripped-down task tracker for opencode subagent invocations.
 *
 * Features:
 * - Task lifecycle tracking (start/complete/fail) via tool.execute hooks
 * - Configurable timeout enforcement for subagent tasks
 * - /tasks, /diagnostics, /continue, /stop actions
 *
 * Intentionally omitted (add back if needed):
 * - Tmux integration
 * - Persistent file storage
 * - Provider fallback engine
 * - Notification buffer
 * - Category-based routing
 */

import { tool, type Plugin } from "@opencode-ai/plugin";

// ── Configuration (edit these directly) ──────────────────────────────────────

const TASK_TIMEOUT_MS = 180_000; // 3 minutes
const MAX_TRACKED_TASKS = 50; // Keep last N tasks in memory

// ── Types ────────────────────────────────────────────────────────────────────

type TaskStatus = "running" | "completed" | "failed" | "stopped";

interface TaskRecord {
  id: string;
  sessionID: string;
  title: string;
  agent: string;
  status: TaskStatus;
  startedAt: number;
  endedAt: number | null;
  details: string;
}

// ── State ────────────────────────────────────────────────────────────────────

const tasks = new Map<string, TaskRecord>();
const taskByCallID = new Map<string, string>();
const loopEnabled = new Map<string, boolean>();

// ── Helpers ──────────────────────────────────────────────────────────────────

function generateID(): string {
  return `tsk_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`;
}

function isTerminal(status: TaskStatus): boolean {
  return status === "completed" || status === "failed" || status === "stopped";
}

function durationMs(task: TaskRecord): number {
  const end = task.endedAt ?? Date.now();
  return end - task.startedAt;
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return `${minutes}m${remainingSeconds}s`;
}

function getSessionTasks(sessionID: string): TaskRecord[] {
  const result: TaskRecord[] = [];
  for (const task of tasks.values()) {
    if (task.sessionID === sessionID) result.push(task);
  }
  return result.sort((a, b) => b.startedAt - a.startedAt);
}

function enforceTimeouts(sessionID: string): number {
  const now = Date.now();
  let count = 0;
  for (const task of tasks.values()) {
    if (task.sessionID !== sessionID) continue;
    if (task.status !== "running") continue;
    if (now - task.startedAt > TASK_TIMEOUT_MS) {
      task.status = "failed";
      task.endedAt = now;
      task.details = `Timed out after ${formatDuration(TASK_TIMEOUT_MS)}`;
      count++;
    }
  }
  return count;
}

function pruneOldTasks(): void {
  if (tasks.size <= MAX_TRACKED_TASKS) return;
  const sorted = [...tasks.entries()].sort(
    (a, b) => b[1].startedAt - a[1].startedAt,
  );
  const toRemove = sorted.slice(MAX_TRACKED_TASKS);
  for (const [id] of toRemove) {
    if (isTerminal(tasks.get(id)!.status)) {
      tasks.delete(id);
    }
  }
}

/**
 * Detect if task tool output looks like a failure.
 * Short outputs with error-like patterns are likely provider/tool errors,
 * not substantive agent analysis that happens to mention failure.
 */
function isLikelyFailure(output: string): boolean {
  if (output.length === 0) return false;
  if (output.length <= 300 && output.toLowerCase().includes("failed")) return true;
  const patterns = [
    /^error:/im,
    /task failed/i,
    /execution failed/i,
    /provider.*error/i,
    /rate limit/i,
    /timed?\s*out/i,
    /connection refused/i,
    /ECONNREFUSED/,
    /ETIMEDOUT/,
  ];
  return patterns.some((p) => p.test(output));
}

// ── Tool ─────────────────────────────────────────────────────────────────────

const orchestrationTool = tool({
  description:
    "Controls orchestration state. Actions: continue, stop, tasks, task, diagnostics.",
  args: {
    action: tool.schema.enum(["continue", "stop", "tasks", "task", "diagnostics"]),
    task_id: tool.schema.string().optional(),
  },
  execute: async (args, context) => {
    const sid = context.sessionID;

    if (args.action === "continue") {
      loopEnabled.set(sid, true);
      return "Continuous loop mode enabled. Loop remains active until /stop is invoked.";
    }

    if (args.action === "stop") {
      loopEnabled.set(sid, false);
      let stopped = 0;
      for (const task of getSessionTasks(sid)) {
        if (task.status === "running") {
          task.status = "stopped";
          task.endedAt = Date.now();
          task.details = "Stopped by /stop command";
          stopped++;
        }
      }
      return `Loop halted. ${stopped} active task(s) marked stopped.`;
    }

    if (args.action === "task") {
      if (!args.task_id) return "Missing task_id. Usage: action=task task_id=<id>";
      const task = tasks.get(args.task_id);
      if (!task || task.sessionID !== sid) return `Task not found: ${args.task_id}`;
      return [
        `# Task ${task.id}`,
        `- Status: ${task.status}`,
        `- Agent: ${task.agent}`,
        `- Title: ${task.title}`,
        `- Duration: ${formatDuration(durationMs(task))}`,
        `- Details: ${task.details}`,
      ].join("\n");
    }

    if (args.action === "tasks") {
      const timedOut = enforceTimeouts(sid);
      const sessionTasks = getSessionTasks(sid);
      if (sessionTasks.length === 0) return "No tracked tasks for this session.";

      const active = sessionTasks.filter((t) => t.status === "running");
      const lines = [
        "# Subagent Tasks",
        "",
        ...sessionTasks.slice(0, 20).map(
          (t) =>
            `- ${t.id} [${t.status}] ${t.agent} "${t.title}" (${formatDuration(durationMs(t))})`,
        ),
      ];
      if (timedOut > 0) lines.push("", `⚠ ${timedOut} task(s) timed out this check.`);
      lines.push("", `Active: ${active.length} | Total tracked: ${sessionTasks.length}`);
      return lines.join("\n");
    }

    // diagnostics
    const timedOut = enforceTimeouts(sid);
    const sessionTasks = getSessionTasks(sid);
    const active = sessionTasks.filter((t) => t.status === "running");
    const completed = sessionTasks.filter((t) => t.status === "completed");
    const failed = sessionTasks.filter((t) => t.status === "failed");
    const stopped = sessionTasks.filter((t) => t.status === "stopped");

    const agentCounts = new Map<string, number>();
    for (const t of sessionTasks) {
      agentCounts.set(t.agent, (agentCounts.get(t.agent) ?? 0) + 1);
    }

    return [
      "# Orchestration Diagnostics",
      "",
      "## Summary",
      `- Loop mode: ${loopEnabled.get(sid) ? "enabled" : "disabled"}`,
      `- Task timeout: ${formatDuration(TASK_TIMEOUT_MS)}`,
      `- Timed out this check: ${timedOut}`,
      "",
      "## Task Counts",
      `- Active: ${active.length}`,
      `- Completed: ${completed.length}`,
      `- Failed: ${failed.length}`,
      `- Stopped: ${stopped.length}`,
      `- Total tracked: ${sessionTasks.length}`,
      "",
      "## Agent Distribution",
      ...[...agentCounts.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([agent, count]) => `- ${agent}: ${count}`),
    ].join("\n");
  },
});

// ── Plugin ───────────────────────────────────────────────────────────────────

const OrchestrationPlugin: Plugin = async () => {
  return {
    tool: {
      bootstrap_orchestration: orchestrationTool,
    },

    "tool.execute.before": async (input, _output) => {
      if (input.tool !== "task") return;

      const args = _output.args as Record<string, unknown> | undefined;
      const description =
        (typeof args?.description === "string" && args.description.trim()) ||
        "untitled-task";
      const agent =
        (typeof args?.subagent_type === "string" && args.subagent_type.trim()) ||
        "unknown";

      const record: TaskRecord = {
        id: generateID(),
        sessionID: input.sessionID,
        title: description.length > 48 ? `${description.slice(0, 45)}...` : description,
        agent,
        status: "running",
        startedAt: Date.now(),
        endedAt: null,
        details: `Delegated to ${agent}`,
      };

      tasks.set(record.id, record);
      taskByCallID.set(input.callID, record.id);
      pruneOldTasks();
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool !== "task") return;

      const taskID = taskByCallID.get(input.callID);
      if (!taskID) return;

      const record = tasks.get(taskID);
      if (!record || isTerminal(record.status)) return;

      const text = typeof output.output === "string" ? output.output : "";

      if (isLikelyFailure(text)) {
        record.status = "failed";
        record.endedAt = Date.now();
        record.details = `Failed after ${formatDuration(durationMs(record))}`;
      } else {
        record.status = "completed";
        record.endedAt = Date.now();
        record.details = `Completed in ${formatDuration(durationMs(record))}`;
      }
    },
  };
};

export default OrchestrationPlugin;
