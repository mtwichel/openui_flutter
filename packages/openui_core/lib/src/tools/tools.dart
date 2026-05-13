import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Pluggable tool dispatcher.
///
/// `ToolProvider` is the boundary between `openui_core`'s
/// `Query` / `Mutation` semantics and the underlying tool transport
/// (MCP, an in-process function map, an HTTP API, etc.). The renderer
/// hands a [Library] to the query manager; each `Query` /
/// `Mutation` statement that needs to execute calls [callTool] and
/// caches the resolved value under the statement id.
///
/// Implementations are expected to:
///
/// - Resolve the tool by its name.
/// - Pass arguments through as-is.
/// - Throw `ToolNotFoundError` for unknown tool names and
///   `McpToolError` when the upstream tool reports a failure.
///
/// Marked `@experimental` per D12.
@experimental
// `callTool` is the only member by design; the interface exists so
// transports (MCP, HTTP, in-process) can be swapped at the renderer
// boundary. A typedef would work but loses the room to grow without
// a breaking change.
abstract class Tool {
  /// Creates a [Tool].
  const Tool({
    required this.name,
    required this.description,
    this.input,
    this.output,
  });

  /// Tool name as it appears in the prompt.
  final String name;

  /// Human-facing description.
  final String description;

  /// JSON schema describing the tool's input.
  final Schema? input;

  /// JSON schema describing the tool's output, or `null` if not applicable.
  final Schema? output;

  /// Calls the tool named [name] with [args]. Returns the resolved
  /// result. May throw [ToolNotFoundError] or [McpToolError].
  Future<ToolResult> callTool(Map<String, Object?> args);
}

/// Transport-agnostic envelope around the data an MCP-style tool
/// call returns.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ToolResult {
  /// Creates a [ToolResult].
  const ToolResult(this.result, {this.isError = false});

  /// `true` when the upstream tool call reported an error
  /// (`CallToolResult.isError` in mcp_dart).
  final bool isError;

  /// The resolved result.
  final Object? result;
}
