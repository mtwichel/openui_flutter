// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openui_core/openui_core.dart';

/// Async executor for a registered OpenUI tool.
///
/// Matches [ToolExecutor] from `package:openui/openui.dart` without pulling
/// in a Flutter dependency from this pure-Dart package.
typedef ToolExecutor = Future<ToolResult> Function(Map<String, Object?> args);

/// Tool metadata plus executor produced from an MCP tool listing.
typedef OpenUIToolPair = ({ToolDefinition definition, ToolExecutor execute});

/// Extension methods for [mcp.McpClient] to convert to [OpenUIToolPair] values.
extension McpToolExtension on mcp.McpClient {
  /// Converts the MCP client to a list of [OpenUIToolPair] values.
  Future<List<OpenUIToolPair>> asOpenUIToolPairs() async {
    final tools = await listTools();
    return tools.tools.map(_pairFromMcpTool).toList();
  }

  OpenUIToolPair _pairFromMcpTool(mcp.Tool mcpTool) {
    return (
      definition: ToolDefinition(
        name: mcpTool.name,
        description: mcpTool.description ?? '',
        input: Schema.fromMap(mcpTool.inputSchema.toJson()),
        output: mcpTool.outputSchema != null
            ? Schema.fromMap(mcpTool.outputSchema!.toJson())
            : null,
      ),
      execute: (args) => _callMcpTool(mcpTool.name, args),
    );
  }

  Future<ToolResult> _callMcpTool(
    String name,
    Map<String, Object?> args,
  ) async {
    final mcpResult = await callTool(
      mcp.CallToolRequest(
        name: name,
        arguments: Map<String, dynamic>.from(args),
      ),
    );

    return ToolResult(
      _joinText([
        ...mcpResult.content,
        ...?mcpResult.structuredContent?.entries.map(
          (e) => mcp.TextContent(text: '${e.key}: ${e.value}'),
        ),
      ]),
      isError: mcpResult.isError,
    );
  }
}

String _joinText(List<mcp.Content> content) {
  final buffer = StringBuffer();
  for (final c in content) {
    if (c is mcp.TextContent) buffer.write(c.text);
  }
  return buffer.toString();
}
