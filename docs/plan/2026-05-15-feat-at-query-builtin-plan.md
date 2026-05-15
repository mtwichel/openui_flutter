---
title: "feat(openui_core, openui)!: @Query builtin replaces Query(...) syntax"
type: feat
date: 2026-05-15
brainstorm: docs/brainstorm/2026-05-15-at-query-support-brainstorm-doc.md
---

## feat(openui_core, openui)!: `@Query` builtin replaces `Query(...)` syntax - Standard

## Overview

Replace the `name = Query(name: ..., args: ...)` statement form with a `@Query` builtin used as the RHS of a state-var assignment:

```
$products = @Query(fetch_products)
$shoes    = @Query(fetch_products, category: "shoes")
root = Stack([
  @Each($products, "p", Card(title: p.title, subtitle: p.brand))
])
```

`@Query` runs the named tool exactly once per `(statementId, evaluated-args)` tuple after the host's stream flips to "done" and the parse is well-formed, and writes the result through the live `Store` via `store.set('$var', result)`. The store slot is `null` until the call resolves, so the LLM's canonical loading idiom is `$products == null ? Spinner() : Table(rows: $products)`. Re-fire via `@Run($products)`. Errors surface through `Renderer.onError` and leave the slot at its prior value.

Two storage layers collapse into one. `QueryManager._entries` and `EvalContext.queryResults` go away; the store is the only result surface. `QueryManager` becomes a thin "has this `(statementId, args-fingerprint)` fired this lifetime?" gate that calls `store.set` on success and routes failures to `Renderer.onError`.

`Mutation(...)` declarations and the `MutationCall` AST node are **out of scope** — they keep their current shape and dispatcher path.

## Problem Statement / Motivation

Today the renderer keeps query results in two places: the `QueryManager._entries` map (loading / value / error) and an `EvalContext.queryResults` snapshot threaded through every evaluator pass. State and query reads use distinct evaluator paths (`_evalStateRef` vs. `_evalReference`'s `queryResults` branch). The LLM contract reflects the split — `users = Query(...)` for fetches, `$count = 0` for state — and the loading state is invisible from the OpenUI Lang source.

`@Query` collapses both surfaces into the store and exposes loading as a `null` value the LLM can write a conditional against. Re-fire via `@Run($products)` falls out for free because the dispatcher already routes `@Run(identifier)` through the renderer's query lookup. The grammar delta is minimal: `@Query` slots in as a new `BuiltinCall` name; no new statement form is needed.

## Proposed Solution

Five edits, spread across `openui_core` (parser, evaluator, prompt, actions) and `openui` (renderer, query manager). The streaming-parser shape gate added for `@Each` carries over directly.

### Step 1. Parser

`packages/openui_core/lib/src/parser/expressions.dart`

- Replace the `Query` recognition at `:138` (`if (t.value == 'Query') return QueryCall(args, offset: t.offset)`) with a `throw ParseException('Query(...) is no longer a statement form — use $var = @Query(toolName, ...)', t.offset)`. The streaming parser already routes per-statement `ParseException`s through `Program.errors`, so the LLM and the host both get a clear migration signal. Pin the literal substring `'@Query(toolName'` in tests so the migration wording stays stable — mirrors the `@Each` precedent's `"3 args"` / `"string identifier"` discipline.

`packages/openui_core/lib/src/parser/parser.dart`

- Add a parser-level shape validator for `@Query`, mirroring `validateEachShape`. Function name: `validateQueryShape(Statement statement, {int? committedOffsetBoundary})`. Rules:
  - `@Query` may only appear as the *whole* RHS of an assignment where the LHS is a `$STATEVAR` (`Statement.kind == StatementKind.query` after the classification update below). Reject nested `@Query` (`@Query` inside an `ArrayLit`, `BinaryOp`, etc.) with `ParseException('@Query must be the entire RHS of a $var assignment', offset)`.
  - `args.length >= 1`. First arg is positional and must be a `Reference` whose name matches the IDENT rule — the tool name. Error wording: `'@Query requires a tool-name identifier as the first positional argument'`.
  - All other args must be **named**. Reject extra positionals with `'@Query only accepts named arguments after the tool name'`.
- Wire `validateQueryShape` into `parseProgram` next to the existing `validateEachShape` loop (`:94-97`), gated by `validateBuiltinShapes`.
- Pin the wording in tests: `parser_test.dart` should assert that each error message contains a specific substring so the streaming gate's filter stays stable.

`packages/openui_core/lib/src/parser/ast.dart`

- Update `classifyStatement` (`:591`) so the order is:
  1. `expression is MutationCall` → `mutation` (unchanged)
  2. `expression is BuiltinCall && expression.name == '@Query'` → `query` (**new**)
  3. `name.startsWith('$')` → `state`
  4. otherwise → `value`
- Remove the `expression is QueryCall` branch entirely — `QueryCall` is deleted in the same PR (see "Cleanup" below).
- Update the `StatementKind.query` doc comment to read `\$name = @Query(tool, ...)` (no longer `Query(name: ...)`).

`packages/openui_core/lib/src/parser/streaming.dart`

- Replace the `case StatementKind.query` branch (`:231-239`) so it pulls the `QueryDecl` from a `BuiltinCall` named `@Query` instead of from a `QueryCall`:
  ```dart
  case StatementKind.query:
    final expr = s.expression;
    if (expr is BuiltinCall && expr.name == '@Query') {
      queries.add(
        QueryDecl(
          statementId: s.name, // preserves the $ prefix
          toolName: _toolNameOf(expr),
          namedArgs: _namedArgsOf(expr),
        ),
      );
    }
  ```
- Run `validateQueryShape` next to `validateEachShape` (`:205-212`) with the same `committedOffsetBoundary: split.prefix.length` gate so mid-stream `$products = @Query(fetch_products` (autoClose-patched) does not surface a shape error.
- Update `QueryDecl` (`:125-135`) to carry the parsed shape directly: `final String toolName; final List<Argument> namedArgs;`. Drop the old `args: List<Argument>` field. Constructor signature: `const QueryDecl({required this.statementId, required this.toolName, required this.namedArgs});`. This makes the `QueryManager` plumbing trivial.

### Step 2. Evaluator

`packages/openui_core/lib/src/eval/evaluator.dart`

- Drop `EvalContext.queryResults` (the `final Map<String, Object?> queryResults` field at `:64`, the constructor param at `:33`, and the `_inherit` copy at `:47`).
- Delete the `if (stmt.kind == StatementKind.query || stmt.kind == StatementKind.mutation) return context.queryResults[name];` branch in `_evalReference` (`:195-197`). After this change, every `@Query`-backed value is read as `$products` (a `StateRef`) and flows through `_evalStateRef` → `context.store`. The bare-`Reference` query-lookup branch is dead because the new shape requires a `$STATEVAR` LHS.
- Register a `@Query` handler in `EvalContext.builtins`. It must return `null` and **not** evaluate the args (the args are evaluated by `QueryManager` at fire time). The handler exists so that an accidental render-time traversal of the `@Query` AST (e.g. before `ensureFired` has run) doesn't raise `no handler registered for builtin @Query`.
- Functional builtin registry (`packages/openui_core/lib/src/eval/builtins.dart`) gets a one-line `@Query` entry pointing at a private `_evalQueryNoop` that returns `null`.

### Step 3. `QueryManager`

`packages/openui/lib/src/query_manager.dart`

- Replace the `_entries: Map<String, QueryEntry>` field with `_fired: Map<String, Map<String, Object?>>`, keyed by `decl.statementId` and storing the most recent **evaluated args map**. Comparison uses `package:collection`'s `MapEquality` (already in `openui_core`'s transitive deps) — no new `_Fingerprint` class. The map gates "has this `(statementId, args)` already fired?"
- New constructor signature: `QueryManager({required Library<Widget> library, required Store store, required void Function(OpenUIError) onError});`. The `onError` type must match `_RendererState._reportError` exactly so the renderer can pass it as-is. The manager writes results through `store.set` and routes failures through `onError`. Drop the `onChange` listener and the `QueryEntry` class entirely.
- New `ensureFired` signature: `void ensureFired(QueryDecl decl, EvalContext ctx)`. The manager:
  1. Evaluates each `Argument` in `decl.namedArgs` against `ctx` to produce a `Map<String, Object?> evaluatedArgs`.
  2. If `_fired[decl.statementId]` exists and `MapEquality().equals(_fired[decl.statementId], evaluatedArgs)`, return.
  3. **Update `_fired[decl.statementId] = evaluatedArgs` synchronously, before awaiting.** This is the in-flight gate — a second `ensureFired` arriving for the same `statementId` during the same micro-task tick must short-circuit on step 2.
  4. Looks up `library.tool(decl.toolName)`. On miss, calls `onError(EvaluationError(message: 'Unknown tool: ${decl.toolName}', statementId: decl.statementId))` and returns.
  5. Fires `tool.callTool(evaluatedArgs)` as an unawaited future. On success, calls `store.set(decl.statementId, value)`. On failure, wraps non-`OpenUIError` throws as `EvaluationError(message: error.toString(), statementId: decl.statementId)` (mirroring `fireMutation`'s wrapping at `query_manager.dart:114-121`) and calls `onError(error)`. The store value is left untouched on failure (per brainstorm decision).
- `@visibleForTesting void invalidate(QueryDecl decl, EvalContext ctx)` clears `_fired[decl.statementId]` and re-calls `ensureFired`. Marked test-only because the renderer's `_onRun` can inline the same two-line clear-then-fire pattern; the method exists for test legibility.
- `fireMutation` keeps its current signature — mutations are out of scope.
- Delete `entryFor`, `snapshotValues`, `errors()`, `_invoke`, `_stringArg`, `_mapArg`, `_literalValue`, and the `_fire` method's `onChange` calls. The `_disposed` flag stays.

### Step 4. Renderer

`packages/openui/lib/src/renderer.dart`

- Construction: pass the store and an error sink into `QueryManager` (`:155-159`). The error sink is the renderer's existing `_reportError`.
- After every parse pass (`:210-215`), gate firing on `!widget.isStreaming && result.meta.incomplete.isEmpty`. If both hold, walk `result.meta.queries` and call `manager.ensureFired(decl, ctx)` for each. Build `ctx` once for the pass via `_buildEvalContext(result)`.
- `_buildEvalContext` (`:315-324`): drop the `queryResults` argument. The store is the single result surface.
- `_handleQueryChange` (`:167`) goes away. The store's existing `_handleStoreChange` already triggers rebuilds when `store.set` lands.
- `_onRun` (`:284-313`): update the `meta.queries` branch (`:298-302`) to clear `_fired[q.statementId]` and call `manager.ensureFired(q, ctx)` (passing the rebuilt context for arg re-evaluation) instead of `invalidate(id, q.args)`. Equivalent to `manager.invalidate(q, ctx)` but inlined since `invalidate` is `@visibleForTesting`. The mutation branch is unchanged.
- `_maybeReportErrors`: drop the `_queryManager?.errors()` block (`:231-233`) and the dedup of `queryErrors` (`:238`). Query errors now reach `onError` via `_reportError` directly from the manager.

### Step 5. Actions: `@Run($var)` support

`packages/openui_core/lib/src/actions/actions.dart`

- `_stepFromAst`'s `@Run` arm (`:279-289`) currently rejects a `StateRef` first argument. Extend it to accept `StateRef`: when `v is StateRef`, set `statementId: '\$${v.name}'` (preserving the `$` so it matches `QueryDecl.statementId` for `@Query`-backed state vars). `Reference` is still accepted for plain tool calls like `@Run(snackbar, message: "Hello")` and for mutation re-fires like `@Run(refresh)`.
- Add unit tests for `_stepFromAst` in `packages/openui_core/test/src/actions/actions_test.dart` covering: (a) `@Run($products)` produces `RunStep(statementId: '$products')`; (b) `@Run(snackbar, message: "Hello")` still produces `RunStep(statementId: 'snackbar', argsAst: {'message': Literal('Hello')})`. The renderer integration test covers the end-to-end re-fire path; this unit test pins the AST-to-step contract.

### Step 6. Prompt

`packages/openui_core/lib/src/prompt/prompt.dart`

- `_kGrammarPrimer` (`:13`): add a bullet for `@Query` near the existing `@Run` / `@Set` bullets:
  ```
  - `$var = @Query(toolName, namedArg: value, ...)` fetches data from a
    registered tool and stores it in `$var`. The slot is `null` until the
    fetch completes — render a loading state with
    `$var == null ? Spinner() : Table(rows: $var)`. Re-fire with
    `@Run($var)`.
  ```
- Add one canonical example near the existing examples block:
  `$products = @Query(fetch_products)\nroot = $products == null ? Text("Loading...") : @Each($products, "p", Card(title: p.title))`
- Run `grep -n "Query(\|Mutation(" packages/openui_core/lib/src/prompt/prompt.dart` and purge any lingering legacy examples. Today a grep returns nothing in `prompt.dart`, but the brainstorm called this out explicitly — run the grep again before merging in case the examples list grows.

### Step 7. Lang reference

`docs/lang-reference.md`

- Statement-classification table (`:75-79`): replace the `query` row to key off `@Query`:
  | `query` | LHS is a `$IDENT` and RHS is `@Query(...)` | `$users = @Query(list_users)` |
- Remove the second clause of the order-of-checks paragraph (`:79`) — `$foo = Query(...)` no longer exists. The remaining ordering rule (`mutation` before `state`) stands.
- Builtins table (`:83-89`): add a `@Query` row.
  | `@Query` | `@Query(toolName, named: value, ...)` | Only valid as the entire RHS of `$var = @Query(...)`. Runs the named tool exactly once per `(statementId, evaluated-args)` tuple after streaming completes; writes the result through the store. `null` while loading. Errors surface via `Renderer.onError`. Re-fire with `@Run($var)`. |
- Streaming-semantics list (`:155-163`): keep `meta.queries: List<QueryDecl>` but update the QueryDecl shape note to mention `toolName` / `namedArgs`.

### File touch list

| File | Change |
|---|---|
| `packages/openui_core/lib/src/parser/expressions.dart` | Drop or replace the `if (t.value == 'Query')` branch at `:138`. Recommended: emit a migration `ParseException`. |
| `packages/openui_core/lib/src/parser/parser.dart` | New `validateQueryShape(Statement, {int? committedOffsetBoundary})`. Wire into `parseProgram`'s `validateBuiltinShapes` loop. |
| `packages/openui_core/lib/src/parser/ast.dart` | Update `classifyStatement` order; update `StatementKind.query` doc; consider removing the `QueryCall` AST node and its case arms (see "Cleanup" below). |
| `packages/openui_core/lib/src/parser/streaming.dart` | `QueryDecl` carries `toolName` + `namedArgs`. `_compute` populates `QueryDecl` from a `BuiltinCall('@Query', ...)`. Re-run `validateQueryShape` with the prefix boundary. |
| `packages/openui_core/lib/src/eval/evaluator.dart` | Drop `EvalContext.queryResults` (field, ctor param, `_inherit` copy). Drop the `queryResults` lookup in `_evalReference`. |
| `packages/openui_core/lib/src/eval/builtins.dart` | Register a `@Query` handler that returns `null` without evaluating args. |
| `packages/openui_core/lib/src/actions/actions.dart` | `_stepFromAst`'s `@Run` arm accepts `StateRef`; `statementId` carries the leading `$`. |
| `packages/openui_core/test/src/actions/actions_test.dart` | Add `_stepFromAst` tests covering `@Run(StateRef)` and `@Run(Reference, named: ...)`. Create the file if absent (search for an existing actions test file first — the dispatcher tests may live under `dispatcher_test.dart`). |
| `packages/openui_core/lib/src/prompt/prompt.dart` | Add `@Query` grammar bullet and one canonical example. |
| `packages/openui_core/lib/openui_core.dart` | Drop `QueryCall` from the re-export list if/when the AST class is removed; keep `QueryDecl` (shape changed). |
| `packages/openui/lib/src/query_manager.dart` | Rewrite per Step 3. New constructor signature; new `ensureFired(QueryDecl, EvalContext)` / `invalidate(QueryDecl, EvalContext)`. Drop `QueryEntry`. |
| `packages/openui/lib/src/renderer.dart` | Gate firing on `!isStreaming && incomplete.isEmpty`. Drop `_handleQueryChange`. Update `_onRun` to pass the rebuilt context. Drop `queryResults` from `_buildEvalContext`. Drop the query-errors branch in `_maybeReportErrors`. |
| `packages/openui_core/test/src/parser/parser_test.dart` | New `@Query` shape tests (tool-name first, named-only after, reject bare `@Query` outside `$var =`, reject nested `@Query`). Update or remove `Query and Mutation become QueryCall / MutationCall` test (`:629`) — keep the Mutation half. |
| `packages/openui_core/test/src/parser/streaming_test.dart` | Replace `users = Query(name: "list")` test cases (`:282`, `:294-295`, `:371`) with `$users = @Query(list_users)` and the new `QueryDecl` shape. Add a mid-stream gate test mirroring the `@Each` autoClose test. |
| `packages/openui_core/test/src/parser/materialize_test.dart` | Update or remove the `QueryCall args` case (`:283`). Remove the `wrap(QueryCall(...)).typeName == 'Query'` assertion at `:95` if `QueryCall` is deleted. |
| `packages/openui_core/test/src/eval/evaluator_test.dart` | Drop `queryResults` from the default-context test (`:44`) and the parametrised `queryResults` constructor tests (`:130`, `:145`). Update the `QueryCall in expression position` test (`:536`) or delete it if `QueryCall` is removed. |
| `packages/openui/test/src/query_manager_test.dart` | Rewrite for the new constructor and `ensureFired(QueryDecl, EvalContext)` shape. Cover: (a) fires once per fingerprint; (b) different args re-fire; (c) tool error → `onError(...)`, store left untouched; (d) success writes through `store.set('$var', ...)`; (e) `invalidate` clears the fingerprint and re-fires; (f) unknown tool → `onError(EvaluationError)`. Preserve the `fireMutation` group as-is. |
| `packages/openui/test/src/renderer_test.dart` | Add: (1) `@Query` does **not** fire while `isStreaming == true`; (2) `@Query` fires exactly once after `isStreaming` flips to false, store reflects the result, an `@Each` over `$products` materializes; (3) re-fire via `@Run($products)` re-evaluates args from the current store; (4) tool failure surfaces via `onError` and leaves `$products` at its prior value. Update the `Run step invalidates and re-fires the named query` test (`:365-411`) to use `$data = @Query(lookup)` plus `[@Run($data)]`. |
| `docs/lang-reference.md` | Update statement-classification row, add `@Query` row in the builtins table, refresh `QueryDecl` shape note. |
| `packages/openui_core/CHANGELOG.md` | Document the breaking change: `Query(name: ...)` removed; `@Query` builtin added. List the `EvalContext.queryResults` removal and the `QueryDecl` shape change. |
| `packages/openui/CHANGELOG.md` | Note the `QueryManager` constructor signature change, the `QueryEntry` removal, and the renderer's query-firing gate on `!isStreaming && incomplete.isEmpty`. |
| `apps/openui_flutter_example/lib/chat/...` (prompt seeds, if any) | A grep for `Query(` in `apps/openui_flutter_example` came back empty, so no seed updates needed unless the implementer finds a hidden reference. Verify and update if found. |

## Technical Considerations

- **Architecture.** The store is already the single source of truth for `$state` reads (`Store.subscribe` drives the renderer's rebuild). Wiring `@Query` through `store.set` reuses that machinery — no new subscription model. The evaluator's existing `_evalStateRef` is the only read path that runs at render time; query reads ride that same code.
- **Firing gate.** The renderer's `_runPipeline` runs on every `setState`. After every parse pass, the renderer checks `!widget.isStreaming && result.meta.incomplete.isEmpty` before walking `meta.queries`. This naturally handles both "stream finished and the parse is complete" and "the next host invocation arrives with `isStreaming: false` and a complete parse already in hand." No new lifecycle hook is required.
- **Args evaluate at fire time.** `QueryManager.ensureFired(decl, ctx)` evaluates each named arg against the freshest `EvalContext`. A `@Run($products)` after a `@Set($category, "shoes")` re-evaluates `category: $category` against the post-set store. The dispatcher in `actions.dart` already builds a fresh context per dispatch.
- **Cache lifetime across messages.** A new assistant message creates a fresh parse. **Decision (locking the open question):** the firing gate handles this implicitly — `ensureFired` short-circuits when the args map matches the cached one and re-fires (overwriting `_fired[statementId]`) when it differs. No explicit cross-pass walk is needed. If `$products` disappears from `meta.queries` entirely (LLM removed the statement), the stale `_fired` entry stays but is harmless — nothing reads it, and the next pass either re-declares the query (re-firing on arg change) or leaves the slot alone. **Deferred to a follow-up PR:** writing `store.set(statementId, null)` on statement disappearance. The brainstorm flagged it as the "tidy" option but it adds a cross-pass walk for a contrived edge case (a downstream statement reading a deleted query's slot), and the firing-gate guarantees nothing visible regresses without it.
- **Concurrent `@Query` declarations.** Today `_fire` dispatches each call as an unawaited future, so two `@Query` statements fire in parallel. **Decision (locking the open question):** keep that. The new `ensureFired` still kicks off `tool.callTool` without awaiting, so parallelism is preserved. Each completion calls `store.set` independently; the store's `subscribe` listener coalesces rebuilds.
- **Error envelope.** v1 has no per-variable error envelope. Failures surface once via `Renderer.onError`. If the LLM needs to render an error UI it has to read the host-visible error state (out of this PR). The store slot stays at its prior value (or `null` if it never resolved) — verified that `@Each(null, "x", ...)` returns `[]` (`packages/openui_core/lib/src/eval/builtins.dart:115`), so the failure path doesn't break iteration.
- **`@Run` on a state-var statement id.** `_stepFromAst`'s `@Run` arm currently only accepts `Reference` first args. Extending it to `StateRef` is a one-branch addition; the resulting `RunStep.statementId` carries the leading `$` so it matches `QueryDecl.statementId` directly. The renderer's `_onRun` already does an `id == q.statementId` compare; no change there.
- **Deprecation of `Query(...)`.** This is a breaking change. The parser emits a migration `ParseException` (Step 1) so the LLM and the host see a clear migration message. **`QueryCall` AST class is deleted in this PR** along with all its case arms (`_materializeValue` at `parse.dart:385`, `evaluator.dart:161`, the exhaustive switches at `parse.dart:324`, the re-export in `openui_core.dart:74`, and all `QueryCall` references in `parser_test.dart`, `materialize_test.dart`, and `evaluator_test.dart`). The case list is finite and the breaking change is already in this PR — keeping `QueryCall` as dead code would force every exhaustive switch to carry a permanent dead arm.
- **Streaming false-positive risk.** The new `validateQueryShape` must use the same `committedOffsetBoundary: split.prefix.length` gate as `validateEachShape`. Mid-stream `$products = @Query(fet` (no closing paren) goes through `autoClose` to become parseable, then the validator skips it because its statement offset lies in the tail.
- **`@Query` outside a `$var =` assignment.** The shape validator must reject `@Query` anywhere except as the entire RHS of a `$STATEVAR = ...` statement. That includes nested positions like `Stack([@Query(...)])` and value-LHS positions like `data = @Query(...)`. The parser-level rejection keeps the evaluator's no-op handler purely defensive.
- **`Mutation(...)` parity.** Brainstorm explicitly scopes mutations out. `MutationCall`, `MutationDecl`, `fireMutation`, and the dispatcher branch all keep their current shapes. The `@Run` `StateRef` extension does not affect mutation dispatch because mutations are LHS-classified by `name` (no `$` prefix) and looked up by `id == m.statementId`. If the LLM writes `@Run($refresh)` where `refresh` is a mutation, the lookup falls through to the direct-tool branch and (correctly) errors as not declared.
- **Cleanup audit.** Grep for `queryResults`, `QueryCall`, `Query(`, and `QueryEntry` across `packages/openui_core` and `packages/openui` before merging. Each match either needs a code change or a CHANGELOG mention. Example app: `grep -rn "Query(" apps/openui_flutter_example/lib apps/openui_flutter_example/test` came back empty during research — re-run before merge.

## Acceptance Criteria

- [ ] `parseProgram('$products = @Query(fetch_products)')` yields one statement with `kind == StatementKind.query` whose `expression` is a `BuiltinCall(name: '@Query', args: [Argument(value: Reference('fetch_products'))])`.
- [ ] `parseProgram('$products = @Query(fetch_products, category: "shoes")')` yields a `QueryDecl(statementId: '$products', toolName: 'fetch_products', namedArgs: [Argument(name: 'category', value: Literal('shoes'))])` in `result.meta.queries`.
- [ ] `parseProgram('$x = @Query()')` records a `ParseException` whose message contains `"tool-name identifier"`.
- [ ] `parseProgram('$x = @Query("not_a_ref")')` records a `ParseException` (first arg must be a `Reference`, not a string literal).
- [ ] `parseProgram('$x = @Query(tool, "positional")')` records a `ParseException` whose message contains `"only accepts named arguments"`.
- [ ] `parseProgram('data = @Query(tool)')` records a `ParseException` (LHS must be a state-var).
- [ ] `parseProgram('root = Stack([@Query(tool)])')` records a `ParseException` whose message contains `"must be the entire RHS"`.
- [ ] `parseProgram('users = Query(name: "list")')` records a migration `ParseException` whose message mentions `'@Query'` (assuming we go with the recommended migration-error variant).
- [ ] Streaming parser fed `'$products = @Query(fetch_products'` (no closing paren) yields a `ParseResult` whose `meta.errors` contains no `@Query` shape complaint and whose `incomplete` set contains `'$products'`.
- [ ] Streaming parser fed `'$products = @Query(fetch_products)\n'` yields a `ParseResult` whose `meta.errors` is empty and whose `meta.queries.single.statementId == '$products'`.
- [ ] `QueryManager.ensureFired(decl, ctx)` calls the tool once per `(statementId, evaluated-args)` cycle. A second `ensureFired` with the same args is a no-op.
- [ ] In-flight gate: two `ensureFired` calls for the same `statementId` issued in the same micro-task tick (before the first tool future resolves) result in **one** `tool.callTool` invocation. Verified by stubbing the tool to return a `Completer.future` and asserting `tool.calls == 1` before the completer fires.
- [ ] `QueryManager.ensureFired(decl, ctx)` writes the resolved value to the store: `store.get('$products')` equals the tool result after the future completes.
- [ ] `QueryManager.invalidate(decl, ctx)` re-evaluates args against the live store before re-firing.
- [ ] `QueryManager.ensureFired` with an unknown tool name calls `onError(EvaluationError(...))` and does not touch the store.
- [ ] `QueryManager.ensureFired` whose tool future fails calls `onError(error)` and leaves the store slot at its prior value (verified via a `store.set('$products', ['prior'])` seed before the failing fire).
- [ ] Renderer test: a program with `$products = @Query(tool)\nroot = $products == null ? Text("Loading") : @Each($products, "p", Text(p))` shows `Text("Loading")` while `isStreaming == true` and the tool has not fired; after pumping with `isStreaming: false`, the tool fires and `@Each` renders one `Text` per item.
- [ ] Renderer test: `@Query` does not fire while `isStreaming == true`. Even with a complete-looking parse, the renderer must skip firing until `isStreaming` flips to false.
- [ ] Renderer test: `[@Run($products)]` on a Button re-fires the query and `tool.calls` increments. Args evaluate against the current store at re-fire time.
- [ ] Renderer test: tool failure surfaces a single `OpenUIError` through `Renderer.onError`. `store.get('$products')` is unchanged.
- [ ] Cache-lifetime test: two consecutive parse passes where `$products = @Query(fetch)` appears in both with identical args do **not** re-fire the tool (`tool.calls == 1`). The same passes with different args re-fire exactly once.
- [ ] `@Reset($products)` (where `$products = @Query(...)`) writes `null` to the store and does **not** call the tool. The dispatcher emits an event with `success: false` and `reason: 'no declared default'` (the existing `@Reset` behavior for state vars without a declared default — query-backed vars fall into this path naturally). Add an explicit acceptance criterion test asserting `store.get('$products')` is unchanged (NOT null) and `tool.calls` stays at its pre-reset count. — Note: the brainstorm proposed writing `null`, but the existing `@Reset` dispatcher path (`actions.dart:348-383`) emits `success: false` when no default is declared, leaving the store untouched. **Decision:** use the existing dispatcher behavior (no null write, success: false event). Re-fetch is `@Run($products)`.
- [ ] Evaluator test: a bare `Reference('products')` (legacy form) no longer returns from `queryResults` — the field is removed. The `EvalContext` constructor no longer accepts a `queryResults` argument; existing tests at `evaluator_test.dart:44, 130, 145` updated.
- [ ] System prompt grammar primer mentions `@Query` in one bullet plus one example.
- [ ] `docs/lang-reference.md` reflects the new `@Query` row, statement-classification update, and `QueryDecl` shape note.
- [ ] `packages/openui_core/CHANGELOG.md` documents: `Query(...)` form removed; `@Query` builtin added; `EvalContext.queryResults` removed; `QueryDecl` shape changed; (optionally) `QueryCall` AST class deleted.
- [ ] `packages/openui/CHANGELOG.md` documents: `QueryManager` constructor / API rewrite; `QueryEntry` removed; firing now gates on `!isStreaming && incomplete.isEmpty`.
- [ ] `@Map`, `@Filter`, `@Each`, `@Count` test suites pass unchanged (regression check).
- [ ] `flutter test` passes in `packages/openui_core` and `packages/openui`.
- [ ] `flutter analyze` passes; `very_good_analysis` clean.

## Success Metrics

- One result-storage layer: `Store`. `QueryManager._entries` and `EvalContext.queryResults` are gone.
- The LLM's loading idiom is `$products == null ? Spinner() : ...`, exercised in at least one prompt-side example and one renderer test.
- `@Run($products)` re-fires through the same path as `@Run(some_mutation)`. No new dispatcher branch.
- No new top-level statement form. `@Query` slots in as a `BuiltinCall`; the grammar stays at `statement ::= identifier "=" expression`.
- A single migration commit. Tests in `query_manager_test.dart`, `renderer_test.dart`, `parser_test.dart`, `streaming_test.dart`, and `evaluator_test.dart` are updated together with the source change.

## Dependencies & Risks

- **Risk: streaming false-positives.** A mid-stream `$products = @Query(fet` could surface a `@Query requires a tool-name identifier` error on every keystroke. Mitigation: the `committedOffsetBoundary` gate on `validateQueryShape` mirrors the `@Each` precedent. Dedicated streaming test required.
- **Risk: cache-lifetime regression.** The "drop slot to null when the statement disappears" rule means an LLM that briefly omits a `$products = @Query(...)` line during streaming could blank the store. Mitigation: the firing gate (`!isStreaming && incomplete.isEmpty`) means the cache walk only runs once streaming completes — mid-stream the renderer keeps the prior store value through the `_lastGoodRoot` cache path. Add a regression test that streams a buffer where `$products` appears, disappears for one tick, and reappears with the same args before the stream ends — the tool should fire once total.
- **Risk: `EvalContext.queryResults` removal breaks downstream callers.** All call sites in this monorepo are in `renderer.dart:320-321` and the evaluator tests. Grep before merging confirms no third-party consumer (the package is `@experimental`, so no API contract).
- **Risk: `QueryCall` AST class removal cascades.** The exhaustive switches in `evaluator.dart:161`, `_materializeValue` (`parse.dart:385`), `materialize_test.dart:95,283`, `parser_test.dart:173-199,280,397,629`, and `evaluator_test.dart:536` all need updates. Mitigation: explicit file-touch entries for each site (see the table). A pre-merge grep for `QueryCall` should return zero hits outside the CHANGELOG.
- **Risk: missed `@Run($var)` extension.** The action-step parser must accept `StateRef` for `@Run`. Without it, `[@Run($products)]` silently returns `null` from `actionPlanFromAst` and the renderer treats it as "no action handler" — silently broken. Mitigation: explicit unit test `_stepFromAst` accepts `StateRef` for `@Run`.
- **Risk: example-app prompt drift.** Grep confirmed no `Query(` references in `apps/openui_flutter_example` today, but the FetchProducts demo's prompt seeds may use the old form in a way that grep missed (e.g. an LLM-generated transcript pinned in tests). Mitigation: implementer runs the example app end-to-end before merging and confirms a `$products = @Query(fetch_products)` flow renders a table.
- **No dependency-version bumps required.** Pure source change inside the monorepo.

## References & Research

- Brainstorm: `docs/brainstorm/2026-05-15-at-query-support-brainstorm-doc.md`
- Existing query manager: `packages/openui/lib/src/query_manager.dart` (full file rewritten)
- Existing renderer query plumbing: `packages/openui/lib/src/renderer.dart:155-159` (`_buildQueryManager`), `:167-170` (`_handleQueryChange`), `:210-215` (firing loop), `:284-313` (`_onRun`), `:315-324` (`_buildEvalContext`)
- Existing parser: `packages/openui_core/lib/src/parser/parser.dart:73-100` (`parseProgram`), `:115-205` (`validateEachShape` and helpers — the model for `validateQueryShape`)
- Expression parser: `packages/openui_core/lib/src/parser/expressions.dart:128-140` (builtin and type-call recognition; the `Query` branch at `:138` is the deletion target)
- Statement classification: `packages/openui_core/lib/src/parser/ast.dart:589-596`
- Streaming compute: `packages/openui_core/lib/src/parser/streaming.dart:191-273` (`_compute`); `QueryDecl` definition at `:125-135`
- Evaluator: `packages/openui_core/lib/src/eval/evaluator.dart:62-65` (`queryResults` field), `:178-202` (`_evalReference`), `:204-225` (`_evalStateRef`), `:145-153` (`BuiltinCall` dispatch)
- Functional builtins: `packages/openui_core/lib/src/eval/builtins.dart:27-33` (registry), `:89-136` (`_evalEach`)
- Action dispatcher: `packages/openui_core/lib/src/actions/actions.dart:261-298` (`_stepFromAst`); `@Run` arm at `:279-289` is the StateRef extension point
- Existing prompt primer: `packages/openui_core/lib/src/prompt/prompt.dart:13-59`
- Existing tests: `packages/openui/test/src/query_manager_test.dart` (full rewrite), `packages/openui/test/src/renderer_test.dart:365-411` (the `Run step invalidates and re-fires` block to update), `packages/openui_core/test/src/parser/streaming_test.dart:267-302` (`StateDecl, QueryDecl, MutationDecl carry the AST verbatim` and surrounding), `packages/openui_core/test/src/eval/evaluator_test.dart:42-145, :536`
- Lang reference to edit: `docs/lang-reference.md:75-79` (statement classification), `:83-99` (builtins tables)
- Recent breaking-change precedent: `docs/plan/2026-05-14-feat-each-named-loop-var-plan.md` (same shape — parser shape validator, streaming gate, breaking-change CHANGELOG, full test rewrite for the affected feature)
- Commits to mirror in style: `232a943` (`feat(openui_core)!: @Each loop vars, streaming store refresh, and mutation-aware inputs`) and `d5c5941` (`feat(openui_core)!: array-only x-action plans`)
