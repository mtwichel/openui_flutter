// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openui_core/openui_core.dart';

/// Extension methods for [mcp.McpClient] to convert to [Tool] instances.
extension McpToolExtension on mcp.McpClient {
  /// Converts the MCP client to a list of [Tool] instances.
  Future<List<Tool>> asOpenUITools() async {
    final tools = await listTools();
    return tools.tools.map((t) => McpTool(t, this)).toList();
  }
}

/// {@template mcp_tool}
/// A GenUI tool backed by an MCP tool.
/// {@endtemplate}
class McpTool implements Tool {
  /// {@macro mcp_tool}
  McpTool(this._mcpTool, this._mcpClient);

  final mcp.Tool _mcpTool;
  final mcp.McpClient _mcpClient;

  @override
  String get name => _mcpTool.name;

  @override
  String get description => _mcpTool.description ?? '';

  @override
  Schema? get input => Schema.fromMap(_mcpTool.inputSchema.toJson());

  @override
  Schema? get output => _mcpTool.outputSchema != null
      ? Schema.fromMap(_mcpTool.outputSchema!.toJson())
      : null;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async {
    final mcpResult = await _mcpClient.callTool(
      mcp.CallToolRequest(
        name: _mcpTool.name,
        arguments: Map<String, dynamic>.from(args),
      ),
    );

    return ToolResult(
      isError: mcpResult.isError,

      _joinText([
        ...mcpResult.content,
        ...?mcpResult.structuredContent?.entries.map(
          (e) => mcp.TextContent(text: '${e.key}: ${e.value}'),
        ),
      ]),
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
