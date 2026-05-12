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

/// `@Run(refresh)`. Runtime-internal — the dispatcher routes the step
/// to the renderer's `QueryManager`, never to the host. A thrown
/// failure halts the rest of the plan (mutations halt on failure).
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
/// ASTs and emits an [ActionEvent] with
/// [BuiltinActionType.continueConversation].
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

/// `@OpenUrl(url)`. The dispatcher evaluates [urlAst] and emits an
/// [ActionEvent] with [BuiltinActionType.openUrl] and the URL in
/// `params['url']`.
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

/// Component-emitted action step with a host-visible custom [type].
///
/// Constructed by component Dart code (not the parser): [params] are
/// plain Dart values that pass straight through to the emitted
/// [ActionEvent.params].
///
/// Marked `@experimental` per D12.
@experimental
final class CustomActionStep extends ActionStep {
  /// Creates a [CustomActionStep].
  const CustomActionStep({
    required this.type,
    this.params = const <String, Object?>{},
    this.humanFriendlyMessage,
  });

  /// The host-visible action type. Surfaces as [ActionEvent.type].
  final String type;

  /// Type-specific payload. Surfaces as [ActionEvent.params].
  final Map<String, Object?> params;

  /// Optional user-facing message. Surfaces as
  /// [ActionEvent.humanFriendlyMessage].
  final String? humanFriendlyMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomActionStep &&
          other.type == type &&
          other.humanFriendlyMessage == humanFriendlyMessage &&
          _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    CustomActionStep,
    type,
    humanFriendlyMessage,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
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

/// One host-visible action emission.
///
/// The renderer's `onAction` callback fires once per host-routed step:
/// `@ToAssistant`, `@OpenUrl`, and any [CustomActionStep]. `@Set`,
/// `@Reset`, and `@Run` are runtime-internal and never surface here.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ActionEvent {
  /// Creates an [ActionEvent].
  const ActionEvent({
    required this.type,
    this.humanFriendlyMessage,
    this.params = const <String, Object?>{},
    this.formState,
    this.formName,
  });

  /// Open string. Built-in values live on [BuiltinActionType]. Custom
  /// types come from component code constructing a [CustomActionStep].
  final String type;

  /// User-facing message. For `@ToAssistant`, the evaluated message.
  /// For implicit Button activation, the Button's `label`. For
  /// `@OpenUrl` and custom types, the component supplies whatever is
  /// meaningful (may be `null` or empty).
  final String? humanFriendlyMessage;

  /// Type-specific payload. For `@OpenUrl`: `{'url': String}`. For
  /// `@ToAssistant`: `{'context': String}` when the second arg is
  /// present. For custom types: whatever the component passes.
  final Map<String, Object?> params;

  /// Form values at the moment the action fires, or `null` when not
  /// inside a Form. The map is unmodifiable.
  final Map<String, Object?>? formState;

  /// Form name, or `null` when not inside a Form.
  final String? formName;
}

/// Canonical [ActionEvent.type] strings for built-in action steps.
///
/// Hosts compare directly:
///
/// ```dart
/// if (event.type == BuiltinActionType.continueConversation) { ... }
/// ```
///
/// `abstract final` blocks instantiation and extension — this is a
/// namespace for the canonical strings.
///
/// Marked `@experimental` per D12.
@experimental
abstract final class BuiltinActionType {
  /// `@ToAssistant` and implicit-Button activations.
  static const String continueConversation = 'continueConversation';

  /// `@OpenUrl`.
  static const String openUrl = 'openUrl';
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
/// The parser is closed to the five JS-defined builtins. Custom
/// action types reach the host through component code constructing a
/// [CustomActionStep] directly.
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
/// `meta.stateDecls`) and writes that. `RunStep` is dispatched
/// through [onRun] (the renderer routes it to its `QueryManager`).
/// `ContinueConversationStep`, `OpenUrlStep`, and any
/// [CustomActionStep] are emitted as [ActionEvent]s through
/// [onHostStep].
///
/// **Rethrow contract**: [dispatchAction] never throws to callers.
/// `onRun` failures are caught internally and halt the rest of the
/// plan. Eval failures on `@ToAssistant` / `@OpenUrl` for non-string
/// results cause skip-emission and the plan continues. Other step
/// kinds do not throw.
///
/// [formState] arrives already wrapped in `Map.unmodifiable` by the
/// caller (the renderer wraps once at snapshot time). The dispatcher
/// passes it through verbatim to every emitted [ActionEvent].
///
/// Marked `@experimental` per D12.
@experimental
Future<void> dispatchAction({
  required ActionPlan plan,
  required EvalContext context,
  required Future<void> Function(RunStep step) onRun,
  required void Function(ActionEvent event) onHostStep,
  Map<String, AstNode> stateDefaults = const <String, AstNode>{},
  Map<String, Object?>? formState,
  String? formName,
  String? humanFriendlyMessage,
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
        try {
          await onRun(step);
        } on Object {
          return;
        }
      case ContinueConversationStep():
        final msg = evaluate(step.messageAst, context);
        if (msg is! String) continue;
        final params = <String, Object?>{};
        final cAst = step.contextAst;
        if (cAst != null) {
          final c = evaluate(cAst, context);
          if (c is String) params['context'] = c;
        }
        onHostStep(
          ActionEvent(
            type: BuiltinActionType.continueConversation,
            humanFriendlyMessage: msg,
            params: params,
            formState: formState,
            formName: formName,
          ),
        );
      case OpenUrlStep():
        final u = evaluate(step.urlAst, context);
        if (u is! String) continue;
        onHostStep(
          ActionEvent(
            type: BuiltinActionType.openUrl,
            humanFriendlyMessage: humanFriendlyMessage,
            params: <String, Object?>{'url': u},
            formState: formState,
            formName: formName,
          ),
        );
      case CustomActionStep():
        onHostStep(
          ActionEvent(
            type: step.type,
            humanFriendlyMessage: step.humanFriendlyMessage,
            params: step.params,
            formState: formState,
            formName: formName,
          ),
        );
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

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
