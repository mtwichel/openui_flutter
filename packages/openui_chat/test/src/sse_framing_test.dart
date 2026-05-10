import 'dart:async';
import 'dart:convert';

import 'package:openui_chat/src/sse_framing.dart';
import 'package:test/test.dart';

Stream<List<int>> _bytes(List<String> chunks) async* {
  for (final chunk in chunks) {
    yield utf8.encode(chunk);
  }
}

Stream<String> _text(List<String> chunks) async* {
  for (final chunk in chunks) {
    yield chunk;
  }
}

void main() {
  group('decodeSseBytes', () {
    test('frames a single event terminated by a blank line', () async {
      final events = await decodeSseBytes(_bytes(['data: hello\n\n'])).toList();
      expect(events, [const SseEvent(data: 'hello')]);
    });

    test('joins multi-line data within one event', () async {
      final events = await decodeSseBytes(
        _bytes(['data: first\ndata: second\n\n']),
      ).toList();
      expect(events, [const SseEvent(data: 'first\nsecond')]);
    });

    test('captures event and id fields', () async {
      final events = await decodeSseBytes(
        _bytes(['event: greeting\nid: 42\ndata: hi\n\n']),
      ).toList();
      expect(
        events,
        [const SseEvent(data: 'hi', eventType: 'greeting', id: '42')],
      );
    });

    test('handles CRLF line endings', () async {
      final events = await decodeSseBytes(
        _bytes(['data: hi\r\n\r\n']),
      ).toList();
      expect(events, [const SseEvent(data: 'hi')]);
    });

    test('skips comment lines', () async {
      final events = await decodeSseBytes(
        _bytes([': keep-alive\ndata: x\n\n']),
      ).toList();
      expect(events, [const SseEvent(data: 'x')]);
    });

    test('splits across chunk boundaries', () async {
      // The "data: hello" line is split across three chunks; framing
      // must still resolve to a single event.
      final events = await decodeSseBytes(
        _bytes(['data:', ' hello', '\n\n']),
      ).toList();
      expect(events, [const SseEvent(data: 'hello')]);
    });

    test('flushes any trailing event at end-of-stream', () async {
      // Backends that close abruptly without a trailing \n\n still
      // get their last event delivered.
      final events = await decodeSseBytes(_bytes(['data: trail\n'])).toList();
      expect(events, [const SseEvent(data: 'trail')]);
    });

    test('tolerates malformed UTF-8 within an event', () async {
      // A bad byte inside one event's data must not throw —
      // Utf8Decoder(allowMalformed: true) replaces with U+FFFD and we
      // keep going. We deliberately bracket the bad byte with
      // surrounding ASCII so the event boundary stays predictable
      // across Dart versions' chunked-decoder behavior.
      Stream<List<int>> bytes() async* {
        yield utf8.encode('data: before ');
        yield [0xFF];
        yield utf8.encode(' after\n\n');
      }

      final events = await decodeSseBytes(bytes()).toList();
      expect(events.length, 1);
      expect(events.first.data, contains('before'));
      expect(events.first.data, contains('after'));
    });

    test('decodeSseText test seam frames the same as bytes', () async {
      final events = await decodeSseText(_text(['data: x\n\n'])).toList();
      expect(events, [const SseEvent(data: 'x')]);
    });

    test('SseEvent equality is structural', () {
      const a = SseEvent(data: 'x', eventType: 'e', id: '1');
      const b = SseEvent(data: 'x', eventType: 'e', id: '1');
      const c = SseEvent(data: 'y');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('propagates errors from the underlying byte stream', () {
      final controller = StreamController<List<int>>();
      final events = decodeSseBytes(controller.stream).toList();
      controller.addError(StateError('boom'));
      unawaited(controller.close());
      expect(events, throwsStateError);
    });
  });
}
