// ActionPlan, ActionStep, actionPlanFromAst, and dispatchAction
// contract tests.
//
// Each step type has a small structural test (== / hashCode plus
// distinguishing fields). actionPlanFromAst is exercised through the
// real parser to confirm the AST-to-step mapping for every
// recognised builtin and the rejection paths. dispatchAction is
// driven through every variant — including @Run failure (halts the
// rest of the plan but never throws to the caller), @ToAssistant /
// @OpenUrl skip-emission for non-string eval results, and
// formState / formName / humanFriendlyMessage propagation.
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
  Future<void> Function(RunStep step)? onRun,
  void Function(ActionEvent event)? onHostStep,
  Map<String, Object?>? formState,
  String? formName,
  String? humanFriendlyMessage,
}) {
  return dispatchAction(
    plan: plan,
    context: context,
    stateDefaults: stateDefaults,
    onRun: onRun ?? (_) async {},
    onHostStep: onHostStep ?? (_) {},
    formState: formState,
    formName: formName,
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

    test('OpenUrlStep is structural', () {
      const a = OpenUrlStep(urlAst: Literal('https://x', offset: 0));
      const b = OpenUrlStep(urlAst: Literal('https://x', offset: 9));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(
        a,
        isNot(
          equals(
            const OpenUrlStep(urlAst: Literal('https://y', offset: 0)),
          ),
        ),
      );
    });

    group('CustomActionStep', () {
      test('identical fields compare equal with matching hashCodes', () {
        const a = CustomActionStep(
          type: 'custom',
          params: <String, Object?>{'k': 'v', 'n': 1},
          humanFriendlyMessage: 'msg',
        );
        const b = CustomActionStep(
          type: 'custom',
          params: <String, Object?>{'k': 'v', 'n': 1},
          humanFriendlyMessage: 'msg',
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different type ⇒ not equal', () {
        const a = CustomActionStep(type: 'a');
        const b = CustomActionStep(type: 'b');
        expect(a, isNot(equals(b)));
      });

      test('different humanFriendlyMessage ⇒ not equal', () {
        const a = CustomActionStep(type: 't', humanFriendlyMessage: 'x');
        const b = CustomActionStep(type: 't', humanFriendlyMessage: 'y');
        expect(a, isNot(equals(b)));
      });

      test('null vs empty humanFriendlyMessage ⇒ not equal', () {
        const a = CustomActionStep(type: 't');
        const b = CustomActionStep(type: 't', humanFriendlyMessage: '');
        expect(a, isNot(equals(b)));
      });

      test('same params in different insertion order ⇒ still equal', () {
        const a = CustomActionStep(
          type: 't',
          params: <String, Object?>{'a': 1, 'b': 2},
        );
        const b = CustomActionStep(
          type: 't',
          params: <String, Object?>{'b': 2, 'a': 1},
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different params keys ⇒ not equal', () {
        const a = CustomActionStep(
          type: 't',
          params: <String, Object?>{'a': 1},
        );
        const b = CustomActionStep(
          type: 't',
          params: <String, Object?>{'b': 1},
        );
        expect(a, isNot(equals(b)));
      });
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
  });

  group('actionPlanFromAst', () {
    test('@Set produces a one-step plan with target and valueAst', () {
      final plan = _planFor(r'a = @Set($count, $count + 1)');
      expect(plan.steps, hasLength(1));
      final step = plan.steps.single as SetStep;
      expect(step.target, r'$count');
      expect(step.valueAst, isA<BinaryOp>());
    });

    test('@Set with fewer than 2 args returns null', () {
      expect(actionPlanFromAst(_rhs(r'a = @Set($count)')), isNull);
    });

    test('@Set whose first arg is not a StateRef returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Set(plain, 1)')), isNull);
    });

    test('@Reset gathers every StateRef target', () {
      final plan = _planFor(r'a = @Reset($a, $b, $c)');
      final step = plan.steps.single as ResetStep;
      expect(step.targets, [r'$a', r'$b', r'$c']);
    });

    test('@Reset drops non-StateRef args', () {
      final plan = _planFor(r'a = @Reset($a, plain, $c)');
      final step = plan.steps.single as ResetStep;
      expect(step.targets, [r'$a', r'$c']);
    });

    test('@Run with a Reference produces a RunStep', () {
      final plan = _planFor('a = @Run(refresh)');
      final step = plan.steps.single as RunStep;
      expect(step.statementId, 'refresh');
    });

    test('@Run with no args returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Run()')), isNull);
    });

    test('@Run with a non-Reference arg returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Run("x")')), isNull);
    });

    test('@ToAssistant with one arg leaves contextAst null', () {
      final plan = _planFor('a = @ToAssistant("hello")');
      final step = plan.steps.single as ContinueConversationStep;
      expect(step.messageAst, isA<Literal>());
      expect(step.contextAst, isNull);
    });

    test('@ToAssistant with two args sets both ASTs', () {
      final plan = _planFor('a = @ToAssistant("hello", "extra")');
      final step = plan.steps.single as ContinueConversationStep;
      expect(step.messageAst, isA<Literal>());
      expect(step.contextAst, isA<Literal>());
    });

    test('@ToAssistant with no args returns null', () {
      expect(actionPlanFromAst(_rhs('a = @ToAssistant()')), isNull);
    });

    test('@OpenUrl wraps the URL AST', () {
      final plan = _planFor('a = @OpenUrl("https://x")');
      final step = plan.steps.single as OpenUrlStep;
      expect(step.urlAst, isA<Literal>());
    });

    test('@OpenUrl with no args returns null', () {
      expect(actionPlanFromAst(_rhs('a = @OpenUrl()')), isNull);
    });

    test('an unrecognized builtin name returns null', () {
      expect(actionPlanFromAst(_rhs('a = @Unknown()')), isNull);
    });

    test('a non-builtin AST node returns null', () {
      expect(actionPlanFromAst(const Literal(1, offset: 0)), isNull);
    });

    test('ArrayLit of action builtins yields a multi-step plan', () {
      final plan = _planFor(r'a = [@Set($a, 1), @Run(load)]');
      expect(plan.steps, hasLength(2));
      expect(plan.steps[0], isA<SetStep>());
      expect(plan.steps[1], isA<RunStep>());
    });

    test('ArrayLit with mixed action / non-action drops non-actions', () {
      final plan = _planFor(r'a = [@Set($a, 1), 42, "noise"]');
      expect(plan.steps, hasLength(1));
      expect(plan.steps.single, isA<SetStep>());
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
      final plan = _planFor(r'a = @Set($count, 1 + 1)');
      await _run(plan, ctx);
      expect(ctx.store.get(r'$count'), 2);
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
      final plan = _planFor(r'a = @Reset($count)');
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
        final plan = _planFor(r'a = @Reset($a, $missing, $b)');
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

    test('RunStep invokes onRun with the step', () async {
      final ctx = fresh();
      final plan = _planFor('a = @Run(refresh)');
      RunStep? seen;
      await _run(
        plan,
        ctx,
        onRun: (step) async {
          seen = step;
        },
      );
      expect(seen?.statementId, 'refresh');
    });

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
          onRun: (_) async => throw Exception('boom'),
        );
        expect(ctx.store.get(r'$count'), isNull);
      },
    );

    test(
      'ContinueConversationStep emits an ActionEvent with type and '
      'params populated',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = @ToAssistant("hello", "extra")');
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events, hasLength(1));
        final event = events.single;
        expect(event.type, BuiltinActionType.continueConversation);
        expect(event.humanFriendlyMessage, 'hello');
        expect(event.params['context'], 'extra');
      },
    );

    test(
      'ContinueConversationStep without context arg leaves params '
      'empty of "context"',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = @ToAssistant("hello")');
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events.single.params.containsKey('context'), isFalse);
      },
    );

    test(
      'ContinueConversationStep skips emission when message evaluates '
      'non-string',
      () async {
        final ctx = fresh();
        const plan = ActionPlan(
          steps: [
            ContinueConversationStep(messageAst: Literal(123, offset: 0)),
          ],
        );
        final events = <ActionEvent>[];
        await _run(plan, ctx, onHostStep: events.add);
        expect(events, isEmpty);
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
        expect(events.single.params.containsKey('context'), isFalse);
      },
    );

    test('OpenUrlStep emits openUrl event with url in params', () async {
      final ctx = fresh();
      final plan = _planFor('a = @OpenUrl("https://example.com")');
      final events = <ActionEvent>[];
      await _run(plan, ctx, onHostStep: events.add);
      expect(events.single.type, BuiltinActionType.openUrl);
      expect(events.single.params['url'], 'https://example.com');
    });

    test('OpenUrlStep skips emission when url evaluates non-string', () async {
      final ctx = fresh();
      const plan = ActionPlan(
        steps: [OpenUrlStep(urlAst: Literal(42, offset: 0))],
      );
      final events = <ActionEvent>[];
      await _run(plan, ctx, onHostStep: events.add);
      expect(events, isEmpty);
    });

    test('CustomActionStep emits its type and params verbatim', () async {
      final ctx = fresh();
      const plan = ActionPlan(
        steps: [
          CustomActionStep(
            type: 'submit',
            params: <String, Object?>{'a': 1, 'b': 'two'},
            humanFriendlyMessage: 'doing it',
          ),
        ],
      );
      final events = <ActionEvent>[];
      await _run(plan, ctx, onHostStep: events.add);
      final event = events.single;
      expect(event.type, 'submit');
      expect(event.humanFriendlyMessage, 'doing it');
      expect(event.params, <String, Object?>{'a': 1, 'b': 'two'});
    });

    test(
      'formState, formName, and humanFriendlyMessage propagate to every '
      'host-routed event',
      () async {
        final ctx = fresh();
        final plan = _planFor(
          'a = [@ToAssistant("hello"), @OpenUrl("https://x")]',
        );
        final events = <ActionEvent>[];
        final formState = Map<String, Object?>.unmodifiable(
          <String, Object?>{'name': 'Alice'},
        );
        await _run(
          plan,
          ctx,
          onHostStep: events.add,
          formState: formState,
          formName: 'signup',
          humanFriendlyMessage: 'passed-through',
        );
        expect(events, hasLength(2));
        for (final e in events) {
          expect(e.formName, 'signup');
          expect(e.formState, same(formState));
        }
        // @ToAssistant prefers the evaluated message over the passed-in
        // humanFriendlyMessage; @OpenUrl keeps the passed-in one.
        expect(events[0].humanFriendlyMessage, 'hello');
        expect(events[1].humanFriendlyMessage, 'passed-through');
      },
    );

    test('formState arrives at onHostStep unmodifiable', () async {
      final ctx = fresh();
      final plan = _planFor('a = @ToAssistant("hi")');
      final events = <ActionEvent>[];
      await _run(
        plan,
        ctx,
        onHostStep: events.add,
        formState: Map<String, Object?>.unmodifiable(
          <String, Object?>{'k': 'v'},
        ),
      );
      expect(
        () => events.single.formState!['k'] = 'mutated',
        throwsUnsupportedError,
      );
    });
  });
}
