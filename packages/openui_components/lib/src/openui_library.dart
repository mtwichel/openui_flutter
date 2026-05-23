// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:openui/openui.dart';
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

/// Builds the v0.1 [LibraryDefinition] with every builtin component
/// registered.
LibraryDefinition standardLibraryDefinition() {
  return LibraryDefinition(
    components: [
      stackDefinition(),
      cardDefinition(),
      cardHeaderDefinition(),
      separatorDefinition(),
      calloutDefinition(),
      textContentDefinition(),
      markdownDefinition(),
      imageDefinition(),
      inputDefinition(),
      selectDefinition(),
      buttonDefinition(),
      tableDefinition(),
      colDefinition(),
      tabsDefinition(),
      tabItemDefinition(),
      barChartDefinition(),
      lineChartDefinition(),
    ],
  );
}

/// Builds the v0.1 [ComponentRegistry] with render callbacks for every
/// builtin component.
ComponentRegistry standardComponentRegistry() {
  // Function tear-offs in [renderers] are not compile-time constants.
  // ignore: prefer_const_constructors
  return ComponentRegistry(
    renderers: {
      'Stack': renderStack,
      'Card': renderCard,
      'CardHeader': renderCardHeader,
      'Separator': renderSeparator,
      'Callout': renderCallout,
      'TextContent': renderTextContent,
      'MarkDownRenderer': renderMarkdown,
      'Image': renderImage,
      'Input': renderInput,
      'Select': renderSelect,
      'Button': renderButton,
      'Table': renderTable,
      'Col': renderCol,
      'Tabs': renderTabs,
      'TabItem': renderTabItem,
      'BarChart': renderBarChart,
      'LineChart': renderLineChart,
    },
  );
}
