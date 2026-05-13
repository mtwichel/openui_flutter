# OpenUI Flutter

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

**OpenUI Lang in, Flutter widgets out.** This repo is a Flutter port of [OpenUI](https://www.openui.com): your model (or any source) produces **OpenUI Lang** text—line-oriented statements like `root = Stack([...])`—and you pass that text into the **`Renderer`** widget with a **component library**. The renderer parses incrementally (streaming-safe), keeps reactive state and forms in sync, and builds native widgets.

There is no separate “codegen” step: **valid OpenUI Lang is just a string** you obtain however you like (LLM stream, HTTP SSE, local fixture, file asset).

---

## How the pieces fit together

1. **OpenUI Lang source** — A growing `String` (cumulative assistant output). Usually from an LLM constrained by a **hand-authored system prompt** (this repo has no Dart equivalent to JS `library.prompt()` / `@openuidev/cli`). See [Authoring the system prompt](#3-authoring-the-system-prompt-this-repo) below and [docs/lang-reference.md](docs/lang-reference.md) for grammar and builtins. The upstream [System prompts](https://www.openui.com/docs/openui-lang/system-prompts) doc describes a **TypeScript/Node** toolchain you *may* reuse to pre-generate text; it is not how the Flutter packages work internally.
2. **`Library<Widget>`** — Registers component names (`Stack`, `Card`, `Form`, …) to Flutter builders. For most apps, use the built-in library from **`openui_components`** (`openuiLibrary()` or `openuiChatLibrary()`).
3. **`Renderer`** (from **`openui`**) — Takes `library`, the full `response` string so far, and `isStreaming`. On each update it re-parses and rebuilds the tree; set `isStreaming: true` while chunks are still arriving.

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

`openui_core` is pulled in transitively; add it explicitly only if you define custom components with `defineComponent` (see [packages/openui/README.md](packages/openui/README.md)).

### 2. Pick a built-in library

- **`openuiLibrary()`** — General-purpose; root is a `Stack`-style layout (good for playgrounds and standalone UIs).
- **`openuiChatLibrary()`** — Same components, chat-oriented defaults (see package docs / [OpenUI overview](https://www.openui.com/docs/openui-lang/overview#built-in-component-libraries)).

Create it once (e.g. in `State` or a top-level `final`) so the instance is stable across rebuilds.

### 3. Authoring the system prompt (this repo)

**There is no prompt generator in the Dart packages.** `openui_core` exposes `Library`, `defineComponent`, and parsers—it does not emit LLM instructions. You maintain one or more **`String`** system prompts yourself and pass them through your chat SDK or HTTP layer like any other app.

#### What ships in this repo (reference patterns)

**Live LLM (dartantic) — canonical example.** [`apps/openui_flutter_example/lib/src/llm_chat/dartantic_chat_service.dart`](apps/openui_flutter_example/lib/src/llm_chat/dartantic_chat_service.dart) defines `openUiLangSystemPrompt`, a large `const String`, and wires it as the first chat turn:

```dart
Chat(
  Agent(agentString),
  history: [ChatMessage.system(openUiLangSystemPrompt)],
);
```

That prompt is **curated**, not machine-generated from the library: a short grammar primer aligned with [docs/lang-reference.md](docs/lang-reference.md), an **explicit allowlist** of component names the prompt author chose to expose to the model (a subset of the full builtin set), action-step rules (`@Set`, `@Reset`, …), and **few-shot** OpenUI Lang programs (the project’s plans describe mirroring [`apps/openui_flutter_example/assets/scripts/`](apps/openui_flutter_example/assets/scripts/) such as `01_hello.txt`, `02_counter.txt`, `04_form.txt`). You can keep the string in Dart, split it across files, or load paragraphs from `rootBundle`—the runtime only sees the final `String` passed to the model.

#### Keeping prompts aligned with `openuiLibrary()`

To avoid drift between what the model may emit and what [`Renderer`](packages/openui/lib/src/renderer.dart) can resolve:

- **Allowlist by name:** `openuiLibrary().names` (see [`Library.names`](packages/openui_core/lib/src/library/library.dart)) returns every registered component `Type` token. Your prompt’s “use only these components” section can be built or tested from that iterable in Dart.
- **Stricter subset:** The example app intentionally documents only a **subset** in `openUiLangSystemPrompt` so smaller models stay on rails—even though `openuiChatLibrary()` registers more components than the prompt lists.
- **Advanced:** Each [`Component`](packages/openui_core/lib/src/library/library.dart) carries a JSON [`Schema`](packages/openui_core/lib/src/library/library.dart) for props; you can inspect or copy those definitions into the prompt by hand (there is no first-party “schema → English” helper yet).

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
  final _library = openuiLibrary();

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

If the OpenUI Lang program uses `Query` / `Mutation` or action steps (`@Set`, `@Run`, …), supply a **`toolProvider`** (or a test **`queryLoader`**) and handle **`onAction`** / **`onStateUpdate`** as needed. Details are in [packages/openui/README.md](packages/openui/README.md) and [docs/architecture.md](docs/architecture.md).

---

## Packages

| Package | Type | Purpose |
| --- | --- | --- |
| [`openui_core`](packages/openui_core) | pure Dart | Lexer, parser, AST, evaluator, reactive store, library DSL, action steps |
| [`openui`](packages/openui) | Flutter | `Renderer` widget, error boundary, form-state cache |
| [`openui_components`](packages/openui_components) | Flutter | Built-in widget library (`openuiLibrary` / `openuiChatLibrary`) |
| [`openui_mcp`](packages/openui_mcp) | pure Dart | `McpToolProvider` over `mcp_dart` |

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

Flutter pin rationale: **[docs/decisions/2026-05-10-phase0-decisions.md](docs/decisions/2026-05-10-phase0-decisions.md)** (decision **D1**).

### Status (v0.1)

Feature-complete for the initial scope: core language + streaming parser, Flutter `Renderer` + components, MCP tool provider, and the example app. Post–v0.1 backlog is deferred; see **docs/architecture.md** and repo issues for direction.

### Contributing

- CHANGELOG entry per affected package on PRs
- 100% line coverage on logic; `// coverage:ignore-line` needs a one-line justification
- Public API documented with dartdoc
- Each package’s `analysis_options.yaml` extends `very_good_analysis`

---

## License

MIT — see [LICENSE](LICENSE).
