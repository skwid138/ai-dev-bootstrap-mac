-- JustVibes launcher — AppleScript host for JustVibes.app (Branch F).
--
-- This script is compiled by `osacompile` (see launcher/build.sh) into
-- JustVibes.app/Contents/MacOS/applet — the standard AppleScript runtime
-- entry point produced by `osacompile -o`. The compiled bundle's
-- CFBundleExecutable is `applet` (Mach-O); this `.applescript` is the
-- compiled-into-Resources/Scripts/main.scpt source.
--
-- Why an AppleScript host (Branch F goal):
--   The previous launcher (launcher/launch.sh, now launcher/launch-helper.sh)
--   was the bundle's CFBundleExecutable directly. Bash → exec'd /usr/bin/open
--   → Ghostty took over the Dock tile / Cmd+Tab entry / Activity Monitor
--   process name. JustVibes' branded identity (piggy-bank icon, "JustVibes"
--   process name) was never visible because nothing persistent ever ran
--   under the bundle's identity.
--
--   AppleScript apps host a persistent process (the `applet` runtime) that
--   stays alive for the lifetime of the script. With `on idle` returning a
--   non-zero delay, the runtime owns a Dock tile / Cmd+Tab entry /
--   Activity Monitor entry — all driven by the bundle's CFBundleName
--   (set to "JustVibes" by build.sh). The user sees JustVibes' piggy-bank
--   identity in the Dock; the spawned Ghostty terminal window keeps
--   Ghostty's identity (structural per launcher_improvement_plan.md §2 —
--   we don't try to rebrand Ghostty's own window).
--
-- Hard rules absorbed from launcher_improvement_plan.md rev-6 (§1.5.4.3 +
-- §1.5.6) — DO NOT VIOLATE:
--
--   1. NEVER use `tell application "Ghostty" to ...`.
--   2. NEVER use `tell application id "com.mitchellh.ghostty" ...`.
--   3. NEVER use `exists application "Ghostty"`.
--      All three compile to LaunchServices bundle-resolution calls that
--      LAUNCH Ghostty as a side effect — the original "ghost ghostty
--      process" bug. Use `do shell script` calling out to filesystem
--      checks (test -d) instead. The launch-helper.sh already does this;
--      this AppleScript must not re-introduce the trap.
--
--   4. `running of application "Ghostty"` IS safe — it queries process
--      state without bundle resolution. Verified §1.5.4.3 Tests 4+7. The
--      helper script uses it for cold/hot detection; this AppleScript
--      could too if it ever needed to, but currently does not.
--
--   5. `tell application "System Events"` IS safe (Branch F.1 / §8.7).
--      System Events is an Apple-shipped automation broker that is
--      already running and is NOT subject to the LaunchServices
--      bundle-resolution trap of constraint #1. We use it in
--      `focusGhostty` to bring a tracked Ghostty window forward via its
--      unix PID (no bundle resolution required).
--
--   6. NEVER spawn Ghostty's Mach-O directly. `/usr/bin/open` only.
--      Spawning the binary directly triggers TCC Automation prompts on
--      first launch (§1.5.4.2 H11). `open` is a shell binary, not an
--      AppleEvent target — no prompt.
--
--   7. NEVER edit ~/.config/ghostty/config. Hard rule.
--
-- Stay-alive behavior (Option A from §8.3, ratified at Branch F ship):
--   We use `on idle ... return 600` so the runtime stays alive owning the
--   Dock tile until the user explicitly quits JustVibes (Cmd+Q from the
--   Dock context menu, or via the Cmd+Tab → Cmd+Q path). The user must
--   separately quit Ghostty when they're done with the terminal — this is
--   the documented Branch F trade-off ("two things to quit"). Option B
--   (watch the spawned Ghostty PID and exit when it dies) was deferred:
--   Ghostty's quit semantics are window-scoped, not process-scoped, and a
--   PID-watcher would need careful handling of the user closing only the
--   JustVibes window vs. quitting all of Ghostty.
--
-- Logic delegation:
--   The AppleScript is intentionally tiny. All decision logic (probe
--   Ghostty install, resolve opencode, cold/hot detection, conditional
--   -n flag, alert dialogs) lives in launch-helper.sh — a plain bash
--   script that the bats suite exercises with mocked open/osascript.
--   Keeping the logic in shell preserves test coverage and lets a curious
--   user read what the launcher does without learning AppleScript.

-- Resolve the bundle's path. `path to me` returns the .app; we drop the
-- `posix path of` form into a string for shell-quoting.
on bundlePath()
    return POSIX path of (path to me)
end bundlePath

-- Path to the helper script inside the bundle. `osacompile -o` places
-- this AppleScript at Contents/Resources/Scripts/main.scpt; build.sh
-- additionally drops launch-helper.sh at Contents/Resources/launch-helper.sh.
on helperPath()
    return (my bundlePath()) & "Contents/Resources/launch-helper.sh"
end helperPath

-- Run the helper. Errors from `do shell script` raise an AppleScript
-- exception which we catch and surface via `display alert` so the user
-- sees something actionable rather than a silent failure.
on runHelper()
    set helper to my helperPath()
    try
        -- 2>&1 so any helper diagnostics land in the AppleScript error
        -- text (which we display on failure). The helper is well-behaved
        -- on the happy path: it execs `/usr/bin/open` and exits 0
        -- without printing anything to stdout/stderr.
        do shell script (quoted form of helper) & " 2>&1"
    on error errMsg number errNum
        -- errNum 1 = generic shell-error (helper exited non-zero, e.g.
        -- Ghostty or opencode missing — the helper already showed its
        -- own alert in that case, but we still want to log).
        do shell script "/usr/bin/logger -t justvibes " & quoted form of ¬
            ("launch-helper failed (errNum=" & errNum & "): " & errMsg)
    end try
end runHelper

on run
    my runHelper()
    -- Fall through to `on idle` for stay-alive behavior. The default
    -- idle interval is 30s; we return a longer interval below.
end run

-- ── Branch F.1 (§8.7): Cmd-Tab focus handler ────────────────────────────
--
-- AppleScript fires `on reopen` when the user clicks the JustVibes Dock
-- tile (or Cmd-Tabs to its card) while the applet is already running.
-- Because the applet has no UI window, the default behavior is "nothing
-- visibly happens" — confusing UX. Instead, bring the spawned Ghostty
-- window forward via its tracked unix PID, or fall through to a fresh
-- launch if no PID is tracked / the tracked process is dead.
--
-- `on reopen` does NOT fire on the first launch — `on run` handles that.
-- The two handlers cleanly partition cold-state and warm-state launches.
on reopen
    my refocusOrRelaunch()
end reopen

-- Read the spawned Ghostty's PID from the tempfile written by
-- launch-helper.sh after `open -Fa`. Returns the integer PID on success,
-- 0 on any failure (missing file, unreadable, non-numeric content). 0
-- signals the caller to fall through to `runHelper()`.
on readGhostyPid()
    try
        set pidText to do shell script "cat \"${TMPDIR:-/tmp}/justvibes/ghostty.pid\""
        return (pidText as integer)
    on error
        return 0
    end try
end readGhostyPid

-- Bring the process with the given unix PID to the foreground via
-- System Events. System Events queries process state directly (no
-- LaunchServices bundle resolution), so this is safe per §8.7.2 — the
-- analog of `running of application` verified in §1.5.4.3 Tests 4+7.
--
-- Returns true on success, false if the process no longer exists or
-- System Events refused (e.g. Accessibility permission denied). The
-- caller treats false as "PID is stale; relaunch".
on focusGhostty(pid)
    try
        tell application "System Events"
            set frontmost of (first process whose unix id is pid) to true
        end tell
        return true
    on error
        return false
    end try
end focusGhostty

-- Reopen orchestrator: try to focus the tracked Ghostty window; if
-- there's no tracked PID OR the tracked PID is stale, fall through to
-- a cold-state launch (and clear the stale pidfile so we don't loop).
on refocusOrRelaunch()
    set pid to my readGhostyPid()
    if pid is 0 then
        -- No tracked PID. Cold-state semantics.
        my runHelper()
        return
    end if
    if my focusGhostty(pid) then
        return
    end if
    -- PID was stale. Clear the file and relaunch.
    do shell script "rm -f \"${TMPDIR:-/tmp}/justvibes/ghostty.pid\""
    my runHelper()
end refocusOrRelaunch

-- Periodic idle handler. Returning N tells the AppleScript runtime to
-- call us again after N seconds, keeping the process alive (and the
-- Dock tile visible) until the user quits JustVibes. We do nothing
-- here — just stay alive.
on idle
    return 600
end idle

-- Clean exit when the user quits via Dock / Cmd+Q. Without an explicit
-- `on quit ... continue quit` handler, `osascript` apps sometimes need
-- this scaffold to terminate cleanly under macOS 14+.
on quit
    set pid to my readGhostyPid()
    if pid is not 0 then
        try
            do shell script "kill " & pid
        end try
        try
            do shell script "rm -f \"${TMPDIR:-/tmp}/justvibes/ghostty.pid\""
        end try
    end if
    continue quit
end quit
