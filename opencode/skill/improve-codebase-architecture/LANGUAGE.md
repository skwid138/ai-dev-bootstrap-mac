# Language

Use this vocabulary consistently when discussing architecture. Plain-language explanations are included so non-technical users can follow the reasoning.

## Terms

**Module**  
Anything with an interface and an implementation: a function, class, package, or feature slice.

**Interface**  
Everything a caller must know to use the module correctly: inputs, outputs, invariants, ordering, error behavior, config, and performance expectations. It is broader than a type signature.

**Implementation**  
The code inside the module.

**Depth**  
Leverage at the interface. A deep module gives callers a lot of behavior through a small interface. A shallow module makes callers learn almost as much as the implementation knows.

**Deepening (making code simpler to use from the outside)**  
Putting more useful behavior behind a smaller interface.

**Seam (connection point where behavior can be swapped)**  
A place where behavior can be swapped, tested, or adapted without editing all callers.

**Adapter**  
A concrete thing plugged into a seam, such as an in-memory adapter for tests or an HTTP adapter for production.

**Leverage**  
What callers get from depth: more capability for less knowledge.

**Locality**  
What maintainers get from depth: changes, bugs, and knowledge concentrated in one place.

**Call path (how the code is reached)**  
The route from the user action or command down to the module being discussed.

**Failure mode (what could go wrong)**  
Crash, wrong result, lost data, slow path, confusing UI, or hard-to-debug behavior.

## Principles

- **Depth is a property of the interface, not the line count.** A deep module may have many internal parts; callers still see a small surface.
- **Deletion test.** Imagine deleting the module. If complexity disappears, it was probably pass-through. If complexity spreads across callers, it was valuable.
- **The interface is the test surface.** Good tests use the same surface real callers use.
- **One adapter means a hypothetical seam. Two adapters means a real seam.** Avoid indirection unless something actually varies.

## Relationships

- A module has an interface and implementation.
- A seam is where an interface lives.
- An adapter satisfies an interface at a seam.
- Depth produces leverage for callers and locality for maintainers.

## Phrases to avoid

- "Boundary" when you mean seam.
- "Signature" when you mean full interface.
- "Just add abstraction" without naming the adapter and failure mode it handles.
