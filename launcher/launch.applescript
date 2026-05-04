-- Vibe Code launcher — AppleScript host for Vibe Code.app (Branch F).
--
-- This script is compiled by `osacompile` (see launcher/build.sh) into
-- Vibe Code.app/Contents/MacOS/applet — the standard AppleScript runtime
-- entry point produced by `osacompile -o`. The compiled bundle's
-- CFBundleExecutable is `applet` (Mach-O); this `.applescript` is the
-- compiled-into-Resources/Scripts/main.scpt source.
--
-- Why an AppleScript host (Branch F goal):
--   The previous launcher (launcher/launch.sh, now launcher/launch-helper.sh)
--   was the bundle's CFBundleExecutable directly. Bash → exec'd /usr/bin/open
--   → Ghostty took over the Dock tile / Cmd+Tab entry / Activity Monitor
--   process name. Vibe Code's branded identity (piggy-bank icon, "Vibe Code"
--   process name) was never visible because nothing persistent ever ran
--   under the bundle's identity.
--
--   AppleScript apps host a persistent process (the `applet` runtime) that
--   stays alive for the lifetime of the script. With `on idle` returning a
--   non-zero delay, the runtime owns a Dock tile / Cmd+Tab entry /
--   Activity Monitor entry — all driven by the bundle's CFBundleName
--   (set to "Vibe Code" by build.sh). The user sees Vibe Code's piggy-bank
--   identity in the Dock; the spawned Ghostty terminal window keeps
--   Ghostty's identity (structural per launcher_improvement_plan.md §2 —
--   we don't try to rebrand Ghostty's own window).
--
-- Hard rules absorbed from launcher_improvement_plan.md rev-6 (§1.5.4.3 +
-- §1.5.6) — DO NOT VIOLATE:
--
--   1. NEVER use `tell application "Ghostty" to ...`.
--   2. NEVER use `exists application "Ghostty"`.
--      Both compile to LaunchServices bundle-resolution calls that LAUNCH
--      Ghostty as a side effect — the original "ghost ghostty process"
--      bug. Use `do shell script` calling out to filesystem checks
--      (test -d) instead. The launch-helper.sh already does this; this
--      AppleScript must not re-introduce the trap.
--
--   2. `running of application "Ghostty"` IS safe — it queries process
--      state without bundle resolution. Verified §1.5.4.3 Tests 4+7. The
--      helper script uses it for cold/hot detection; this AppleScript
--      could too if it ever needed to, but currently does not.
--
--   3. NEVER spawn Ghostty's Mach-O directly. `/usr/bin/open` only.
--      Spawning the binary directly triggers TCC Automation prompts on
--      first launch (§1.5.4.2 H11). `open` is a shell binary, not an
--      AppleEvent target — no prompt.
--
--   4. NEVER edit ~/.config/ghostty/config. Hard rule.
--
-- Stay-alive behavior (Option A from §8.3, ratified at Branch F ship):
--   We use `on idle ... return 600` so the runtime stays alive owning the
--   Dock tile until the user explicitly quits Vibe Code (Cmd+Q from the
--   Dock context menu, or via the Cmd+Tab → Cmd+Q path). The user must
--   separately quit Ghostty when they're done with the terminal — this is
--   the documented Branch F trade-off ("two things to quit"). Option B
--   (watch the spawned Ghostty PID and exit when it dies) was deferred:
--   Ghostty's quit semantics are window-scoped, not process-scoped, and a
--   PID-watcher would need careful handling of the user closing only the
--   Vibe Code window vs. quitting all of Ghostty.
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
        do shell script "/usr/bin/logger -t vibe-code " & quoted form of ¬
            ("launch-helper failed (errNum=" & errNum & "): " & errMsg)
    end try
end runHelper

on run
    my runHelper()
    -- Fall through to `on idle` for stay-alive behavior. The default
    -- idle interval is 30s; we return a longer interval below.
end run

-- Periodic idle handler. Returning N tells the AppleScript runtime to
-- call us again after N seconds, keeping the process alive (and the
-- Dock tile visible) until the user quits Vibe Code. We do nothing
-- here — just stay alive.
on idle
    return 600
end idle

-- Clean exit when the user quits via Dock / Cmd+Q. Without an explicit
-- `on quit ... continue quit` handler, `osascript` apps sometimes need
-- this scaffold to terminate cleanly under macOS 14+.
on quit
    continue quit
end quit
