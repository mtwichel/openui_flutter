// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openui_mcp/openui_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpToolExtension', () {
    test('asOpenUIToolPairs maps every listed MCP tool', () async {
      final client = _FakeMcpClient(
        listToolsResult: mcp.ListToolsResult(
          tools: [
            _buildMcpTool(name: 'echo', description: 'Echo text'),
            _buildMcpTool(name: 'sum'),
          ],
        ),
        callToolResult: const mcp.CallToolResult(content: []),
      );

      final pairs = await client.asOpenUIToolPairs();

      expect(pairs, hasLength(2));
      expect(pairs.map((p) => p.definition.name), ['echo', 'sum']);
      expect(
        pairs.map((p) => p.definition.description),
        ['Echo text', ''],
      );
    });

    test('pair definition maps input and output schemas', () async {
      final client = _FakeMcpClient(
        listToolsResult: mcp.ListToolsResult(
          tools: [
            _buildMcpTool(
              name: 'weather_lookup',
              description: 'Look up current weather.',
              inputSchema: const {
                'type': 'object',
                'properties': {
                  'city': {'type': 'string'},
                },
              },
              outputSchema: const {
                'type': 'object',
                'properties': {
                  'temperature': {'type': 'number'},
                },
              },
            ),
          ],
        ),
        callToolResult: const mcp.CallToolResult(content: []),
      );

      final pair = (await client.asOpenUIToolPairs()).single;

      expect(pair.definition.name, 'weather_lookup');
      expect(pair.definition.description, 'Look up current weather.');
      expect(pair.definition.input?.value['type'], 'object');
      expect(
        (pair.definition.input!.value['properties']! as Map)['city'],
        isNotNull,
      );
      expect(pair.definition.output?.value['type'], 'object');
      expect(
        (pair.definition.output!.value['properties']! as Map)['temperature'],
        isNotNull,
      );
    });

    test(
      'returns null output schema when MCP output schema is absent',
      () async {
        final client = _FakeMcpClient(
          listToolsResult: mcp.ListToolsResult(
            tools: [_buildMcpTool(name: 'ping')],
          ),
          callToolResult: const mcp.CallToolResult(content: []),
        );

        final pair = (await client.asOpenUIToolPairs()).single;

        expect(pair.definition.output, isNull);
        expect(pair.definition.description, isEmpty);
      },
    );

    test(
      'execute forwards args and flattens MCP content to ToolResult',
      () async {
        final client = _FakeMcpClient(
          listToolsResult: mcp.ListToolsResult(
            tools: [_buildMcpTool(name: 'do_work')],
          ),
          callToolResult: const mcp.CallToolResult(
            isError: true,
            structuredContent: {'ok': false},
            content: [
              mcp.TextContent(text: 'first'),
              mcp.ImageContent(data: 'AA==', mimeType: 'image/png'),
              mcp.TextContent(text: ' second'),
            ],
          ),
        );
        final pair = (await client.asOpenUIToolPairs()).single;

        final result = await pair.execute(const {
          'count': 3,
          'nested': {'mode': 'safe'},
        });

        expect(client.lastCallToolRequest, isNotNull);
        expect(client.lastCallToolRequest!.name, 'do_work');
        expect(client.lastCallToolRequest!.arguments, {
          'count': 3,
          'nested': {'mode': 'safe'},
        });
        expect(result.isError, isTrue);
        expect(result.result, 'first secondok: false');
      },
    );

    test(
      'execute returns empty string when no text content is present',
      () async {
        final client = _FakeMcpClient(
          listToolsResult: mcp.ListToolsResult(
            tools: [_buildMcpTool(name: 'image_only')],
          ),
          callToolResult: const mcp.CallToolResult(
            content: [
              mcp.ImageContent(data: 'AA==', mimeType: 'image/png'),
            ],
          ),
        );
        final pair = (await client.asOpenUIToolPairs()).single;

        final result = await pair.execute(const {'id': 1});

        expect(result.result, isEmpty);
        expect(result.isError, isFalse);
      },
    );

    test(
      'execute stringifies structuredContent entries into the result text',
      () async {
        final client = _FakeMcpClient(
          listToolsResult: mcp.ListToolsResult(
            tools: [_buildMcpTool(name: 'structured_only')],
          ),
          callToolResult: const mcp.CallToolResult(
            structuredContent: {'count': 3, 'ok': true},
            content: [],
          ),
        );
        final pair = (await client.asOpenUIToolPairs()).single;

        final result = await pair.execute(const {'id': 1});

        expect(result.result, 'count: 3ok: true');
        expect(result.isError, isFalse);
      },
    );
  });
}

mcp.Tool _buildMcpTool({
  required String name,
  String? description,
  Map<String, Object?> inputSchema = const {'type': 'object'},
  Map<String, Object?>? outputSchema,
}) {
  return mcp.Tool(
    name: name,
    description: description,
    inputSchema: mcp.JsonSchema.fromJson(
      Map<String, dynamic>.from(inputSchema),
    ),
    outputSchema: outputSchema == null
        ? null
        : mcp.JsonSchema.fromJson(
            Map<String, dynamic>.from(outputSchema),
          ),
  );
}

class _FakeMcpClient extends mcp.McpClient {
  _FakeMcpClient({
    required this.listToolsResult,
    required this.callToolResult,
  }) : super(const mcp.Implementation(name: 'test-client', version: '1.0.0'));

  final mcp.ListToolsResult listToolsResult;
  final mcp.CallToolResult callToolResult;
  mcp.CallToolRequest? lastCallToolRequest;

  @override
  Future<mcp.ListToolsResult> listTools({
    mcp.ListToolsRequest? params,
    mcp.RequestOptions? options,
  }) async {
    return listToolsResult;
  }

  @override
  Future<mcp.CallToolResult> callTool(
    mcp.CallToolRequest params, {
    mcp.RequestOptions? options,
  }) async {
    lastCallToolRequest = params;
    return callToolResult;
  }
}
