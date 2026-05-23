/** @jsxImportSource @opentui/solid */
/**
 * Create ASCII Font: https://patorjk.com/software/taag/#p=display&f=Big+Mono+9&t=Vibes&x=none&v=4&h=4&w=80&we=false
 *
 * Big Mono 9 Font
 */

const tui = async (api: any) => {
  api.slots.register({
    slots: {
      home_logo(_ctx: any, _value: any) {
        return (
          <box flexDirection="column">
            <box flexDirection="row">
              <text fg="#5DBDB3">{"                             "}</text>
              <text fg="#F8B4C4">{"█    █                            "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"  ███                  █     "}</text>
              <text fg="#F8B4C4">{"█░  ░█        █                   "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █                  █     "}</text>
              <text fg="#F8B4C4">{"▓▒  ▒▓        █                   "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █  █   █  ▒███▒  █████   "}</text>
              <text fg="#F8B4C4">{"▒█  █▒ ███    █▓██    ███   ▒███▒ "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █  █   █  █▒ ░█    █     "}</text>
              <text fg="#F8B4C4">{" █  █    █    █▓ ▓█  ▓▓ ▒█  █▒ ░█ "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █  █   █  █▒░      █     "}</text>
              <text fg="#F8B4C4">{" █░░█    █    █   █  █   █  █▒░   "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █  █   █  ░███▒    █     "}</text>
              <text fg="#F8B4C4">{" ▓▒▒▓    █    █   █  █████  ░███▒ "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"    █  █   █     ▒█    █     "}</text>
              <text fg="#F8B4C4">{" ▒██▒    █    █   █  █         ▒█ "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"█░ ▒█  █▒ ▓█  █░ ▒█    █░    "}</text>
              <text fg="#F8B4C4">{"  ██     █    █▓ ▓█  ▓▓  █  █░ ▒█ "}</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">{"▒███░  ▒██▒█  ▒███▒    ▒██   "}</text>
              <text fg="#F8B4C4">{"  ██   █████  █▓██    ███▒  ▒███▒ "}</text>
            </box>
          </box>
        )
      },
    },
  })
}

export default {
  id: "bootstrap.justvibes-logo",
  tui,
}
