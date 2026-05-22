// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
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

/// Registration metadata for the `Callout` component.
ComponentDefinition calloutDefinition() {
  return ComponentDefinition(
    name: 'Callout',
    description: 'tinted banner for alerts and notices',
    schema: Schema.object(
      properties: {
        'text': Schema.string(),
        'variant': Schema.string(),
      },
      required: const ['text'],
    ),
  );
}

/// Renders `Callout`.
Widget renderCallout(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  return CalloutWidget(
    text: props['text']?.toString() ?? '',
    variant: props['variant'] as String? ?? 'info',
  );
}
