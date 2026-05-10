// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// `Tabs(children)` — `DefaultTabController` + `TabBar` + `TabBarView`.
/// Children are [TabItemDescription] entries (label + pre-rendered
/// content widget).
class TabsWidget extends StatelessWidget {
  /// Creates a [TabsWidget].
  const TabsWidget({required this.items, super.key});

  /// One entry per tab.
  final List<TabItemDescription> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return DefaultTabController(
      length: items.length,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabs: <Widget>[for (final item in items) Tab(text: item.label)],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: TabBarView(
              children: <Widget>[for (final item in items) item.content],
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry in a [TabsWidget]'s `items` list.
class TabItemDescription {
  /// Creates a [TabItemDescription].
  const TabItemDescription({required this.label, required this.content});

  /// Label shown in the tab bar.
  final String label;

  /// Pre-rendered content body.
  final Widget content;
}

/// Registration for `Tabs`. Child slots come from inline `TabItem(...)`
/// values that the renderer pre-renders.
Component<Widget> tabsComponent() {
  return defineComponent<Widget>(
    name: 'Tabs',
    schema: objectSchema(const <String, Object?>{
      'children': <String, Object?>{'type': 'array'},
    }),
    render: (ctx, props, renderNode, id) {
      // The renderer wraps `TabItem(...)` into a Widget that carries
      // its label as a fallback Text. To present a real TabBar, we
      // need access to the AST. Read the source statement and walk its
      // CompCall args directly.
      final stmt = ctx.statements[id];
      final expression = stmt?.expression;
      if (expression is! CompCall) {
        return const SizedBox.shrink();
      }
      final childrenArg = expression.args.firstWhere(
        (a) => a.name == 'children',
        orElse: () => const Argument(value: NullLiteral(offset: 0), offset: 0),
      );
      final list = childrenArg.value;
      if (list is! ArrayLit) return const SizedBox.shrink();
      final items = <TabItemDescription>[];
      for (final element in list.elements) {
        if (element is! CompCall || element.type != 'TabItem') continue;
        var label = '';
        AstNode? body;
        for (final arg in element.args) {
          if (arg.name == 'label') {
            final v = arg.value;
            if (v is Literal && v.value is String) label = v.value! as String;
          } else if (arg.name == 'content') {
            body = arg.value;
          }
        }
        items.add(
          TabItemDescription(
            label: label,
            content: body == null
                ? const SizedBox.shrink()
                : renderNode(body, ctx),
          ),
        );
      }
      return TabsWidget(items: items);
    },
  );
}

/// Registration for `TabItem`. Not normally rendered standalone — Tabs
/// reads the inline TabItem args. If a TabItem somehow surfaces on its
/// own (e.g. orphan statement), render the content prop alone.
Component<Widget> tabItemComponent() {
  return defineComponent<Widget>(
    name: 'TabItem',
    schema: objectSchema(const <String, Object?>{
      'label': <String, Object?>{'type': 'string'},
      'content': <String, Object?>{},
    }),
    render: (ctx, props, renderNode, id) {
      final content = props['content'];
      if (content is Widget) return content;
      return const SizedBox.shrink();
    },
  );
}
