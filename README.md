# OpenUI Flutter

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

**OpenUI Lang in, Flutter widgets out.** This repo is a Flutter port of [OpenUI](https://www.openui.com): your model (or any source) produces **OpenUI Lang** text—line-oriented statements like `root = Stack([...])`—and you pass that text into the **`Renderer`** widget with a **render library**. The renderer parses incrementally (streaming-safe), keeps reactive state and forms in sync, and builds native widgets.

There is no separate “codegen” step: **valid OpenUI Lang is just a string** you obtain however you like (LLM stream, HTTP SSE, local fixture, file asset).

---

## How the pieces fit together

1. **OpenUI Lang source** — A growing `String` (cumulative assistant output). Usually from an LLM constrained by a **system prompt**. See [Authoring the system prompt](#3-authoring-the-system-prompt) and [docs/lang-reference.md](docs/lang-reference.md) for grammar and builtins.
2. **`RenderLibrary<Widget>`** — Pairs component **specs** (`Component` + JSON Schema) with Flutter **renderers** and optional **tool handlers**. For most apps, start from **`standardLibrary()`** in `openui_components`.
3. **`Renderer`** (from **`openui`**) — Takes `library`, the full `response` string so far, and `isStreaming`. On each update it re-parses and rebuilds the tree; set `isStreaming: true` while chunks are still arriving.

---

## Step-by-step: use OpenUI in your own Flutter app

### 1. Add dependencies

In your app’s `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  openui: ^0.0.1-dev.2
  openui_components: ^0.0.1-dev.2
  shadcn_ui: ^0.54.0
```

`openui_core` is pulled in transitively; add it explicitly when you define custom components, tools, or prompts.

### 2. Pick a built-in library

**`standardLibrary()`** — All 16 builtin components (`Stack`, `Card`, `Input`, charts, …) as a `RenderLibrary<Widget>`. Create it once (e.g. in `State` or a top-level `final`) so the instance is stable across rebuilds.

Wrap the app in **`ShadApp`** so shadcn-styled builtins match the example (see [packages/openui_components/README.md](packages/openui_components/README.md)).

### 3. Authoring the system prompt

**`openui_core` can generate LLM instructions from your library spec.** Call `library.prompt()` on any `Library` or `RenderLibrary` — it emits a grammar primer, component signatures derived from each `Component.schema`, tool metadata, and default rules (see `generatePrompt` in `openui_core`).

#### What ships in this repo (reference pattern)

The example app builds the prompt from the same library the renderer uses:

```dart
final snackbar = SnackbarTool();
final fetchProducts = FetchProductsTool();
final fetchProduct = FetchProductTool();

final library = standardLibrary().extend(
  tools: [snackbar, fetchProducts, fetchProduct],
  toolHandlers: {
    snackbar.name: snackbar.callTool,
    fetchProducts.name: fetchProducts.callTool,
    fetchProduct.name: fetchProduct.callTool,
  },
);
final systemPrompt = library.prompt();
```

[`apps/openui_flutter_example/lib/chat/view/chat_page.dart`](apps/openui_flutter_example/lib/chat/view/chat_page.dart) wires that string into [`DartanticChatService`](apps/openui_flutter_example/lib/chat/dartantic_chat_service.dart) as the first system message. The model only sees components and tools registered on that library instance.

#### Keeping prompts aligned with `standardLibrary()`

- **Generated allowlist:** `standardLibrary().prompt()` lists every non-`internal` component (`Col` and `TabItem` are internal).
- **Custom rules / examples:** pass `additionalRules:` or `examples:` to `prompt()`.
- **Hand-edited prompts:** still valid — the renderer only cares about OpenUI Lang text, not how the prompt was produced.

#### Optional: upstream JS/CLI output as input text

If you maintain a React/TS OpenUI library and use [`@openuidev/cli`](https://www.openui.com/docs/openui-lang/system-prompts), the **artifact is still a plain string**. You can check generated `.txt` into this repo or load it from assets — orthogonal to the Flutter renderer.

### 4. Produce OpenUI Lang text

You need a **string** that matches the grammar.

- **From an LLM:** Send the system prompt, then stream assistant **text** deltas. Instruct the model to emit **only** OpenUI Lang (no prose, no fenced markdown around the program) so `Renderer` can parse incrementally.
- **Without an LLM:** Use a static string or load `.txt` from assets while you integrate—same `Renderer` path.

### 5. Stream or batch into `Renderer`

`Renderer.response` must be the **entire program accumulated so far** (not just the latest token), matching how the JS `<Renderer response={...} />` works. While the source is still growing, set **`isStreaming: true`**.

```dart
import 'package:flutter/material.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GenUiPane extends StatefulWidget {
  const GenUiPane({super.key});

  @override
  State<GenUiPane> createState() => _GenUiPaneState();
}

class _GenUiPaneState extends State<GenUiPane> {
  final _library = standardLibrary();

  /// Cumulative OpenUI Lang from your LLM (or fixture).
  String _openUiSource = '';

  /// True while chunks are still arriving.
  bool _isStreaming = false;

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
      response: _openUiSource.isEmpty ? null : _openUiSource,
      isStreaming: _isStreaming,
      onError: (errors) {
        debugPrint('OpenUI errors: $errors');
      },
    );
  }
}
```

Wire `_onLlmTextDelta` / `_onLlmStreamFinished` to your provider (`dartantic`, raw HTTP, etc.). The only contract `Renderer` cares about is **cumulative text + streaming flag**.

### 6. Queries, mutations, and actions (when you need them)

`@Query` assignments call tools registered on `RenderLibrary.toolHandlers`. Action steps (`@Set`, `@Run`, …) flow through `onAction` / `onContinueConversation` / `onStateUpdate` as needed. See [packages/openui/README.md](packages/openui/README.md) and [docs/architecture.md](docs/architecture.md).

For MCP-backed tools, see [packages/openui_mcp/README.md](packages/openui_mcp/README.md).

---

## Packages

| Package | Type | Purpose |
| --- | --- | --- |
| [`openui_core`](packages/openui_core) | pure Dart | Lexer, parser, AST, evaluator, reactive store, `Library` / `RenderLibrary`, `generatePrompt`, tools |
| [`openui`](packages/openui) | Flutter | `Renderer` widget, error boundary, form-state cache |
| [`openui_components`](packages/openui_components) | Flutter | Built-in widgets via `standardLibrary()` (shadcn_ui) |
| [`openui_mcp`](packages/openui_mcp) | pure Dart | `McpTool` + `asOpenUITools()` for MCP servers |

Plus the private example app [`apps/openui_flutter_example/`](apps/openui_flutter_example/) and test helpers [`packages/openui_test_helpers/`](packages/openui_test_helpers/).

The layout mirrors [thesysdev/openui](https://github.com/thesysdev/openui) with VGV-style layering. Deeper package map and data flow: **[docs/architecture.md](docs/architecture.md)**.

---

## Reference implementation (optional)

The example app is a **live Gemini chat** that streams OpenUI Lang into `Renderer` with DummyJSON product tools. It is useful as a working reference, not a prerequisite for using the packages.

- Code: [`apps/openui_flutter_example/`](apps/openui_flutter_example/)
- Setup: [`apps/openui_flutter_example/README.md`](apps/openui_flutter_example/README.md)

---

## For contributors

```bash
dart pub global activate melos
dart pub get          # resolves the pub workspace (root pubspec.lock)
melos bootstrap       # optional: syncs shared deps and runs bootstrap hooks
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

Feature-complete for the initial scope: core language + streaming parser, Flutter `Renderer` + shadcn-based components, MCP tool adapters, and the example app. Post–v0.1 backlog is deferred; see **docs/architecture.md** and repo issues for direction.

### Contributing

- CHANGELOG entry per affected package on PRs
- 100% line coverage on logic; `// coverage:ignore-line` needs a one-line justification
- Public API documented with dartdoc
- Each package’s `analysis_options.yaml` extends `very_good_analysis`

---

## License

MIT — see [LICENSE](LICENSE).
