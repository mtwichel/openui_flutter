/// Headless chat controller and SSE adapters for OpenUI Flutter.
///
/// This is the only file consumers should import from `openui_chat`.
/// The `src/` tree is private. Every public symbol is currently marked
/// `@experimental` — the shape may change between v0.1 and v0.2.
library;

export 'src/adapters/adapter.dart'
    show
        AssistantMessageEnd,
        AssistantMessageStart,
        AssistantStreamEvent,
        AssistantTextDelta,
        AssistantToolCall,
        StreamProtocolAdapter;
export 'src/adapters/ag_ui.dart' show agUiAdapter;
export 'src/adapters/openai_completions.dart' show openAICompletionsAdapter;
export 'src/adapters/openai_responses.dart' show openAIResponsesAdapter;
export 'src/adapters/plain_sse.dart' show plainSseAdapter;
export 'src/chat_state.dart' show ChatState;
export 'src/controller.dart'
    show OpenUiChatController, RequestBuilder, defaultRequestBuilder;
export 'src/formats/message_format.dart'
    show MessageFormat, identityFormat, openAiFormat, openAiResponsesFormat;
export 'src/message.dart'
    show
        AssistantMessage,
        Message,
        SystemMessage,
        ToolCallMessage,
        ToolResultMessage,
        UserMessage;
export 'src/sse_framing.dart' show SseEvent, decodeSseBytes;
