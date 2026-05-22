// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `Select(options, value)` — `DropdownButton` whose selection is
/// two-way bound to a `$state` variable.
class SelectWidget extends StatelessWidget {
  /// Creates a [SelectWidget].
  const SelectWidget({
    required this.options,
    this.binding,
    super.key,
  });

  /// Option values.
  final List<String> options;

  /// Reactive binding from the renderer.
  final ReactiveAssign? binding;

  @override
  Widget build(BuildContext context) {
    final value = binding?.value as String?;
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : null,
      items: <DropdownMenuItem<String>>[
        for (final option in options)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: binding == null
          ? null
          : (next) {
              if (next == null) return;
              RendererScope.of(context).store.set(binding!.target, next);
            },
    );
  }
}

/// Registration metadata for `Select`. `value` is reactive.
ComponentDefinition selectDefinition() {
  return ComponentDefinition(
    name: 'Select',
    description: 'dropdown bound to state variable',
    schema: Schema.object(
      properties: {
        'options': Schema.list(items: Schema.string()),
        'value': Schema.string().xReactive(),
      },
      required: const ['options', 'value'],
    ),
  );
}

/// Renders `Select`.
Widget renderSelect(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  final raw = props['options'];
  final options = raw is List<Object?>
      ? raw.whereType<String>().toList()
      : const <String>[];
  final value = props['value'];
  return SelectWidget(
    options: options,
    binding: value is ReactiveAssign ? value : null,
  );
}
