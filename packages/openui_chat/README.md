# openui_chat

[![Pub](https://img.shields.io/pub/v/openui_chat.svg)](https://pub.dev/packages/openui_chat)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Headless chat controller for OpenUI Flutter.

`OpenUiChatController` is a pure-Dart class that talks SSE to your LLM
backend, streams `AssistantMessage` deltas into a `ChatState`, and
forwards `@ToAssistant` action steps back into the conversation. It
does not depend on Flutter — wire `stateStream` into Bloc, Provider,
Riverpod, or `setState` yourself.

## Status

v0.1, Phase 3 complete. Ships:

- `OpenUiChatController` with `sendMessage`, `cancelMessage`,
  `handleAction`, `dispose`.
- Five `Message` shapes (`User`, `Assistant`, `System`, `ToolCall`,
  `ToolResult`).
- Four stream adapters: `agUiAdapter`, `openAICompletionsAdapter`,
  `openAIResponsesAdapter`, `plainSseAdapter`.
- Three `MessageFormat` serializers: `identityFormat`, `openAiFormat`,
  `openAiResponsesFormat`.

## Install

```yaml
dependencies:
  openui_chat: ^0.1.0
```

## Quick start

```dart
import 'package:openui_chat/openui_chat.dart';

final controller = OpenUiChatController(
  requestBuilder: defaultRequestBuilder(Uri.parse('https://api.example.com/chat')),
  adapter: openAICompletionsAdapter(),
  messageFormat: openAiFormat,
);

controller.stateStream.listen((state) {
  // rebuild your UI here
});

await controller.sendMessage('Build me a card with a chart');
```

## Cancellation

Each `sendMessage` allocates its own `http.Client`. `cancelMessage()`
closes only that client; sibling controllers keep streaming.

## Concurrent sends

Calling `sendMessage` while a turn is already in flight cancels the
previous turn (queue-and-replace, per Decision D8).

## Adapters

| Adapter | Wire format |
| --- | --- |
| `agUiAdapter` | SSE; each `data:` line is a JSON `AGUIEvent`. |
| `openAICompletionsAdapter` | OpenAI Chat Completions SSE deltas. |
| `openAIResponsesAdapter` | OpenAI Responses API SSE. |
| `plainSseAdapter` | Raw text per `data:` line. |

Adapter selection is constructor-time. The first three throw
`AdapterMismatchError` from `openui_core` on the first malformed
payload, so a misconfigured backend fails loudly instead of producing
silent empty output.

## License

MIT — see [LICENSE](LICENSE).
