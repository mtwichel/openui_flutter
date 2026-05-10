import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';
import 'package:openui_core/src/eval/evaluator.dart';
import 'package:openui_core/src/parser/parser.dart';

/// Sealed action-step variants. An [ActionPlan] is a list of these,
/// and [dispatchAction] executes them sequentially.
///
/// All non-trivial values (Set values, ToAssistant message + context,
/// OpenUrl url) are carried as unevaluated [AstNode]s and re-evaluated
/// against the live store at the moment the dispatcher reaches the
/// step (Decision D3). Reset targets and Run statement ids are
/// resolved at parse time because they're identifiers, not values.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
sealed class ActionStep {
  const ActionStep();
}

/// `@Set($target, value)`. The dispatcher evaluates [valueAst] against
/// the *current* store and writes the result to [target] (the
/// `$`-prefixed state-var name).
///
/// Marked `@experimental` per D12.
@experimental
final class SetStep extends ActionStep {
  /// Creates a [SetStep].
  const SetStep({required this.target, required this.valueAst});

  /// The `$`-prefixed state-var to write.
  final String target;

  /// Unevaluated AST. Re-evaluated at click time.
  final AstNode valueAst;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetStep && other.target == target && other.valueAst == valueAst;

  @override
  int get hashCode => Object.hash(SetStep, target, valueAst);
}

/// `@Reset($a, $b, ...)`. The dispatcher looks up each target's
/// declared default and writes it back. Targets without a known
/// default emit an [EvaluationError] and are skipped — the rest of
/// the plan continues.
///
/// Marked `@experimental` per D12.
@experimental
final class ResetStep extends ActionStep {
  /// Creates a [ResetStep] with `$`-prefixed [targets].
  const ResetStep({required this.targets});

  /// The state-var names to reset, including the leading `$`.
  final List<String> targets;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetStep && _listEquals(targets, other.targets);

  @override
  int get hashCode => Object.hash(ResetStep, Object.hashAll(targets));
}

/// `@Run(refresh)`. The dispatcher invokes the registered `onRun`
/// callback with [statementId]; a thrown exception halts the rest of
/// the plan (mutations halt on failure).
///
/// Marked `@experimental` per D12.
@experimental
final class RunStep extends ActionStep {
  /// Creates a [RunStep] for the named query / mutation statement.
  const RunStep({required this.statementId});

  /// The id of the statement to re-fire.
  final String statementId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunStep && other.statementId == statementId;

  @override
  int get hashCode => Object.hash(RunStep, statementId);
}

/// `@ToAssistant(message, context?)`. The dispatcher evaluates the
/// ASTs and forwards the resulting strings to the registered
/// `onContinueConversation` callback.
///
/// Marked `@experimental` per D12.
@experimental
final class ContinueConversationStep extends ActionStep {
  /// Creates a [ContinueConversationStep].
  const ContinueConversationStep({
    required this.messageAst,
    this.contextAst,
  });

  /// The user message to enqueue (evaluated to a string at dispatch).
  final AstNode messageAst;

  /// Optional extra context for the assistant.
  final AstNode? contextAst;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContinueConversationStep &&
          other.messageAst == messageAst &&
          other.contextAst == contextAst;

  @override
  int get hashCode =>
      Object.hash(ContinueConversationStep, messageAst, contextAst);
}

/// `@OpenUrl(url)`. The dispatcher evaluates [urlAst] and forwards
/// the resulting string to `onOpenUrl` (typically wrapping
/// `url_launcher`).
///
/// Marked `@experimental` per D12.
@experimental
final class OpenUrlStep extends ActionStep {
  /// Creates an [OpenUrlStep].
  const OpenUrlStep({required this.urlAst});

  /// The URL expression evaluated at dispatch.
  final AstNode urlAst;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OpenUrlStep && other.urlAst == urlAst;

  @override
  int get hashCode => Object.hash(OpenUrlStep, urlAst);
}

/// An ordered list of [ActionStep]s. Steps execute sequentially;
/// [RunStep] failures halt the plan, every other step type runs to
/// completion. Equality is structural over the steps list.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ActionPlan {
  /// Creates an [ActionPlan] with the given [steps].
  const ActionPlan({required this.steps});

  /// The steps in dispatch order.
  final List<ActionStep> steps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionPlan && _listEquals(steps, other.steps);

  @override
  int get hashCode => Object.hash(ActionPlan, Object.hashAll(steps));
}

/// Converts an [AstNode] into an [ActionPlan].
///
/// Recognised shapes:
///
/// - A single action-builtin call (e.g. `@Set(...)`) yields a
///   one-step plan.
/// - An [ArrayLit] of action-builtin calls yields a multi-step plan;
///   non-action elements are dropped.
///
/// Returns `null` when [node] is neither shape — the renderer treats
/// that as "this prop isn't an action handler".
///
/// Marked `@experimental` per D12.
@experimental
ActionPlan? actionPlanFromAst(AstNode node) {
  if (node is ArrayLit) {
    final steps = <ActionStep>[];
    for (final e in node.elements) {
      final s = _stepFromAst(e);
      if (s != null) steps.add(s);
    }
    return ActionPlan(steps: steps);
  }
  final s = _stepFromAst(node);
  if (s == null) return null;
  return ActionPlan(steps: [s]);
}

ActionStep? _stepFromAst(AstNode node) {
  if (node is! BuiltinCall) return null;
  switch (node.name) {
    case '@Set':
      if (node.args.length < 2) return null;
      final target = node.args[0].value;
      if (target is! StateRef) return null;
      return SetStep(
        target: '\$${target.name}',
        valueAst: node.args[1].value,
      );
    case '@Reset':
      final targets = <String>[];
      for (final a in node.args) {
        final v = a.value;
        if (v is StateRef) targets.add('\$${v.name}');
      }
      return ResetStep(targets: targets);
    case '@Run':
      if (node.args.isEmpty) return null;
      final v = node.args.first.value;
      if (v is! Reference) return null;
      return RunStep(statementId: v.name);
    case '@ToAssistant':
      if (node.args.isEmpty) return null;
      return ContinueConversationStep(
        messageAst: node.args[0].value,
        contextAst: node.args.length > 1 ? node.args[1].value : null,
      );
    case '@OpenUrl':
      if (node.args.isEmpty) return null;
      return OpenUrlStep(urlAst: node.args.first.value);
  }
  return null;
}

/// Executes [plan] step-by-step against the live [context].
///
/// `SetStep` writes to `context.store`. `ResetStep` looks up the
/// declared default in [stateDefaults] (typically built from
/// `meta.stateDecls`) and writes that. The three integration steps —
/// `RunStep`, `ContinueConversationStep`, `OpenUrlStep` — fire their
/// respective callbacks; absent callbacks make those step kinds
/// silent no-ops.
///
/// Per the lang-reference, a [RunStep] failure (the callback throws)
/// halts the rest of the plan. Other step kinds always continue.
///
/// Marked `@experimental` per D12.
@experimental
Future<void> dispatchAction({
  required ActionPlan plan,
  required EvalContext context,
  Map<String, AstNode> stateDefaults = const <String, AstNode>{},
  Future<void> Function(String statementId)? onRun,
  void Function(String message, String? extraContext)? onContinueConversation,
  void Function(String url)? onOpenUrl,
}) async {
  for (final step in plan.steps) {
    switch (step) {
      case SetStep():
        final v = evaluate(step.valueAst, context);
        context.store.set(step.target, v);
      case ResetStep():
        for (final t in step.targets) {
          final defAst = stateDefaults[t];
          if (defAst == null) {
            context.errors.add(
              EvaluationError(
                message: '@Reset target $t has no declared default',
              ),
            );
          } else {
            final v = evaluate(defAst, context);
            context.store.set(t, v);
          }
        }
      case RunStep():
        if (onRun != null) {
          try {
            await onRun(step.statementId);
          } on Object {
            return;
          }
        }
      case ContinueConversationStep():
        if (onContinueConversation != null) {
          final msg = evaluate(step.messageAst, context);
          if (msg is String) {
            String? extra;
            final cAst = step.contextAst;
            if (cAst != null) {
              final c = evaluate(cAst, context);
              if (c is String) extra = c;
            }
            onContinueConversation(msg, extra);
          }
        }
      case OpenUrlStep():
        if (onOpenUrl != null) {
          final u = evaluate(step.urlAst, context);
          if (u is String) onOpenUrl(u);
        }
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
