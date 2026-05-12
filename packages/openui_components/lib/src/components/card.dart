// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// Renders the OpenUI Lang `Card`. `variant` is `'card'` (default,
/// elevated), `'sunk'` (filled / no elevation), or `'clear'` (no
/// surface — just a padded container).
class CardWidget extends StatelessWidget {
  /// Creates a [CardWidget].
  const CardWidget({
    required this.children,
    this.variant = 'card',
    super.key,
  });

  /// Children to wrap.
  final List<Widget> children;

  /// `'card'`, `'sunk'`, or `'clear'`.
  final String variant;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
    switch (variant) {
      case 'sunk':
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: body,
        );
      case 'clear':
        return body;
      case 'card':
      default:
        return Card(child: body);
    }
  }
}

/// `CardHeader(title, subtitle?)`.
class CardHeaderWidget extends StatelessWidget {
  /// Creates a [CardHeaderWidget].
  const CardHeaderWidget({required this.title, this.subtitle, super.key});

  /// Title text (bold).
  final String title;

  /// Optional subtitle.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Registration for the `Card` component.
Component<Widget> cardComponent() {
  return defineComponent<Widget>(
    name: 'Card',
    description: 'elevated surface container',
    schema: objectSchema(
      const <String, Object?>{
        'variant': <String, Object?>{'type': 'string'},
        'children': <String, Object?>{'type': 'array'},
      },
      required: const ['children'],
    ),
    render: (ctx, props, renderNode, id) {
      final children =
          (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
          const <Widget>[];
      return CardWidget(
        variant: props['variant'] as String? ?? 'card',
        children: children,
      );
    },
  );
}

/// Registration for the `CardHeader` component.
Component<Widget> cardHeaderComponent() {
  return defineComponent<Widget>(
    name: 'CardHeader',
    description: 'title and optional subtitle block',
    schema: objectSchema(
      const <String, Object?>{
        'title': <String, Object?>{'type': 'string'},
        'subtitle': <String, Object?>{'type': 'string'},
      },
      required: const ['title'],
    ),
    render: (ctx, props, renderNode, id) {
      return CardHeaderWidget(
        title: props['title'] as String? ?? '',
        subtitle: props['subtitle'] as String?,
      );
    },
  );
}
