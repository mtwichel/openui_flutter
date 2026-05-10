# Changelog

## 0.1.0 (unreleased)

- **feat**: `OpenUiChatController` — headless controller that drives a
  `Message` list through a configurable SSE adapter. Per-turn
  `http.Client` allocation; `cancelMessage` closes only the active
  client. Queue-and-replace concurrent sends.
- **feat**: `Message` sealed class — `UserMessage`,
  `AssistantMessage`, `ToolCallMessage`, `ToolResultMessage`,
  `SystemMessage`. UUID v4 ids; structural equality.
- **feat**: `ChatState` — immutable transcript snapshot
  (`messages`, `isRunning`, `error`, `threadId`) with `copyWith`.
- **feat**: SSE framing helper — frames a raw byte stream on `\n\n`
  through `Utf8Decoder(allowMalformed: true)`.
- **feat**: Four stream adapters — `agUiAdapter`,
  `openAICompletionsAdapter`, `openAIResponsesAdapter`,
  `plainSseAdapter`. Each throws `AdapterMismatchError` on the first
  malformed payload (except `plainSseAdapter`, which accepts anything).
- **feat**: `MessageFormat` — `identityFormat`, `openAiFormat`,
  `openAiResponsesFormat`.
- **feat**: `handleAction` — routes `ContinueConversationStep` back
  through `sendMessage` so `@ToAssistant` action steps roundtrip.
- **chore**: package scaffold (Phase 0).
