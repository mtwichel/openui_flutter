// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Renders `Separator()` as a thin horizontal divider.
RenderComponent<Widget> separatorComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Separator',
      description: 'horizontal divider line',
      schema: Schema.object(properties: {}),
    ),
    render: (ctx, props, renderNode, id) {
      return const ShadSeparator.horizontal(
        margin: EdgeInsets.symmetric(vertical: 8),
      );
    },
  );
}
