// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_components/src/components/bar_chart.dart';
import 'package:openui_components/src/components/button.dart';
import 'package:openui_components/src/components/callout.dart';
import 'package:openui_components/src/components/card.dart';
import 'package:openui_components/src/components/image.dart';
import 'package:openui_components/src/components/input.dart';
import 'package:openui_components/src/components/line_chart.dart';
import 'package:openui_components/src/components/markdown.dart';
import 'package:openui_components/src/components/select.dart';
import 'package:openui_components/src/components/separator.dart';
import 'package:openui_components/src/components/stack.dart';
import 'package:openui_components/src/components/table.dart';
import 'package:openui_components/src/components/tabs.dart';
import 'package:openui_components/src/components/text_content.dart';
import 'package:openui_core/openui_core.dart';

/// Builds the v0.1 `RenderLibrary<Widget>` with every builtin component
/// registered.
RenderLibrary<Widget> standardLibrary() {
  final list = [
    stackComponent(),
    cardComponent(),
    cardHeaderComponent(),
    separatorComponent(),
    calloutComponent(),
    textContentComponent(),
    markdownComponent(),
    imageComponent(),
    inputComponent(),
    selectComponent(),
    buttonComponent(),
    tableComponent(),
    colComponent(),
    tabsComponent(),
    tabItemComponent(),
    barChartComponent(),
    lineChartComponent(),
  ];
  return RenderLibrary<Widget>(
    spec: Library(
      components: list.map((c) => c.spec).toList(),
      tools: const [],
    ),
    renderers: {for (final c in list) c.name: c.render},
    toolHandlers: const {},
  );
}
