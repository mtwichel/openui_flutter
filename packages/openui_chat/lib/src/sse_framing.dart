import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

/// One parsed Server-Sent-Events event after `\n\n` framing.
///
/// The SSE spec also defines `event:`, `id:`, and `retry:` fields. v0.1
/// of `openui_chat` only consumes `data:` payloads — every other field
/// is ignored. The [data] string is the joined payload across every
/// `data:` line in the frame (newline-separated).
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class SseEvent {
  /// Creates an [SseEvent].
  const SseEvent({required this.data, this.eventType, this.id});

  /// Joined `data:` payload. Empty `data:` lines produce an empty
  /// trailing newline; the spec treats `data:\ndata:` as `"\n"`.
  final String data;

  /// Optional `event:` tag — passed through verbatim.
  final String? eventType;

  /// Optional `id:` tag — passed through verbatim.
  final String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseEvent &&
          other.data == data &&
          other.eventType == eventType &&
          other.id == id;

  @override
  int get hashCode => Object.hash(SseEvent, data, eventType, id);
}

/// Converts a stream of raw response bytes into [SseEvent]s.
///
/// Bytes pass through `Utf8Decoder(allowMalformed: true)` so a
/// malformed code unit mid-stream does not throw and kill the message.
/// Events are framed on `\n\n` (also `\r\n\r\n` per the spec).
/// Comments (lines starting with `:`) are dropped.
///
/// Marked `@experimental` per D12.
@experimental
Stream<SseEvent> decodeSseBytes(Stream<List<int>> bytes) {
  return bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(_lineSplitter)
      .transform(_eventFramer);
}

/// Test seam — frame a text stream that's already been UTF-8 decoded.
@visibleForTesting
Stream<SseEvent> decodeSseText(Stream<String> text) {
  return text.transform(_lineSplitter).transform(_eventFramer);
}

final StreamTransformer<String, String> _lineSplitter =
    StreamTransformer<String, String>.fromBind((source) {
      late StreamController<String> controller;
      final buffer = StringBuffer();
      StreamSubscription<String>? sub;

      controller = StreamController<String>(
        onListen: () {
          sub = source.listen(
            (chunk) {
              buffer.write(chunk);
              var s = buffer.toString();
              // Normalize CRLF to LF so framing logic doesn't need to
              // care about transport variation.
              s = s.replaceAll('\r\n', '\n');
              var idx = s.indexOf('\n');
              while (idx >= 0) {
                controller.add(s.substring(0, idx));
                s = s.substring(idx + 1);
                idx = s.indexOf('\n');
              }
              buffer
                ..clear()
                ..write(s);
            },
            onError: controller.addError,
            onDone: () {
              if (buffer.isNotEmpty) {
                controller.add(buffer.toString());
                buffer.clear();
              }
              unawaited(controller.close());
            },
          );
        },
        onCancel: () async => sub?.cancel(),
      );
      return controller.stream;
    });

final StreamTransformer<String, SseEvent> _eventFramer =
    StreamTransformer<String, SseEvent>.fromBind((source) {
      late StreamController<SseEvent> controller;
      final dataLines = <String>[];
      String? eventType;
      String? id;
      StreamSubscription<String>? sub;

      void flush() {
        if (dataLines.isEmpty && eventType == null && id == null) return;
        controller.add(
          SseEvent(
            data: dataLines.join('\n'),
            eventType: eventType,
            id: id,
          ),
        );
        dataLines.clear();
        eventType = null;
        id = null;
      }

      controller = StreamController<SseEvent>(
        onListen: () {
          sub = source.listen(
            (line) {
              if (line.isEmpty) {
                flush();
                return;
              }
              if (line.startsWith(':')) return; // comment
              final colon = line.indexOf(':');
              final field = colon < 0 ? line : line.substring(0, colon);
              var value = colon < 0 ? '' : line.substring(colon + 1);
              if (value.startsWith(' ')) value = value.substring(1);
              switch (field) {
                case 'data':
                  dataLines.add(value);
                case 'event':
                  eventType = value;
                case 'id':
                  id = value;
              }
            },
            onError: controller.addError,
            onDone: () {
              flush();
              unawaited(controller.close());
            },
          );
        },
        onCancel: () async => sub?.cancel(),
      );
      return controller.stream;
    });
