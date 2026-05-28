import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';
import 'package:openui_core/src/eval/evaluator.dart';
import 'package:openui_core/src/parser/parser.dart';

/// Sealed action-step variants. An [ActionPlan] is a list of these,
/// and [dispatchAction] executes them sequentially.
///
/// All non-trivial values (Set values, ToAssistant message + context)
/// are carried as unevaluated [AstNode]s and re-evaluated
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
  const RunStep({required this.statementId, this.argsAst = const {}});

  /// The id of the statement to re-fire.
  final String statementId;

  /// Optional named args to pass to tool-like Run targets.
  final Map<String, AstNode> argsAst;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunStep &&
          other.statementId == statementId &&
          _mapEquals(other.argsAst, argsAst);

  @override
  int get hashCode => Object.hash(
    RunStep,
    statementId,
    Object.hashAllUnordered(
      argsAst.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
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
/// Hosts receive these from [dispatchAction] for every built-in step
/// (`@Set`, `@Reset`, `@Run`, `@ToAssistant`). `@Set` always succeeds once
/// reached. `@Reset` / `@Run` / `@ToAssistant` include `params['success']` when the outcome
/// is not a straightforward success (`false` for skipped reset targets,
/// failed `onRun`, or a non-string `@ToAssistant` message).
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
  });

  /// Open string. Built-in values live on [BuiltinActionType].
  final String type;

  /// User-facing summary when present. For `@ToAssistant`, the evaluated
  /// message. For implicit Button activation, the Button's `label`. For
  /// `@Set` / `@Reset` / `@Run`, a short description of the step. For custom
  /// types, whatever the component supplies (may be `null` or empty).
  final String? humanFriendlyMessage;

  /// Type-specific payload. For `@ToAssistant`: `success` is `false`
  /// when the message did not evaluate to a string; otherwise `success`
  /// is `true` and `context` may be present. For `@Set`: `target`, `value`.
  /// For `@Reset`: `target`, `value`, and `success: true`, or `target`,
  /// `success: false`, and `reason` when skipped. For `@Run`:
  /// `statementId`, `args`, and `success` plus `error` when `onRun`
  /// fails. For custom types: whatever the component passes.
  final Map<String, Object?> params;
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

  /// `@Set(...)` — store write.
  static const String set = 'set';

  /// `@Reset(...)` — store restore to declared defaults.
  static const String reset = 'reset';

  /// `@Run(...)` — tool / mutation / query invocation (after `onRun`
  /// succeeds).
  static const String run = 'run';
}

/// Converts `Action([@Set(...), ...])` into an [ActionPlan].
///
/// Steps are built from unevaluated AST via [_stepFromAst] so `@Set`
/// values re-evaluate at click time (Decision D3). Invalid step ASTs are
/// filtered (canonical JS parity). An empty step list after filtering
/// yields an [ActionPlan] with no steps (renderer treats as disabled).
///
/// Marked `@experimental` per D12.
@experimental
ActionPlan? actionPlanFromActionCall(AstNode node) {
  if (node is! CompCall || node.type != 'Action') return null;
  if (node.args.isEmpty) return const ActionPlan(steps: []);
  final stepsArg = node.args.first.value;
  if (stepsArg is! ArrayLit) return null;
  final steps = <ActionStep>[];
  for (final e in stepsArg.elements) {
    final s = _stepFromAst(e);
    if (s != null) steps.add(s);
  }
  return ActionPlan(steps: steps);
}

/// A one-step [ActionPlan] that sends [message] to the assistant, same
/// outcome as `[@ToAssistant("...")]` after evaluation.
///
/// Use when a component (for example `Button` without `action`) must call
/// `RendererScope.triggerAction` with a non-null plan per the renderer API.
ActionPlan implicitContinueConversationPlan(String message) {
  return ActionPlan(
    steps: [
      ContinueConversationStep(
        messageAst: Literal(message, offset: 0),
      ),
    ],
  );
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
      final String statementId;
      if (v is StateRef) {
        // Legacy `@Run($data)` — query ids are bare (`data`), not `$data`.
        statementId = v.name;
      } else if (v is Reference) {
        statementId = v.name;
      } else {
        return null;
      }
      final named = <String, AstNode>{};
      for (final arg in node.args.skip(1)) {
        final name = arg.name;
        if (name == null) continue;
        named[name] = arg.value;
      }
      return RunStep(statementId: statementId, argsAst: named);
    case '@ToAssistant':
      if (node.args.isEmpty) return null;
      return ContinueConversationStep(
        messageAst: node.args[0].value,
        contextAst: node.args.length > 1 ? node.args[1].value : null,
      );
  }
  return null;
}

/// Executes [plan] step-by-step against the live [context].
///
/// `SetStep` writes to `context.store`. `ResetStep` looks up the
/// declared default in [stateDefaults] (typically built from
/// `meta.stateDecls`) and writes that. `RunStep` is dispatched
/// through [onRun] (the renderer routes it to its `QueryManager`).
/// After each step (including failed or skipped outcomes), an
/// [ActionEvent] is emitted through [onHostStep] (`BuiltinActionType.set`,
/// `reset`, `run`, `continueConversation`, or the custom type).
/// `ContinueConversationStep` only performs host
/// emission (no store or `onRun` side effects inside [dispatchAction]).
///
/// **Rethrow contract**: [dispatchAction] never throws to callers.
/// `onRun` failures are caught internally, an event is emitted with
/// `params['success'] == false`, and the rest of the plan is skipped.
/// A non-string `@ToAssistant` message still emits once with
/// `success: false` and the plan continues. Other step kinds do not
/// throw.
///
/// Marked `@experimental` per D12.
@experimental
Future<void> dispatchAction({
  required ActionPlan plan,
  required EvalContext context,
  required Future<void> Function(
    RunStep step,
    Map<String, Object?> args,
  )
  onRun,
  required void Function(ActionEvent event) onHostStep,
  Map<String, AstNode> stateDefaults = const <String, AstNode>{},
  String? humanFriendlyMessage,
}) async {
  for (final step in plan.steps) {
    switch (step) {
      case SetStep():
        final v = evaluate(step.valueAst, context);
        context.store.set(step.target, v);
        onHostStep(
          ActionEvent(
            type: BuiltinActionType.set,
            humanFriendlyMessage: 'Set ${step.target}',
            params: <String, Object?>{
              'target': step.target,
              'value': v,
            },
          ),
        );
      case ResetStep():
        for (final t in step.targets) {
          final defAst = stateDefaults[t];
          if (defAst == null) {
            context.errors.add(
              EvaluationError(
                message: '@Reset target $t has no declared default',
              ),
            );
            onHostStep(
              ActionEvent(
                type: BuiltinActionType.reset,
                humanFriendlyMessage: 'Reset $t (skipped)',
                params: <String, Object?>{
                  'target': t,
                  'success': false,
                  'reason': 'no declared default',
                },
              ),
            );
          } else {
            final v = evaluate(defAst, context);
            context.store.set(t, v);
            onHostStep(
              ActionEvent(
                type: BuiltinActionType.reset,
                humanFriendlyMessage: 'Reset $t',
                params: <String, Object?>{
                  'target': t,
                  'value': v,
                  'success': true,
                },
              ),
            );
          }
        }
      case RunStep():
        final runArgs = <String, Object?>{
          for (final entry in step.argsAst.entries)
            entry.key: evaluate(entry.value, context),
        };
        try {
          await onRun(step, runArgs);
          onHostStep(
            ActionEvent(
              type: BuiltinActionType.run,
              humanFriendlyMessage: 'Run ${step.statementId}',
              params: <String, Object?>{
                'statementId': step.statementId,
                'args': runArgs,
                'success': true,
              },
            ),
          );
        } on Object catch (e) {
          onHostStep(
            ActionEvent(
              type: BuiltinActionType.run,
              humanFriendlyMessage: 'Run ${step.statementId} (failed)',
              params: <String, Object?>{
                'statementId': step.statementId,
                'args': runArgs,
                'success': false,
                'error': _dispatchErrorMessage(e),
              },
            ),
          );
          return;
        }
      case ContinueConversationStep():
        final msg = evaluate(step.messageAst, context);
        if (msg is! String) {
          onHostStep(
            ActionEvent(
              type: BuiltinActionType.continueConversation,
              params: <String, Object?>{
                'success': false,
                'reason': '@ToAssistant message did not evaluate to String',
                'evaluated': msg,
              },
            ),
          );
          continue;
        }
        final params = <String, Object?>{'success': true};
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
          ),
        );
    }
  }
}

String _dispatchErrorMessage(Object error) {
  if (error is OpenUIError) {
    return error.message ?? error.toString();
  }
  return error.toString();
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
