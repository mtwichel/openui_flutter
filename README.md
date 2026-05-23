# OpenUI Flutter

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

**OpenUI Lang in, Flutter widgets out.** This repo is a Flutter port of [OpenUI](https://www.openui.com): your model (or any source) produces **OpenUI Lang** text—line-oriented statements like `root = Stack([...])`—and you pass that text into the **`Renderer`** widget with a **component library**. The renderer parses incrementally (streaming-safe), keeps reactive state and forms in sync, and builds native widgets.

There is no separate “codegen” step: **valid OpenUI Lang is just a string** you obtain however you like (LLM stream, HTTP SSE, local fixture, file asset).

---

## How the pieces fit together

1. **OpenUI Lang source** — A growing `String` (cumulative assistant output). Usually from an LLM constrained by a **system prompt** derived from your `LibraryDefinition` via `library.prompt()` (or `generatePrompt(library)` from `openui_core`). See [Authoring the system prompt](#3-authoring-the-system-prompt) below and [docs/lang-reference.md](docs/lang-reference.md) for grammar and builtins. For gaps vs the canonical [thesysdev/openui](https://github.com/thesysdev/openui) language and component set, see [docs/canonical-comparison.md](docs/canonical-comparison.md).
2. **Triple wiring** — `LibraryDefinition` (schemas + tool metadata), `ComponentRegistry` (render callbacks), and `ToolRegistry` (executors). For most apps, use `standardLibraryDefinition()` + `standardComponentRegistry()` from **`openui_components`**.
3. **`Renderer`** (from **`openui`**) — Takes `library`, `componentRegistry`, `toolRegistry`, the full `response` string so far, and `isStreaming`. On each update it re-parses and rebuilds the tree; set `isStreaming: true` while chunks are still arriving.

---

## Step-by-step: use OpenUI in your own Flutter app

### 1. Add dependencies

In your app’s `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  openui: ^0.1.0
  openui_components: ^0.1.0
```

`openui_core` is pulled in transitively; add it explicitly when you define custom `ComponentDefinition` / `ToolDefinition` values or call `generatePrompt`.

### 2. Pick the standard library

Create the triple wiring once (e.g. top-level `final`s) so instances are stable across rebuilds:

```dart
final library = standardLibraryDefinition();
final componentRegistry = standardComponentRegistry();
final toolRegistry = ToolRegistry(executors: {
  // app-specific tool executors keyed by name
});
final systemPrompt = library.prompt();
```

Pass the same `library` object to `Renderer` and to your LLM as the system prompt so schemas stay aligned.

### 3. Authoring the system prompt

**`LibraryDefinition.prompt()`** (or `generatePrompt(library)`) emits a system prompt from your registered components and tools. Extend the library first so the prompt matches runtime wiring:

```dart
final library = standardLibraryDefinition().extend(tools: [myToolDefinition()]);
final systemPrompt = library.prompt();
```

#### What ships in this repo (reference patterns)

**Live LLM (dartantic) — canonical example.** [`apps/openui_flutter_example/lib/chat/view/chat_page.dart`](apps/openui_flutter_example/lib/chat/view/chat_page.dart) builds `_chatLibraryDefinition` from `standardLibraryDefinition().extend(...)`, derives `_chatSystemPrompt` from `_chatLibraryDefinition.prompt()`, and passes the same library to `Renderer`.

#### Keeping prompts aligned with `standardLibraryDefinition()`

To avoid drift between what the model may emit and what [`Renderer`](packages/openui/lib/src/renderer.dart) can resolve:

- **Component allowlist:** iterate `library.components` and filter `internal: false` for names exposed to the model.
- **Tool schemas:** include app tools in `library.extend(tools: [...])` before calling `.prompt()`.
- **Triple wiring:** every component in the library needs a matching `ComponentRegistry` entry; every tool needs a `ToolRegistry` executor under the same name.

#### Optional: upstream JS/CLI output as input text

If you already maintain a React/TS OpenUI library and use [`@openuidev/cli`](https://www.openui.com/docs/openui-lang/system-prompts) or `generatePrompt` from `@openuidev/lang-core`, the **artifact is still a plain string**. You can check the generated `.txt` into this repo, load it from assets, or fetch it at startup—orthogonal to the Flutter renderer, which only consumes OpenUI Lang on the assistant channel.

### 4. Produce OpenUI Lang text

You do **not** need a Dart-side “codegen” for the UI program. You need a **string** that matches the grammar.

- **From an LLM:** Send the system prompt from step 3, then stream assistant **text** deltas. Instruct the model to emit **only** OpenUI Lang (no prose, no fenced markdown around the program) so `Renderer` can parse incrementally.
- **Without an LLM:** Use a static string or load `.txt` from assets while you integrate—same `Renderer` path.

### 5. Stream or batch into `Renderer`

`Renderer.response` must be the **entire program accumulated so far** (not just the latest token), matching how the JS `<Renderer response={...} />` works. While the source is still growing, set **`isStreaming: true`**.

```dart
import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';

class GenUiPane extends StatefulWidget {
  const GenUiPane({super.key});

  @override
  State<GenUiPane> createState() => _GenUiPaneState();
}

class _GenUiPaneState extends State<GenUiPane> {
  final _library = standardLibraryDefinition();
  final _componentRegistry = standardComponentRegistry();
  final _toolRegistry = ToolRegistry(executors: {});

  /// Cumulative OpenUI Lang from your LLM (or fixture).
  String _openUiSource = '';

  /// True while chunks are still arriving.
  bool _isStreaming = false;

  /// Call this from your LLM/SDK integration: append each text delta.
  void _onLlmTextDelta(String delta) {
    setState(() {
      _openUiSource += delta;
      _isStreaming = true;
    });
  }

  void _onLlmStreamFinished() {
    setState(() => _isStreaming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Renderer(
      library: _library,
      componentRegistry: _componentRegistry,
      toolRegistry: _toolRegistry,
      response: _openUiSource.isEmpty ? null : _openUiSource,
      isStreaming: _isStreaming,
      onError: (errors) {
        // Optional: log or show a banner; errors are also non-fatal in-tree.
        debugPrint('OpenUI errors: $errors');
      },
    );
  }
}
```

Wire `_onLlmTextDelta` / `_onLlmStreamFinished` to your provider (`dartantic`, `firebase_ai`, raw HTTP, etc.). The only contract `Renderer` cares about is **cumulative text + streaming flag**.

### 6. Queries, mutations, and actions (when you need them)

If the OpenUI Lang program uses `@Query` / `@Run` or action steps (`@Set`, `@Run`, …), register executors on **`ToolRegistry`** and handle **`onAction`** / **`onStateUpdate`** as needed. Details are in [packages/openui/README.md](packages/openui/README.md) and [docs/architecture.md](docs/architecture.md).

---

## Packages

| Package | Type | Purpose |
| --- | --- | --- |
| [`openui_core`](packages/openui_core) | pure Dart | Lexer, parser, AST, evaluator, reactive store, library definitions, prompt generation |
| [`openui`](packages/openui) | Flutter | `Renderer` widget, error boundary, form-state cache |
| [`openui_components`](packages/openui_components) | Flutter | Built-in widget library (`standardLibraryDefinition` / `standardComponentRegistry`) |
| [`openui_mcp`](packages/openui_mcp) | pure Dart | MCP adapter (`asOpenUIToolPairs`) |

Plus the private example app [`apps/openui_flutter_example/`](apps/openui_flutter_example/) and test helpers [`packages/openui_test_helpers/`](packages/openui_test_helpers/).

The layout mirrors [thesysdev/openui](https://github.com/thesysdev/openui) with VGV-style layering. Deeper package map and data flow: **[docs/architecture.md](docs/architecture.md)**.

---

## Reference implementation (optional)

The example app wires **Scripts** (recorded OpenUI Lang replayed as deltas) and **Live** (real LLM + Firebase). It is useful as a working reference, not a prerequisite for using the packages.

- Code: [`apps/openui_flutter_example/`](apps/openui_flutter_example/)
- Live + Firebase setup: [`apps/openui_flutter_example/README.md`](apps/openui_flutter_example/README.md)
- Hosted Scripts build: **[mtwichel.github.io/openui_flutter](https://mtwichel.github.io/openui_flutter/)**

---

## For contributors

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
melos run test:flutter
```

The example app’s tests are run separately (not in `melos run test:flutter`):

```bash
cd apps/openui_flutter_example && flutter test
```

### Toolchain

- Flutter **3.41.9** (stable) — CI pins this version
- Dart **^3.9.0**
- Melos **^7.7.0**
- Very Good CLI **^1.2.0**

### Status (v0.1)

Feature-complete for the initial scope: core language + streaming parser, Flutter `Renderer` + components, MCP adapter, and the example app. Post–v0.1 backlog is deferred; see **docs/architecture.md** and repo issues for direction.

### Contributing

- CHANGELOG entry per affected package on PRs
- 100% line coverage on logic; `// coverage:ignore-line` needs a one-line justification
- Public API documented with dartdoc
- Each package’s `analysis_options.yaml` extends `very_good_analysis`

---

## License

MIT — see [LICENSE](LICENSE).
