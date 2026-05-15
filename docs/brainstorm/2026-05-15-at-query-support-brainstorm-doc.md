---
date: 2026-05-15
topic: at-query-support
---

# `@Query` support

## What We're Building

A new `@Query` builtin that calls a tool from the registered library and stores
its result in a store variable, so the LLM can fetch data once per assistant
message and bind it into the UI declaratively. `@Query` is declared at the top
level alongside `$state` and `root`. It does not fire while the message is still
streaming. Once the stream completes (the host signals `isStreaming == false`
and the parser reports no incomplete statements), each `@Query` runs its tool
exactly once and writes the result to the named store variable. After that,
ordinary store re-render mechanics apply — the UI updates automatically.

This replaces the existing `Query(name: ..., args: ...)` builtin-call form and
its `QueryDecl` plumbing. The new system also collapses two storage layers into
one: today the renderer keeps query results in `QueryManager._entries` *and*
state in `Store`; with `@Query`, results land directly in `Store` and the
manager becomes a thin dedup/lifecycle gate. The existing `Mutation(...)`
declaration form is **out of scope** for this change — it's an orthogonal
concern and the user's request was specifically about queries.

## Why This Approach

Considered three syntaxes:

**Approach A (recommended) — assignment to a store variable**

```openui
$products = @Query(fetch_products)
$shoes    = @Query(fetch_products, category: "shoes")
root = Stack([
  @Each($products, "p", Card(title: p.title, subtitle: p.brand))
])
```

- Pros: reuses the store as the single source of truth; reads in expressions
  use the existing `$var` machinery; fits the existing grammar
  (`identifier = expression`) with no new statement form. Re-firing via
  `@Run($products)` works for free — the dispatcher already routes
  `@Run(identifier)` through the renderer's query-lookup path.
- Cons: visually overloads the `$x = ...` shape — `$x = 0` is a state
  default while `$x = @Query(...)` is an async fetch with implicit `null`
  initial value. Mitigated by classifying the statement as `query` (not
  `state`) so the parser, evaluator, and `@Reset` semantics treat the two
  paths distinctly, and by surfacing `null` as the canonical
  loading-state idiom (`$products == null ? Spinner() : ...`).
- Best when: we want minimal new surface area and consistent `$var` reads
  at the use sites.

**Approach B — target-as-argument, action-step shape**

```openui
@Query($products, fetch_products, category: "shoes")
```

- Pros: visually matches `@Set($var, value)` and `@Run(name, args)`.
- Cons: introduces a new top-level statement form (a bare builtin call with
  no LHS), which the current grammar disallows (`statement ::= identifier "="
  expression`). Adds a parser branch and breaks the "every statement names a
  value" invariant. Re-firing requires a separate handle since the query
  isn't named by a statement id.
- Best when: we want visual symmetry with action steps. Not worth the
  grammar break.

**Approach C — non-state identifier, current shape with `@` prefix**

```openui
products = @Query(fetch_products)
```

- Pros: closest to the existing `users = Query(...)` shape.
- Cons: introduces a second flavor of "named binding" (not a `$state`, not
  a comp ref), which the evaluator already does for queries and which the
  recent commits have been simplifying away. Locks us out of `@Run($products)`
  consistency and complicates the loading idiom (no obvious null sentinel).
- Best when: we want a clean separation between "fetched" and "state."
  Doesn't pay for itself given existing store machinery.

**Picked Approach A** — smallest grammar delta, reuses stores end-to-end,
re-fire via `@Run` falls out for free.

## Key Decisions

- **Syntax: `$var = @Query(toolName, namedArg: value, ...)`.**
  *Rationale:* fits the existing `statement ::= identifier "=" expression`
  grammar with `@Query` slotting in as another `BuiltinCall`. Tool name is the
  first positional argument (a bare `Reference`); all other args are named,
  exactly like `@Run`.

- **Statement classification is `query`, not `state`.**
  *Rationale:* `$x = @Query(...)` produces a `QueryDecl` entry, not a
  `StateDecl`. There is no declared default — the store slot is initialized to
  `null` on the first parse of the statement. This means `@Reset($products)`
  has no declared default to write back; treat `@Reset` on a query-backed var
  as "write `null` and do *not* re-fire" (refetch is `@Run($var)`).

- **Fires when the host's stream signal flips to "done" and the parse is
  well-formed.** *Rationale:* concretely, the renderer adds a side-effect to
  its existing build path: after each parse, if `rendererScope.isStreaming ==
  false && parseResult.meta.incomplete.isEmpty`, walk `meta.queries` and for
  each unfired `(statementId, evaluated-args-fingerprint)` tuple call
  `QueryManager.ensureFired`. The check runs on every rebuild, so it triggers
  both when `isStreaming` transitions to false and when a non-streaming input
  arrives already-complete. No new "message done" host hook is required.

- **Args evaluate against the live store at fire time.**
  *Rationale:* matches `@Set` / `@Run` semantics already in
  `dispatchAction`. The cache fingerprint is the map of *evaluated* arg
  values, so an `@Run($var)` after a state change with the same evaluated
  args is a no-op (intentional — re-fire uses `invalidate` to force).

- **`Store` is the single result cache; `QueryManager._entries` goes away.**
  *Rationale:* removes the parallel-storage hazard noted in
  `query_manager.dart`'s `snapshotValues` / `entryFor`. After this change,
  `QueryManager` only tracks "has this `(statementId, args)` been fired in
  this renderer lifetime?" — the value lives in `Store` exclusively. The
  evaluator no longer needs `EvalContext.queryResults`; it reads `$var`
  through the store like any other state ref.

- **Initial value is `null`; success writes the tool result via
  `store.set('$var', result)`.** *Rationale:* lets the LLM author the
  obvious loading idiom (`$products == null ? Spinner() : Table(rows:
  $products)`). Verified that `@Each(null, "x", ...)` returns `[]`
  (`packages/openui_core/lib/src/eval/builtins.dart:115`), so the
  null-during-loading pattern is safe inside iteration too.

- **Errors fire `Renderer.onError` with an `OpenUIError` and leave `$var`
  at its prior value.** *Rationale:* a single host-visible surface for
  failures matches the existing render/adapter error path. No error envelope
  on the variable in v1.

- **Re-fire via `@Run($var)`.**
  *Rationale:* the dispatcher already routes `@Run(identifier)` through the
  renderer's `_onRun`, which looks up the statement id in `meta.queries`. The
  only change is that `QueryManager.invalidate` now writes back to the store
  on completion instead of into `_entries`.

- **Args may reference store variables; re-firing is manual, not reactive.**
  *Rationale:* allowing `category: $category` is cheap (args evaluate at
  fire time). We do *not* auto-refetch when those refs change — that's a
  reactive-query feature with real lifecycle complexity (debouncing,
  in-flight cancellation, arg-diffing). Keep v1 imperative: the LLM emits
  `@Run($products)` in the same action plan that mutated `$category`.

- **System prompt updates.**
  *Rationale:* `prompt.dart`'s `_kGrammarPrimer` is the LLM contract. Add a
  `@Query` bullet, remove the `Query(...)` / `Mutation(...)` builtin-call
  references (there are none today in the primer — but the rules / examples
  may need a `@Query` example). Add one canonical example near the existing
  `@Run` / `@Set` examples: `$products = @Query(fetch_products)` plus an
  `@Each($products, "p", ...)` reading site.

## Implementation Sketch (for the planning phase)

1. **Parser.** Recognize `BuiltinCall` named `@Query` as the RHS of a
   `$state = ...` statement. Classify the statement as `query`. Replace
   `QueryDecl`'s current `name`/`args` shape with `toolName` + ordered
   named-arg ASTs. Reject `@Query` outside the assignment position with a
   `ParseError`. Remove the `Query(...)` builtin-call recognition path.
2. **`QueryManager`.** Slim `_invoke` to read `toolName` and named-arg ASTs
   from the new `QueryDecl`, evaluate args against the live store, call the
   tool, and write back via `store.set('$var', value)`. Replace `_entries`
   with a `Set<String> _fired` (or `Map<String, ArgsFingerprint>` to support
   arg-change re-fires). Drop `snapshotValues`, `entryFor`,
   `EvalContext.queryResults` — the store is the only result surface.
3. **Renderer.** After every parse, if `!isStreaming && meta.incomplete.isEmpty`,
   walk `meta.queries` and call `QueryManager.ensureFired` for each unfired
   `(statementId, evaluated-args)` tuple. `_onRun` keeps routing `@Run` on a
   query id to `QueryManager.invalidate`. Tool errors now flow through
   `Renderer.onError` instead of into a cached `QueryEntry.error`.
4. **Prompt.** Update `_kGrammarPrimer` in `prompt.dart` with a `@Query`
   bullet and one canonical example. Add a rule spelling out the
   `$x = @Query(toolName, ...)` shape and the loading-via-null idiom.
5. **Lang reference.** `docs/lang-reference.md`: replace the `query` row in
   the statement-classification table to key off `@Query`; remove the
   `Query` example in favor of `$users = @Query(list_users)`.
6. **Tests.** Port `query_manager_test.dart` and `renderer_test.dart` query
   sections to the new shape. Add: (a) `@Query` does *not* fire while
   `isStreaming == true`; (b) re-fire via `@Run($var)` re-evaluates args
   from the current store; (c) tool error surfaces via `Renderer.onError`
   and leaves `$var` at its prior value.
7. **Example app.** Update prompt seeds in `chat/` to use `@Query`. Verify
   the FetchProducts demo renders a table after streaming completes.

Mutation parser/dispatcher/`fireMutation` paths are untouched.

## Open Questions

- **Cache lifetime across messages.** A new assistant message creates a
  fresh parse. If it re-declares `$products = @Query(...)` with the same
  args, do we keep the previous value (smooth re-render) or reset to `null`
  (LLM-observable state cleanup)? Default proposal for planning: keep if
  `(statementId, evaluated-args)` matches the previous parse's tuple; drop
  otherwise.
- **Concurrent `@Query` declarations.** Today `QueryManager._fire`
  effectively fires in parallel via unawaited futures. Confirm we keep that
  and don't accidentally serialize through the dispatcher.
