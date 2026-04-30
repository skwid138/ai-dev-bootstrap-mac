# Fix Patterns

Common fix patterns organized by detector type. Always prefer the pattern that
matches existing codebase conventions.

---

## NullDerefBoundary — Normalize at the boundary

**Preferred: Add defaults in `transformResponse`**

This is almost always the best fix. Normalize once at the API boundary so every
consumer gets safe data.

```typescript
// BEFORE — only guards `results`
transformResponse: (response: PaginatedAssetsResponse) => ({
  ...response,
  results: response.results || [],
})

// AFTER — guards all fields that consumers access
transformResponse: (response: PaginatedAssetsResponse) => ({
  ...response,
  results: response.results || [],
  averageAssetScores: response.averageAssetScores ?? {},
})
```

**Fallback: Guard at the consumer**

When you can't modify the boundary (third-party API, shared slice), guard at
the consumer with optional chaining or nullish coalescing:

```typescript
// BEFORE
const score = tag.averageAssetScores[FeatureSetKeyMap[platform]]

// AFTER
const score = tag.averageAssetScores?.[FeatureSetKeyMap[platform]]
```

**Anti-pattern: Scattered null checks everywhere**

Don't add `if (x != null)` checks at every consumer. This is noisy, easy to
miss in new code, and doesn't fix the root cause.

---

## TypeRealityMismatch — Make types honest

**Preferred: Make the type reflect reality**

```typescript
// BEFORE — lies about the runtime shape
interface ApiResponse {
  averageAssetScores: FeatureSetScoreRecord
}

// AFTER — honest about what the API actually returns
interface ApiResponse {
  averageAssetScores: FeatureSetScoreRecord | null
}
```

Then let TypeScript enforce guards at every consumer.

**Alternative: Validate and normalize at ingestion**

Use a runtime validation layer (Zod, io-ts, or manual check) at the API
boundary to guarantee the type contract:

```typescript
transformResponse: (raw: unknown) => {
  const response = apiResponseSchema.parse(raw)
  return response // now guaranteed to match the type
}
```

---

## GuardGap — Extend existing guards

When some paths already guard a value but others don't, extend the pattern:

```typescript
// BEFORE — guard exists in one place
if (asset.tags) {
  asset.tags = asset.tags.filter(...)
} else {
  asset.tags = []
}

// BUT — another consumer doesn't guard
const nextTagIds = asset.tags.map((tag) => tag.id) // crashes if tags is undefined

// FIX — apply the same guard pattern
const nextTagIds = (asset.tags ?? []).map((tag) => tag.id)
```

---

## ImplicitAssumption — Add explicit checks

```typescript
// BEFORE — assumes array is non-empty
const first = items[0]

// AFTER — handle empty case
const first = items[0] // may be undefined
if (!first) return null

// OR — with fallback
const first = items.at(0) ?? defaultItem
```

---

## UnhandledAsync — Add error boundaries and cleanup

**React component cleanup:**
```typescript
// BEFORE — state update after unmount
useEffect(() => {
  fetchData().then(setData)
}, [])

// AFTER — with cleanup
useEffect(() => {
  let cancelled = false
  fetchData().then((data) => {
    if (!cancelled) setData(data)
  })
  return () => { cancelled = true }
}, [])
```

**Promise error handling:**
```typescript
// BEFORE
someAsyncFn()

// AFTER
someAsyncFn().catch((error) => {
  noticeError(error)
})
```
