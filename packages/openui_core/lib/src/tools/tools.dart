import 'package:meta/meta.dart';

/// Transport-agnostic envelope around the data a tool call returns.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ToolResult {
  /// Creates a [ToolResult].
  const ToolResult(this.result, {this.isError = false});

  /// `true` when the upstream tool call reported an error.
  final bool isError;

  /// The resolved result.
  final Object? result;
}
