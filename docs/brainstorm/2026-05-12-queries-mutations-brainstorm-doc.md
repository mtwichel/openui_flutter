---
date: 2026-05-12
topic: queries-mutations
---

# Reactive queries and mutations

## What We're Building

Feature parity with the JS `openui-lang` runtime's queries-and-mutations model, so an LLM-generated `Query("list_tickets", {status: $status}, {rows: []}, 30)` behaves the same in Flutter as it does on the web. Today the Flutter parser already classifies `Query` and `Mutation` calls, surfaces them in `ParseMeta`, and the `QueryManager` in `packages/openui/lib/src/query_manager.dart` fires them lazily through a `ToolProvider`. What is missing is the reactive and positional surface. Arguments are extracted as raw literals so `$state` references never resolve. The cache is keyed by `statementId` alone. There are no defaults or auto-refresh. Mutations have no lifecycle object. The action dispatcher cannot await a mutation before the next `@Run`.

The work brings the runtime in line with the spec at `docs/lang-reference.md` and the JS docs at https://www.openui.com/docs/openui-lang/queries-mutations, shipped as three incremental PRs on top of the existing infrastructure.

## Why This Approach

Three approaches were considered:

**Incremental enhancement** <- Recommended

Extend the existing `QueryManager` and parser-side `QueryDecl` / `MutationDecl` rather than rewriting them. Add reactive argument evaluation, a dep-tracking AST walk, a content-addressed cache key, defaults, auto-refresh, and a `MutationResult` shape that flows through `EvalContext`. Ships as three independent PRs that each leave the runtime working.

- Pros: Reuses the parser, AST, evaluator, and store work already merged. Each PR is reviewable on its own. No public-API churn for consumers who only use literal args today.
- Cons: Some scaffolding lands in PR 1 before its full payoff is visible, including the cache-key swap and the eval-context plumbing.
- Best when: the bones already match the target architecture, which they do here.

**Full unified `OperationManager` rewrite** <- Not recommended

Replace `QueryManager` with a single class that handles both queries and mutations using the JS internal layout. Designed around content-addressed caching from line one.

- Pros: Cleaner separation between query lifecycle and mutation lifecycle. Closer line-for-line to the JS source.
- Cons: One large PR. Forces a rename and API churn for code already wired against `QueryManager`. Higher review and rollback cost. The existing `QueryManager` already converges on this shape after PR 1, so the unified rename can land later if it pays off.
- Best when: building greenfield. We are not.

**Minimal positional-arg shim** <- Not recommended

Just teach `_stringArg` and `_mapArg` to accept positional args and stop there.

- Pros: One-day change. Unblocks LLMs emitting JS-style positional syntax.
- Cons: Leaves queries non-reactive. Changing `$state` in args would not re-fire. The whole point of `Query(name, args, default, refresh)` is the reactivity story, and skipping it misrepresents what the lang supports.
- Best when: only the syntax matters and reactivity is deferred indefinitely. Not the case here.

Recommendation is incremental enhancement, split into three PRs so each is independently mergeable and revertible.

## Key Decisions

- **Positional args become canonical, named args are dropped.** JS uses positional. The Flutter docs currently show `Query(name: "list_tickets", args: {...})`, but no consumer should be on that surface yet. The entire `openui_core` API is `@experimental` per D12, and the example app exercises generated rather than hand-written OpenUI code. Switching now avoids a permanent split with JS. The parser already accepts whatever `_parseArgList` returns. The change is in `QueryManager` and in `docs/lang-reference.md`.

- **`Query(name, args, default, refreshInterval)` positional shape.** Arg 0 must be a string literal tool name. Arg 1 is the args object AST. Arg 2 is the default value AST. Arg 3 is an optional positive integer of seconds. `Mutation(name, args)` has no default and no auto-refresh.

- **Args are evaluated through the evaluator at fire time, not extracted as literals.** Replace `_mapArg` with a call into the existing evaluator against the renderer's current `EvalContext`. This unlocks `$state` references in query args.

- **Dependency tracking via a parser-side AST walk.** `QueryDecl` and `MutationDecl` gain a `Set<String> deps` field populated by walking the args AST for `StateRef` nodes. The renderer subscribes to the store and calls `queryManager.maybeRefire(decl)` when any dep changes. Cheaper than recomputing the cache key on every store tick.

- **Cache key matches JS: `toolName::stableHash(evaluatedArgs)::stableHash(depValues)`.** Two queries that call the same tool with the same args share a cache entry, exactly as in JS. The renderer maintains a `Map<String, String>` from statementId to the current cache key so `@Run(stmt)` can invalidate the right entry. Old cache keys for a given statementId are evicted when the statementId binds to a new key. Mutations are keyed by `statementId` alone and always fire fresh.

- **`MutationResult` shape lives in `openui_core` and is exposed in `EvalContext.queryResults` under the mutation's statement id.** Fields: `status` (`"idle" | "loading" | "success" | "error"`), `error: String?`, `value: Object?`. Templates can write `createResult.status == "error"` directly, matching the JS docs. `QueryManager` is extended to track mutation entries in the same `_entries` map for v0.1. No split into `MutationManager` for now.

- **Auto-refresh uses a per-statement `Timer.periodic`.** Timers are owned by `QueryManager`, scoped to the renderer's lifetime, and cleared on `dispose()` or when the statement disappears from `ParseMeta`. The 4th arg accepts a positive integer of seconds. Zero or negative disables. If a tick fires while the previous fetch is still in flight, the tick is skipped. Matches JS. Tab and visibility throttling are out of scope for v0.1.

- **Mutation concurrency guard.** A second `@Run(createResult)` while the first is in flight resolves the dispatcher's `await` immediately as a no-op without firing the mutation again. The first fetch continues to completion and its result is what observers see. Matches JS double-submit prevention.

- **Mutation to query refresh stays user-controlled via the action plan.** No new builtin. The existing pattern `Action([@Run(createResult), @Run(tickets), @Reset($title)])` is enough, because the dispatcher already runs steps sequentially per D3 and awaits each `@Run`. The mutation manager exposes a `Future<void>` that the dispatcher awaits before advancing, so `@Run(tickets)` only fires after `createResult` resolves.

- **Default value stands in for `null` only while loading and only before the first successful result.** After the first success, errors and refetches keep the last-good value visible. Stale-while-revalidate. JS does this and it is the right ergonomic default.

- **Reserved snapshot keys deferred.** JS exposes `__openui_loading`, `__openui_refetching`, `__openui_errors` so templates can introspect global state. The Flutter renderer already has a separate loading-overlay path and `error_boundary.dart`. The reserved keys are not blocking and can be added once a generated template needs them.

- **No optimistic update arg on `Mutation`.** JS does not have one. Defer.

- **PR breakdown.**
  - **PR 1: Reactive foundation.** Positional-arg parsing in `QueryManager`. Arg evaluation through the evaluator. `QueryDecl.deps` and `MutationDecl.deps` populated by a `StateRef` walk in `streaming.dart`. Cache key changed to `toolName::stableHash(args)::stableHash(deps)`. Renderer subscribes to the store and re-fires queries on dep change. Updates to `docs/lang-reference.md` for the positional shape.
  - **PR 2: Defaults and auto-refresh.** Third positional arg becomes the default value. Fourth arg drives a per-statement `Timer.periodic`. Skip-while-in-flight semantics. Stale-while-revalidate after first success.
  - **PR 3: Mutation lifecycle.** `MutationResult { status, error, value }` exposed in `EvalContext.queryResults`. Concurrency guard. Mutation `Future<void>` plumbed into the dispatcher so sequential `@Run` chains await correctly.

## Open Questions

- Does dropping the named-arg `Query(name: ..., args: ...)` syntax need a deprecation window, or is the `@experimental` marker enough cover? Worth confirming before PR 1.

- Forward references in dep tracking. If `$status` appears in a query before `$status` is declared, the dep is still real once the declaration arrives. The walk needs to extract all `StateRef` names regardless of order. Should be the existing parser behavior but worth a dedicated test.
