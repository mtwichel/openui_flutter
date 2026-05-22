// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui_core/openui_core.dart';

/// Registration metadata for `Separator`.
ComponentDefinition separatorDefinition() {
  return ComponentDefinition(
    name: 'Separator',
    description: 'horizontal divider line',
    schema: Schema.object(properties: {}),
  );
}

/// Renders `Separator`.
Widget renderSeparator(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  return const Divider(height: 16);
}
