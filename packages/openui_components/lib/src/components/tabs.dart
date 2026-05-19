// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// `Tabs(children)` — `ShadTabs` switcher.
/// Children are [TabItemDescription] entries (label + pre-rendered
/// content widget).
class TabsWidget extends StatefulWidget {
  /// Creates a [TabsWidget].
  const TabsWidget({
    required this.items,
    this.bodyHeight = 240,
    super.key,
  });

  /// One entry per tab.
  final List<TabItemDescription> items;

  /// Fixed height parameter kept for backwards compatibility.
  final double bodyHeight;

  @override
  State<TabsWidget> createState() => _TabsWidgetState();
}

class _TabsWidgetState extends State<TabsWidget> {
  String? _activeTabValue;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      _activeTabValue = widget.items.first.label;
    }
  }

  @override
  void didUpdateWidget(TabsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isNotEmpty &&
        (_activeTabValue == null ||
            !widget.items.any((item) => item.label == _activeTabValue))) {
      _activeTabValue = widget.items.first.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return ShadTabs<String>(
      value: _activeTabValue,
      onChanged: (val) {
        setState(() {
          _activeTabValue = val;
        });
      },
      tabs: [
        for (final item in widget.items)
          ShadTab(
            value: item.label,
            content: item.content,
            child: Text(item.label),
          ),
      ],
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
RenderComponent<Widget> tabsComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Tabs',
      description: 'tabbed content switcher',
      schema: Schema.object(
        properties: {
          'children': Schema.list(items: Schema.any()),
        },
        required: ['children'],
      ),
    ),
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
RenderComponent<Widget> tabItemComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'TabItem',
      internal: true,
      schema: Schema.object(
        properties: {
          'label': Schema.string(),
          'content': Schema.any(),
        },
        required: const ['label', 'content'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      final content = props['content'];
      if (content is Widget) return content;
      return const SizedBox.shrink();
    },
  );
}
