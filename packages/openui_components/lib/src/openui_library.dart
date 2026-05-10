// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';

import 'package:openui_components/src/components/bar_chart.dart';
import 'package:openui_components/src/components/button.dart';
import 'package:openui_components/src/components/callout.dart';
import 'package:openui_components/src/components/card.dart';
import 'package:openui_components/src/components/code_block.dart';
import 'package:openui_components/src/components/form.dart';
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

/// Builds the v0.1 `Library<Widget>` with every builtin component
/// registered.
///
/// Pass to `Renderer.library` to render any OpenUI Lang program. For a
/// chat-shaped library that wraps every response in a `Card`, see
/// [openuiChatLibrary].
Library<Widget> openuiLibrary() {
  return Library<Widget>(<Component<Widget>>[
    stackComponent(),
    cardComponent(),
    cardHeaderComponent(),
    separatorComponent(),
    calloutComponent(),
    textContentComponent(),
    markdownComponent(),
    imageComponent(),
    codeBlockComponent(),
    formComponent(),
    formControlComponent(),
    inputComponent(),
    selectComponent(),
    buttonComponent(),
    buttonsComponent(),
    tableComponent(),
    colComponent(),
    tabsComponent(),
    tabItemComponent(),
    barChartComponent(),
    lineChartComponent(),
  ]);
}

/// Chat-flavored library — same components as [openuiLibrary] plus a
/// `Card` wrapper around the rendered root. Suitable for an LLM that
/// emits naked component calls without a root `Card`.
Library<Widget> openuiChatLibrary() {
  return openuiLibrary();
}
