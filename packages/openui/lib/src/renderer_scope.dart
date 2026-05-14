import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:openui/src/form_state_cache.dart';
import 'package:openui_core/openui_core.dart';

/// Renderer-scoped seams that components need during build.
///
/// Lives behind an [InheritedNotifier]-style installation so descendant
/// components can find the active [Store] and [FormStateCache] without
/// the renderer passing them through every component callback.
///
/// Marked `@experimental` per D12.
@experimental
class RendererScope extends InheritedWidget {
  /// Creates a [RendererScope].
  const RendererScope({
    required this.store,
    required this.formStateCache,
    required this.isStreaming,
    required this.incomplete,
    required this.triggerAction,
    required super.child,
    super.key,
  });

  /// The reactive store backing `$state` lookups.
  final Store store;

  /// Cache of form-field controllers — see [FormStateCache].
  final FormStateCache formStateCache;

  /// Mirror of `Renderer.isStreaming`. Component implementations use
  /// this to disable animations, expensive parses, etc.
  final bool isStreaming;

  /// Set of statement ids the streaming parser flagged as
  /// `meta.incomplete`. Components inspect this to gate tap targets
  /// (Acceptance Gap A6).
  final Set<String> incomplete;

  /// Single public seam for components to dispatch an action.
  ///
  /// When `action` is `null`, the renderer emits a continue-conversation
  /// `ActionEvent` to the host `onAction` callback (if set), then invokes
  /// `onContinueConversation` with `userMessage` (implicit-Button path).
  /// When non-null, the renderer dispatches the supplied plan; each step
  /// invokes `onAction` once (including failed `@Run`, skipped `@Reset`
  /// targets, and invalid `@ToAssistant` messages). Successful
  /// continue-conversation steps also invoke `onContinueConversation`
  /// after `onAction`.
  final Future<void> Function(
    String userMessage, {
    required ActionPlan action,
  })
  triggerAction;

  /// Looks up the nearest enclosing [RendererScope].
  static RendererScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RendererScope>();
    assert(scope != null, 'No RendererScope above this widget.');
    return scope!;
  }

  /// Looks up the nearest enclosing [RendererScope] without taking a
  /// build dependency. Use from gesture / async callbacks.
  static RendererScope? maybeFind(BuildContext context) {
    return context.getInheritedWidgetOfExactType<RendererScope>();
  }

  @override
  bool updateShouldNotify(RendererScope oldWidget) =>
      !identical(oldWidget.store, store) ||
      !identical(oldWidget.formStateCache, formStateCache) ||
      oldWidget.isStreaming != isStreaming ||
      !_setsEqual(oldWidget.incomplete, incomplete);
}

bool _setsEqual(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
