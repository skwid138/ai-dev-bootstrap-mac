# Interface Design

Use this when the user wants to explore alternative interfaces for a chosen deepening candidate. The point is to compare different ways the module could be simpler to use from the outside.

## Long-running command discipline

Spawning three or more parallel subagents is expensive. Before doing it:

1. Explain what each subagent will produce.
2. Show the shared brief and each design constraint.
3. Estimate cost: subagent count, wall time, and token use.
4. Ask the user to confirm.

## Process

### 1. Frame the problem

Before designing, state:

- Constraints the new interface must satisfy.
- Dependency category from [DEEPENING.md](DEEPENING.md).
- Current call path (how the code is reached).
- Main failure modes (what could go wrong).
- A rough code sketch to ground the discussion. This is not the proposal yet.

### 2. Propose the parallel exploration

Suggest 3 or 4 different interface-design briefs. Example constraints:

1. **Smallest interface** — 1–3 entry points, maximum leverage.
2. **Flexible interface** — supports many caller shapes.
3. **Common-case interface** — makes the most frequent caller trivial.
4. **Adapter-focused interface** — useful when a real seam must support production and test adapters.

Wait for confirmation before dispatching.

### 3. Dispatch or self-generate designs

If the user confirms parallel exploration, send the briefs together so they can run concurrently. If the project is small, you may self-generate the alternatives instead.

Each design should include:

1. Interface: methods, types, invariants, ordering, and error behavior.
2. Usage example.
3. What implementation details are hidden behind the seam.
4. Dependency strategy and adapters.
5. Tradeoffs: where leverage is high, where it is thin.

### 4. Present and compare

Present designs one at a time, then compare them by:

- **Depth** — how much behavior sits behind the interface.
- **Locality** — where future changes and bugs concentrate.
- **Seam placement** — whether the connection point is in the right place.
- **Failure modes** — what each design handles or exposes.

Give a recommendation. The user wants a strong read, not a menu with no opinion.

The chosen design feeds the deepening package in the main skill. Do not implement it here.
