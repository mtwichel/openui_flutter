// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `CodeBlock(code, language?)` — monospace selectable text. No syntax
/// highlighting in v0.1 (deferred to Phase 5).
class CodeBlockWidget extends StatelessWidget {
  /// Creates a [CodeBlockWidget].
  const CodeBlockWidget({required this.code, this.language, super.key});

  /// Source code.
  final String code;

  /// Optional language label (display only).
  final String? language;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (language != null && language!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                language!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

/// Registration for the `CodeBlock` component.
Component<Widget> codeBlockComponent() {
  return defineComponent<Widget>(
    name: 'CodeBlock',
    description: 'monospace code display block',
    schema: objectSchema(
      const <String, Object?>{
        'code': <String, Object?>{'type': 'string'},
        'language': <String, Object?>{'type': 'string'},
      },
      required: const ['code'],
    ),
    render: (ctx, props, renderNode, id) {
      return CodeBlockWidget(
        code: props['code']?.toString() ?? '',
        language: props['language'] as String?,
      );
    },
  );
}
