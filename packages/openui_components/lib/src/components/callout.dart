// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Banner with a leading icon. `variant` selects the color scheme
/// (`'info'`, `'warning'`, `'error'`, `'success'`).
class CalloutWidget extends StatelessWidget {
  /// Creates a [CalloutWidget].
  const CalloutWidget({
    required this.text,
    this.variant = 'info',
    super.key,
  });

  /// Body text.
  final String text;

  /// `'info'`, `'warning'`, `'error'`, or `'success'`.
  final String variant;

  @override
  Widget build(BuildContext context) {
    final (iconData, isDestructive) = switch (variant) {
      'warning' => (LucideIcons.triangleAlert, false),
      'error' => (LucideIcons.circleAlert, true),
      'success' => (LucideIcons.checkCircle, false),
      _ => (LucideIcons.info, false),
    };

    final content = Text(text);

    if (isDestructive) {
      return Semantics(
        container: true,
        label: 'Callout: $text',
        child: ShadAlert.destructive(
          icon: Icon(iconData),
          description: content,
        ),
      );
    } else {
      return Semantics(
        container: true,
        label: 'Callout: $text',
        child: ShadAlert(
          icon: Icon(iconData),
          description: content,
        ),
      );
    }
  }
}

/// Registration for the `Callout` component.
RenderComponent<Widget> calloutComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Callout',
      description: 'tinted banner for alerts and notices',
      schema: Schema.object(
        properties: {
          'text': Schema.string(),
          'variant': Schema.string(),
        },
        required: const ['text'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      return CalloutWidget(
        text: props['text']?.toString() ?? '',
        variant: props['variant'] as String? ?? 'info',
      );
    },
  );
}
