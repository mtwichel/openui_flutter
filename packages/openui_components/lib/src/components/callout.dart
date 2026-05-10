// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (variant) {
      'warning' => (Icons.warning_amber_outlined, scheme.tertiaryContainer),
      'error' => (Icons.error_outline, scheme.errorContainer),
      'success' => (Icons.check_circle_outline, scheme.primaryContainer),
      _ => (Icons.info_outline, scheme.secondaryContainer),
    };
    return Semantics(
      container: true,
      label: 'Callout: $text',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// Registration for the `Callout` component.
Component<Widget> calloutComponent() {
  return defineComponent<Widget>(
    name: 'Callout',
    schema: objectSchema(const <String, Object?>{
      'text': <String, Object?>{'type': 'string'},
      'variant': <String, Object?>{'type': 'string'},
    }),
    render: (ctx, props, renderNode, id) {
      return CalloutWidget(
        text: props['text'] as String? ?? '',
        variant: props['variant'] as String? ?? 'info',
      );
    },
  );
}
