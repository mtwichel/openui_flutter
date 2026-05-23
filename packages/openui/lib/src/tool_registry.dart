// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Async executor for a registered OpenUI tool.
typedef ToolExecutor = Future<ToolResult> Function(Map<String, Object?> args);

/// Lookup map from tool name to executor callback.
///
/// Marked `@experimental` per D12.
@experimental
class ToolRegistry {
  /// Creates a [ToolRegistry].
  const ToolRegistry({required this.executors});

  /// Registered executors keyed by tool name.
  final Map<String, ToolExecutor> executors;

  /// Returns the executor for [name], or `null` when not registered.
  ToolExecutor? operator [](String name) => executors[name];
}
