// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    final initial = options.contains(value) ? value : null;
    return ShadSelect<String>(
      initialValue: initial,
      options: [
        for (final option in options)
          ShadOption(value: option, child: Text(option)),
      ],
      selectedOptionBuilder: (context, val) => Text(val),
      placeholder: const Text('Select option...'),
      onChanged: binding == null
          ? null
          : (next) {
              if (next == null) return;
              RendererScope.of(context).store.set(binding!.target, next);
            },
    );
  }
}

/// Registration for `Select`. `value` is reactive.
RenderComponent<Widget> selectComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Select',
      description: 'dropdown bound to state variable',
      schema: Schema.object(
        properties: {
          'options': Schema.list(items: Schema.string()),
          'value': Schema.string().xReactive(),
        },
        required: const ['options', 'value'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      final raw = props['options'];
      final options = raw is List<Object?>
          ? raw.whereType<String>().toList()
          : const <String>[];
      final value = props['value'];
      return SelectWidget(
        options: options,
        binding: value is ReactiveAssign ? value : null,
      );
    },
  );
}
