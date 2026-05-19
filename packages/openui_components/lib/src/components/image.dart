// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
            color: ShadTheme.of(context).colorScheme.muted,
            child: const Icon(LucideIcons.imageOff),
          );
        },
      ),
    );
  }
}

/// Registration for the `Image` component.
RenderComponent<Widget> imageComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Image',
      description: 'network image with fallback',
      schema: Schema.object(
        properties: {
          'src': Schema.string(),
          'alt': Schema.string(),
        },
        required: const ['src'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      return ImageWidget(
        src: props['src'] as String? ?? '',
        alt: props['alt'] as String?,
      );
    },
  );
}
