/** @jsxImportSource @opentui/solid */

const tui = async (api: any) => {
  api.slots.register({
    slots: {
      home_prompt(_ctx: any, value: any) {
        const Prompt = api.ui.Prompt
        const Slot = api.ui.Slot
        return (
          <Prompt
            ref={value.ref}
            workspaceID={value.workspace_id}
            right={<Slot name="home_prompt_right" workspace_id={value.workspace_id} />}
            placeholders={{
              normal: [
                "Build me a recipe app",
                "Help me organize something",
                "Will you help me with something?",
                "Make a website for my business",
                "I have an idea for an app",
                "My computer is doing something weird, can you fix it?",
                "Can you automate something for me?",
                "Is there a better way to do this?",
                "Can you make me an app I can use on my phone?",
                "Can you help me get data from a website?",
                "Can you help me build a goal tracking app?",
              ],
              shell: [
                "Show me my files",
                "What's using disk space?",
                "Check for software updates",
              ],
            }}
          />
        )
      },
    },
  })
}

export default {
  id: "bootstrap.home-prompt",
  tui,
}
