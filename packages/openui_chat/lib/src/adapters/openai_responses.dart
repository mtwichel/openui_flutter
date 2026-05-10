// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:openui_chat/src/adapters/adapter.dart';
import 'package:openui_chat/src/sse_framing.dart';
import 'package:openui_core/openui_core.dart';

const String _adapterName = 'openAIResponsesAdapter';

/// Adapter for the OpenAI Responses API SSE format. Each `data:` line
/// is a JSON object with a `type` field. Recognised events:
///
/// - `response.output_text.delta` → `{type, delta: "..."}` →
///   [AssistantTextDelta]
/// - `response.created` → [AssistantMessageStart]
/// - `response.completed` → [AssistantMessageEnd]
///
/// Marked `@experimental` per D12.
StreamProtocolAdapter openAIResponsesAdapter() {
  return (Stream<List<int>> bytes) async* {
    var firstEvent = true;
    await for (final event in decodeSseBytes(bytes)) {
      if (event.data.isEmpty) continue;
      final result = _decode(event.data, firstEvent: firstEvent);
      firstEvent = false;
      if (result != null) yield result;
    }
  };
}

AssistantStreamEvent? _decode(String payload, {required bool firstEvent}) {
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
  switch (raw['type']) {
    case 'response.output_text.delta':
      final delta = raw['delta'];
      if (delta is String) return AssistantTextDelta(delta);
      return null;
    case 'response.created':
      return const AssistantMessageStart();
    case 'response.completed':
      return const AssistantMessageEnd();
  }
  return null;
}

String _preview(String s) => s.length <= 200 ? s : s.substring(0, 200);
