# openui_chat

[![Pub](https://img.shields.io/pub/v/openui_chat.svg)](https://pub.dev/packages/openui_chat)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Headless chat controller for OpenUI Flutter.

`OpenUiChatController` is a plain `ChangeNotifier`-style class that talks SSE
to your LLM backend, streams `AssistantMessage` deltas, and dispatches
`ActionPlan` events. It does not depend on Flutter — wire it into Bloc,
Provider, Riverpod, or `setState` yourself.

Adapters in v0.1: `agUiAdapter`, `openAICompletionsAdapter`,
`openAIResponsesAdapter`, `plainSseAdapter`.

## Status

v0.1 in development. Phase 0 scaffold only.

## Install

```yaml
dependencies:
  openui_chat: ^0.1.0
```

## License

MIT — see [LICENSE](LICENSE).
