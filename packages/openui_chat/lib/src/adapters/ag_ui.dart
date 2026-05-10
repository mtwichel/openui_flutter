// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:openui_chat/src/adapters/adapter.dart';
import 'package:openui_chat/src/sse_framing.dart';
import 'package:openui_core/openui_core.dart';

const String _adapterName = 'agUiAdapter';

/// Adapter for the AG-UI SSE protocol: every `data:` payload is a
/// JSON-encoded AG-UI event. Recognised shapes:
///
/// - `{type: "text_message_content", delta: "..."}`
///   → [AssistantTextDelta]
/// - `{type: "text_message_start", messageId: "..."}`
///   → [AssistantMessageStart]
/// - `{type: "text_message_end"}` → [AssistantMessageEnd]
///
/// Unknown event types are dropped (they may add new lifecycle events
/// in the future and we don't want to break older clients).
///
/// Throws [AdapterMismatchError] on the first payload that isn't a
/// JSON object — a misrouted OpenAI Completions stream, for example.
///
/// Marked `@experimental` per D12.
StreamProtocolAdapter agUiAdapter() {
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
  if (raw is! Map<String, Object?>) {
    if (firstEvent) {
      throw AdapterMismatchError(
        adapterName: _adapterName,
        payloadPreview: _preview(payload),
        hint: 'Expected a JSON object; got ${raw.runtimeType}.',
      );
    }
    return null;
  }
  switch (raw['type']) {
    case 'text_message_content':
      final delta = raw['delta'];
      if (delta is String) return AssistantTextDelta(delta);
      return null;
    case 'text_message_start':
      final id = raw['messageId'];
      return AssistantMessageStart(messageId: id is String ? id : null);
    case 'text_message_end':
      return const AssistantMessageEnd();
  }
  return null;
}

String _preview(String s) => s.length <= 200 ? s : s.substring(0, 200);
