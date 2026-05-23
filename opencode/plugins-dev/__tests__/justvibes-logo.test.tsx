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

vi.mock(
  "@opentui/solid/jsx-dev-runtime",
  () => {
    const render = (type: unknown, props: Record<string, unknown>) => {
      if (typeof type === "function") {
        return (type as (props: Record<string, unknown>) => unknown)(props);
      }

      return { type, props };
    };

    return {
      Fragment: (props: { children: unknown }) => props.children,
      jsxDEV: render,
    };
  },
  // @ts-expect-error Vitest supports virtual mocks at runtime, but v3 types do not expose this option.
  { virtual: true },
);

import plugin from "../../plugins/justvibes-logo";

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

type TestElement = {
  type: string;
  props: Record<string, unknown>;
};

describe("justvibes logo plugin", () => {
  it("exports the bootstrap JustVibes logo plugin id and TUI hook", () => {
    expect(plugin.id).toBe("bootstrap.justvibes-logo");
    expect(plugin.tui).toEqual(expect.any(Function));
  });

  it("registers a JustVibes home logo with split brand colors", async () => {
    const api = {
      slots: {
        register: vi.fn(),
      },
    };

    await plugin.tui(api);

    expect(api.slots.register).toHaveBeenCalledTimes(1);
    const registration = api.slots.register.mock.calls[0]?.[0];
    expect(registration.slots.home_logo).toEqual(expect.any(Function));

    const result = registration.slots.home_logo(
      { session: "unused" },
      { value: "unused" },
    ) as TestElement;

    expect(result.type).toBe("box");
    expect(result.props.flexDirection).toBe("column");

    const rows = result.props.children as TestElement[];
    expect(rows.length).toBeGreaterThan(0);

    rows.forEach((row) => {
      expect(row.type).toBe("box");
      expect(row.props.flexDirection).toBe("row");

      const segments = row.props.children as TestElement[];
      expect(segments).toHaveLength(2);
      expect(segments[0]?.type).toBe("text");
      expect(segments[0]?.props.fg).toBe("#5DBDB3");
      expect(segments[1]?.type).toBe("text");
      expect(segments[1]?.props.fg).toBe("#F8B4C4");
    });
  });
});
