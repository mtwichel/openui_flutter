// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `Input(name, value, placeholder?)` — a text field whose value is
/// two-way bound to a `$state` variable. The controller lives in the
/// renderer-owned `FormStateCache`, keyed by `(formName, name)`.
class InputWidget extends StatelessWidget {
  /// Creates an [InputWidget].
  const InputWidget({
    required this.name,
    this.binding,
    this.placeholder,
    super.key,
  });

  /// Field name.
  final String name;

  /// Reactive binding from the renderer — when non-null, edits flow
  /// back to the store via [Store.set].
  final ReactiveAssign? binding;

  /// Placeholder text.
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final scope = RendererScope.of(context);
    final controller = scope.formStateCache.controllerFor(
      formName: 'default',
      fieldName: name,
      initialValue: binding?.value as String? ?? '',
    );
    return TextField(
      key: ValueKey<String>('input-default-$name'),
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: placeholder,
      ),
      onChanged: (text) {
        final b = binding;
        if (b != null) scope.store.set(b.target, text);
      },
    );
  }
}

/// Registration for `Input`. The `value` prop is marked reactive so
/// the renderer surfaces a `ReactiveAssign` marker when bound to a
/// `$state` var.
Component<Widget> inputComponent() {
  return Component<Widget>(
    name: 'Input',
    description: 'text field bound to state variable',
    schema: Schema.object(
      properties: {
        'name': Schema.string(),
        'value': Schema.string().xReactive(),
        'placeholder': Schema.string(),
      },
      required: const ['name', 'value'],
    ),
    render: (ctx, props, renderNode, id) {
      final value = props['value'];
      return InputWidget(
        name: props['name'] as String? ?? id,
        binding: value is ReactiveAssign ? value : null,
        placeholder: props['placeholder'] as String?,
      );
    },
  );
}
