# Canonical Example: The averageAssetScores Crash

This is a real bug found by AI analysis in the client-portal creative audit
feature. It demonstrates the exact pattern that bug-hunter is designed to catch.

---

## The bug

**Symptom:** App crashes when viewing the creative audit overview for certain
clients.

**Root cause:** The API sometimes returns `averageAssetScores: null` in the
paginated assets response, but the frontend code accesses it as a non-null
object.

---

## Why tests didn't catch it

1. **TypeScript types lie:** `PaginatedCreativeAuditAssetsResponse` defines
   `averageAssetScores: FeatureSetScoreRecord` — non-optional, non-nullable.
   TypeScript is satisfied.

2. **Test mocks are well-formed:** Every test mock (`mockAssetTag`,
   `mockCreativeAuditAsset`) returns complete objects with all fields populated.
   No test exercises the "API returns null for this field" path.

3. **Mutation testing can't help:** Stryker mutates *existing* code. There's
   no null guard to mutate — the bug is *missing* code. The component files
   generated zero mutants because the crash-risk code is property access in
   JSX that Stryker's mutators don't target.

---

## The proof chain

### 1. Boundary
**File:** `src/features/creativeAudit/services/api.ts:99-102`

```typescript
transformResponse: (response: PaginatedCreativeAuditAssetsResponse) => ({
  ...response,
  results: response.results || [],  // ✅ guarded
  // averageAssetScores: NOT guarded ❌
})
```

The transform guards `results` but NOT `averageAssetScores`. This is a
**GuardGap** — the developer was aware that API fields need normalization
(they guarded `results`) but missed `averageAssetScores`.

### 2. Transform gap
The `averageAssetScores` field passes through `transformResponse` unchanged.
If the API returns `null`, it stays `null`.

### 3. Consumer
**File:** `src/features/creativeAudit/components/Overview/components/AssetsTable.tsx:182`

```typescript
averageScores: paginatedAssets.averageAssetScores,
```

Passed to state, then to `TagRollupRow` component.

### 4. Crash site
**File:** `src/features/creativeAudit/components/Overview/components/TagRollupRow.tsx:66`

```typescript
const score = averageAssetScores[FeatureSetKeyMap[platform]]
```

When `averageAssetScores` is `null`, this throws:
`TypeError: Cannot read properties of null (reading 'youTube')`

**Second crash site:**
**File:** `src/features/creativeAudit/components/Overview/components/TagsTable.tsx:74`

```typescript
const score = tag.averageAssetScores[FeatureSetKeyMap[platform]]
```

Same pattern — direct property access on potentially-null object.

---

## The fix

**Best fix — normalize at the boundary:**

```typescript
transformResponse: (response: PaginatedCreativeAuditAssetsResponse) => ({
  ...response,
  results: response.results || [],
  averageAssetScores: response.averageAssetScores ?? {},
})
```

**Alternative — guard at consumers:**

```typescript
// TagRollupRow.tsx
const score = averageAssetScores?.[FeatureSetKeyMap[platform]]

// TagsTable.tsx
const score = tag.averageAssetScores?.[FeatureSetKeyMap[platform]]
```

The boundary fix is preferred because it protects ALL consumers, including
future ones.

---

## Bug hunt finding format

This is how bug-hunter would report this finding:

```
#### BH-GuardGap-001: averageAssetScores not normalized in transformResponse

**Severity:** P0 | **Confidence:** High | **Type:** GuardGap
**Location:** `src/features/creativeAudit/services/api.ts:99`

**Proof chain:**
1. **Boundary:** `getCreativeAuditAssetsPaginated` endpoint returns
   `PaginatedCreativeAuditAssetsResponse` — `services/api.ts:82`
2. **Transform:** `transformResponse` guards `results` but NOT
   `averageAssetScores` — `services/api.ts:99-102`
3. **Consumer:** `AssetsTable` passes `paginatedAssets.averageAssetScores`
   to state — `AssetsTable.tsx:182`
4. **Crash site:** `TagRollupRow` accesses
   `averageAssetScores[FeatureSetKeyMap[platform]]` — `TagRollupRow.tsx:66`

**Runtime scenario:** API returns `averageAssetScores: null` for a client
with no scored assets. The null passes through the transform unchanged and
reaches TagRollupRow, which crashes with TypeError.

**Fix suggestion:**
In `services/api.ts` transformResponse, add:
`averageAssetScores: response.averageAssetScores ?? {}`

**Test suggestion:** Mock the paginated assets API to return
`averageAssetScores: null` and assert the component renders without throwing.
```

---

## Key takeaways for detector design

1. **The GuardGap detector found this** — not NullDerefBoundary. The strongest
   signal was that `results` IS guarded but `averageAssetScores` is NOT, in
   the same transform function.

2. **TypeScript types were misleading.** The type says non-optional, but the
   runtime behavior differs. The detector should not trust types alone.

3. **The fix is at the boundary.** Normalizing in `transformResponse` protects
   all current and future consumers. This is always the preferred fix pattern.

4. **Multiple crash sites from one root cause.** The report should deduplicate
   by root cause (the missing normalization) and list all affected sites.
