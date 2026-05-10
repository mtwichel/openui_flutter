// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:openui_chat/src/adapters/adapter.dart';
import 'package:openui_chat/src/sse_framing.dart';
import 'package:openui_core/openui_core.dart';

const String _adapterName = 'openAICompletionsAdapter';

/// Adapter for the OpenAI Chat Completions SSE format. Each `data:`
/// line is either `[DONE]` (marks end of stream) or a JSON object
/// like:
///
/// ```json
/// {"choices":[{"delta":{"content":" world"}}]}
/// ```
///
/// First-chunk shape varies — some servers send `{"role":"assistant"}`
/// with no content — so we don't throw [AdapterMismatchError] until we
/// see a payload that isn't JSON or doesn't have the `choices` array.
///
/// Marked `@experimental` per D12.
StreamProtocolAdapter openAICompletionsAdapter() {
  return (Stream<List<int>> bytes) async* {
    var firstEvent = true;
    yield const AssistantMessageStart();
    await for (final event in decodeSseBytes(bytes)) {
      if (event.data.isEmpty) continue;
      if (event.data == '[DONE]') break;
      final result = _decode(event.data, firstEvent: firstEvent);
      firstEvent = false;
      if (result != null) yield result;
    }
    yield const AssistantMessageEnd();
  };
}

AssistantTextDelta? _decode(String payload, {required bool firstEvent}) {
  Object? raw;
  try {
    raw = jsonDecode(payload);
  } on FormatException {
    if (firstEvent) {
      throw AdapterMismatchError(
        adapterName: _adapterName,
        payloadPreview: _preview(payload),
        hint: 'Expected JSON; got non-JSON. Wrong adapter?',
      );
    }
    return null;
  }
  if (raw is! Map<String, Object?>) return null;
  final choices = raw['choices'];
  if (choices is! List<Object?>) {
    if (firstEvent) {
      throw AdapterMismatchError(
        adapterName: _adapterName,
        payloadPreview: _preview(payload),
        hint: 'Expected a "choices" array. Wrong adapter?',
      );
    }
    return null;
  }
  if (choices.isEmpty) return null;
  final first = choices.first;
  if (first is! Map<String, Object?>) return null;
  final delta = first['delta'];
  if (delta is! Map<String, Object?>) return null;
  final content = delta['content'];
  if (content is String && content.isNotEmpty) {
    return AssistantTextDelta(content);
  }
  return null;
}

String _preview(String s) => s.length <= 200 ? s : s.substring(0, 200);
