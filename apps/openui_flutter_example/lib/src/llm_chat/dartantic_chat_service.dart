import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// dartantic provider name registered by `main.dart` and consumed by
/// the default agent string below. Sharing the constant keeps the
/// registration and consumption in lockstep — change one and you change
/// both.
const String kGeminiProvider = 'google';

/// Default agent string used by the production service.
const String _kDefaultAgent = '$kGeminiProvider:gemini-flash-latest';

/// Live-LLM implementation of [DartanticChatService] backed by a dartantic
/// [Chat] against the Gemini Developer API. The `google` provider
/// factory must be registered in `main.dart`
/// before instantiation.
class DartanticChatService {
  /// Creates a [DartanticChatService].
  ///
  /// [agentString] is the dartantic agent identifier; defaults to
  /// `google:gemini-flash-latest`.
  /// [systemPrompt] is the system prompt injected at the start of every
  /// chat session.
  DartanticChatService({
    required String systemPrompt,
    String agentString = _kDefaultAgent,
  }) : _agentString = agentString,
       _systemPrompt = systemPrompt,
       _chat = _makeChat(agentString, systemPrompt);

  final String _agentString;
  final String _systemPrompt;
  Chat _chat;

  static Chat _makeChat(String agentString, String systemPrompt) {
    debugPrint('[chat] === new session ===');
    debugPrint('[chat] agent: $agentString');
    debugPrint('[chat] system prompt:');
    debugPrint(systemPrompt);
    return Chat(
      Agent(
        agentString,
        chatModelOptions: const GoogleChatModelOptions(
          serverSideTools: {GoogleServerSideTool.googleSearch},
        ),
        enableThinking: true,
      ),
      history: [ChatMessage.system(systemPrompt)],
    );
  }

  /// Sends [text] to the model as the next turn of the conversation and
  /// returns a stream of output/thinking/tool events. The stream completes when
  /// the model finishes; it errors if the model or transport fails.
  Stream<LlmChatEvent> sendMessage(String text) async* {
    debugPrint('[chat] --- user ---');
    debugPrint(text);
    debugPrint('[chat] --- assistant (streaming) ---');

    final assembled = StringBuffer();
    final seenToolActivities = <String>{};
    await for (final chunk in _chat.sendStream(text)) {
      final thinking = chunk.thinking;
      if (thinking != null && thinking.trim().isNotEmpty) {
        debugPrint('[chat:thinking] $thinking');
        yield LlmChatEvent.thinking(thinking);
      }

      for (final toolActivity in _toolActivitiesFromMetadata(chunk.metadata)) {
        if (seenToolActivities.add(toolActivity)) {
          debugPrint('[chat:tool] $toolActivity');
          yield LlmChatEvent.tool(toolActivity);
        }
      }

      if (chunk.output.isNotEmpty) {
        assembled.write(chunk.output);
        yield LlmChatEvent.output(chunk.output);
      }
    }

    debugPrint('[chat] --- assistant (complete) ---');
    debugPrint(assembled.toString());
  }

  /// Discards in-memory history so the next [sendMessage] starts a fresh
  /// conversation.
  void reset() {
    _chat = _makeChat(_agentString, _systemPrompt);
  }
}

Iterable<String> _toolActivitiesFromMetadata(
  Map<String, Object?> metadata,
) sync* {
  if (metadata.isEmpty) return;
  for (final entry in metadata.entries) {
    if (!_isToolMetadataKey(entry.key)) continue;
    final details = _toolMetadataDetails(entry.value);
    if (details.isEmpty) {
      yield entry.key;
      continue;
    }
    for (final detail in details) {
      yield '${entry.key}: $detail';
    }
  }
}

bool _isToolMetadataKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('tool') ||
      normalized.contains('search') ||
      normalized.contains('function');
}

List<String> _toolMetadataDetails(Object? value) {
  if (value == null) return const [];
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? const [] : <String>[text];
  }
  if (value is num || value is bool) {
    return <String>['$value'];
  }
  if (value is List<Object?>) {
    return value.expand(_toolMetadataDetails).toList(growable: false);
  }
  if (value is Map<Object?, Object?>) {
    final type = value['type']?.toString();
    final name = value['name']?.toString();
    final status = value['status']?.toString();
    final summary = [type, name, status]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .join(' · ');
    if (summary.isNotEmpty) return <String>[summary];
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList(growable: false);
  }
  return <String>[value.toString()];
}

/// Event kinds emitted by [DartanticChatService.sendMessage].
enum LlmChatEventType {
  /// Assistant-visible output text.
  output,

  /// Model reasoning/thinking updates.
  thinking,

  /// Tool-use activity emitted by the model.
  tool,
}

/// Stream event emitted by the backing LLM service.
class LlmChatEvent {
  /// Creates an [LlmChatEvent].
  const LlmChatEvent({
    required this.type,
    required this.text,
  });

  /// Creates an assistant output event.
  const LlmChatEvent.output(String text)
    : this(type: LlmChatEventType.output, text: text);

  /// Creates a thinking event.
  const LlmChatEvent.thinking(String text)
    : this(type: LlmChatEventType.thinking, text: text);

  /// Creates a tool-activity event.
  const LlmChatEvent.tool(String text)
    : this(type: LlmChatEventType.tool, text: text);

  /// Event category.
  final LlmChatEventType type;

  /// Event text payload.
  final String text;
}
