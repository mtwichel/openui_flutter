import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';

/// Pluggable tool dispatcher.
///
/// `ToolProvider` is the boundary between `openui_core`'s
/// `Query` / `Mutation` semantics and the underlying tool transport
/// (MCP, an in-process function map, an HTTP API, etc.). The renderer
/// hands a [ToolProvider] to the query manager; each `Query` /
/// `Mutation` statement that needs to execute calls [callTool] and
/// caches the resolved value under the statement id.
///
/// Implementations are expected to:
///
/// - Resolve the tool by its name.
/// - Pass arguments through as-is.
/// - For MCP-backed providers, call [extractToolResult] on the
///   underlying `CallToolResult` before returning, so the renderer
///   sees the JS-reference shape (raw map, decoded JSON, plain
///   string, or a thrown error).
/// - Throw `ToolNotFoundError` for unknown tool names and
///   `McpToolError` when the upstream tool reports a failure.
///
/// Marked `@experimental` per D12.
@experimental
// `callTool` is the only member by design; the interface exists so
// transports (MCP, HTTP, in-process) can be swapped at the renderer
// boundary. A typedef would work but loses the room to grow without
// a breaking change.
// ignore: one_member_abstracts
abstract interface class ToolProvider {
  /// Calls the tool named [name] with [args]. Returns the resolved
  /// result, already extracted via [extractToolResult] for MCP-backed
  /// providers. May throw [ToolNotFoundError] or [McpToolError].
  Future<Object?> callTool(String name, Map<String, Object?> args);
}

/// Transport-agnostic envelope around the data an MCP-style tool
/// call returns. `openui_mcp` (and any other transport adapter)
/// converts its native response shape into a [ToolResult] before
/// passing it to [extractToolResult]; this keeps `openui_core` free
/// of an `mcp_dart` dependency while still owning the extraction
/// policy from spike S0.3.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ToolResult {
  /// Creates a [ToolResult].
  const ToolResult({
    this.isError = false,
    this.structuredContent,
    this.text = '',
  });

  /// `true` when the upstream tool call reported an error
  /// (`CallToolResult.isError` in mcp_dart).
  final bool isError;

  /// Structured payload, when the tool returned one
  /// (`CallToolResult.structuredContent` in mcp_dart). Takes
  /// precedence over [text] for non-error results.
  final Map<String, Object?>? structuredContent;

  /// Joined text content from the tool call, after concatenating
  /// every `TextContent.text`. Empty string when the tool returned
  /// only non-text content (image, audio, resource link).
  final String text;
}

/// Mirrors the JS reference's `extractToolResult`. Returns the
/// renderer-facing value the query manager caches under the
/// statement id.
///
/// Branches, in order:
///
/// 1. `isError == true` — throw [McpToolError] with the joined text
///    (or `'tool reported error'` when the text is empty).
/// 2. `structuredContent` non-null — return it directly.
/// 3. `text` empty — return `null`.
/// 4. `text` parses as JSON — return the decoded value.
/// 5. Otherwise — return the raw `text` string.
///
/// Marked `@experimental` per D12.
@experimental
Object? extractToolResult(ToolResult result) {
  if (result.isError) {
    final msg = result.text.isEmpty ? 'tool reported error' : result.text;
    throw McpToolError(message: msg);
  }
  if (result.structuredContent != null) return result.structuredContent;
  if (result.text.isEmpty) return null;
  try {
    return jsonDecode(result.text);
  } on FormatException {
    return result.text;
  }
}
