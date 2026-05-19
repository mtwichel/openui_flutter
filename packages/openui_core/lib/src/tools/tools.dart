import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

part 'tools.mapper.dart';

/// Pluggable tool handler execution callback.
typedef ToolHandler = Future<ToolResult> Function(Map<String, Object?> args);

/// Pure metadata describing a tool in the prompt.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class Tool with ToolMappable {
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
}

/// Transport-agnostic envelope around the data an MCP-style tool
/// call returns.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
@MappableClass()
class ToolResult with ToolResultMappable {
  /// Creates a [ToolResult].
  const ToolResult(this.result, {this.isError = false});

  /// `true` when the upstream tool call reported an error
  /// (`CallToolResult.isError` in mcp_dart).
  final bool isError;

  /// The resolved result.
  final Object? result;
}
