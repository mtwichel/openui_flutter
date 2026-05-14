// ActionPlan, ActionStep, actionPlanFromAst, and dispatchAction
// contract tests.
//
// Each step type has a small structural test (== / hashCode plus
// distinguishing fields). actionPlanFromAst is exercised through the
// real parser to confirm the AST-to-step mapping for every
// recognised builtin and the rejection paths. dispatchAction is
// driven through every variant — including @Run failure (emits a failed
// event, halts the rest of the plan, never throws to the caller),
// @ToAssistant with a non-string message (emits with success: false),
// humanFriendlyMessage propagation, and @Set / @Reset / @Run emitting
// ActionEvents for every step outcome.
import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

ActionPlan _planFor(String source) {
  final program = parseProgram(source);
  final rhs = program.statements.single.expression;
  return actionPlanFromAst(rhs)!;
}

AstNode _rhs(String source) =>
    parseProgram(source).statements.single.expression;

Future<void> _run(
  ActionPlan plan,
  EvalContext context, {
  Map<String, AstNode> stateDefaults = const <String, AstNode>{},
  Future<void> Function(RunStep step, Map<String, Object?> args)? onRun,
  void Function(ActionEvent event)? onHostStep,
  String? humanFriendlyMessage,
}) {
  return dispatchAction(
    plan: plan,
    context: context,
    stateDefaults: stateDefaults,
    onRun: onRun ?? (_, _) async {},
    onHostStep: onHostStep ?? (_) {},
    humanFriendlyMessage: humanFriendlyMessage,
  );
}

void main() {
  group('ActionStep equality', () {
    test('SetStep is structural', () {
      const a = SetStep(target: r'$count', valueAst: Literal(1, offset: 0));
      const b = SetStep(target: r'$count', valueAst: Literal(1, offset: 9));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(
        a,
        isNot(
          equals(
            const SetStep(
              target: r'$other',
              valueAst: Literal(1, offset: 0),
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const SetStep(
              target: r'$count',
              valueAst: Literal(2, offset: 0),
            ),
          ),
        ),
      );
    });

    test('ResetStep compares the targets list element-wise', () {
      const a = ResetStep(targets: [r'$a', r'$b']);
      const b = ResetStep(targets: [r'$a', r'$b']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(a, isNot(equals(const ResetStep(targets: [r'$a']))));
      expect(
        a,
        isNot(equals(const ResetStep(targets: [r'$a', r'$c']))),
      );
    });

    test('RunStep is structural', () {
      const a = RunStep(statementId: 'refresh');
      const b = RunStep(statementId: 'refresh');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(a, isNot(equals(const RunStep(statementId: 'other'))));
      expect(
        a,
        isNot(
          equals(
            const RunStep(
              statementId: 'refresh',
              argsAst: <String, AstNode>{'message': Literal('x', offset: 0)},
            ),
          ),
        ),
      );
    });

    test('RunStep argsAst equality walks map entries (missing key)', () {
      const a = RunStep(
        statementId: 'r',
        argsAst: {'k': Literal(1, offset: 0)},
      );
      const b = RunStep(
        statementId: 'r',
        argsAst: {'other': Literal(1, offset: 0)},
      );
      expect(a, isNot(equals(b)));
    });

    test('RunStep argsAst equality walks map entries (different value)', () {
      const a = RunStep(
        statementId: 'r',
        argsAst: {'k': Literal(1, offset: 0)},
      );
      const b = RunStep(
        statementId: 'r',
        argsAst: {'k': Literal(2, offset: 0)},
      );
      expect(a, isNot(equals(b)));
    });

    test('ContinueConversationStep compares both ASTs', () {
      const a = ContinueConversationStep(
        messageAst: Literal('hi', offset: 0),
        contextAst: Literal('ctx', offset: 0),
      );
      const b = ContinueConversationStep(
        messageAst: Literal('hi', offset: 9),
        contextAst: Literal('ctx', offset: 9),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(
        a,
        isNot(
          equals(
            const ContinueConversationStep(
              messageAst: Literal('hi', offset: 0),
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const ContinueConversationStep(
              messageAst: Literal('bye', offset: 0),
              contextAst: Literal('ctx', offset: 0),
            ),
          ),
        ),
      );
    });
  });

  group('ActionPlan', () {
    test('equality is structural over the steps list', () {
      const a = ActionPlan(
        steps: [RunStep(statementId: 'r')],
      );
      const b = ActionPlan(
        steps: [RunStep(statementId: 'r')],
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(a, isNot(equals(const ActionPlan(steps: <ActionStep>[]))));
    });

    test('implicitContinueConversationPlan mirrors @ToAssistant(...) plan', () {
      final implicit = implicitContinueConversationPlan('Hello');
      final parsed = actionPlanFromAst(
        _rhs('a = [@ToAssistant("Hello")]'),
      );
      expect(parsed, isNotNull);
      expect(implicit, equals(parsed));
    });
  });

  group('actionPlanFromAst', () {
    test('@Set produces a one-step plan with target and valueAst', () {
      final plan = _planFor(r'a = [@Set($count, $count + 1)]');
      expect(plan.steps, hasLength(1));
      final step = plan.steps.single as SetStep;
      expect(step.target, r'$count');
      expect(step.valueAst, isA<BinaryOp>());
    });

    test('@Set with fewer than 2 args returns null', () {
      expect(actionPlanFromAst(_rhs(r'a = @Set($count)')), isNull);
      expect(actionPlanFromAst(_rhs(r'a = [@Set($count)]')), isNull);
    });

    test('@Set whose first arg is not a StateRef returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Set(plain, 1)')), isNull);
      expect(actionPlanFromAst(_rhs('a = [@Set(plain, 1)]')), isNull);
    });

    test('@Reset gathers every StateRef target', () {
      final plan = _planFor(r'a = [@Reset($a, $b, $c)]');
      final step = plan.steps.single as ResetStep;
      expect(step.targets, [r'$a', r'$b', r'$c']);
    });

    test('@Reset drops non-StateRef args', () {
      final plan = _planFor(r'a = [@Reset($a, plain, $c)]');
      final step = plan.steps.single as ResetStep;
      expect(step.targets, [r'$a', r'$c']);
    });

    test('@Run with a Reference produces a RunStep', () {
      final plan = _planFor('a = [@Run(refresh)]');
      final step = plan.steps.single as RunStep;
      expect(step.statementId, 'refresh');
      expect(step.argsAst, isEmpty);
    });

    test('@Run parses trailing named args into RunStep.argsAst', () {
      final plan = _planFor('a = [@Run(snackbar, message: "Hello")]');
      final step = plan.steps.single as RunStep;
      expect(step.statementId, 'snackbar');
      expect(step.argsAst.keys, contains('message'));
      expect(step.argsAst['message'], const Literal('Hello', offset: 0));
    });

    test('@Run with no args returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Run()')), isNull);
      expect(actionPlanFromAst(_rhs('a = [@Run()]')), isNull);
    });

    test('@Run with a non-Reference arg returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Run("x")')), isNull);
      expect(actionPlanFromAst(_rhs('a = [@Run("x")]')), isNull);
    });

    test('@ToAssistant with one arg leaves contextAst null', () {
      final plan = _planFor('a = [@ToAssistant("hello")]');
      final step = plan.steps.single as ContinueConversationStep;
      expect(step.messageAst, isA<Literal>());
      expect(step.contextAst, isNull);
    });

    test('@ToAssistant with two args sets both ASTs', () {
      final plan = _planFor('a = [@ToAssistant("hello", "extra")]');
      final step = plan.steps.single as ContinueConversationStep;
      expect(step.messageAst, isA<Literal>());
      expect(step.contextAst, isA<Literal>());
    });

    test('@ToAssistant with no args returns null', () {
      expect(actionPlanFromAst(_rhs('a = @ToAssistant()')), isNull);
      expect(actionPlanFromAst(_rhs('a = [@ToAssistant()]')), isNull);
    });

    test('an unrecognized builtin name returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Unknown()')), isNull);
      expect(actionPlanFromAst(_rhs('a = [@Unknown()]')), isNull);
    });

    test('a non-builtin AST node returns null', () {
      expect(actionPlanFromAst(const Literal(1, offset: 0)), isNull);
    });

    test('bare action builtin is not an action plan', () {
      expect(actionPlanFromAst(_rhs(r'a = @Set($count, 1)')), isNull);
    });

    test('empty array is not an action plan', () {
      expect(actionPlanFromAst(_rhs('a = []')), isNull);
    });

    test('ArrayLit of action builtins yields a multi-step plan', () {
      final plan = _planFor(r'a = [@Set($a, 1), @Run(load)]');
      expect(plan.steps, hasLength(2));
      expect(plan.steps[0], isA<SetStep>());
      expect(plan.steps[1], isA<RunStep>());
    });

    test('Action(...) is not accepted as an action plan', () {
      expect(
        actionPlanFromAst(_rhs(r'a = Action([@Set($a, 1), @Run(load)])')),
        isNull,
      );
      expect(
        actionPlanFromAst(_rhs('a = Action(@ToAssistant("hello"))')),
        isNull,
      );
    });

    test('ArrayLit with a non-action element returns null', () {
      expect(
        actionPlanFromAst(_rhs(r'a = [@Set($a, 1), 42, "noise"]')),
        isNull,
      );
    });
  });

  group('dispatchAction', () {
    EvalContext fresh({Map<String, Object?>? state}) {
      final store = Store();
      if (state != null) state.forEach(store.set);
      return EvalContext(statements: const [], store: store);
    }

    test('SetStep evaluates valueAst and writes to the store', () async {
      final ctx = fresh();
      final plan = _planFor(r'a = [@Set($count, 1 + 1)]');
      await _run(plan, ctx);
      expect(ctx.store.get(r'$count'), 2);
    });

    test('SetStep emits an ActionEvent after writing the store', () async {
      final ctx = fresh();
      final plan = _planFor(r'a = [@Set($count, 1 + 1)]');
      final events = <ActionEvent>[];
      await _run(plan, ctx, onHostStep: events.add);
      expect(events, hasLength(1));
      expect(events.single.type, BuiltinActionType.set);
      expect(events.single.params['target'], r'$count');
      expect(events.single.params['value'], 2);
    });

    test('SetStep sees fresh store state across sequential steps', () async {
      final ctx = fresh(state: {r'$count': 0});
      final plan = _planFor(
        r'a = [@Set($count, $count + 1), @Set($count, $count + 1)]',
      );
      await _run(plan, ctx);
      expect(ctx.store.get(r'$count'), 2);
    });

    test('ResetStep evaluates the declared default and writes', () async {
      final ctx = fresh(state: {r'$count': 99});
      final plan = _planFor(r'a = [@Reset($count)]');
      final defaults = <String, AstNode>{
        r'$count': const Literal(0, offset: 0),
      };
      await _run(plan, ctx, stateDefaults: defaults);
      expect(ctx.store.get(r'$count'), 0);
    });

    test(
      'ResetStep with a missing default emits an error and continues',
      () async {
        final ctx = fresh(state: {r'$a': 5, r'$b': 10});
        final plan = _planFor(r'a = [@Reset($a, $missing, $b)]');
        final defaults = <String, AstNode>{
          r'$a': const Literal(0, offset: 0),
          r'$b': const Literal(1, offset: 0),
        };
        await _run(plan, ctx, stateDefaults: defaults);
        expect(ctx.store.get(r'$a'), 0);
        expect(ctx.store.get(r'$b'), 1);
        expect(ctx.errors, hasLength(1));
        expect(
          (ctx.errors.single as EvaluationError).message,
          contains(r'$missing'),
        );
      },
    );

    test(
      'ResetStep emits ActionEvents for every target, including skipped '
      'targets without a default',
      () async {
        final ctx = fresh(state: {r'$a': 5, r'$b': 10});
        final plan = _planFor(r'a = [@Reset($a, $missing, $b)]');
        final defaults = <String, AstNode>{
          r'$a': const Literal(0, offset: 0),
          r'$b': const Literal(1, offset: 0),
        };
        final events = <ActionEvent>[];
        await _run(plan, ctx, stateDefaults: defaults, onHostStep: events.add);
        expect(events, hasLength(3));
        expect(events.every((e) => e.type == BuiltinActionType.reset), isTrue);
        expect(events[0].params['target'], r'$a');
        expect(events[0].params['success'], isTrue);
        expect(events[1].params['target'], r'$missing');
        expect(events[1].params['success'], isFalse);
        expect(events[2].params['target'], r'$b');
        expect(events[2].params['success'], isTrue);
      },
    );

    test('RunStep invokes onRun with the step', () async {
      final ctx = fresh();
      final plan = _planFor('a = [@Run(refresh)]');
      RunStep? seen;
      await _run(
        plan,
        ctx,
        onRun: (step, _) async {
          seen = step;
        },
      );
      expect(seen?.statementId, 'refresh');
    });

    test('RunStep evaluates named args and passes them to onRun', () async {
      final ctx = fresh(state: const <String, Object?>{r'$name': 'Hello'});
      final plan = _planFor(r'a = [@Run(snackbar, message: $name)]');
      Map<String, Object?>? seenArgs;
      await _run(
        plan,
        ctx,
        onRun: (_, args) async {
          seenArgs = args;
        },
      );
      expect(seenArgs, isNotNull);
      expect(seenArgs!['message'], 'Hello');
    });

    test('RunStep emits a success ActionEvent after onRun succeeds', () async {
      final ctx = fresh();
      final plan = _planFor('a = [@Run(snackbar, message: "hi")]');
      final events = <ActionEvent>[];
      await _run(
        plan,
        ctx,
        onRun: (_, _) async {},
        onHostStep: events.add,
      );
      expect(events, hasLength(1));
      expect(events.single.type, BuiltinActionType.run);
      expect(events.single.params['statementId'], 'snackbar');
      final args = events.single.params['args']! as Map<String, Object?>;
      expect(args['message'], 'hi');
      expect(events.single.params['success'], isTrue);
    });

    test('RunStep emits a failed ActionEvent when onRun throws', () async {
      final ctx = fresh();
      final plan = _planFor('a = [@Run(x)]');
      final events = <ActionEvent>[];
      await _run(
        plan,
        ctx,
        onRun: (_, _) async => throw Exception('boom'),
        onHostStep: events.add,
      );
      expect(events, hasLength(1));
      expect(events.single.type, BuiltinActionType.run);
      expect(events.single.params['success'], isFalse);
      expect(events.single.params['error'], contains('boom'));
    });

    test(
      'RunStep maps thrown OpenUIError with message to error string',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = [@Run(x)]');
        final events = <ActionEvent>[];
        await _run(
          plan,
          ctx,
          onRun: (_, _) async =>
              throw const ParseError(message: 'parse failed', offset: 0),
          onHostStep: events.add,
        );
        expect(events.single.params['error'], 'parse failed');
      },
    );

    test(
      'RunStep maps thrown OpenUIError without message using toString',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = [@Run(x)]');
        final events = <ActionEvent>[];
        await _run(
          plan,
          ctx,
          onRun: (_, _) async => throw const CyclicStateError(
            cycle: [r'$a', r'$b', r'$a'],
          ),
          onHostStep: events.add,
        );
        final err = events.single.params['error']! as String;
        expect(err, contains('CyclicStateError'));
        expect(err, contains(r'$a'));
      },
    );

    test(
      'RunStep callback throwing halts the rest of the plan but does '
      'not propagate',
      () async {
        final ctx = fresh();
        final plan = _planFor(
          r'a = [@Run(load), @Set($count, 99)]',
        );
        // dispatchAction must not throw — the throw is contained.
        await _run(
          plan,
          ctx,
          onRun: (_, _) async => throw Exception('boom'),
        );
        expect(ctx.store.get(r'$count'), isNull);
      },
    );

    test(
      'ContinueConversationStep emits an ActionEvent with type and '
      'params populated',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = [@ToAssistant("hello", "extra")]');
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events, hasLength(1));
        final event = events.single;
        expect(event.type, BuiltinActionType.continueConversation);
        expect(event.humanFriendlyMessage, 'hello');
        expect(event.params['success'], isTrue);
        expect(event.params['context'], 'extra');
      },
    );

    test(
      'ContinueConversationStep without context arg leaves params '
      'empty of "context"',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = [@ToAssistant("hello")]');
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events.single.params['success'], isTrue);
        expect(events.single.params.containsKey('context'), isFalse);
      },
    );

    test(
      'ContinueConversationStep emits with success false when message '
      'evaluates non-string',
      () async {
        final ctx = fresh();
        const plan = ActionPlan(
          steps: [
            ContinueConversationStep(messageAst: Literal(123, offset: 0)),
          ],
        );
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.continueConversation);
        expect(events.single.params['success'], isFalse);
        expect(events.single.params['evaluated'], 123);
      },
    );

    test(
      'ContinueConversationStep emits even when contextAst is non-string '
      '(drops context only)',
      () async {
        final ctx = fresh();
        const plan = ActionPlan(
          steps: [
            ContinueConversationStep(
              messageAst: Literal('hello', offset: 0),
              contextAst: Literal(99, offset: 0),
            ),
          ],
        );
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events.single.humanFriendlyMessage, 'hello');
        expect(events.single.params['success'], isTrue);
        expect(events.single.params.containsKey('context'), isFalse);
      },
    );
  });
}
