// ToolProvider, ToolResult, and extractToolResult contract tests.
//
// Mirrors the spike S0.3 branch table:
//   - isError → throws McpToolError with the joined text
//   - isError with empty text → throws with the fallback message
//   - structuredContent non-null → returned directly
//   - empty text and no structured content → null
//   - text parses as JSON → decoded value
//   - text doesn't parse as JSON → raw string
// Plus a smoke test that ToolProvider can be implemented.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

class _StubProvider implements ToolProvider {
  _StubProvider(this.handler);

  final Future<Object?> Function(String, Map<String, Object?>) handler;

  @override
  Future<Object?> callTool(
    String name,
    Map<String, Object?> args,
  ) => handler(name, args);
}

void main() {
  group('ToolResult', () {
    test('default fields: not an error, no structured content, empty text', () {
      const r = ToolResult();
      expect(r.isError, isFalse);
      expect(r.structuredContent, isNull);
      expect(r.text, '');
    });

    test('exposes the supplied fields', () {
      const r = ToolResult(
        isError: true,
        structuredContent: {'k': 1},
        text: 'msg',
      );
      expect(r.isError, isTrue);
      expect(r.structuredContent, {'k': 1});
      expect(r.text, 'msg');
    });
  });

  group('extractToolResult', () {
    test(
      'isError with non-empty text throws McpToolError carrying the text',
      () {
        const r = ToolResult(isError: true, text: 'permission denied');
        expect(
          () => extractToolResult(r),
          throwsA(
            isA<McpToolError>().having(
              (e) => e.message,
              'message',
              'permission denied',
            ),
          ),
        );
      },
    );

    test('isError with empty text throws with the fallback message', () {
      const r = ToolResult(isError: true);
      expect(
        () => extractToolResult(r),
        throwsA(
          isA<McpToolError>().having(
            (e) => e.message,
            'message',
            'tool reported error',
          ),
        ),
      );
    });

    test('structuredContent takes precedence over text', () {
      const r = ToolResult(
        structuredContent: {'id': 1, 'name': 'alice'},
        text: '{"id": 999}',
      );
      expect(extractToolResult(r), {'id': 1, 'name': 'alice'});
    });

    test('empty text returns null when there is no structured content', () {
      const r = ToolResult();
      expect(extractToolResult(r), isNull);
    });

    test('text JSON is decoded into the matching Dart shape', () {
      const r = ToolResult(text: '[1, 2, 3]');
      expect(extractToolResult(r), [1, 2, 3]);
    });

    test('text JSON object is decoded into a Map', () {
      const r = ToolResult(text: '{"ok": true}');
      expect(extractToolResult(r), {'ok': true});
    });

    test('non-JSON text is returned verbatim', () {
      const r = ToolResult(text: 'hello world');
      expect(extractToolResult(r), 'hello world');
    });
  });

  group('ToolProvider', () {
    test(
      'a stub implementation can be exercised through the interface',
      () async {
        final provider = _StubProvider((name, args) async {
          return 'called $name with ${args.length} args';
        });
        expect(
          await provider.callTool('echo', {'x': 1, 'y': 2}),
          'called echo with 2 args',
        );
      },
    );

    test('a stub implementation may throw ToolNotFoundError', () async {
      final provider = _StubProvider((name, args) async {
        throw ToolNotFoundError(toolName: name);
      });
      expect(
        () => provider.callTool('missing', const {}),
        throwsA(isA<ToolNotFoundError>()),
      );
    });
  });
}
