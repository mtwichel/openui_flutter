// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui_core/openui_core.dart';

/// Inherited binding scope so descendant inputs know which form they
/// belong to (the form name keys the renderer's `FormStateCache`).
class FormScope extends InheritedWidget {
  /// Creates a [FormScope].
  const FormScope({required this.name, required super.child, super.key});

  /// Form name — keys the controller cache.
  final String name;

  /// Looks up the nearest enclosing [FormScope], or `null` when no
  /// [FormScope] ancestor is mounted.
  static FormScope? maybeFind(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormScope>();
  }

  @override
  bool updateShouldNotify(FormScope oldWidget) => oldWidget.name != name;
}

/// `Form(name, children)` — installs a [FormScope] so descendant
/// inputs can find their owning form.
class FormWidget extends StatelessWidget {
  /// Creates a [FormWidget].
  const FormWidget({
    required this.name,
    required this.children,
    super.key,
  });

  /// Form name.
  final String name;

  /// Pre-rendered children.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FormScope(
      name: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final child in children)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Registration for `Form`.
Component<Widget> formComponent() {
  return Component<Widget>(
    name: 'Form',
    description: 'named form container for inputs',
    schema: Schema.object(
      properties: {
        'name': Schema.string(),
        'children': Schema.list(items: Schema.any()),
      },
      required: const ['name', 'children'],
    ),
    render: (ctx, props, renderNode, id) {
      final children =
          (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
          const <Widget>[];
      return FormWidget(
        name: props['name'] as String? ?? id,
        children: children,
      );
    },
  );
}

/// `FormControl(label, children)` — a labeled wrapper around one field.
class FormControlWidget extends StatelessWidget {
  /// Creates a [FormControlWidget].
  const FormControlWidget({
    required this.label,
    required this.children,
    this.helperText,
    super.key,
  });

  /// Label shown above the field.
  final String label;

  /// Optional helper text below the field.
  final String? helperText;

  /// Field content.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.labelMedium),
        const SizedBox(height: 4),
        ...children,
        if (helperText != null && helperText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(helperText!, style: theme.bodySmall),
          ),
      ],
    );
  }
}

/// Registration for `FormControl`.
Component<Widget> formControlComponent() {
  return Component<Widget>(
    name: 'FormControl',
    description: 'labeled field wrapper',
    schema: Schema.object(
      properties: {
        'label': Schema.string(),
        'helperText': Schema.string(),
        'children': Schema.list(items: Schema.any()),
      },
      required: const ['label', 'children'],
    ),
    render: (ctx, props, renderNode, id) {
      final children =
          (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
          const <Widget>[];
      return FormControlWidget(
        label: props['label']?.toString() ?? '',
        helperText: props['helperText'] as String?,
        children: children,
      );
    },
  );
}
