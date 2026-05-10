---
title: Phase 0 decision register
date: 2026-05-10
status: accepted
---

# Phase 0 decision register

This file resolves the architectural unknowns flagged in the plan before any consumer-package code is written. Each decision is binding for v0.1 unless explicitly revisited in a later decision file.

## D1. Toolchain versions

**Decision.** Pin the workspace to **Flutter 3.41.9** (Dart 3.11.5). Every package declares `sdk: ^3.9.0`.

**Why.** The plan specifies `sdk: ^3.9.0` and "Pin Flutter `stable` channel at version `3.27.x`". Those two constraints contradict each other: Dart 3.9 first ships with Flutter 3.35.0 (2025-08-14). The 3.27.x pin was carried over from an earlier draft when Dart 3.6 was current. Today (2026-05-10) the current stable is 3.41.9 / Dart 3.11.5. We honor the Dart constraint and use the latest stable Flutter, which is the strictest realistic interpretation of the plan.

**Implications.**
- CI workflows pin `flutter-version: 3.41.9` and `channel: stable`.
- Plan acceptance criterion "Min Flutter `3.27.0`" remains a *minimum*; this PR's pin is the *current* version.
- Bumping Flutter is a single workflow file change; no package code depends on a specific Flutter minor.

## D2. Parser keying and memoization

**Decision.** `parse(response, library, {rootName})` is a pure function. The streaming parser caches completed statements by their textual hash; the pending tail re-parses on every chunk. The top-level cache key is `(response.length, library.id, rootName)`.

**Why.** Caching by full-string hash is wasteful when 95% of the buffer is unchanged. Splitting at the last bracket-depth-zero newline lets us re-use the prefix's parse on every chunk. `library.id` participates in the key because two libraries with the same components but different render functions are distinct.

**How to apply.** Producers must implement `Library.id` as a stable hash of the registered component set. Tests assert that re-parsing identical input is O(1) on the cache layer.

## D3. Action `$var` resolution timing

**Decision.** `@Set` and `@Reset` carry their unevaluated AST through to dispatch. The action plan dispatcher re-evaluates `valueAst` against the live store at the moment the click handler runs, **not at parse time** and **not at plan-construction time**.

**Why.** `@Set($count, $count + 1)` must read the current `$count`. Evaluating at parse time captures a stale closure; evaluating at plan-construction time fails when a long `@Run` precedes a `@Set` that reads now-mutated state. The JS reference uses the same per-step evaluation strategy.

**How to apply.** `SetStep.valueAst` is `AstNode`, not `Object?`. The dispatcher loop calls `evaluator.evaluate(step.valueAst, currentContext)` immediately before applying.

## D4. Reactive store scope

**Decision.** One `Store` instance per `Renderer`. Sibling `Renderer`s do not share state.

**Why.** Sharing a store across renderers would let LLM output in one chat thread mutate widgets rendered for another. Per-renderer is the safe default. Apps that genuinely want shared state can pass a single `Store` to multiple renderers via the `initialState` mechanism plus an externally-owned controller — explicit, not implicit.

## D5. Adapter selection and malformed events

**Decision.** Adapter is selected at `OpenUiChatController` construction time (constructor parameter). On the first malformed event the adapter throws `AdapterMismatchError(adapterName, offendingPayloadPreview)`.

**Why.** Adapter heuristics that try to guess the wire format silently swallow real bugs. Explicit selection plus loud failure is the rule from D5 of the plan's risk table.

**How to apply.** Each adapter wraps its decode in a try/catch and rethrows as `AdapterMismatchError` with a 200-character payload preview. The four v0.1 adapters: `agUiAdapter`, `openAICompletionsAdapter`, `openAIResponsesAdapter`, `plainSseAdapter`. `langgraph` and `openai-readable-stream` are deferred to v0.2 (Acceptance Gap A21).

## D6. UTF-8 policy

**Decision.** All adapters decode with `Utf8Decoder(allowMalformed: true)`. A malformed byte sequence emits a warn-level log via `package:logging` and is replaced with `U+FFFD`.

**Why.** A malformed byte mid-stream must not throw and kill the assistant message. `allowMalformed: false` would. The brainstorm's initial suggestion was wrong on this; the plan's Risk Analysis row "UTF-8 split across SSE chunks" lands on the correct policy.

## D7. Form controller cache

**Decision.** `_FormStateCache` is owned by the `Renderer`. Key: `(formName, fieldName)`. When a field disappears from the parsed tree, its controller is retained for **250 ms** before disposal.

**Why.** The LLM may delete and immediately re-add the same field as it streams (auto-close gymnastics). 250 ms is long enough to absorb that re-add without losing focus or cursor position. The grace window is the JS reference's "stable" check, ported.

**How to apply.** Each `dispose` is gated on a `Timer(250ms)` that the cache cancels if the field reappears. Tests assert focus survives a delete-then-re-add within 250 ms.

## D8. Query result cache

**Decision.** Query results live in `openui_core`'s `QueryManager`, keyed by `statementId`. The cache persists across `Renderer` rebuilds (it is owned by the renderer's evaluation context, not by individual widgets). `@Run(name)` invalidates by statement id and re-fires.

**Why.** A query result that lives in widget state evaporates on rebuild. Widget rebuilds are frequent during streaming; query results must outlive them.

**How to apply.** v0.1 has no dependency tracking — `@Run` re-fires unconditionally. Smarter invalidation is Phase 5.

## D9. Concurrent sends

**Decision.** Queue-and-replace. A `sendMessage` call while another is in flight cancels the in-flight one and starts the new one.

**Why.** Two assistant messages interleaving in the same chat would be confusing and rare-in-practice. Cancelling the previous send is the simpler contract.

**How to apply.** `OpenUiChatController` holds an `Optional<http.Client>` for the in-flight stream. `sendMessage` closes that client (which the adapter's stream surfaces as a `done` event) and assigns a fresh one before issuing the request.

## D10. `json_schema_builder` fallback

**Decision.** Use `json_schema_builder ^0.1.3`. If S0.1 confirms `x-reactive` survives `toJson()`, no wrapper is needed. If keywords are stripped, write a thin `S` wrapper that re-injects extensions post-build.

**Why.** The package is preview-quality. The brainstorm's worst-case fallback is hand-rolling a minimal `JSONSchema` type covering the subset we use (object, string, integer, number, boolean, array, union, format, x-extensions). That fallback is documented as an escape hatch, not the primary path.

**Outcome.** S0.1 ran during this phase: `json_schema_builder` preserves `x-reactive` through `toJson()` round-trip. See `docs/spike-results/s0-1-json-schema-builder.md`. Decision: use the package directly. Custom keywords are merged via a one-liner that spreads the inner schema's backing map (`Schema.fromMap({...inner.value, 'x-reactive': true})`); no wrapper class needed.

## D11. mcp_dart envelope

**Decision.** `extractToolResult(CallToolResult)` returns `result.structuredContent` if non-null; else joins `TextContent.text` over `result.content`, attempts `jsonDecode`, falls back to the raw string. `result.isError == true` joins `TextContent.text` and throws `McpToolError(message)`.

**Why.** Matches the JS reference. `mcp_dart 2.1.1` exposes `Content` as a sealed type — the cast to `TextContent` is direct (`switch (c) { case TextContent t: ... }`).

**Outcome.** S0.3 documented from package source rather than a live MCP server (no server available in the Phase 0 env). See `docs/spike-results/s0-3-mcp-dart-envelope.md`. The cast helper compiles against `mcp_dart 2.1.1`'s public surface.

## D12. Public API discipline

**Decision.** Each package's barrel `lib/<package>.dart` is the only consumer-visible import. Every `src/**` file is private; no individual `export 'src/...'`. `@experimental` (from `package:meta`) marks AST node types and `ParseResult` in `openui_core` — their shape may change between v0.1 and v0.2.

**Why.** Auditable surface for pub.dev consumers; freedom to refactor internals without bumping major.

## D13. Layer boundary enforcement

**Decision.** Each package's `analysis_options.yaml` enables `avoid_relative_lib_imports`. CI runs `dart pub deps --json` and fails on disallowed back-edges (e.g., `openui_core` depending on `flutter`).

**Why.** Boundaries that are only documented decay. Boundaries that are checked don't.

**How to apply.** A small Dart script in `tool/check_deps.dart` reads each package's `pubspec.yaml`, asserts the `dependencies` set against the allowed list. Wired into the per-package CI job.

## D14. Coverage policy

**Decision.** 100% line coverage on logic; `// coverage:ignore-line` allowed only with a one-line justification comment, reviewed in PR. Unreachable platform branches (Image.network errorBuilder, url_launcher failure paths) are the typical case.

**Why.** Plan acceptance criterion. The justification rule keeps the escape hatch from rotting into a free pass.

## D15. Reactive prop cycles

**Decision.** The evaluator carries a per-evaluation `Set<String>` of `$var`s currently being resolved. Re-entering the set triggers `meta.errors.add(CyclicStateError(...))` and the cycle returns `null` instead of recursing. Process keeps running.

**Why.** Plan risk row "Cyclic state (a = $b, b = $a) causes stack overflow". Surface as data, not exception.

## D16. Renderer error boundary recovery threshold

**Decision.** A single successful `build()` clears the cached last-good widget. No frame counter.

**Why.** Flutter's synchronous build means a non-throwing render is definitive (Acceptance Gap A14). The JS reference's three-frame counter exists because React concurrent rendering can roll back; Flutter cannot.
