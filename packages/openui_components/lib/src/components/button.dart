// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `Button(label, onClick, variant?)` — a Material button wired to an
/// action plan via the `onClick` prop.
class ButtonWidget extends StatelessWidget {
  /// Creates a [ButtonWidget].
  const ButtonWidget({
    required this.label,
    this.onPressed,
    this.variant = 'primary',
    super.key,
  });

  /// Label text.
  final String label;

  /// Tap callback. `null` disables the button (the renderer passes
  /// `null` while the containing statement is still streaming —
  /// Acceptance Gap A6).
  final VoidCallback? onPressed;

  /// `'primary'`, `'secondary'`, or `'text'`.
  final String variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case 'secondary':
        return OutlinedButton(onPressed: onPressed, child: Text(label));
      case 'text':
        return TextButton(onPressed: onPressed, child: Text(label));
      case 'primary':
      default:
        return ElevatedButton(onPressed: onPressed, child: Text(label));
    }
  }
}

/// Registration for `Button`.
Component<Widget> buttonComponent() {
  return Component<Widget>(
    name: 'Button',
    description: 'tappable button with action',
    schema: Schema.object(
      properties: {
        'label': Schema.string(),
        'variant': Schema.string(enumValues: ['primary', 'secondary', 'text']),
        'onClick': Schema.any().xAction(),
      },
      required: ['label'],
    ),
    render: (ctx, props, renderNode, id) {
      final label = props['label']?.toString() ?? '';
      final variant = props['variant'] as String? ?? 'primary';
      final hasOnClickProp = props.containsKey('onClick');
      final rawOnClick = props['onClick'];
      final action = rawOnClick is ActionPlan ? rawOnClick : null;
      final disabled = hasOnClickProp && action == null;
      return Builder(
        builder: (context) {
          final scope = RendererScope.maybeFind(context);
          final onPressed = (scope == null || disabled)
              ? null
              : () => scope.triggerAction(
                  label,
                  action: action,
                );
          return ButtonWidget(
            label: label,
            variant: variant,
            onPressed: onPressed,
          );
        },
      );
    },
  );
}
