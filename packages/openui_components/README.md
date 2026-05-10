# openui_components

[![Pub](https://img.shields.io/pub/v/openui_components.svg)](https://pub.dev/packages/openui_components)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Builtin component library for OpenUI Flutter.

Provides ~15 components in v0.1: `Stack`, `Card`, `CardHeader`, `TextContent`,
`MarkDownRenderer`, `Callout`, `Image`, `Table`, `Tabs`, `Form`, `Input`,
`Select`, `Button`, `Buttons`, `Separator`, `CodeBlock`, `BarChart`,
`LineChart`. Each is wired to the renderer's reactive store and form-state
cache.

Two ready-made libraries:

- `openuiLibrary()` — components only, no root wrapper.
- `openuiChatLibrary()` — wraps every response in a `Card`, matching the JS
  reference.

## Status

v0.1 in development. Phase 0 scaffold only.

## Install

```yaml
dependencies:
  openui_components: ^0.1.0
```

## License

MIT — see [LICENSE](LICENSE).
