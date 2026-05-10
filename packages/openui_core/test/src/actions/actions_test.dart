// ActionPlan, ActionStep, actionPlanFromAst, and dispatchAction
// contract tests.
//
// Each step type has a small structural test (== / hashCode plus
// distinguishing fields). actionPlanFromAst is exercised through the
// real parser to confirm the AST-to-step mapping for every
// recognised builtin and the rejection paths. dispatchAction is
// driven through every variant — including missing-callback no-ops,
// `@Reset` with a missing default (records error, continues), and
// `@Run` failure (halts the rest of the plan).

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

ActionPlan _planFor(String source) {
  final program = parseProgram(source);
  final rhs = program.statements.single.expression;
  return actionPlanFromAst(rhs)!;
}

AstNode _rhs(String source) =>
    parseProgram(source).statements.single.expression;

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
      // Length differs.
      expect(a, isNot(equals(const ResetStep(targets: [r'$a']))));
      // Element differs.
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
      // contextAst missing in one.
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
      // messageAst differs.
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
      expect(
        a,
        isNot(equals(const ActionPlan(steps: <ActionStep>[]))),
      );
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
      // `@Set(plain, 1)` — first arg is a Reference, not a StateRef.
      expect(actionPlanFromAst(_rhs('a = @Set(plain, 1)')), isNull);
    });

    test('@Reset gathers every StateRef target', () {
      final plan = _planFor(r'a = @Reset($a, $b, $c)');
      final step = plan.steps.single as ResetStep;
      expect(step.targets, [r'$a', r'$b', r'$c']);
    });

    test('@Reset drops non-StateRef args', () {
      // `plain` is a bare Reference, not a StateRef; the dispatcher
      // would have no idea how to reset it. Drop silently.
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
      // The literal "x" is not a statement id.
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
      await dispatchAction(plan: plan, context: ctx);
      expect(ctx.store.get(r'$count'), 2);
    });

    test('SetStep sees fresh store state across sequential steps', () async {
      // Two SetSteps: the second reads $count after the first wrote.
      final ctx = fresh(state: {r'$count': 0});
      final plan = _planFor(
        r'a = [@Set($count, $count + 1), @Set($count, $count + 1)]',
      );
      await dispatchAction(plan: plan, context: ctx);
      expect(ctx.store.get(r'$count'), 2);
    });

    test('ResetStep evaluates the declared default and writes', () async {
      final ctx = fresh(state: {r'$count': 99});
      final plan = _planFor(r'a = @Reset($count)');
      final defaults = <String, AstNode>{
        r'$count': const Literal(0, offset: 0),
      };
      await dispatchAction(
        plan: plan,
        context: ctx,
        stateDefaults: defaults,
      );
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
        await dispatchAction(
          plan: plan,
          context: ctx,
          stateDefaults: defaults,
        );
        expect(ctx.store.get(r'$a'), 0);
        expect(ctx.store.get(r'$b'), 1);
        expect(ctx.errors, hasLength(1));
        expect(
          (ctx.errors.single as EvaluationError).message,
          contains(r'$missing'),
        );
      },
    );

    test('RunStep invokes onRun with the statement id', () async {
      final ctx = fresh();
      final plan = _planFor('a = @Run(refresh)');
      String? seenId;
      await dispatchAction(
        plan: plan,
        context: ctx,
        onRun: (id) async {
          seenId = id;
        },
      );
      expect(seenId, 'refresh');
    });

    test('RunStep callback throwing halts the rest of the plan', () async {
      final ctx = fresh();
      final plan = _planFor(
        r'a = [@Run(load), @Set($count, 99)]',
      );
      await dispatchAction(
        plan: plan,
        context: ctx,
        onRun: (_) async => throw Exception('boom'),
      );
      // The Set step after the failed Run did not run.
      expect(ctx.store.get(r'$count'), isNull);
    });

    test('RunStep without an onRun callback is a no-op', () async {
      final ctx = fresh();
      final plan = _planFor(
        r'a = [@Run(load), @Set($count, 1)]',
      );
      await dispatchAction(plan: plan, context: ctx);
      // Set still runs because Run was a silent no-op.
      expect(ctx.store.get(r'$count'), 1);
    });

    test(
      'ContinueConversationStep evaluates messageAst (and contextAst)',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = @ToAssistant("hello", "extra")');
        String? seenMsg;
        String? seenCtx;
        await dispatchAction(
          plan: plan,
          context: ctx,
          onContinueConversation: (m, c) {
            seenMsg = m;
            seenCtx = c;
          },
        );
        expect(seenMsg, 'hello');
        expect(seenCtx, 'extra');
      },
    );

    test(
      'ContinueConversationStep without context arg leaves it null',
      () async {
        final ctx = fresh();
        final plan = _planFor('a = @ToAssistant("hello")');
        String? seenCtx = 'sentinel';
        await dispatchAction(
          plan: plan,
          context: ctx,
          onContinueConversation: (m, c) {
            seenCtx = c;
          },
        );
        expect(seenCtx, isNull);
      },
    );

    test(
      'ContinueConversationStep skips when message evaluates non-string',
      () async {
        final ctx = fresh();
        // Build a step manually with a non-string message AST.
        const plan = ActionPlan(
          steps: [
            ContinueConversationStep(messageAst: Literal(123, offset: 0)),
          ],
        );
        var fired = false;
        await dispatchAction(
          plan: plan,
          context: ctx,
          onContinueConversation: (_, _) {
            fired = true;
          },
        );
        expect(fired, isFalse);
      },
    );

    test(
      'ContinueConversationStep skips when contextAst evaluates non-string',
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
        String? seenCtx = 'sentinel';
        await dispatchAction(
          plan: plan,
          context: ctx,
          onContinueConversation: (m, c) {
            seenCtx = c;
          },
        );
        // Message fired; context dropped.
        expect(seenCtx, isNull);
      },
    );

    test('ContinueConversationStep without callback is a no-op', () async {
      final ctx = fresh();
      final plan = _planFor('a = @ToAssistant("hello")');
      // No assertion needed — if it threw, the test fails.
      await dispatchAction(plan: plan, context: ctx);
    });

    test('OpenUrlStep evaluates urlAst and forwards', () async {
      final ctx = fresh();
      final plan = _planFor('a = @OpenUrl("https://example.com")');
      String? seen;
      await dispatchAction(
        plan: plan,
        context: ctx,
        onOpenUrl: (u) => seen = u,
      );
      expect(seen, 'https://example.com');
    });

    test('OpenUrlStep silently skips when url evaluates non-string', () async {
      final ctx = fresh();
      const plan = ActionPlan(
        steps: [OpenUrlStep(urlAst: Literal(42, offset: 0))],
      );
      var fired = false;
      await dispatchAction(
        plan: plan,
        context: ctx,
        onOpenUrl: (_) => fired = true,
      );
      expect(fired, isFalse);
    });

    test('OpenUrlStep without callback is a no-op', () async {
      final ctx = fresh();
      final plan = _planFor('a = @OpenUrl("https://x")');
      await dispatchAction(plan: plan, context: ctx);
    });
  });
}
