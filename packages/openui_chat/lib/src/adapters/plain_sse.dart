import 'dart:async';

import 'package:openui_chat/src/adapters/adapter.dart';
import 'package:openui_chat/src/sse_framing.dart';

/// Plain-text SSE adapter: each `data:` payload is a raw delta. Used
/// by the example app's stubbed-LLM script player and any backend that
/// wants to skip JSON envelopes.
///
/// No `AdapterMismatchError` paths — anything decodes as plain text.
/// The stream emits exactly one [AssistantMessageStart] at the head
/// and one [AssistantMessageEnd] when the upstream completes.
///
/// Marked `@experimental` per D12.
StreamProtocolAdapter plainSseAdapter() {
  return (Stream<List<int>> bytes) async* {
    yield const AssistantMessageStart();
    await for (final event in decodeSseBytes(bytes)) {
      if (event.data.isEmpty) continue;
      yield AssistantTextDelta(event.data);
    }
    yield const AssistantMessageEnd();
  };
}
