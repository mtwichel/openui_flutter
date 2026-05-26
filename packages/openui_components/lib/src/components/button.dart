// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `Button(label, action, variant?)` — a Material button wired to an
/// action plan via the `action` prop (`Action([@Set(...), ...])`).
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
        // Canonical `tertiary`; Flutter schema keeps `text` as alias.
        return TextButton(onPressed: onPressed, child: Text(label));
      case 'primary':
      default:
        return ElevatedButton(onPressed: onPressed, child: Text(label));
    }
  }
}

/// Registration metadata for `Button`.
ComponentDefinition buttonDefinition() {
  return ComponentDefinition(
    name: 'Button',
    description: 'tappable button with action',
    schema: Schema.object(
      properties: {
        'label': Schema.string(),
        'action': Schema.any().xAction(),
        'variant': Schema.string(enumValues: ['primary', 'secondary', 'text']),
      },
      required: ['label'],
    ),
  );
}

/// Renders `Button`.
Widget renderButton(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  final label = props['label']?.toString() ?? '';
  final variant = props['variant'] as String? ?? 'primary';
  final hasActionProp = props.containsKey('action');
  final rawAction = props['action'];
  final explicit = rawAction is ActionPlan ? rawAction : null;
  final disabled = hasActionProp && explicit == null;
  final plan = explicit ?? implicitContinueConversationPlan(label);
  return Builder(
    builder: (context) {
      final scope = RendererScope.maybeFind(context);
      final onPressed = (scope == null || disabled)
          ? null
          : () => scope.triggerAction(
              label,
              action: plan,
            );
      return ButtonWidget(
        label: label,
        variant: variant,
        onPressed: onPressed,
      );
    },
  );
}
