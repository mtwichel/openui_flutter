---
date: 2026-05-10
topic: openui-flutter-port
---

# OpenUI Flutter Port

## What We're Building

A Flutter port of [OpenUI](https://www.openui.com), the open standard for generative UI. Models stream UI as a small declarative language (OpenUI Lang) and the runtime renders it incrementally as native Flutter widgets. The port targets feature parity with the JavaScript reference implementation: a streaming parser, reactive `$state`, builtins (`@Count`, `@Filter`, `@Each`, etc.), `Query`/`Mutation` tool calls, and an action system (`@Set`, `@Run`, `@ToAssistant`, `@OpenUrl`).

The work ships as a small monorepo of pub.dev-publishable packages plus a Flutter example app demonstrating the full chat flow with stubbed LLM responses.

## Why This Approach

Three approaches were considered:

**Mirror the JS layered architecture (chosen).** Five packages: `openui_core` (pure Dart parser/runtime), `openui` (Flutter renderer + library DSL), `openui_chat` (headless chat state, streaming adapters), `openui_components` (built-in widget library), and `openui_mcp` (optional MCP adapter). Mirrors the reference implementation, lets non-chat consumers depend on the renderer alone, and keeps optional dependencies out of the core.

**Single mega-package.** Simpler to scaffold but violates VGV layered-architecture conventions, forces every consumer to pull charts and chat state, and leaves no room for `openui_core` to be useful in non-Flutter Dart contexts (e.g., backends generating prompts).

**Two packages (lang + everything Flutter).** Middle ground but couples chat layouts and chart components to the renderer, which inflates dependency footprint for users who only want to render.

The chosen layout matches the reference architecture, keeps `openui_core` framework-free, and lets each package evolve independently.

## Key Decisions

### Architecture

- **Five packages** — `openui_core`, `openui`, `openui_chat`, `openui_components`, `openui_mcp`. `openui_core` is pure Dart (no Flutter), the rest depend on Flutter as needed. **Why:** mirrors JS layout, allows backend-only use of `openui_core` for prompt generation, and keeps optional deps off the critical path.
- **Schema DSL: `json_schema_builder`** — Component prop schemas declared with `S.object({...})` fluent API. **Why:** Dart has no Zod equivalent; `json_schema_builder` ships a clean fluent API, runtime-introspectable, and dovetails with the existing `LibraryJSONSchema`-based parser.
- **Component-typed props via custom keyword** — JSON Schema has no native `Component` type. Encode child slots with `format: 'openui-component'` (single) or `format: 'openui-component-array'` (slot list) and a `x-component-ref` extension for typed sub-components (e.g., `Slice`, `Series`, `Col`). **Why:** keeps schemas standards-compliant while preserving the JS lib's typed-children semantics.
- **Reactive props via `PropSchema.reactive()` → `x-reactive: true`** — wraps any prop schema and emits the `x-reactive` extension keyword. The evaluator reads this keyword to detect two-way bindings (`$days` passed to a reactive prop emits a `ReactiveAssign` marker). **Why:** mirrors JS's `markReactive()` without inventing a parallel API; standards-compliant since `x-` keywords are reserved for extensions.
- **Form state hydration owned by the renderer** — `Renderer` holds a `ValueNotifier<Map<String, Map<String, Object?>>>` keyed by `formName → fieldName → value`. `TextField`s build with their controller initialized from this map; on change, the controller writes back via `onStateUpdate`. Controllers are disposed by the widget tree. **Why:** keeps form state outside Flutter's controller lifecycle while matching the JS hydration contract.
- **Insertion-order positional mapping** — Dart `Map` preserves insertion order, so the order of properties in `S.object({...})` becomes the positional-argument order. **Why:** matches the JS approach (Zod key order) without extra metadata.
- **Ship `mergeStatements` in v1** — port the JS edit-mode merge function so the LLM can patch existing programs by statement name. ~200 lines, no new deps. **Why:** small, self-contained, useful for any chat that supports edits; cheaper to port now than to retrofit later.

### State and rendering

- **`Renderer` widget** in `openui` mirrors the React `<Renderer />` API: takes `response` (raw text), `library`, `isStreaming`, `onAction`, `onStateUpdate`, `initialState`, `onParseResult`, `toolProvider`, `queryLoader`, `onError`. **Why:** API parity makes docs and JS examples translatable line-by-line.
- **Internal state via `ValueNotifier`/`ChangeNotifier`** in the renderer — no Bloc/Riverpod dep on the core renderer. **Why:** the renderer is a leaf widget; coupling it to a state-management package would force that choice on every consumer.
- **Component renderer signature** — `Widget Function(BuildContext, Map<String, Object?> props, Widget Function(Object?) renderNode, String? statementId)`. The `renderNode` callback recursively renders children/element values. **Why:** mirrors `ComponentRenderProps` from the JS library exactly.
- **Streaming-tolerant render** — error boundary equivalent shows last-good children when an evaluation/render error occurs, auto-recovers when valid input arrives. Implemented with a try/catch wrapper widget that caches the last successful child. **Why:** prevents UI from going blank during partial parses.

### Chat layer

- **Headless, stream-based** — `OpenUiChatController` exposes `Stream<ChatState>`, `Stream<Message>` and plain Dart classes. No `flutter_bloc` or `provider` dep. **Why:** users plug into whatever state-management they already use (Bloc, Riverpod, signals, raw `StreamBuilder`). VGV-friendly without forcing the choice.
- **Three streaming adapters in v1** — AG-UI events SSE, OpenAI Chat Completions SSE, plain SSE/text chunks. **Why:** AG-UI matches the JS reference backend, OpenAI is the most common direct integration, plain SSE handles custom backends and our example app. OpenAI Responses can come later.
- **Streaming via `http` + per-stream `http.Client`** — each in-flight stream owns its own `http.Client`; cancellation closes only that client. SSE parsing is tiny — split on `\n\n`, strip `data:` prefix, parse JSON. Decode bytes through `Utf8Decoder(allowMalformed: false)` to handle codepoints split across chunks. **Why:** sharing one client kills unrelated streams on cancel; naive UTF-8 concatenation breaks on multibyte boundaries. No SSE-package dependency needed.
- **Action plan execution wired through the controller** — `Renderer.onAction` forwards `ActionEvent`s to `OpenUiChatController.handleAction`, which dispatches by step type: `set`/`reset` mutate the renderer's reactive store; `run` re-fires the named query/mutation; `continue_conversation` enqueues a user message; `open_url` calls `url_launcher`. **Why:** centralizes integration so consumers don't reimplement the action contract per app.

### Tooling

- **MCP optional via separate `openui_mcp` package** — `openui_core` defines a small `ToolProvider` interface (`Future<Object?> callTool(String name, Map<String, Object?> args)`). Function-map providers ship in core. `openui_mcp` wraps `mcp_dart` and exposes an `McpToolProvider` adapter. **Why:** matches JS where MCP is an optional peer dep; keeps the core surface clean and lets MCP swap implementations without touching `openui_core`.
- **No CLI in v1** — skip the `openui-cli` port for now. Users scaffold via Very Good CLI (`very_good create flutter_app`) and add the packages manually. **Why:** the JS CLI mostly does Next.js scaffolding; we can add a brick later if there's demand.

### Components library (MVP set, ~15)

Stack, Card, CardHeader, TextContent, MarkDownRenderer (using `flutter_markdown`), Callout, Image, Table + Col, Tabs + TabItem, Form + FormControl + Input + Select + Button + Buttons, Separator, CodeBlock (plain monospace, no syntax highlighting in v1), BarChart, LineChart (using `fl_chart`).

**Why this slice:** covers ~80% of typical chat-generated UIs (text, layout, tables, forms, two charts). Easy to expand later. `fl_chart` is mature, MIT-licensed, and supports the chart types needed for full parity (radar, pie, scatter) when we extend.

### Example app

- **Stubbed-LLM chat app** at `example/openui_flutter_example`. **Why:** runs without an API key, shows every renderer feature (streaming, `$state`, `Query`/`Mutation`, forms, charts, actions) using pre-recorded scripts that simulate token-by-token streaming. Easy to demo, deterministic for tests.
- Includes a "showcase" screen where users type OpenUI Lang and see it render live, alongside the chat surface.

### Quality

- **Tests:** unit tests for lexer/parser/evaluator in `openui_core`; widget tests for the renderer and each component in `openui`/`openui_components`; integration test for the chat flow in the example app.
- **Documentation:** every public Dart symbol has dartdoc comments; each package ships a README mirroring its JS counterpart's structure (Install / What this does / Quick Start / API / Examples).
- **Linting:** `very_good_analysis` across all packages.
- **CI hint:** test all packages with `dart test` / `flutter test`, format check with `dart format`, lint check with `flutter analyze`.

## Risks

- **`mcp_dart` maturity unverified** — we picked it as the optional MCP backend without auditing release cadence, API stability, or test coverage. Mitigation: spike `openui_mcp` early; if `mcp_dart` is unsuitable, write a minimal MCP client ourselves (the protocol surface we need is small — `callTool` + envelope unwrapping).
- **`json_schema_builder` may strip unknown keywords** — our `format: 'openui-component'`, `x-component-ref`, and `x-reactive` extensions assume the builder preserves custom keywords on `toJson()`. If it doesn't, wrap `S.object({...})` in our own thin layer that re-injects extensions before handing the schema to the parser.
- **UTF-8 split across SSE chunks** — naive byte concatenation breaks on multibyte boundaries when an LLM emits non-ASCII text mid-chunk. Always pipe the raw byte stream through `Utf8Decoder(allowMalformed: false)` before SSE line splitting.
- **Streaming cancellation leaks** — sharing one `http.Client` across streams means cancelling one kills all others. Each `OpenUiChatController.send` allocates its own client and disposes it on completion or cancel.

## Open Questions

- **Tool-result extraction shape** — JS `extractToolResult` unwraps MCP response envelopes (`content[0].text` JSON-decode dance). Confirm `mcp_dart` returns the same envelope so we can port the helper directly.
- **Versioning and release** — pub.dev workspace setup with `melos` vs independent versioning per package. Decide during planning.
