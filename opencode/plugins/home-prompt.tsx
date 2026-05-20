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
                "Help me organize my photos",
                "What can you help me with?",
                "Make a website for my business",
                "I have an idea for an app",
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
