// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

/// Component definitions used by renderer and wiring tests.
final testComponentDefinitions = <ComponentDefinition>[
  ComponentDefinition(
    name: 'Text',
    schema: Schema.fromMap(<String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'text': <String, Object?>{'type': 'string'},
      },
    }),
  ),
  ComponentDefinition(
    name: 'Column',
    schema: Schema.fromMap(<String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'children': <String, Object?>{'type': 'array'},
      },
    }),
  ),
  ComponentDefinition(
    name: 'Counter',
    schema: Schema.fromMap(<String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'value': <String, Object?>{'type': 'integer'},
        'onIncrement': <String, Object?>{
          'type': 'object',
          'x-action': true,
        },
      },
    }),
  ),
  ComponentDefinition(
    name: 'Input',
    schema: Schema.fromMap(<String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'name': const <String, Object?>{'type': 'string'},
        'value': <String, Object?>{
          'type': 'string',
          'x-reactive': true,
        },
      },
    }),
  ),
  ComponentDefinition(
    name: 'Throwing',
    schema: Schema.fromMap(const <String, Object?>{'type': 'object'}),
  ),
];

/// Render callbacks keyed by component name for test harnesses.
final testComponentRenderers = <String, ComponentRender>{
  'Text': (ctx, props, renderNode, id) {
    return Text(props['text'] as String? ?? '');
  },
  'Column': (ctx, props, renderNode, id) {
    final children =
        (props['children'] as List<Object?>?)?.cast<Widget>() ??
        const <Widget>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  },
  'Counter': (ctx, props, renderNode, id) {
    final value = props['value'] as int? ?? 0;
    final hasAction = props.containsKey('onIncrement');
    final action = props['onIncrement'] as ActionPlan?;
    final disabled = hasAction && action == null;
    return Builder(
      builder: (context) {
        final scope = RendererScope.maybeFind(context);
        final onTap = (scope == null || disabled || action == null)
            ? null
            : () => scope.triggerAction('', action: action);
        return GestureDetector(
          onTap: onTap,
          child: Text('count=$value'),
        );
      },
    );
  },
  'Input': (ctx, props, renderNode, id) {
    return Builder(
      builder: (context) {
        final binding = props['value'];
        final field = props['name'] as String? ?? id;
        final cache = RendererScope.of(context).formStateCache;
        final storeText = binding is ReactiveAssign
            ? (binding.value as String? ?? '')
            : '';
        final controller = cache.controllerFor(
          formName: 'form',
          fieldName: field,
          initialValue: storeText,
        );
        final store = RendererScope.of(context).store;
        if (store.lastNotifyOrigin == StoreChangeOrigin.mutation &&
            controller.text != storeText) {
          controller.value = TextEditingValue(
            text: storeText,
            selection: TextSelection.collapsed(offset: storeText.length),
          );
        }
        return TextField(
          key: ValueKey<String>('input-$field'),
          controller: controller,
          onChanged: (text) {
            if (binding is ReactiveAssign) {
              ctx.store.set(binding.target, text);
            }
          },
        );
      },
    );
  },
  'Throwing': (ctx, props, renderNode, id) {
    throw StateError('boom from $id');
  },
};
