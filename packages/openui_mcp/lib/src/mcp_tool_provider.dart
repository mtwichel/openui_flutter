// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Pluggable seam between [McpToolProvider] and `mcp_dart`'s
/// [mcp.McpClient]. Hides the actual transport so consumers can wire
/// in a stdio client, an HTTPS client, or a test double.
///
/// Marked `@experimental` per D12.
@experimental
typedef McpCallToolFn =
    Future<mcp.CallToolResult> Function(
      String name,
      Map<String, Object?> args,
    );

/// `ToolProvider` backed by an MCP transport.
///
/// Wraps a [client]-style callable (typically `mcp.McpClient.callTool`)
/// and routes every call through `extractToolResult` from `openui_core`
/// so consumers see the JS-reference-compatible envelope:
///
/// 1. `isError == true` → throws `McpToolError`.
/// 2. `structuredContent` non-null → returns the map.
/// 3. Otherwise → joins `TextContent` payloads and tries `jsonDecode`,
///    falling back to the raw text or `null` for empty.
///
/// Marked `@experimental` per D12.
@experimental
class McpToolProvider implements ToolProvider {
  /// Creates an [McpToolProvider].
  McpToolProvider({required this.client});

  /// Convenience constructor that wires directly to an
  /// [mcp.McpClient]. Equivalent to
  /// `McpToolProvider(client: client.callTool)` modulo argument
  /// adaptation.
  factory McpToolProvider.from(mcp.McpClient mcpClient) {
    return McpToolProvider(
      client: (name, args) => mcpClient.callTool(
        mcp.CallToolRequest(
          name: name,
          arguments: Map<String, dynamic>.from(args),
        ),
      ),
    );
  }

  /// The callable that performs one tool invocation.
  final McpCallToolFn client;

  @override
  Future<Object?> callTool(String name, Map<String, Object?> args) async {
    final raw = await client(name, args);
    return extractToolResult(_toToolResult(raw));
  }
}

ToolResult _toToolResult(mcp.CallToolResult raw) {
  return ToolResult(
    isError: raw.isError,
    structuredContent: raw.structuredContent == null
        ? null
        : Map<String, Object?>.from(raw.structuredContent!),
    text: _joinText(raw.content),
  );
}

String _joinText(List<mcp.Content> content) {
  final buffer = StringBuffer();
  for (final c in content) {
    if (c is mcp.TextContent) buffer.write(c.text);
  }
  return buffer.toString();
}
