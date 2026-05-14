---
title: "feat: reactive queries and mutations"
type: feat
date: 2026-05-12
---

## Reactive queries and mutations

## Overview

Bring the Flutter `openui_core` and `openui` runtime to feature parity with the JS `openui-lang` queries-and-mutations model. An LLM-generated `Query("list_tickets", {status: $status}, {rows: []}, 30)` will fetch through `ToolProvider`, expose `{rows: []}` as the default until the first success, re-fire when `$status` changes, and auto-refresh every 30 seconds. A `Mutation("create_ticket", {title: $title})` will surface a `{status, error, value}` shape in `EvalContext.queryResults` so templates can read `createResult.status == "error"`, and the action dispatcher will await it before advancing to the next `@Run`.

Brainstorm: `docs/brainstorm/2026-05-12-queries-mutations-brainstorm-doc.md`.

Shipped as three PRs on the `feat/queries-mutations` branch. Each PR leaves the runtime working.

## Problem Statement

`QueryManager` in `packages/openui/lib/src/query_manager.dart` already fires queries lazily through a `ToolProvider`, but the implementation is non-reactive. Arguments are extracted as raw literals by `_stringArg` and `_mapArg` (lines 178-206), so `$state` references in query args never resolve. The cache is keyed by `statementId` alone, so even if args were reactive there would be no way to track them. There is no default value, no auto-refresh, no stale-while-revalidate.

The action system rework in commit `736032d` already plumbed the `await` chain: `dispatchAction` awaits `onRun(step, args)` at `actions.dart:398`, and the renderer's `_onRun` at `renderer.dart:268-297` routes a `RunStep` to `manager.fireMutation` / `manager.invalidate` / a direct tool call. So the wiring half of the mutation lifecycle is already in place. What is still missing: a `MutationResult` lifecycle object surfaced through `EvalContext.queryResults`, a concurrency guard, and `fireMutation` that swallows errors instead of rethrowing (it currently rethrows at `query_manager.dart:123`, and the dispatcher halts the plan on `onRun` throw per its docstring at `actions.dart:347-351` and the test "RunStep callback throwing halts the rest of the plan but does not propagate" at `actions_test.dart:409-425`).

Today's named-arg surface (`Query(name: "list_users", args: {...})`) also diverges from the JS positional syntax (`Query("list_users", {})`) that the LLM prompt teaches.

## Proposed Solution

Three PRs that progressively extend the existing infrastructure.

### PR 1 — Reactive foundation

Replace the literal-only arg extraction in `QueryManager` with full evaluator-based argument resolution. Add a parser-side `StateRef` walker that populates `QueryDecl.deps` and `MutationDecl.deps`. Change the cache key from `statementId` to JS-style `toolName::stableHash(args)::stableHash(deps)`, and have the renderer's store subscription trigger re-evaluation whenever any tracked dep changes.

### PR 2 — Defaults and auto-refresh

Promote the third positional arg to the default value AST. Promote the fourth positional arg to a refresh interval in seconds, driving a `Timer.periodic` per statement. Add stale-while-revalidate: keep the last successful value visible during refetch and error. Skip auto-refresh ticks while a fetch is in flight.

### PR 3 — Mutation lifecycle

Add an internal sealed `MutationResult` hierarchy in `openui` so `QueryManager` can track mutation state in a type-safe way. Serialize it to a `{status, error, value}` `Map<String, Object?>` in `snapshotValues()` so the evaluator's existing `MemberAccess` path resolves `createResult.status` without changes to `openui_core`. Add concurrency guard. Refactor `fireMutation` to capture errors into `MutationResultError` and return normally so the dispatcher's halt-on-throw at `actions.dart:397-401` is unreachable for mutations and `Action([@Run(createResult), @Run(tickets)])` sequences correctly. The renderer's `_onRun` at `renderer.dart:268-297` already awaits `fireMutation` — only the manager-side lifecycle work is left.

### Architectural points carried from the brainstorm

- **Positional args canonical.** `Query(name, args, default, refreshInterval)` and `Mutation(name, args)`. Named-arg syntax is dropped. The `openui_core` API is `@experimental` per D12 and no consumer is on hand-written named-arg surfaces.
- **Cache key matches JS.** `toolName::stableHash(args)::stableHash(deps)`. The manager keeps a `Map<String, String> _stmtToKey` from statementId to current cache key. The map is the indirection between the statementId-keyed public API (`entryFor`, `invalidate`, `@Run`) and the content-addressed internal cache. It is justified because lookups by statementId happen per render.
- **Stale-while-revalidate.** Default value renders only before the first success. After that, last-good value persists through refetches and errors.
- **Skip-while-in-flight.** Auto-refresh ticks during an in-flight fetch are dropped, matching JS.
- **Mutation concurrency.** Second `@Run` while the first is in flight resolves the dispatcher's `await` as a no-op without firing again.
- **Mutation errors do not halt the plan.** The dispatcher halts the rest of an `ActionPlan` when `onRun` throws (`actions.dart:397-401`, asserted by `actions_test.dart:409-425`). PR 3 refactors `fireMutation` to capture the exception in `MutationResultError` and return normally so that halt path is unreachable for mutations. Matching JS, an errored `@Run(createTicket)` still allows a chained `@Run(refresh)` to fire.
- **Mutation-to-query refresh.** User-controlled via `Action([@Run(createResult), @Run(tickets)])`. The dispatcher already awaits each step at `actions.dart:398`. The renderer's `_onRun` at `renderer.dart:268-297` awaits `fireMutation` today; PR 3 makes the awaited future observably non-throwing so the chained `@Run` always runs.
- **`RunStep.argsAst`.** `@Run(target, foo: $bar)` carries invocation-time named args that the dispatcher evaluates into `Map<String, Object?>` and hands to `onRun`. Queries and mutations ignore those args and re-use their decl-time positional args (`q.args` / `m.args`) so reactivity stays driven by the decl. Direct-tool `@Run` targets (no matching query / mutation decl) consume the runArgs via `library.tool(id).callTool(args)` — already implemented at `renderer.dart:288-292`.
- **`MutationResult` is internal to `openui`.** Map-wrapped in `snapshotValues()`. No public `openui_core` export. Keeps the evaluator unchanged.

## Implementation Tasks

### PR 1 — Reactive foundation

#### `openui_core` — parser

- [ ] Add `final Set<String> deps` to `QueryDecl` at `packages/openui_core/lib/src/parser/streaming.dart:125` and to `MutationDecl` at `:142`. Constructor accepts `deps: const <String>{}` as the default so unrelated test fixtures still compile.
- [ ] Add a private `Set<String> _collectStateRefs(List<Argument> args)` helper inside `streaming.dart`. Walks the args AST recursively. Returns the set of `StateRef.name` values encountered anywhere in the tree.
- [ ] Update `StreamParser._compute` at `streaming.dart:215-231` so the populated `QueryDecl` / `MutationDecl` carry `deps: _collectStateRefs(args)`.
- [ ] Update the doc comment on `QueryDecl.args` at `streaming.dart:132-134` and `MutationDecl.args` at `:148-150`. Drop the "named arguments" note. Replace with a one-liner that the args are positional per the JS spec.
- [ ] Add an `@experimental` dartdoc note on the new `deps` field stating that it covers every `StateRef` reachable from the args AST.

#### `openui_core` — public API

- [ ] No new exports for PR 1. `QueryDecl` and `MutationDecl` already exported via the barrel.

#### `openui` — `QueryManager` refactor

- [ ] Replace `_stringArg` / `_mapArg` / `_literalValue` at `packages/openui/lib/src/query_manager.dart:178-206` with `({String toolName, Map<String, Object?> args}) _resolveCall(List<Argument> args, EvalContext ctx)`. The helper:
  - Extracts arg 0 (positional) as the tool name. Errors with `EvaluationError` if missing or non-string.
  - Evaluates arg 1 (positional) through `evaluate(node, ctx)`. Cast to `Map<String, Object?>`. Missing arg defaults to `const <String, Object?>{}`.
  - Returns a Dart record `(toolName, args)`. PR 2 will add more fields to the record.
- [ ] Change `ensureFired` and `invalidate` signatures at `query_manager.dart:86` and `:95` to accept `(QueryDecl decl, EvalContext ctx)` instead of `(String statementId, List<Argument> args)`. The decl carries `args` and `statementId`.
- [ ] Add a `Map<String, String> _stmtToKey` and a `_keyFor(String toolName, Map<String, Object?> args, Map<String, Object?> depValues)`. Stable hash: encode `{tool, args, deps}` via a private `_canonicalize` that walks the value, sorts map keys, and emits via `dart:convert` `JsonEncoder`. Accepts `String`, `num`, `bool`, `null`, `List`, `Map<String, Object?>`. Throws `ArgumentError` on any other value type to fail loudly rather than produce unstable hashes.
- [ ] Change `_entries` from `Map<String, QueryEntry>` keyed by statementId to `Map<String, QueryEntry>` keyed by cache key.
- [ ] On `ensureFired(decl, ctx)`:
  1. Build `depValues` by reading `ctx.store.get(name)` for each `name` in `decl.deps`.
  2. Build the cache key.
  3. If `_stmtToKey[decl.statementId]` is set to a different key, evict the previous key's entry.
  4. Record `_stmtToKey[decl.statementId] = key`.
  5. If `_entries[key]` exists, return. Otherwise call `_fire(key, statementId, toolName, args)`.
- [ ] `invalidate(decl, ctx)` clears `_entries` at the current key for the statement and calls `ensureFired(decl, ctx)` again. Matches `@Run` (bypass cache).
- [ ] Add `maybeRefire(decl, ctx)`. Builds the key with the latest deps. If it differs from `_stmtToKey[decl.statementId]`, fires the new key. Used by the renderer on store changes.
- [ ] Update `entryFor(String statementId)` at `:68` to read through `_stmtToKey`. Returns `const QueryEntry()` if the statement has no key yet.
- [ ] Update `snapshotValues()` at `:73-77` to iterate `_stmtToKey.entries`, mapping statementId to `_entries[key]?.value`.

#### `openui` — `Renderer` integration

- [ ] Update the query-firing loop in `_runPipeline()` at `renderer.dart:190-195`:
  - Build a query-eval context once per pipeline pass via `_buildEvalContext(result)`.
  - For each `query` in `result.meta.queries`, call `manager.ensureFired(query, ctx)` (new signature replaces the current `manager.ensureFired(query.statementId, query.args)`).
  - Mutations stay untouched in PR 1. They surface no `entryFor` until PR 3 lands.
- [ ] Update `_handleStoreChange()` at `renderer.dart:147-151` to also call `manager.maybeRefire(query, ctx)` for each query before `setState`. Build the context inline. This is the reactive trigger.
- [ ] Update `_onRun` at `renderer.dart:268-297` to migrate its two existing call sites to the new manager API: `manager.fireMutation(m, ctx)` and `manager.invalidate(q, ctx)`. The `RunStep`/`runArgs`-based routing and direct-tool fallback stay as is. The `_onRun` signature `(ParseResult? result, RunStep step, Map<String, Object?> args)` does not change.

#### Tests — PR 1

- [ ] Add to `packages/openui_core/test/src/parser/streaming_test.dart` under a new `group('QueryDecl.deps', ...)`:
  - `QueryDecl.deps` is empty for `Query("foo", {bar: 1})`.
  - `QueryDecl.deps` contains `status` for `Query("list", {status: $status})`.
  - `QueryDecl.deps` contains both `a` and `b` for `Query("x", {a: $a, b: $b})`.
  - Deep refs: `Query("x", {f: @Filter(items, p), s: $status})` includes `status`.
  - Nested in `ObjectLit`, `ArrayLit`, `BinaryOp`, `Ternary`, `MemberAccess`, `BuiltinCall`, `CompCall`. One test per case.
  - Repeated refs deduplicated.
  - `MutationDecl.deps` populates identically.
  - **Exhaustive AST coverage test.** Builds an instance of every concrete `AstNode` subtype declared in `parser/ast.dart`, embeds each as a query arg, asserts `_collectStateRefs` does not throw and returns a defined `Set<String>`. Uses Dart reflection-free enumeration: a hand-maintained list paired with a comment pointing back to `parser/ast.dart`. Future AST additions force this test to be updated.
- [ ] Update `packages/openui/test/src/query_manager_test.dart` under a new `group('reactive args and cache key', ...)`:
  - Existing tests that pass `(statementId, args)` migrate to passing `QueryDecl` and `EvalContext`.
  - Cache key reuses an existing entry when two queries call the same tool with the same args.
  - Cache key changes when a dep value changes. New entry fires. Old entry evicted.
  - `entryFor(statementId)` reads through `_stmtToKey`.
  - `snapshotValues()` reflects the current key per statement.
  - `_canonicalize` throws `ArgumentError` on a non-canonical value (e.g., a `DateTime`).
- [ ] Add a new `group('reactivity', ...)` to `packages/openui/test/src/renderer_test.dart` (folded in rather than a new file, matching the per-source-file convention):
  - Given `$status = "open"\ndata = Query("list", {status: $status}, {rows: []})\nbtn = Button("Toggle", Action([@Set($status, "closed")]))`, tapping the button fires a second `callTool` call with `{status: "closed"}`.
  - Two queries with identical tool+args share a single `callTool` invocation.

### PR 2 — Defaults and auto-refresh

#### `openui` — `QueryEntry` and `QueryManager`

- [ ] Extend `QueryEntry` at `query_manager.dart:18-35` with `final bool hasFirstSuccess` (default `false`). The existing `value` field carries the last successful value through subsequent loading and error states (stale-while-revalidate).
- [ ] Extend `_resolveCall` (now a record `(String, Map, AstNode?, int)` or a small private class — record is fine until field count grows) to extract:
  - Arg 2 (positional) as the default value AST. Evaluated against the context at fire time.
  - Arg 3 (positional) as an `int` refresh interval in seconds. Zero, negative, or non-int disables auto-refresh.
- [ ] On `_fire(...)`:
  - If `hasFirstSuccess == false`, set the entry's `value` to the evaluated default until the future resolves.
  - On success: set `value`, `hasFirstSuccess = true`, `error = null`.
  - On error: keep `value` if `hasFirstSuccess` else use default. Set `error`.
- [ ] Add `required EvalContext Function() contextProvider` as a constructor parameter on `QueryManager`. Not nullable, not mutable. Owned by the renderer at construction. Renderer creates the closure inside `_buildQueryManager()` capturing `this`. Existing test seam (`loader`) continues to bypass it.
- [ ] Add a `Map<String, Timer> _timers` keyed by statementId. On each `ensureFired`:
  - If the resolved `refreshSeconds > 0`, ensure a timer exists. If the interval changed, cancel and replace.
  - Timer callback: skip if the entry at the current key has `loading == true`. Otherwise call `invalidate(decl, contextProvider())`.
- [ ] Add `pruneStale(Set<String> activeStatementIds)`. Cancels timers and removes `_stmtToKey` entries for IDs not in the set.
- [ ] `dispose()` at `query_manager.dart:129-132` cancels all timers before clearing `onChange`.

#### `openui` — `Renderer`

- [ ] In `_buildQueryManager()` at `renderer.dart:141-145`, pass `contextProvider: () => _buildEvalContext(_lastResult)` to the `QueryManager` constructor.
- [ ] In `_runPipeline()`, after firing queries call `manager.pruneStale({for (final q in result.meta.queries) q.statementId, for (final m in result.meta.mutations) m.statementId})`.

#### Tests — PR 2

- [ ] In `query_manager_test.dart` under a new `group('defaults and stale-while-revalidate', ...)`:
  - Default value visible while the first fetch is in flight.
  - Default value visible if the first fetch errors.
  - Last-good value visible during refetch (stale-while-revalidate).
  - Last-good value visible if the refetch errors.
- [ ] Under a new `group('auto-refresh', ...)`:
  - `refreshSeconds = 1` fires `callTool` again after ~1s. Uses `fakeAsync`.
  - Refresh tick during an in-flight fetch is skipped.
  - Changing `refreshSeconds` cancels and replaces the timer.
  - `pruneStale` cancels removed-statement timers and clears `_stmtToKey`.
  - `dispose` cancels all timers.

### PR 3 — Mutation lifecycle

#### `openui` — `MutationResult` (internal)

- [ ] Create `packages/openui/lib/src/mutation_result.dart`. Sealed hierarchy:
  ```dart
  @internal
  sealed class MutationResult {
    const MutationResult();
    Map<String, Object?> toMap();
  }

  @internal
  final class MutationResultIdle extends MutationResult {
    const MutationResultIdle();
    @override
    Map<String, Object?> toMap() =>
        const {'status': 'idle', 'error': null, 'value': null};
  }

  @internal
  final class MutationResultLoading extends MutationResult {
    const MutationResultLoading();
    @override
    Map<String, Object?> toMap() =>
        const {'status': 'loading', 'error': null, 'value': null};
  }

  @internal
  final class MutationResultSuccess extends MutationResult {
    const MutationResultSuccess(this.value);
    final Object? value;
    @override
    Map<String, Object?> toMap() =>
        {'status': 'success', 'error': null, 'value': value};
  }

  @internal
  final class MutationResultError extends MutationResult {
    const MutationResultError(this.message);
    final String message;
    @override
    Map<String, Object?> toMap() =>
        {'status': 'error', 'error': message, 'value': null};
  }
  ```
- [ ] Not exported from `packages/openui/lib/openui.dart`. Internal implementation detail. Templates only see the `Map<String, Object?>` produced by `toMap()` via `snapshotValues()`.

#### `openui` — `QueryManager` mutation track

- [ ] Add a `Map<String, MutationResult> _mutations` keyed by statementId. Add a `Map<String, Future<void>> _inflightMutations` for the concurrency guard.
- [ ] Add `Future<void> fireMutation(MutationDecl decl, EvalContext ctx)`:
  - If `_inflightMutations[decl.statementId]` exists, return the same future. Concurrent calls coalesce.
  - Resolve `(toolName, args)` via `_resolveCall`.
  - Set `_mutations[id] = const MutationResultLoading()`. Call `onChange`.
  - Invoke `toolProvider.callTool(toolName, args)`. On success set `_mutations[id] = MutationResultSuccess(value)`. On error set `_mutations[id] = MutationResultError(error.toString())`. Either way the returned future completes normally.
  - In `whenComplete`, remove from `_inflightMutations`, call `onChange`.
- [ ] Seed `_mutations[id] = const MutationResultIdle()` when a mutation decl first appears in `pruneStale`'s active set. Call from the new `pruneStale` body added in PR 2.
- [ ] Extend `snapshotValues()`. For each `id` in `_mutations`, include `id → _mutations[id]!.toMap()` in the returned map. Mutation results appear alongside query values keyed by statementId. The existing evaluator `MemberAccess` path on a `Map<String, Object?>` resolves `createResult.status` unchanged.

#### `openui` — `Renderer` await wiring

- [ ] `_onRun` at `renderer.dart:268-297` already does the routing (mutation → `fireMutation`, query → `invalidate`, otherwise → direct tool). PR 3 only needs to verify two invariants after the manager refactor:
  - `await manager.fireMutation(m, ctx)` resolves regardless of the underlying tool throwing — `fireMutation` captures the error into `MutationResultError` and returns normally. The `dispatchAction` await at `actions.dart:398` chains as before.
  - The dispatcher's halt-on-throw path at `actions.dart:397-401` (covered by the `actions_test.dart:409-425` test) is unreachable for mutations once the refactor lands. Errored mutations stay observable via `createResult.status == "error"`.

#### Tests — PR 3

- [ ] Add `packages/openui/test/src/mutation_result_test.dart`. One `group` per concrete subtype:
  - Each subtype's `toMap()` returns the documented shape.
  - Equality, hashCode, and `const` constructor behavior are exercised where relevant.
- [ ] Extend `query_manager_test.dart` with a new `group('mutation lifecycle', ...)`:
  - `fireMutation` transitions idle → loading → success and the snapshot map reflects each state.
  - `fireMutation` on a failing `callTool` transitions idle → loading → error. Future resolves normally. Snapshot map contains `status: "error"` and `error: <message>`.
  - Concurrent `fireMutation` calls share one future and result in a single `callTool` invocation.
  - `snapshotValues()` includes mutation entries keyed by statementId.
- [ ] In `renderer_test.dart` under `group('action sequencing', ...)`:
  - `Action([@Run(createMutation), @Run(query)])` fires `query` only after the mutation's `Future` resolves. Use a `Completer` from the test to control the mutation's `callTool` resolution and assert ordering.
  - An errored mutation still allows the chained `@Run(query)` to fire. Asserts that `fireMutation` swallows the error rather than throwing into the dispatcher.
- [ ] In `renderer_test.dart` under `group('mutation result binding', ...)`:
  - Template `createResult.status == "error" ? Text(createResult.error) : Text("ok")` renders the error message after a failing mutation.

## Acceptance Criteria

- [ ] `Query("list", {status: $status}, {rows: []})` re-fires when `$status` is mutated by an action.
- [ ] Two queries with identical `(toolName, args)` share a single `ToolProvider.callTool` invocation.
- [ ] `Query("list", {}, {rows: []}, 30)` invokes `callTool` repeatedly every ~30 seconds. Refresh ticks during an in-flight fetch are dropped.
- [ ] Default value (arg 2) renders before the first success and on first-load failure. After the first success, the last-good value persists through refetches and errors.
- [ ] `Mutation("create", {title: $title})` does not fire on render.
- [ ] `@Run(createMutation)` followed by `@Run(query)` in the same action plan awaits the mutation before re-firing the query.
- [ ] Concurrent `@Run(createMutation)` while the mutation is in flight is a no-op. The dispatcher proceeds to the next step after the in-flight call resolves.
- [ ] When a mutation errors, the chained `@Run(query)` still fires. The error is observable via `createResult.status == "error"` and `createResult.error`.
- [ ] Templates can read `createResult.status`, `createResult.error`, and `createResult.value` through the standard `MemberAccess` evaluator path against the snapshot map.
- [ ] `QueryDecl.deps` and `MutationDecl.deps` contain every `StateRef` name in the args AST, deduplicated.
- [ ] `docs/lang-reference.md` is updated to show positional `Query` and `Mutation` syntax matching the JS docs at https://www.openui.com/docs/openui-lang/queries-mutations.
- [ ] The exhaustive AST coverage test in `streaming_test.dart` exercises every concrete `AstNode` subtype.
- [ ] All existing `openui_core` and `openui` tests pass. New tests above pass.
- [ ] No public API breakage outside the `QueryManager.ensureFired` / `invalidate` signature change and the new required `contextProvider` constructor parameter. The class is `@experimental` per D12.

## Technical Considerations

- **Stable hashing.** `_canonicalize` accepts only `String`, `num`, `bool`, `null`, `List`, `Map<String, Object?>`. Throws `ArgumentError` otherwise. The evaluator produces `Map<String, Object?>` from `ObjectLit` and `List<Object?>` from `ArrayLit`, so the supported types match the runtime's natural output.
- **Timer ownership.** Auto-refresh timers must be canceled before the renderer disposes the manager and before a statement disappears from `ParseMeta`. The `pruneStale` and `dispose` paths cover both. Tests use `fakeAsync` to validate cancelation order.
- **Forward references in deps.** `Query("x", {s: $status})` may be parsed before `$status = "open"` (streaming). `_collectStateRefs` only sees the AST and returns `$status` regardless of declaration order. The renderer reads `_store.get('status')` and gets `null` until the state decl is processed, producing a defined cache key. When the state decl lands and seeds `'open'`, the store change triggers `maybeRefire`. Covered by the streaming test cases.
- **`MutationResult` shape decision.** Committed to map-wrapping in `snapshotValues()`. The sealed hierarchy lives inside `openui` for type-safe state transitions. The evaluator sees only `Map<String, Object?>`. This keeps `openui_core` and its `MemberAccess` evaluator untouched.
- **`contextProvider` lifecycle.** Required at construction. The renderer captures `this` in the closure. Disposal sequence in `Renderer.dispose()` already runs `_queryManager.dispose()` before clearing state. Timer fires after dispose are impossible because all timers are canceled in `dispose()`.

## Dependencies & Risks

- **Risk: cache-key explosion.** A query with a `$counter` dep that increments rapidly creates a new cache entry per value, leaking memory. Mitigation: when `_stmtToKey[id]` rebinds, evict the previous key's entry (in the plan above). Future LRU bound is deferred.
- **Risk: timer drift in tests.** Auto-refresh tests use `fakeAsync` from `package:fake_async`. The package is already a transitive dev_dep through `flutter_test`. If a direct import is needed, add `fake_async: ^1.3.1` to the `dev_dependencies` of `packages/openui/pubspec.yaml`. Verify before PR 2 lands.
- **Risk: lang-reference / prompt drift.** Updating `docs/lang-reference.md` for positional syntax does not automatically update the LLM prompt. Verify the grammar primer in `openui_core/lib/src/prompt/prompt.dart` reflects positional `Query` and `Mutation` syntax before PR 1 merges.
- **Dependency: no production package additions.** All runtime work uses `dart:async` and `dart:convert` already imported. The `fake_async` note above is the only possible `pubspec.yaml` change.

## Known Gaps (not in scope)

- **Reserved snapshot keys.** JS exposes `__openui_loading`, `__openui_refetching`, `__openui_errors`. The Flutter renderer has separate loading and error paths. Add only if a generated template needs them.
- **Refetching vs loading distinction.** JS distinguishes initial-load from refetch. `QueryEntry.loading` is true in both cases here.
- **Optimistic update arg on `Mutation`.** JS does not have one.
- **Tab and visibility throttling for auto-refresh.** Not in JS either.
- **LRU bound on `_entries`.** Follow-up if real apps show cache growth.

## References

- Brainstorm: `docs/brainstorm/2026-05-12-queries-mutations-brainstorm-doc.md`
- JS docs (canonical spec): https://www.openui.com/docs/openui-lang/queries-mutations
- JS reference impl: `~/Developer/AI/openui/packages/lang-core/src/runtime/queryManager.ts`
- Lang reference (Flutter): `docs/lang-reference.md` lines 75-100 (statement classification, `@Run` semantics)
- Decision record D12 (`@experimental` marker): `docs/decisions/2026-05-10-phase0-decisions.md`
- Current `QueryManager`: `packages/openui/lib/src/query_manager.dart`
- Current renderer integration: `packages/openui/lib/src/renderer.dart:190-195` (queries fired from `_runPipeline`) and `:268-297` (`_onRun` routing mutations / queries / direct tools)
- Dispatcher await + halt-on-throw: `packages/openui_core/lib/src/actions/actions.dart:392-401`
- Action rework that introduced the new `onRun(RunStep step, Map<String, Object?> args)` signature and halt semantics: commit `736032d` ("feat: rework action system to JS reference parity")
