// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// Renders text with a semantic-size token (`large-heavy`, `medium`,
/// `small-light`, etc.) mapped to Material's text theme.
///
/// While the containing statement is streaming, the widget wraps its
/// text in a `Semantics` node marked `liveRegion: true` so screen
/// readers announce updates (Acceptance Gap A5).
class TextContentWidget extends StatelessWidget {
  /// Creates a [TextContentWidget].
  const TextContentWidget({
    required this.text,
    this.size = 'medium',
    this.isStreaming = false,
    super.key,
  });

  /// Body text.
  final String text;

  /// Size token from the package's `kTextSizeTokens` table; defaults
  /// to `'medium'`.
  final String size;

  /// `true` while the containing statement is in `meta.incomplete`.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = switch (size) {
      'display-heavy' => theme.displaySmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      'large-heavy' => theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      'large' => theme.headlineSmall,
      'medium-heavy' => theme.titleMedium,
      'small-heavy' => theme.labelLarge,
      'small' => theme.bodySmall,
      'small-light' => theme.bodySmall?.copyWith(
        color: Theme.of(context).hintColor,
      ),
      _ => theme.bodyMedium,
    };
    return Semantics(
      liveRegion: isStreaming,
      child: Text(text, style: style),
    );
  }
}

/// Registration for the `TextContent` component.
Component<Widget> textContentComponent() {
  return defineComponent<Widget>(
    name: 'TextContent',
    description: 'styled paragraph text',
    schema: objectSchema(
      const <String, Object?>{
        'text': <String, Object?>{'type': 'string'},
        'size': <String, Object?>{'type': 'string'},
      },
      required: const ['text'],
    ),
    render: (ctx, props, renderNode, id) {
      return Builder(
        builder: (context) {
          final scope = RendererScope.maybeFind(context);
          final streaming =
              scope?.isStreaming == true &&
              (scope?.incomplete.contains(id) ?? false);
          return TextContentWidget(
            text: props['text']?.toString() ?? '',
            size: props['size'] as String? ?? 'medium',
            isStreaming: streaming,
          );
        },
      );
    },
  );
}
