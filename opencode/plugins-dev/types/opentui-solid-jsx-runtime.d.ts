type JsxRender = (type: unknown, props: Record<string, unknown>) => unknown;

export const Fragment: (props: { children: unknown }) => unknown;
export const jsx: JsxRender;
export const jsxs: JsxRender;
export const jsxDEV: JsxRender;

export namespace JSX {
  interface IntrinsicElements {
    [elementName: string]: Record<string, unknown>;
  }
}
