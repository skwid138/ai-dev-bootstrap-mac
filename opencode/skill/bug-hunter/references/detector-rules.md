# Detector Rules

Heuristics for each detector category. These define what counts as evidence
and what doesn't.

---

## NullDerefBoundary

**What to look for:**
1. RTK Query `transformResponse` functions — check which fields are guarded
   with `|| []`, `?? {}`, etc. Fields that are NOT guarded are candidates.
2. Consumer components/hooks that access response fields with property access
   (`obj.field`), indexing (`obj[key]`), or method calls (`arr.map()`).
3. The gap: field is accessed without guard AND transform doesn't normalize it.

**Strong evidence (High confidence):**
- Transform explicitly guards field A but not field B in the same response
  → B is likely an oversight
- Consumer does `response.field.subfield` with no optional chaining and
  `field` comes directly from API
- Multiple consumers access the same unguarded field

**Weak evidence (move to Notes):**
- Field is typed as required and there's no evidence the API ever returns null
- Field is only accessed after a truthiness check elsewhere in the same
  component (might be guarded by render logic)

**False positive signals (skip):**
- Field is a primitive that TypeScript would catch at compile time
- Field is accessed inside a conditional that already checks for its existence
- The entire component is wrapped in an error boundary with fallback UI

---

## TypeRealityMismatch

**What to look for:**
1. TypeScript interfaces for API responses where all fields are required
   (no `?` or `| null` or `| undefined`)
2. Evidence that the API can return different shapes:
   - Other fields in the same response ARE typed as optional
   - `transformResponse` adds defaults for some fields (implies awareness)
   - Comments mentioning "API might return..." or "handle missing..."
   - The field is a nested object or array (more likely to be null than
     primitives)

**Strong evidence:**
- Same API response type has a mix of optional and required fields, and the
  required fields include objects/arrays that are accessed without guards
- Backend serializer has `allow_null=True` or `required=False` for a field
  that the frontend types as required

**Weak evidence:**
- All fields are required and there's no evidence of API looseness
- The type is generated from an OpenAPI spec (likely accurate)

---

## GuardGap

**What to look for:**
1. A value that is guarded in one code path but not another
2. Same variable/field accessed with `?.` in one place and `.` in another
3. A function that handles null input but its caller doesn't check the output
4. `if (x)` guard in one branch but direct access in a sibling branch

**Strong evidence:**
- Same field, same component, guarded on line 50 but unguarded on line 80
- `cacheHelpers.ts` has `if (asset.tags)` but `AssetsTable.tsx` does
  `asset.tags.map()` without check
- Transform guards `results` but not `averageAssetScores` in the same
  `transformResponse`

**Weak evidence:**
- Guard is in a different feature/module (might be different data source)
- The unguarded path is only reachable after the guarded path succeeds

---

## ImplicitAssumption

**What to look for:**
1. `arr[0]` or `arr[N]` without length check
2. `Object.keys(obj)[0]` without emptiness check
3. `str.split(delim)[1]` assuming the delimiter exists
4. `.find()` result used without undefined check
5. Destructuring with no defaults: `const { a, b } = obj` where obj might
   not have those keys

**Strong evidence:**
- The array/object comes from an API response or user input (external data)
- No upstream check guarantees non-emptiness
- The access is in a render path (will cause visible error)

**Weak evidence:**
- The array is constructed locally and always has items
- There's a loading/empty state check before the access

---

## UnhandledAsync

**What to look for:**
1. `useEffect` with async operations but no cleanup function
2. `.then()` without `.catch()` on non-RTK-Query promises
3. `await` without try/catch in non-RTK-Query async functions
4. State updates in `.then()` callbacks without unmount protection

**Strong evidence:**
- Component fetches data in useEffect, sets state in callback, no cleanup
- Fire-and-forget promise with no error handling
- Multiple concurrent requests possible with no cancellation

**Weak evidence:**
- RTK Query handles most async edge cases automatically
- The async operation is in a mutation (user-initiated, less likely to race)

---

## General rules

### What counts as a "guard"
- Optional chaining: `obj?.field`
- Nullish coalescing: `obj ?? default`
- Truthiness check: `if (obj) { obj.field }`
- Type narrowing: `if ('field' in obj) { obj.field }`
- Default parameter: `function fn(obj = {}) {}`
- Logical OR: `obj || default` (for non-boolean values)
- Early return: `if (!obj) return`

### What does NOT count as a guard
- TypeScript type assertion: `obj as NonNullType` (compile-time only)
- Non-null assertion: `obj!.field` (compile-time only)
- Being inside a try/catch (catches the error but still crashes the render)
- Being typed as required (types can lie about runtime data)

### Proof chain requirements by severity
- **P0:** All 4 links required (boundary, transform gap, consumer, crash site)
- **P1:** 3 links minimum (can infer one step if others are strong)
- **P2:** 2 links minimum (unguarded access + plausible scenario)
