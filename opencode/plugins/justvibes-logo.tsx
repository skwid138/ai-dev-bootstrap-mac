/** @jsxImportSource @opentui/solid */

const tui = async (api: any) => {
  api.slots.register({
    slots: {
      home_logo(_ctx: any, _value: any) {
        return (
          <box flexDirection="column">
            <box flexDirection="row">
              <text fg="#5DBDB3">███ █ █ ███ ███</text>
              <text fg="#F8B4C4">█ █ ███ ██  ███ ███</text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3">  █ █ █ ██   █ </text>
              <text fg="#F8B4C4">█ █  █  ███ ██  ██ </text>
            </box>
            <box flexDirection="row">
              <text fg="#5DBDB3"> ██ ███ ███  █ </text>
              <text fg="#F8B4C4"> █  ███ ██  ███ ███</text>
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
