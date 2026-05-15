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
class InputWidget extends StatefulWidget {
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
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  /// Keeps the cached [TextEditingController] aligned with the store after a
  /// [StoreChangeOrigin.mutation] (`@Set`, `@Reset`, field edits).
  ///
  /// [FormStateCache.controllerFor] only seeds text when allocating a new
  /// controller; reused controllers would otherwise stay stale. Skipping this
  /// after [StoreChangeOrigin.declarativeSeed] keeps visible typing when
  /// streaming parses refresh declarative defaults — see [Store.lastNotifyOrigin].
  void _syncControllerIfNeeded(
    TextEditingController controller,
    String storeText,
  ) {
    if (controller.text == storeText) return;
    controller.value = TextEditingValue(
      text: storeText,
      selection: TextSelection.collapsed(offset: storeText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = RendererScope.of(context);
    final storeText = widget.binding?.value as String? ?? '';
    final controller = scope.formStateCache.controllerFor(
      formName: 'default',
      fieldName: widget.name,
      initialValue: storeText,
    );
    if (scope.store.lastNotifyOrigin == StoreChangeOrigin.mutation) {
      _syncControllerIfNeeded(controller, storeText);
    }
    return TextField(
      key: ValueKey<String>('input-default-${widget.name}'),
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: widget.placeholder,
      ),
      onChanged: (text) {
        final b = widget.binding;
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
