# openui_components

[![Pub](https://img.shields.io/pub/v/openui_components.svg)](https://pub.dev/packages/openui_components)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Builtin component library for OpenUI Flutter.

Ships 21 components ready to drop into the `openui` renderer:

- **Layout** — `Stack`, `Card`, `CardHeader`, `Separator`, `Callout`
- **Content** — `TextContent`, `MarkDownRenderer`, `Image`, `CodeBlock`
- **Forms** — `Form`, `FormControl`, `Input`, `Select`, `Button`, `Buttons`
- **Data** — `Table`, `Col`, `Tabs`, `TabItem`
- **Charts** — `BarChart`, `LineChart`

Each component is wired to the renderer's reactive store and
`FormStateCache`. Reactive inputs (`Input.value`, `Select.value`) are
two-way bound to `$state` variables through the renderer's
`ReactiveAssign` marker.

## Status

v0.1, Phase 3 complete.

## Install

```yaml
dependencies:
  openui_components: ^0.1.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';

void main() => runApp(const MaterialApp(home: MyPage()));

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
  Button(label: "Bump", onClick: @Set($count, $count + 1)),
  TextContent(text: $count)
])
''',
        library: openuiLibrary(),
      ),
    );
  }
}
```

## Two libraries

| Factory | Behavior |
| --- | --- |
| `openuiLibrary()` | All 21 components, no root wrapper. |
| `openuiChatLibrary()` | Same component set — drop-in for chat surfaces. |

## License

MIT — see [LICENSE](LICENSE).
