# openui

[![Pub](https://img.shields.io/pub/v/openui.svg)](https://pub.dev/packages/openui)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Flutter `Renderer` widget for OpenUI Lang.

The renderer takes a streaming `response: String` from your LLM, parses it
against a `LibraryDefinition` for schemas, resolves widgets through a
`ComponentRegistry`, and rebuilds the widget tree on every chunk. It owns
the reactive store, the form-state cache (so `TextEditingController`s survive
mid-stream rebuilds), the query manager, and a streaming-tolerant error
boundary.

## Status

v0.1. The package ships:

- `Renderer` — the streaming widget (requires triple wiring; see below).
- `ComponentRegistry` / `ToolRegistry` — behavior maps keyed by name.
- `ErrorBoundary` — per-element error capture with last-good fallback.
- `FormStateCache` — `TextEditingController` cache keyed by
  `(formName, fieldName)` with a 250 ms grace window.
- `QueryManager` — `@Query` / `@Run` cache backed by a `ToolRegistry`.
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

  static final _library = LibraryDefinition(
    components: [
      ComponentDefinition(
        name: 'Text',
        schema: Schema.fromMap(const {
          'type': 'object',
          'properties': {'text': {'type': 'string'}},
        }),
      ),
    ],
  );

  static final _componentRegistry = ComponentRegistry(
    renderers: {
      'Text': (ctx, props, renderNode, id) =>
          Text(props['text'] as String? ?? ''),
    },
  );

  static final _toolRegistry = ToolRegistry(executors: {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Renderer(
          response: 'root = Text(text: "Hello, OpenUI!")',
          library: _library,
          componentRegistry: _componentRegistry,
          toolRegistry: _toolRegistry,
        ),
      ),
    );
  }
}
```

For the full built-in library, use `standardLibraryDefinition()` and
`standardComponentRegistry()` from `openui_components`.

`Renderer` is a `StatefulWidget`; each call with a new `response` runs the
streaming parser, seeds the reactive store, and fires any queries the
parsed program declares.

## `Renderer` API

| Field | Purpose |
|---|---|
| `response: String?` | Cumulative source from the LLM. `null` = no content yet. |
| `library: LibraryDefinition` | Component and tool metadata. Required. |
| `componentRegistry: ComponentRegistry` | Name → render callback map. Required. |
| `toolRegistry: ToolRegistry` | Name → executor map. Required (may be empty). |
| `isStreaming: bool` | Whether `response` is still appending. Propagated to components via `RendererScope.isStreaming`. |
| `onAction: void Function(ActionEvent)?` | Notified when an action plan fires. |
| `onStateUpdate: void Function(Map<String, Object?>)?` | Notified after every store write with the post-write snapshot. |
| `initialState: Map<String, Object?>?` | Persisted state seed. Keys include the leading `$`. Wins over parsed defaults. |
| `onParseResult: void Function(ParseResult)?` | Fired once per parse pass. |
| `onError: void Function(List<OpenUIError>)?` | Notified when the active error set changes. |
| `rootName: String` | Entry-point statement (default `'root'`). |

## Custom component wiring checklist

When adding a component outside `openui_components`:

1. Create a `ComponentDefinition` (name, schema, description).
2. Implement a `ComponentRender` function.
3. Add the definition to your `LibraryDefinition` (directly or via `.extend()`).
4. Register the render fn in `ComponentRegistry` under the **same name**.
5. In tests, call `assertLibraryWiring` (see `packages/openui/test/helpers/wiring.dart`) to catch missing renderers or executors.

The same name alignment applies to tools: `ToolDefinition` in the library,
executor in `ToolRegistry`.

## How components consume the renderer

Each component implements a `ComponentRender` callback:

```dart
typedef ComponentRender = Widget Function(
  EvalContext context,
  Map<String, Object?> props,
  Widget Function(AstNode node, EvalContext context) renderNode,
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
