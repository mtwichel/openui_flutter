// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Render callback for a registered OpenUI component.
typedef ComponentRender =
    Widget Function(
      EvalContext context,
      Map<String, Object?> props,
      Widget Function(AstNode node, EvalContext context) renderNode,
      String statementId,
    );

/// Lookup map from component name to render callback.
///
/// Marked `@experimental` per D12.
@experimental
class ComponentRegistry {
  /// Creates a [ComponentRegistry].
  const ComponentRegistry({required this.renderers});

  /// Registered render callbacks keyed by component name.
  final Map<String, ComponentRender> renderers;

  /// Returns the render callback for [name], or `null` when not registered.
  ComponentRender? operator [](String name) => renderers[name];
}
