# Changelog

## 0.1.0 (unreleased)

- **feat**: `Renderer` widget — streaming-aware Flutter renderer for
  OpenUI Lang. Owns the parser, reactive store, query cache,
  form-state cache, and a per-element error boundary.
- **feat**: `ErrorBoundary` widget — caches the last successful child
  and reports captured render errors through `Renderer.onError`.
- **feat**: `FormStateCache` — `TextEditingController` cache keyed by
  `(formName, fieldName)` with a 250 ms grace window on disposal so
  focus survives mid-stream rebuilds.
- **feat**: `QueryManager` — per-renderer cache of `Query` /
  `Mutation` results with `@Run` invalidation and pluggable
  transport (`ToolProvider`) or test seam (`QueryLoader`).
- **feat**: `RendererScope` — `InheritedWidget` exposing the store,
  form-state cache, streaming flag, incomplete-statement set, and
  action dispatcher to descendant components.
- **chore**: package scaffold (Phase 0).
