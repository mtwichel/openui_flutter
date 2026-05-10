# OpenUI Flutter

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

Flutter port of [OpenUI](https://www.openui.com), Thesys's open standard for
generative UI. LLMs stream a small declarative language (OpenUI Lang) and the
runtime renders it incrementally as native Flutter widgets.

This is a Melos-managed monorepo of five publishable packages plus an example
app. The shape mirrors [thesysdev/openui](https://github.com/thesysdev/openui)
with VGV layered-architecture conventions.

## Packages

| Package | Type | Purpose |
|---|---|---|
| [`openui_core`](packages/openui_core) | pure Dart | Lexer, parser, AST, evaluator, reactive store, library DSL, action steps |
| [`openui`](packages/openui) | Flutter | `Renderer` widget, error boundary, form-state cache |
| [`openui_chat`](packages/openui_chat) | pure Dart | `OpenUiChatController`, SSE adapters, message format |
| [`openui_components`](packages/openui_components) | Flutter | Builtin widget library (Stack, Card, Form, charts, ...) |
| [`openui_mcp`](packages/openui_mcp) | pure Dart | `McpToolProvider` over `mcp_dart` |

Plus a private example app under `apps/openui_flutter_example/` and a private
shared-test-helpers package under `packages/openui_test_helpers/`.

## Status

v0.1 is in active development. Phase 0 (architectural decisions, spikes, and
scaffold) is complete. Subsequent phases land the language core, renderer,
components, chat layer, MCP integration, and example app.

See [`docs/architecture.md`](docs/architecture.md) for the package map and data
flow, and [`docs/lang-reference.md`](docs/lang-reference.md) for the OpenUI
Lang grammar and semantics.

## Getting started

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
melos run test:flutter
```

## Toolchain

- Flutter `3.41.9` (channel `stable`)
- Dart `^3.9.0` (current: 3.11.5)
- Very Good CLI `^1.2.0`
- Melos `^7.7.0`

The CI workflows pin Flutter `3.41.9`. See
[`docs/decisions/2026-05-10-phase0-decisions.md`](docs/decisions/2026-05-10-phase0-decisions.md)
entry **D1** for why we deviate from the plan's `3.27.x` pin.

## Contributing

- Each PR must include a CHANGELOG entry per affected package.
- 100% line coverage on logic; `// coverage:ignore-line` requires a one-line
  justification.
- All public symbols must have dartdoc comments.
- Per-package `analysis_options.yaml` extends `very_good_analysis`.

## License

MIT — see [LICENSE](LICENSE).
