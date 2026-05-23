// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_components/src/internal/tokens.dart';
import 'package:openui_core/openui_core.dart';

/// Renders `Stack(direction: ..., gap: ..., align: ..., justify: ...,
/// wrap: ..., children: [...])` as a Flutter `Flex`.
///
/// Defaults: `direction: 'column'`, `gap: 'm'`.
class StackWidget extends StatelessWidget {
  /// Creates a [StackWidget].
  const StackWidget({
    required this.children,
    this.direction = 'column',
    this.gap = 'm',
    this.align,
    this.justify,
    this.wrap = false,
    super.key,
  });

  /// Children to lay out. Pre-rendered by the renderer.
  final List<Widget> children;

  /// `'row'` or `'column'`.
  final String direction;

  /// Gap token (`'xs'`, `'s'`, `'m'`, `'l'`, `'xl'`).
  final String? gap;

  /// `'start'`, `'center'`, `'end'`, or `'stretch'`.
  final String? align;

  /// `'start'`, `'center'`, `'end'`, `'between'`, `'around'`, or
  /// `'evenly'`.
  final String? justify;

  /// `true` to use `Wrap` instead of `Flex`. `gap` becomes both the
  /// `spacing` and `runSpacing` of the wrap.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final spacing = resolveSpacing(gap, fallback: 16);
    final axis = direction == 'row' ? Axis.horizontal : Axis.vertical;
    if (wrap) {
      return Wrap(
        direction: axis,
        spacing: spacing,
        runSpacing: spacing,
        crossAxisAlignment: _wrapAlign(align),
        children: children,
      );
    }
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && spacing > 0) {
        separated.add(
          axis == Axis.vertical
              ? SizedBox(height: spacing)
              : SizedBox(width: spacing),
        );
      }
      separated.add(children[i]);
    }
    return Flex(
      direction: axis,
      mainAxisAlignment: _mainAxis(justify),
      crossAxisAlignment: _crossAxis(align),
      mainAxisSize: MainAxisSize.min,
      children: separated,
    );
  }
}

MainAxisAlignment _mainAxis(String? value) {
  switch (value) {
    case 'center':
      return MainAxisAlignment.center;
    case 'end':
      return MainAxisAlignment.end;
    case 'between':
      return MainAxisAlignment.spaceBetween;
    case 'around':
      return MainAxisAlignment.spaceAround;
    case 'evenly':
      return MainAxisAlignment.spaceEvenly;
    case 'start':
    default:
      return MainAxisAlignment.start;
  }
}

CrossAxisAlignment _crossAxis(String? value) {
  switch (value) {
    case 'center':
      return CrossAxisAlignment.center;
    case 'end':
      return CrossAxisAlignment.end;
    case 'stretch':
      return CrossAxisAlignment.stretch;
    case 'start':
    default:
      return CrossAxisAlignment.start;
  }
}

WrapCrossAlignment _wrapAlign(String? value) {
  switch (value) {
    case 'center':
      return WrapCrossAlignment.center;
    case 'end':
      return WrapCrossAlignment.end;
    case 'start':
    default:
      return WrapCrossAlignment.start;
  }
}

/// Registration metadata for the `Stack` component.
ComponentDefinition stackDefinition() {
  return ComponentDefinition(
    name: 'Stack',
    description: 'vertical or horizontal layout container',
    schema: Schema.object(
      properties: {
        'direction': Schema.string(enumValues: ['row', 'column']),
        'gap': Schema.string(enumValues: ['xs', 's', 'm', 'l', 'xl']),
        'align': Schema.string(
          enumValues: ['start', 'center', 'end', 'stretch'],
        ),
        'justify': Schema.string(
          enumValues: ['start', 'center', 'end', 'between', 'around', 'evenly'],
        ),
        'wrap': Schema.boolean(),
        'children': Schema.list(items: Schema.any()),
      },
      required: ['children'],
    ),
  );
}

/// Renders `Stack`.
Widget renderStack(
  EvalContext ctx,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
  String statementId,
) {
  final children =
      (props['children'] as List<Object?>?)?.whereType<Widget>().toList() ??
      const <Widget>[];
  return StackWidget(
    direction: props['direction'] as String? ?? 'column',
    gap: props['gap'] as String?,
    align: props['align'] as String?,
    justify: props['justify'] as String?,
    wrap: props['wrap'] as bool? ?? false,
    children: children,
  );
}
