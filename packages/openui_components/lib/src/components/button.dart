// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

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
  return defineComponent<Widget>(
    name: 'Button',
    description: 'tappable button with action',
    schema: objectSchema(
      const <String, Object?>{
        'label': <String, Object?>{'type': 'string'},
        'variant': <String, Object?>{'type': 'string'},
        'onClick': <String, Object?>{},
      },
      required: const ['label'],
    ),
    render: (ctx, props, renderNode, id) {
      return ButtonWidget(
        label: props['label']?.toString() ?? '',
        variant: props['variant'] as String? ?? 'primary',
        onPressed: props['onClick'] as VoidCallback?,
      );
    },
  );
}

/// `Buttons(children)` — a horizontal row of buttons with even spacing.
class ButtonsWidget extends StatelessWidget {
  /// Creates a [ButtonsWidget].
  const ButtonsWidget({required this.children, super.key});

  /// Pre-rendered buttons.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) separated.add(const SizedBox(width: 8));
      separated.add(children[i]);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: separated,
    );
  }
}

/// Registration for `Buttons`.
Component<Widget> buttonsComponent() {
  return defineComponent<Widget>(
    name: 'Buttons',
    description: 'horizontal row of buttons',
    schema: objectSchema(
      const <String, Object?>{
        'children': <String, Object?>{'type': 'array'},
      },
      required: const ['children'],
    ),
    render: (ctx, props, renderNode, id) {
      final children =
          (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
          const <Widget>[];
      return ButtonsWidget(children: children);
    },
  );
}
