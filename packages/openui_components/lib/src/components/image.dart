// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui_core/openui_core.dart';

/// `Image(src, alt?)` — wraps `Image.network` with an error placeholder
/// (Acceptance Gap A7).
class ImageWidget extends StatelessWidget {
  /// Creates an [ImageWidget].
  const ImageWidget({required this.src, this.alt, super.key});

  /// Source URL.
  final String src;

  /// Alt text — surfaced via `Semantics`.
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: alt,
      image: true,
      child: Image.network(
        src,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      ),
    );
  }
}

/// Registration metadata for the `Image` component.
ComponentDefinition imageDefinition() {
  return ComponentDefinition(
    name: 'Image',
    description: 'network image with fallback',
    schema: Schema.object(
      properties: {
        'src': Schema.string(),
        'alt': Schema.string(),
      },
      required: const ['src'],
    ),
  );
}

/// Renders `Image`.
Widget renderImage(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  return ImageWidget(
    src: props['src'] as String? ?? '',
    alt: props['alt'] as String?,
  );
}
