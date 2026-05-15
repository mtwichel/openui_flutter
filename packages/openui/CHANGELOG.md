# Changelog

## 0.1.0 (unreleased)

- **BREAKING**: `QueryManager` rewrite for the new `@Query` builtin.
  Constructor is now `QueryManager({library, store, onError})`. Results
  flow through `store.set(statementId, value)` instead of an internal
  `QueryEntry` map; `QueryEntry` is removed. `ensureFired` /
  `invalidate` take `(QueryDecl, EvalContext)` and evaluate args at
  fire time. The renderer gates firing on
  `!isStreaming && incomplete.isEmpty`, so a `@Query` only fires once
  the stream completes and the parse is well-formed. `@Run($var)`
  re-fires the bound query against the live store.
- **chore**: renderer iteration paths follow the new 3-arg `@Each`
  shape — the template is read from `args[2]` and the named loop var
  is bound from the string-literal at `args[1]`. `@Map` is unchanged.
- **feat**: `Renderer` widget — streaming-aware Flutter renderer for
  OpenUI Lang. Owns the parser, reactive store, query cache,
  form-state cache, and a per-element error boundary.
- **feat**: `ErrorBoundary` widget — caches the last successful child
  and reports captured render errors through `Renderer.onError`.
- **feat**: `FormStateCache` — `TextEditingController` cache keyed by
  `(formName, fieldName)` with a 250 ms grace window on disposal so
  focus survives mid-stream rebuilds.
- **feat**: `QueryManager` — per-renderer gate that turns `@Query`
  declarations into one-shot tool calls. Results flow through the
  store; mutations dispatch through `fireMutation` and surface
  failures via `onError`.
- **feat**: `RendererScope` — `InheritedWidget` exposing the store,
  form-state cache, streaming flag, incomplete-statement set, and
  action dispatcher to descendant components.
- **chore**: package scaffold (Phase 0).
