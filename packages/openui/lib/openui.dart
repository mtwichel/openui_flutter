/// Flutter renderer for OpenUI Lang.
///
/// This is the only file consumers should import from `openui`. The
/// `src/` tree is private. Every public symbol is currently marked
/// `@experimental` — the shape may change between v0.1 and v0.2.
library;

export 'src/action_event.dart' show ActionEvent;
export 'src/error_boundary.dart' show ErrorBoundary;
export 'src/form_state_cache.dart' show FormStateCache;
export 'src/query_manager.dart' show QueryEntry, QueryLoader, QueryManager;
export 'src/renderer.dart' show ComponentWidgetRenderer, Renderer;
export 'src/renderer_scope.dart' show RendererScope;
