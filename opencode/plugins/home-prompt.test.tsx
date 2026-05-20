import { describe, expect, it, vi } from "vitest";

vi.mock(
  "@opentui/solid/jsx-runtime",
  () => {
    const render = (type: unknown, props: Record<string, unknown>) => {
      if (typeof type === "function") {
        return (type as (props: Record<string, unknown>) => unknown)(props);
      }

      return { type, props };
    };

    return {
      Fragment: (props: { children: unknown }) => props.children,
      jsx: render,
      jsxs: render,
    };
  },
  // @ts-expect-error Vitest supports virtual mocks at runtime, but v3 types do not expose this option.
  { virtual: true },
);

import plugin from "./home-prompt";

(globalThis as typeof globalThis & { React: unknown }).React = {
  createElement(
    type: unknown,
    props: Record<string, unknown> | null,
    ...children: unknown[]
  ) {
    const elementProps = { ...(props ?? {}) };
    if (children.length === 1) {
      elementProps.children = children[0];
    } else if (children.length > 1) {
      elementProps.children = children;
    }

    if (typeof type === "function") {
      return (type as (props: Record<string, unknown>) => unknown)(elementProps);
    }

    return { type, props: elementProps };
  },
};

describe("home prompt plugin", () => {
  it("exports the bootstrap home prompt plugin id and TUI hook", () => {
    expect(plugin.id).toBe("bootstrap.home-prompt");
    expect(plugin.tui).toEqual(expect.any(Function));
  });

  it("registers non-technical-friendly home prompt placeholders", async () => {
    const api = {
      slots: {
        register: vi.fn(),
      },
      ui: {
        Prompt: vi.fn((props: Record<string, unknown>) => ({
          component: "Prompt",
          props,
        })),
        Slot: vi.fn((props: Record<string, unknown>) => ({
          component: "Slot",
          props,
        })),
      },
    };

    await plugin.tui(api);

    expect(api.slots.register).toHaveBeenCalledTimes(1);
    const registration = api.slots.register.mock.calls[0]?.[0];
    expect(registration.slots.home_prompt).toEqual(expect.any(Function));

    const mockRef = { current: null };
    const result = registration.slots.home_prompt(
      { session: "unused" },
      { ref: mockRef, workspace_id: "test-ws" },
    );

    expect(result).toBeTruthy();
    expect(api.ui.Slot).toHaveBeenCalledWith({
      name: "home_prompt_right",
      workspace_id: "test-ws",
    });
    expect(api.ui.Prompt).toHaveBeenCalledWith(
      expect.objectContaining({
        ref: mockRef,
        workspaceID: "test-ws",
        right: {
          component: "Slot",
          props: {
            name: "home_prompt_right",
            workspace_id: "test-ws",
          },
        },
      }),
    );

    const promptProps = api.ui.Prompt.mock.calls[0]?.[0] as {
      placeholders: { normal: string[]; shell: string[] };
    };
    expect(promptProps.placeholders.normal).toEqual(
      expect.arrayContaining([
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
      ]),
    );
    expect(promptProps.placeholders.shell).toEqual(
      expect.arrayContaining([
        "Show me my files",
        "What's using disk space?",
        "Check for software updates",
      ]),
    );
  });
});
