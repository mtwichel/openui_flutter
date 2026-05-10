# openui

[![Pub](https://img.shields.io/pub/v/openui.svg)](https://pub.dev/packages/openui)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Flutter `Renderer` widget for OpenUI Lang.

The renderer takes a streaming `response: String` from your LLM, parses it
against a `Library` of components, and rebuilds the widget tree on every chunk.
It owns the reactive store, the form-state cache (so `TextEditingController`s
survive mid-stream rebuilds), and the streaming-tolerant error boundary.

## Status

v0.1 in development. Phase 0 scaffold only — the `Renderer` widget lands in
the next PR. See the [top-level README](../../README.md).

## Install

```yaml
dependencies:
  openui: ^0.1.0
```

## License

MIT — see [LICENSE](LICENSE).
