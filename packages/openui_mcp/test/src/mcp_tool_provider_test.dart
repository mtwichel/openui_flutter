// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openui_core/openui_core.dart';
import 'package:openui_mcp/openui_mcp.dart';
import 'package:test/test.dart';

McpToolProvider _provider(
  Future<mcp.CallToolResult> Function(String name, Map<String, Object?> args)
  handler,
) {
  return McpToolProvider(client: handler);
}

void main() {
  group('McpToolProvider', () {
    test('returns structuredContent when present', () async {
      final provider = _provider(
        (name, args) async => const mcp.CallToolResult(
          content: <mcp.Content>[],
          structuredContent: <String, dynamic>{'id': 1, 'name': 'alice'},
        ),
      );

      expect(
        await provider.callTool('lookup', const <String, Object?>{}),
        <String, Object?>{'id': 1, 'name': 'alice'},
      );
    });

    test('joins TextContent payloads and JSON-decodes', () async {
      final provider = _provider(
        (name, args) async => const mcp.CallToolResult(
          content: <mcp.Content>[
            mcp.TextContent(text: '[1, 2, 3]'),
          ],
        ),
      );

      expect(
        await provider.callTool('lookup', const <String, Object?>{}),
        <int>[1, 2, 3],
      );
    });

    test('falls back to raw text when JSON decode fails', () async {
      final provider = _provider(
        (name, args) async => const mcp.CallToolResult(
          content: <mcp.Content>[
            mcp.TextContent(text: 'hello world'),
          ],
        ),
      );

      expect(
        await provider.callTool('lookup', const <String, Object?>{}),
        'hello world',
      );
    });

    test(
      'returns null when the call yields no text and no structured data',
      () async {
        final provider = _provider(
          (name, args) async =>
              const mcp.CallToolResult(content: <mcp.Content>[]),
        );

        expect(await provider.callTool('x', const <String, Object?>{}), isNull);
      },
    );

    test('throws McpToolError when the call reports isError', () async {
      final provider = _provider(
        (name, args) async => const mcp.CallToolResult(
          content: <mcp.Content>[
            mcp.TextContent(text: 'permission denied'),
          ],
          isError: true,
        ),
      );

      await expectLater(
        provider.callTool('bad', const <String, Object?>{}),
        throwsA(
          isA<McpToolError>().having(
            (e) => e.message,
            'message',
            'permission denied',
          ),
        ),
      );
    });

    test('mixed content joins only TextContent payloads', () async {
      final provider = _provider(
        (name, args) async => const mcp.CallToolResult(
          content: <mcp.Content>[
            mcp.TextContent(text: '{"ok":true}'),
            mcp.ImageContent(data: 'binary', mimeType: 'image/png'),
          ],
        ),
      );

      expect(
        await provider.callTool('x', const <String, Object?>{}),
        <String, Object?>{'ok': true},
      );
    });

    test('forwards name and args to the underlying client', () async {
      String? receivedName;
      Map<String, Object?>? receivedArgs;
      final provider = _provider(
        (name, args) async {
          receivedName = name;
          receivedArgs = args;
          return const mcp.CallToolResult(
            content: <mcp.Content>[mcp.TextContent(text: 'ok')],
          );
        },
      );

      await provider.callTool('greet', const <String, Object?>{'who': 'world'});
      expect(receivedName, 'greet');
      expect(receivedArgs, <String, Object?>{'who': 'world'});
    });
  });
}
