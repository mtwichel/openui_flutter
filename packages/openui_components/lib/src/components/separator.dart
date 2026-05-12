// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// Renders `Separator()` as a thin horizontal divider.
Component<Widget> separatorComponent() {
  return defineComponent<Widget>(
    name: 'Separator',
    description: 'horizontal divider line',
    schema: objectSchema(const <String, Object?>{}),
    render: (ctx, props, renderNode, id) {
      return const Divider(height: 16);
    },
  );
}
