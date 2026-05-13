# Deepening

Deepening means making code simpler to use from the outside while concentrating useful behavior behind a smaller interface.

## Dependency categories

When assessing a candidate, classify its dependencies. The category affects where the seam (connection point) should live and how tests should work.

### 1. In-process

Pure computation or in-memory state. Usually easiest to deepen: merge behavior behind one interface and test it directly.

### 2. Local-substitutable

Dependencies with local stand-ins, such as an in-memory filesystem or local test database. Deepen the module and test it with the local stand-in. Keep the seam internal unless callers truly need it.

### 3. Remote but owned

Your own service across a network. Define an interface at the seam. The deep module owns the logic; production uses a network adapter, tests use an in-memory adapter.

Recommendation shape:

> "Put the business rule in one deep module. Use a network adapter in production and an in-memory adapter in tests."

### 4. True external

A third-party service you do not control. The deep module takes an injected interface; tests provide a fake or mock adapter, production provides the real adapter.

## Seam discipline

- **One adapter means a hypothetical seam. Two adapters means a real seam.** Do not add indirection unless it handles real variation.
- **Internal seams vs external seams.** A deep module can have private seams for its own tests without exposing them to callers.
- **Name the failure mode.** If you add a seam, explain what could go wrong without it.

## Testing strategy: replace, do not layer

- Old tests on shallow helper modules often become waste once behavior is covered through the deep interface.
- Write tests at the deepened module's interface.
- Assert observable behavior, not private state.
- Tests should survive internal refactors. If a test must change when internals change, it is probably testing past the interface.
