import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// One action emission from a component back to the renderer.
///
/// Components produce [ActionEvent]s when the user activates an
/// interactive prop (`onClick`, `onSubmit`, etc.). The renderer
/// dispatches the [plan] through `dispatchAction`, and the optional
/// `Renderer.onAction` callback is invoked with the same event so the
/// containing app can audit or override.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ActionEvent {
  /// Creates an [ActionEvent].
  const ActionEvent({
    required this.plan,
    required this.statementId,
    this.payload,
  });

  /// Parsed plan for this action — built from the prop's AST via
  /// `actionPlanFromAst`.
  final ActionPlan plan;

  /// Statement id of the component that produced the event.
  final String statementId;

  /// Optional payload — Form submit events carry the form's collected
  /// state here.
  final Object? payload;
}
