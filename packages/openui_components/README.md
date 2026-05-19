# openui_components

[![Pub](https://img.shields.io/pub/v/openui_components.svg)](https://pub.dev/packages/openui_components)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Builtin component library for OpenUI Flutter.

Ships 16 components as `RenderComponent<Widget>` pairs (spec + renderer),
styled with [shadcn_ui](https://pub.dev/packages/shadcn_ui). Wrap your app in
`ShadApp` (see the example app's `main.dart`) so buttons, inputs, cards, and
tabs pick up the theme.

- **Layout** — `Stack`, `Card`, `CardHeader`, `Separator`, `Callout`
- **Content** — `TextContent`, `MarkDownRenderer`, `Image`
- **Forms** — `Input`, `Select`, `Button`
- **Data** — `Table`, `Col`, `Tabs`, `TabItem`
- **Charts** — `BarChart`, `LineChart`

Each component is wired to the renderer's reactive store and
`FormStateCache`. Reactive props (`Input.value`, `Select.value`) use the
`x-reactive` schema keyword and arrive as `ReactiveAssign` markers from the
renderer.

## Status

v0.1, Phase 3 complete.

## Install

```yaml
dependencies:
  openui_components: ^0.0.1-dev.2
  shadcn_ui: ^0.54.0   # required for correct builtin styling
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      theme: ShadThemeData(brightness: Brightness.light),
      appBuilder: (context) => MaterialApp(
        theme: Theme.of(context),
        home: const MyPage(),
        builder: (context, child) => ShadAppBuilder(child: child),
      ),
    );
  }
}

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Renderer(
        response: r'''
$count = 0
root = Stack(children: [
  TextContent(text: "Hello!", size: "large-heavy"),
  Button(label: "Bump", onClick: [@Set($count, $count + 1)]),
  TextContent(text: $count)
])
''',
        library: standardLibrary(),
      ),
    );
  }
}
```

## `standardLibrary()`

`standardLibrary()` returns a `RenderLibrary<Widget>` with every builtin
registered. Extend it with extra tools or components:

```dart
final snackbar = SnackbarTool(); // your Tool spec + callTool handler

final library = standardLibrary().extend(
  tools: [snackbar],
  toolHandlers: {snackbar.name: snackbar.callTool},
);

final systemPrompt = library.prompt();
```

`library.prompt()` delegates to `openui_core`'s `generatePrompt` and lists
all non-`internal` components (for example `Col` and `TabItem` are omitted).

## License

MIT — see [LICENSE](LICENSE).
