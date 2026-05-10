import 'package:meta/meta.dart';

import 'package:openui_chat/src/message.dart';

/// Maps the chat controller's [Message] list to the JSON shape an LLM
/// backend expects.
///
/// Three formats ship in v0.1, matching the JS reference:
///
/// - [identityFormat] — `[{id, role, content}]` over every message.
///   Generic.
/// - [openAiFormat] — OpenAI Chat Completions: `[{role, content}]` with
///   `assistant` / `user` / `system` roles. `id` is dropped.
/// - [openAiResponsesFormat] — OpenAI Responses API:
///   `[{role, content: [{type, text}]}]`.
///
/// Marked `@experimental` per D12.
@experimental
typedef MessageFormat =
    List<Map<String, Object?>> Function(List<Message> messages);

/// Identity format — `[{id, role, content}]`.
///
/// Marked `@experimental` per D12.
List<Map<String, Object?>> identityFormat(List<Message> messages) {
  return <Map<String, Object?>>[
    for (final m in messages)
      switch (m) {
        UserMessage(:final content) => {
          'id': m.id,
          'role': 'user',
          'content': content,
        },
        AssistantMessage(:final response) => {
          'id': m.id,
          'role': 'assistant',
          'content': response,
        },
        SystemMessage(:final content) => {
          'id': m.id,
          'role': 'system',
          'content': content,
        },
        ToolCallMessage(:final toolName, :final args) => {
          'id': m.id,
          'role': 'tool_call',
          'toolName': toolName,
          'args': args,
        },
        ToolResultMessage(:final toolCallId, :final result, :final isError) => {
          'id': m.id,
          'role': 'tool_result',
          'toolCallId': toolCallId,
          'result': result,
          'isError': isError,
        },
      },
  ];
}

/// OpenAI Chat Completions format — `[{role, content}]`. Tool call /
/// tool result messages are dropped (Completions has its own
/// `tool_calls` field that the renderer doesn't drive in v0.1).
///
/// Marked `@experimental` per D12.
List<Map<String, Object?>> openAiFormat(List<Message> messages) {
  final out = <Map<String, Object?>>[];
  for (final m in messages) {
    switch (m) {
      case UserMessage(:final content):
        out.add(<String, Object?>{'role': 'user', 'content': content});
      case AssistantMessage(:final response):
        out.add(<String, Object?>{'role': 'assistant', 'content': response});
      case SystemMessage(:final content):
        out.add(<String, Object?>{'role': 'system', 'content': content});
      case ToolCallMessage():
      case ToolResultMessage():
        // Tool-call round-trips don't fit Chat Completions cleanly in
        // v0.1; drop them.
        break;
    }
  }
  return out;
}

/// OpenAI Responses API format — `[{role, content: [{type:"text",
/// text}]}]`.
///
/// Marked `@experimental` per D12.
List<Map<String, Object?>> openAiResponsesFormat(List<Message> messages) {
  Map<String, Object?> wrap(String role, String text) => <String, Object?>{
    'role': role,
    'content': <Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': text},
    ],
  };

  final out = <Map<String, Object?>>[];
  for (final m in messages) {
    switch (m) {
      case UserMessage(:final content):
        out.add(wrap('user', content));
      case AssistantMessage(:final response):
        out.add(wrap('assistant', response));
      case SystemMessage(:final content):
        out.add(wrap('system', content));
      case ToolCallMessage():
      case ToolResultMessage():
        break;
    }
  }
  return out;
}
