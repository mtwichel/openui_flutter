// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
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

/// Registration metadata for the `Card` component.
ComponentDefinition cardDefinition() {
  return ComponentDefinition(
    name: 'Card',
    description: 'elevated surface container',
    schema: Schema.object(
      properties: {
        'children': Schema.list(items: Schema.any()),
        'variant': Schema.string(
          enumValues: ['card', 'sunk', 'clear'],
        ),
      },
      required: ['children'],
    ),
  );
}

/// Renders `Card`.
Widget renderCard(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  final children =
      (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
      const <Widget>[];
  return CardWidget(
    variant: props['variant'] as String? ?? 'card',
    children: children,
  );
}

/// Registration metadata for the `CardHeader` component.
ComponentDefinition cardHeaderDefinition() {
  return ComponentDefinition(
    name: 'CardHeader',
    description: 'title and optional subtitle block',
    schema: Schema.object(
      properties: {
        'title': Schema.string(),
        'subtitle': Schema.string(),
      },
      required: ['title'],
    ),
  );
}

/// Renders `CardHeader`.
Widget renderCardHeader(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  return CardHeaderWidget(
    title: props['title']?.toString() ?? '',
    subtitle: props['subtitle'] as String?,
  );
}
