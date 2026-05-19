# openui

[![Pub](https://img.shields.io/pub/v/openui.svg)](https://pub.dev/packages/openui)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Flutter `Renderer` widget for OpenUI Lang.

The renderer takes a streaming `response: String` from your LLM, parses it
against a [`RenderLibrary<Widget>`](https://pub.dev/documentation/openui_core/latest/openui_core/RenderLibrary-class.html)
of component specs + render callbacks, and rebuilds the widget tree on every
chunk. It owns the reactive store, the form-state cache (so
`TextEditingController`s survive mid-stream rebuilds), the query manager, and a
streaming-tolerant error boundary.

## Status

v0.1, Phase 2 complete. The package now ships:

- `Renderer` — the streaming widget.
- `ErrorBoundary` — per-element error capture with last-good fallback.
- `FormStateCache` — `TextEditingController` cache keyed by
  `(formName, fieldName)` with a 250 ms grace window.
- `QueryManager` — `@Run`-invalidatable query cache backed by
  `RenderLibrary.toolHandlers`.
- `RendererScope` — `InheritedWidget` exposing the store and form-state
  cache to component implementations.

Phase 3 ships the built-in component library in `openui_components`.

## Install

```yaml
dependencies:
  openui: ^0.0.1-dev.2
  openui_core: ^0.0.1-dev.2
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final library = RenderLibrary<Widget>(
      spec: const Library(
        components: [
          Component(
            name: 'Text',
            schema: Schema.object(
              properties: {'text': Schema.string()},
            ),
          ),
        ],
        tools: [],
      ),
      renderers: {
        'Text': (ctx, props, renderNode, id) =>
            Text(props['text'] as String? ?? ''),
      },
      toolHandlers: const {},
    );

    return MaterialApp(
      home: Scaffold(
        body: Renderer(
          response: 'root = Text(text: "Hello, OpenUI!")',
          library: library,
        ),
      ),
    );
  }
}
```

`Renderer` is a `StatefulWidget`; each call with a new `response` runs the
streaming parser, seeds the reactive store, and fires any `@Query` declarations
the parsed program declares.

## `Renderer` API

| Field | Purpose |
|---|---|
| `response: String?` | Cumulative source from the LLM. `null` = no content yet. |
| `library: RenderLibrary<Widget>` | Component specs, renderers, and tool handlers. Required. |
| `isStreaming: bool` | Whether `response` is still appending. Propagated to components via `RendererScope.isStreaming`. |
| `onAction: void Function(ActionEvent)?` | Notified when an action plan fires. |
| `onContinueConversation: void Function(String message)?` | Notified for continue-conversation steps with a non-empty message. |
| `onStateUpdate: void Function(Map<String, Object?>)?` | Notified after every store write with the post-write snapshot. |
| `initialState: Map<String, Object?>?` | Persisted state seed. Keys include the leading `$`. Wins over parsed defaults. |
| `onParseResult: void Function(ParseResult)?` | Fired once per parse pass. |
| `onError: void Function(List<OpenUIError>)?` | Notified when the active error set changes. |
| `rootName: String` | Entry-point statement (default `'root'`). |

`@Query` / `@Run` tool calls are resolved through
`library.toolHandlers[toolName]`. Register handlers when building or extending
a `RenderLibrary` (see `openui_components` and the example app).

## How components consume the renderer

Each renderer entry is a `ComponentRender<Widget>` callback:

```dart
typedef ComponentWidgetRenderer = ComponentRender<Widget>;
```

The renderer pre-resolves prop values for you:

- **Primitive props** — already evaluated (e.g. `text: "hi"` arrives as
  `"hi"`).
- **Reactive props** (`x-reactive: true` in the schema, bound to a
  `$state` ref) — arrive as a `ReactiveAssign` marker. Read
  `marker.value` and write user edits back to `marker.target` via
  `context.store.set(target, ...)`.
- **Child components / arrays of components** — pre-rendered to `Widget`
  / `List<Widget>` so you can drop them straight into your tree.
- **Action props** (`@Set`, `@Reset`, `@Run`, `@ToAssistant`) — arrive as
  `void Function()` callbacks that the renderer ties to its action dispatcher.

Need access to the form-state cache or the store from a component?
`RendererScope.maybeFind(context)` exposes both.

## License

MIT — see [LICENSE](LICENSE).
