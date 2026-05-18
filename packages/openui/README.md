# openui

[![Pub](https://img.shields.io/pub/v/openui.svg)](https://pub.dev/packages/openui)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Flutter `Renderer` widget for OpenUI Lang.

The renderer takes a streaming `response: String` from your LLM, parses it
against a `Library<Widget>` of components, and rebuilds the widget tree on
every chunk. It owns the reactive store, the form-state cache (so
`TextEditingController`s survive mid-stream rebuilds), the query manager,
and a streaming-tolerant error boundary.

## Status

v0.1, Phase 2 complete. The package now ships:

- `Renderer` — the streaming widget.
- `ErrorBoundary` — per-element error capture with last-good fallback.
- `FormStateCache` — `TextEditingController` cache keyed by
  `(formName, fieldName)` with a 250 ms grace window.
- `QueryManager` — `@Run`-invalidatable query cache backed by a
  `ToolProvider` or a test `QueryLoader`.
- `RendererScope` — `InheritedWidget` exposing the store and form-state
  cache to component implementations.

Phase 3 ships the built-in component library on top of these primitives.

## Install

```yaml
dependencies:
  openui: ^0.1.0
  openui_core: ^0.1.0
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
    return MaterialApp(
      home: Scaffold(
        body: Renderer(
          response: 'root = Text(text: "Hello, OpenUI!")',
          library: Library<Widget>(<Component<Widget>>[
            defineComponent<Widget>(
              name: 'Text',
              schema: Schema.fromMap(const <String, Object?>{
                'type': 'object',
                'properties': <String, Object?>{
                  'text': <String, Object?>{'type': 'string'},
                },
              }),
              render: (ctx, props, renderNode, id) =>
                  Text(props['text'] as String? ?? ''),
            ),
          ]),
        ),
      ),
    );
  }
}
```

`Renderer` is a `StatefulWidget`; each call with a new `response` runs the
streaming parser, seeds the reactive store, and fires any queries the
parsed program declares.

## `Renderer` API

| Field | Purpose |
|---|---|
| `response: String?` | Cumulative source from the LLM. `null` = no content yet. |
| `library: Library<Widget>` | Component registry. Required. |
| `isStreaming: bool` | Whether `response` is still appending. Propagated to components via `RendererScope.isStreaming`. |
| `onAction: void Function(ActionEvent)?` | Notified when an action plan fires. |
| `onStateUpdate: void Function(Map<String, Object?>)?` | Notified after every store write with the post-write snapshot. |
| `initialState: Map<String, Object?>?` | Persisted state seed. Keys include the leading `$`. Wins over parsed defaults. |
| `onParseResult: void Function(ParseResult)?` | Fired once per parse pass. |
| `toolProvider: ToolProvider?` | Production transport for `Query` / `Mutation`. |
| `queryLoader: QueryLoader?` | Test seam — bypasses `toolProvider`. |
| `onError: void Function(List<OpenUIError>)?` | Notified when the active error set changes. |
| `rootName: String` | Entry-point statement (default `'root'`). |

## How components consume the renderer

Each component defines a `ComponentRender<Widget>` callback:

```dart
typedef ComponentRender<W> = W Function(
  EvalContext context,
  Map<String, Object?> props,
  W Function(AstNode node, EvalContext context) renderNode,
  String statementId,
);
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
  `void Function()` callbacks that the renderer
  ties to its action dispatcher.

Need access to the form-state cache or the store from a component?
`RendererScope.maybeFind(context)` exposes both.

## License

MIT — see [LICENSE](LICENSE).
