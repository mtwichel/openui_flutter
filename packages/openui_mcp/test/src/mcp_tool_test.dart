// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openui_mcp/openui_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpToolExtension', () {
    test('asOpenUITools maps every listed MCP tool', () async {
      final client = _FakeMcpClient(
        listToolsResult: mcp.ListToolsResult(
          tools: [
            _buildMcpTool(name: 'echo', description: 'Echo text'),
            _buildMcpTool(name: 'sum'),
          ],
        ),
        callToolResult: const mcp.CallToolResult(content: []),
      );

      final tools = await client.asOpenUITools();

      expect(tools, hasLength(2));
      expect(tools.first, isA<McpTool>());
      expect(tools.map((t) => t.name), ['echo', 'sum']);
      expect(tools.map((t) => t.description), ['Echo text', '']);
    });
  });

  group('McpTool', () {
    test('maps name, description, input, and output schemas', () {
      final mcpTool = _buildMcpTool(
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
      );

      final tool = McpTool(
        mcpTool,
        _FakeMcpClient(
          listToolsResult: const mcp.ListToolsResult(tools: []),
          callToolResult: const mcp.CallToolResult(content: []),
        ),
      );

      expect(tool.name, 'weather_lookup');
      expect(tool.description, 'Look up current weather.');
      expect(tool.input?.value['type'], 'object');
      expect((tool.input!.value['properties']! as Map)['city'], isNotNull);
      expect(tool.output?.value['type'], 'object');
      expect(
        (tool.output!.value['properties']! as Map)['temperature'],
        isNotNull,
      );
    });

    test('returns null output schema when MCP output schema is absent', () {
      final tool = McpTool(
        _buildMcpTool(name: 'ping'),
        _FakeMcpClient(
          listToolsResult: const mcp.ListToolsResult(tools: []),
          callToolResult: const mcp.CallToolResult(content: []),
        ),
      );

      expect(tool.output, isNull);
      expect(tool.description, isEmpty);
    });

    test(
      'callTool forwards args and flattens MCP content to ToolResult',
      () async {
        final client = _FakeMcpClient(
          listToolsResult: const mcp.ListToolsResult(tools: []),
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
        final tool = McpTool(_buildMcpTool(name: 'do_work'), client);

        final result = await tool.callTool(const {
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
      'callTool returns empty string when no text content is present',
      () async {
        final tool = McpTool(
          _buildMcpTool(name: 'image_only'),
          _FakeMcpClient(
            listToolsResult: const mcp.ListToolsResult(tools: []),
            callToolResult: const mcp.CallToolResult(
              content: [
                mcp.ImageContent(data: 'AA==', mimeType: 'image/png'),
              ],
            ),
          ),
        );

        final result = await tool.callTool(const {'id': 1});

        expect(result.result, isEmpty);
        expect(result.isError, isFalse);
      },
    );

    test(
      'callTool stringifies structuredContent entries into the result text',
      () async {
        final tool = McpTool(
          _buildMcpTool(name: 'structured_only'),
          _FakeMcpClient(
            listToolsResult: const mcp.ListToolsResult(tools: []),
            callToolResult: const mcp.CallToolResult(
              structuredContent: {'count': 3, 'ok': true},
              content: [],
            ),
          ),
        );

        final result = await tool.callTool(const {'id': 1});

        // Structured entries are appended as "key: value" text chunks.
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
