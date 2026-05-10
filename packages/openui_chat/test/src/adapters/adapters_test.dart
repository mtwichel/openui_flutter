// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';

import 'package:openui_chat/openui_chat.dart';
import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

Stream<List<int>> _fixture(String name) async* {
  final file = File('test/fixtures/$name');
  yield utf8.encode(file.readAsStringSync());
}

Stream<List<int>> _inline(String body) async* {
  yield utf8.encode(body);
}

String _joinDeltas(Iterable<AssistantStreamEvent> events) {
  final buffer = StringBuffer();
  for (final e in events) {
    if (e is AssistantTextDelta) buffer.write(e.delta);
  }
  return buffer.toString();
}

void main() {
  group('agUiAdapter', () {
    final adapter = agUiAdapter();

    test('decodes the recorded fixture into start + deltas + end', () async {
      final events = await adapter(_fixture('ag_ui.txt')).toList();
      expect(events.first, isA<AssistantMessageStart>());
      expect((events.first as AssistantMessageStart).messageId, 'msg-1');
      expect(events.last, isA<AssistantMessageEnd>());
      expect(_joinDeltas(events), 'root = Text(text: "hi")');
    });

    test('throws AdapterMismatchError on the first non-JSON payload', () async {
      final stream = adapter(_inline('data: not json\n\n'));
      expect(
        stream.toList(),
        throwsA(isA<AdapterMismatchError>()),
      );
    });

    test('throws AdapterMismatchError on a non-object JSON payload', () async {
      final stream = adapter(_inline('data: 42\n\n'));
      expect(stream.toList(), throwsA(isA<AdapterMismatchError>()));
    });

    test('ignores unknown event types', () async {
      const body =
          'data: {"type":"text_message_content","delta":"x"}\n\n'
          'data: {"type":"future_event"}\n\n';
      final events = await adapter(_inline(body)).toList();
      expect(_joinDeltas(events), 'x');
    });
  });

  group('openAICompletionsAdapter', () {
    final adapter = openAICompletionsAdapter();

    test('decodes the recorded fixture', () async {
      final events = await adapter(_fixture('openai_completions.txt')).toList();
      expect(_joinDeltas(events), 'root = Text(text: "hi")');
      expect(events.first, isA<AssistantMessageStart>());
      expect(events.last, isA<AssistantMessageEnd>());
    });

    test('stops at the [DONE] sentinel', () async {
      const body =
          'data: {"choices":[{"delta":{"content":"a"}}]}\n\n'
          'data: [DONE]\n\n'
          'data: {"choices":[{"delta":{"content":"b"}}]}\n\n';
      final events = await adapter(_inline(body)).toList();
      expect(_joinDeltas(events), 'a');
    });

    test(
      'throws AdapterMismatchError when the payload lacks choices',
      () async {
        const body = 'data: {"unexpected": true}\n\n';
        final stream = adapter(_inline(body));
        expect(stream.toList(), throwsA(isA<AdapterMismatchError>()));
      },
    );
  });

  group('openAIResponsesAdapter', () {
    final adapter = openAIResponsesAdapter();

    test('decodes the recorded fixture', () async {
      final events = await adapter(_fixture('openai_responses.txt')).toList();
      expect(_joinDeltas(events), 'root = Text(text: "hi")');
      expect(events.first, isA<AssistantMessageStart>());
      expect(events.last, isA<AssistantMessageEnd>());
    });

    test('throws AdapterMismatchError on non-JSON payload', () async {
      final stream = adapter(_inline('data: nope\n\n'));
      expect(stream.toList(), throwsA(isA<AdapterMismatchError>()));
    });
  });

  group('plainSseAdapter', () {
    final adapter = plainSseAdapter();

    test('emits start, every payload as a delta, end', () async {
      final events = await adapter(_fixture('plain_sse.txt')).toList();
      expect(events.first, isA<AssistantMessageStart>());
      expect(events.last, isA<AssistantMessageEnd>());
      expect(_joinDeltas(events), 'root =Text(text: "hi")');
    });

    test('accepts anything (no AdapterMismatchError path)', () async {
      const body = 'data: not-json\n\ndata: ":)"\n\n';
      final events = await adapter(_inline(body)).toList();
      expect(events.whereType<AssistantTextDelta>().length, 2);
    });
  });
}
