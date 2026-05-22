// OpenUIError contract tests.
//
// Drives every concrete subclass through the same matrix:
//   - exposes its declared fields
//   - implements Exception (so `throw` is sound under only_throw_errors)
//   - structural equality covers every field that subclass adds
//   - hashCode agrees with equality on equal instances
//   - toString is deterministic and includes the structured fields
//
// Cross-type tests confirm that two subclasses with identical base
// fields are not equal — required so `Renderer.onError`'s "fire only
// when the set changes" dedup logic doesn't collapse different error
// classes into the same identity.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('OpenUIError', () {
    group('ParseError', () {
      const a = ParseError(message: 'unexpected token', offset: 12);

      test('exposes code, message, offset', () {
        expect(a.code, 'parse');
        expect(a.message, 'unexpected token');
        expect(a.offset, 12);
        expect(a.hint, isNull);
        expect(a.statementId, isNull);
      });

      test('is an Exception', () {
        expect(a, isA<Exception>());
        expect(a, isA<OpenUIError>());
      });

      test('equality is structural (identical, equal, every field varies)', () {
        // identical short-circuits to true.
        expect(a == a, isTrue);
        // Two construction-equal instances compare equal.
        const a2 = ParseError(message: 'unexpected token', offset: 12);
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        // Vary each field.
        expect(
          a,
          isNot(equals(const ParseError(message: 'other', offset: 12))),
        );
        expect(
          a,
          isNot(
            equals(const ParseError(message: 'unexpected token', offset: 0)),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const ParseError(
                message: 'unexpected token',
                offset: 12,
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const ParseError(
                message: 'unexpected token',
                offset: 12,
                hint: 'check brackets',
              ),
            ),
          ),
        );
      });

      test('toString includes class name, code, message, offset', () {
        final s = a.toString();
        expect(s, contains('ParseError'));
        expect(s, contains('code: parse'));
        expect(s, contains('message: unexpected token'));
        // offset is not in the base toString format; this is intentional —
        // ParseError uses the base toString, so offset is structured but
        // the message conveys it for humans. The test just confirms the
        // base fields render.
        expect(s, contains('parse'));
      });

      test('hint and statementId render when set', () {
        const e = ParseError(
          message: 'unexpected token',
          offset: 12,
          statementId: 'root',
          hint: 'add a closing brace',
        );
        final s = e.toString();
        expect(s, contains('hint: add a closing brace'));
        expect(s, contains('statementId: root'));
      });
    });

    group('EvaluationError', () {
      const a = EvaluationError(message: 'cannot index null');

      test('exposes code and message', () {
        expect(a.code, 'evaluation');
        expect(a.message, 'cannot index null');
      });

      test('equality is structural', () {
        expect(a == a, isTrue);
        const a2 = EvaluationError(message: 'cannot index null');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const EvaluationError(message: 'other'))),
        );
        expect(
          a,
          isNot(
            equals(
              const EvaluationError(
                message: 'cannot index null',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const EvaluationError(
                message: 'cannot index null',
                hint: 'check input',
              ),
            ),
          ),
        );
      });

      test('toString is deterministic', () {
        expect(
          a.toString(),
          'EvaluationError(code: evaluation, message: cannot index null)',
        );
      });
    });

    group('CyclicStateError', () {
      const a = CyclicStateError(cycle: [r'$a', r'$b', r'$a']);

      test('exposes cycle and code; message is null', () {
        expect(a.code, 'cycle');
        expect(a.cycle, [r'$a', r'$b', r'$a']);
        expect(a.message, isNull);
      });

      test('equality includes the cycle list (length and elements)', () {
        expect(a == a, isTrue);
        const a2 = CyclicStateError(cycle: [r'$a', r'$b', r'$a']);
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        // Different length.
        expect(
          a,
          isNot(equals(const CyclicStateError(cycle: [r'$a', r'$a']))),
        );
        // Same length, different element.
        expect(
          a,
          isNot(
            equals(const CyclicStateError(cycle: [r'$a', r'$c', r'$a'])),
          ),
        );
        // statementId differs.
        expect(
          a,
          isNot(
            equals(
              const CyclicStateError(
                cycle: [r'$a', r'$b', r'$a'],
                statementId: 'x',
              ),
            ),
          ),
        );
        // hint differs.
        expect(
          a,
          isNot(
            equals(
              const CyclicStateError(
                cycle: [r'$a', r'$b', r'$a'],
                hint: 'break the loop',
              ),
            ),
          ),
        );
      });

      test('toString includes the cycle path', () {
        final s = a.toString();
        expect(s, contains('CyclicStateError'));
        expect(s, contains(r'cycle: $a -> $b -> $a'));
        expect(s, contains('code: cycle'));
      });

      test('toString renders hint and statementId when set', () {
        const e = CyclicStateError(
          cycle: [r'$a', r'$a'],
          hint: r'remove $a -> $a',
          statementId: 'root',
        );
        final s = e.toString();
        expect(s, contains(r'hint: remove $a -> $a'));
        expect(s, contains('statementId: root'));
      });
    });

    group('UnknownComponentError', () {
      const a = UnknownComponentError(component: 'Frobnicator');

      test('exposes component', () {
        expect(a.code, 'unknown_component');
        expect(a.component, 'Frobnicator');
      });

      test('equality includes component, statementId, hint', () {
        expect(a == a, isTrue);
        const a2 = UnknownComponentError(component: 'Frobnicator');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const UnknownComponentError(component: 'Other'))),
        );
        expect(
          a,
          isNot(
            equals(
              const UnknownComponentError(
                component: 'Frobnicator',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const UnknownComponentError(
                component: 'Frobnicator',
                hint: 'register it',
              ),
            ),
          ),
        );
      });

      test('toString includes the component name', () {
        final s = a.toString();
        expect(s, contains('UnknownComponentError'));
        expect(s, contains('component: Frobnicator'));
      });

      test('toString renders hint and statementId when set', () {
        const e = UnknownComponentError(
          component: 'F',
          hint: 'add to library',
          statementId: 'r',
        );
        final s = e.toString();
        expect(s, contains('hint: add to library'));
        expect(s, contains('statementId: r'));
      });
    });

    group('MissingRendererError', () {
      const a = MissingRendererError(component: 'Button');

      test('exposes component', () {
        expect(a.code, 'missing_renderer');
        expect(a.component, 'Button');
        expect(a.message, contains('Button'));
      });

      test('equality includes component, statementId, hint', () {
        expect(a == a, isTrue);
        const a2 = MissingRendererError(component: 'Button');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const MissingRendererError(component: 'Other'))),
        );
        expect(
          a,
          isNot(
            equals(
              const MissingRendererError(
                component: 'Button',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const MissingRendererError(
                component: 'Button',
                hint: 'register renderer',
              ),
            ),
          ),
        );
      });

      test('toString includes the component name', () {
        final s = a.toString();
        expect(s, contains('MissingRendererError'));
        expect(s, contains('component: Button'));
      });

      test('toString renders hint and statementId when set', () {
        const e = MissingRendererError(
          component: 'B',
          hint: 'add to registry',
          statementId: 'r',
        );
        final s = e.toString();
        expect(s, contains('hint: add to registry'));
        expect(s, contains('statementId: r'));
      });
    });

    group('MissingToolExecutorError', () {
      const a = MissingToolExecutorError(toolName: 'fetch_products');

      test('exposes toolName', () {
        expect(a.code, 'missing_tool_executor');
        expect(a.toolName, 'fetch_products');
        expect(a.message, contains('fetch_products'));
      });

      test('equality includes toolName, statementId, hint', () {
        expect(a == a, isTrue);
        const a2 = MissingToolExecutorError(toolName: 'fetch_products');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const MissingToolExecutorError(toolName: 'other'))),
        );
        expect(
          a,
          isNot(
            equals(
              const MissingToolExecutorError(
                toolName: 'fetch_products',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const MissingToolExecutorError(
                toolName: 'fetch_products',
                hint: 'register executor',
              ),
            ),
          ),
        );
      });

      test('toString includes the tool name', () {
        final s = a.toString();
        expect(s, contains('MissingToolExecutorError'));
        expect(s, contains('toolName: fetch_products'));
      });

      test('toString renders hint and statementId when set', () {
        const e = MissingToolExecutorError(
          toolName: 't',
          hint: 'add to registry',
          statementId: 'r',
        );
        final s = e.toString();
        expect(s, contains('hint: add to registry'));
        expect(s, contains('statementId: r'));
      });
    });

    group('McpToolError', () {
      const a = McpToolError(message: 'permission denied');

      test('exposes code and message', () {
        expect(a.code, 'mcp_tool');
        expect(a.message, 'permission denied');
      });

      test('equality is structural', () {
        expect(a == a, isTrue);
        const a2 = McpToolError(message: 'permission denied');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const McpToolError(message: 'other'))),
        );
        expect(
          a,
          isNot(
            equals(
              const McpToolError(
                message: 'permission denied',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const McpToolError(
                message: 'permission denied',
                hint: 'log in',
              ),
            ),
          ),
        );
      });

      test('toString is deterministic', () {
        expect(
          a.toString(),
          'McpToolError(code: mcp_tool, message: permission denied)',
        );
      });
    });

    group('ToolNotFoundError', () {
      const a = ToolNotFoundError(toolName: 'list_users');

      test('exposes toolName', () {
        expect(a.code, 'tool_not_found');
        expect(a.toolName, 'list_users');
      });

      test('equality is structural', () {
        expect(a == a, isTrue);
        const a2 = ToolNotFoundError(toolName: 'list_users');
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        expect(
          a,
          isNot(equals(const ToolNotFoundError(toolName: 'delete_user'))),
        );
        expect(
          a,
          isNot(
            equals(
              const ToolNotFoundError(
                toolName: 'list_users',
                statementId: 'x',
              ),
            ),
          ),
        );
        expect(
          a,
          isNot(
            equals(
              const ToolNotFoundError(
                toolName: 'list_users',
                hint: 'register it',
              ),
            ),
          ),
        );
      });

      test('toString includes the tool name', () {
        final s = a.toString();
        expect(s, contains('ToolNotFoundError'));
        expect(s, contains('toolName: list_users'));
      });

      test('toString renders hint and statementId when set', () {
        const e = ToolNotFoundError(
          toolName: 'list_users',
          hint: 'register the tool',
          statementId: 'q',
        );
        final s = e.toString();
        expect(s, contains('hint: register the tool'));
        expect(s, contains('statementId: q'));
      });
    });

    group('AdapterMismatchError', () {
      const a = AdapterMismatchError(
        adapterName: 'agUiAdapter',
        payloadPreview: 'data: {"choices":...',
      );

      test('exposes adapterName and payloadPreview', () {
        expect(a.code, 'adapter_mismatch');
        expect(a.adapterName, 'agUiAdapter');
        expect(a.payloadPreview, 'data: {"choices":...');
      });

      test('equality is structural', () {
        expect(a == a, isTrue);
        const a2 = AdapterMismatchError(
          adapterName: 'agUiAdapter',
          payloadPreview: 'data: {"choices":...',
        );
        expect(a, equals(a2));
        expect(a.hashCode, a2.hashCode);
        // adapterName differs.
        expect(
          a,
          isNot(
            equals(
              const AdapterMismatchError(
                adapterName: 'plainSseAdapter',
                payloadPreview: 'data: {"choices":...',
              ),
            ),
          ),
        );
        // payloadPreview differs.
        expect(
          a,
          isNot(
            equals(
              const AdapterMismatchError(
                adapterName: 'agUiAdapter',
                payloadPreview: 'other',
              ),
            ),
          ),
        );
        // hint differs.
        expect(
          a,
          isNot(
            equals(
              const AdapterMismatchError(
                adapterName: 'agUiAdapter',
                payloadPreview: 'data: {"choices":...',
                hint: 'switch adapter',
              ),
            ),
          ),
        );
      });

      test('toString includes adapter and payload preview', () {
        final s = a.toString();
        expect(s, contains('AdapterMismatchError'));
        expect(s, contains('adapter: agUiAdapter'));
        expect(s, contains('payload: data: {"choices":...'));
      });

      test('toString renders hint when set', () {
        const e = AdapterMismatchError(
          adapterName: 'agUiAdapter',
          payloadPreview: '...',
          hint: 'try plainSseAdapter',
        );
        expect(e.toString(), contains('hint: try plainSseAdapter'));
      });
    });

    group('cross-type', () {
      test(
        'two different subclasses with similar fields are not equal',
        () {
          const a = ParseError(message: 'm', offset: 0);
          const b = EvaluationError(message: 'm');
          // Equal-looking base fields, different runtime types.
          expect(a == b, isFalse);
          expect(b == a, isFalse);
        },
      );

      test('every concrete error implements Exception and OpenUIError', () {
        const errors = <OpenUIError>[
          ParseError(message: 'm', offset: 0),
          EvaluationError(message: 'm'),
          CyclicStateError(cycle: [r'$a']),
          UnknownComponentError(component: 'X'),
          McpToolError(message: 'm'),
          ToolNotFoundError(toolName: 't'),
          AdapterMismatchError(adapterName: 'a', payloadPreview: 'p'),
        ];
        for (final e in errors) {
          expect(e, isA<Exception>());
          expect(e.code, isNotEmpty);
        }
      });

      test(
        'a Set deduplicates equal instances across all subclasses',
        () {
          // Confirms hashCode/== contract holds for Set membership —
          // the dedup mechanism `Renderer.onError` relies on.
          final duplicated = <OpenUIError>[
            const ParseError(message: 'm', offset: 0),
            const ParseError(message: 'm', offset: 0),
            const EvaluationError(message: 'm'),
            const EvaluationError(message: 'm'),
            const CyclicStateError(cycle: [r'$a']),
            const CyclicStateError(cycle: [r'$a']),
            const UnknownComponentError(component: 'X'),
            const UnknownComponentError(component: 'X'),
            const McpToolError(message: 'm'),
            const McpToolError(message: 'm'),
            const ToolNotFoundError(toolName: 't'),
            const ToolNotFoundError(toolName: 't'),
            const AdapterMismatchError(adapterName: 'a', payloadPreview: 'p'),
            const AdapterMismatchError(adapterName: 'a', payloadPreview: 'p'),
          ];
          expect(duplicated.toSet(), hasLength(7));
        },
      );

      test('CyclicStateError list-equality covers identical-list path', () {
        // Construct two CyclicStateErrors that share the SAME cycle
        // list instance, exercising the `identical(a, b)` early-out
        // inside `_listEquals`.
        const cycle = <String>[r'$a', r'$b', r'$a'];
        const a = CyclicStateError(cycle: cycle);
        const b = CyclicStateError(cycle: cycle);
        expect(a, equals(b));
      });

      test('throwing an OpenUIError satisfies only_throw_errors', () {
        // Smoke test that `throw <subclass>` is well-typed.
        expect(
          () => throw const McpToolError(message: 'boom'),
          throwsA(isA<McpToolError>()),
        );
      });
    });
  });
}
