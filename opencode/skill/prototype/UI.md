# UI Prototype

A UI prototype shows several clearly different interface variations on one page. The user can flip between them, pick one, or combine pieces, then throw the rest away.

If the question is about logic or state instead of appearance and interaction, use [LOGIC.md](LOGIC.md).

## When this is right

- "What should this page look like?"
- "Show me a few dashboard options."
- "Try a different layout for this screen."
- Any decision that is easier to judge by seeing and clicking.

## Two shapes

### Shape A — existing page, preferred

Use an existing route when possible. Keep its real header, sidebar, data fetching, and auth. Swap only the rendered design using a `?variant=` URL parameter.

This gives better feedback because the design sits next to real app context.

### Shape B — throwaway page, last resort

Create a new prototype route only when there is no natural existing page. Follow the project's routing conventions and include `prototype` in the route or filename.

## Process

### 1. State the question and number of variants

Default to **3 variants**. More than 5 usually becomes noise.

Write a one-line note near the prototype, for example:

> "Three settings page variants, switchable via `?variant=`, on the existing `/settings` route."

### 2. Generate meaningfully different variants

Variants should differ in structure: layout, information hierarchy, primary action, or interaction pattern. Color-only changes are not enough.

Each variant should:

- Use the page's real purpose and data.
- Match the project's styling system.
- Have a clear name such as `VariantA`, `VariantB`, `VariantC`.

### 3. Wire variants together

Use the URL search parameter to choose a variant:

```tsx
// Pseudo-code — adapt to the project's framework.
const variant = searchParams.get('variant') ?? 'A'
return (
  <>
    {variant === 'A' && <VariantA {...data} />}
    {variant === 'B' && <VariantB {...data} />}
    {variant === 'C' && <VariantC {...data} />}
    <PrototypeSwitcher variants={['A', 'B', 'C']} current={variant} />
  </>
)
```

For Shape A, keep existing data loading above this switch. For Shape B, mount the switch on the throwaway route.

### 4. Build the switcher

The switcher is a small fixed bar at the bottom center of the screen:

- Left arrow cycles backward.
- Label shows the current variant.
- Right arrow cycles forward.

Behavior:

- Update the URL so variants are shareable and reload-stable.
- Support left/right arrow keys, but do not intercept typing in inputs.
- Make it visually distinct from the design.
- Hide it from production builds if the project has an environment flag.

### 5. Hand it over

Surface the URL and variant keys. The useful feedback is often "take the header from B and the sidebar from C."

### 6. Capture the answer and clean up

When one direction wins, record which one and why. Then delete losing variants and the switcher, or promote the winning idea into real production code with normal tests.

## Anti-patterns

- Variants that differ only in color or copy.
- Sharing so much code that the variants cannot truly disagree.
- Wiring prototype controls to real destructive mutations.
- Promoting prototype code directly to production without normal testing and cleanup.
