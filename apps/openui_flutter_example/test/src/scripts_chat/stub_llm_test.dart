// The example app consumes openui_chat experimental types — the
// entire openui_chat surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openui_chat/openui_chat.dart';
import 'package:openui_flutter_example/src/scripts_chat/stub_llm.dart';

class _InMemoryBundle extends CachingAssetBundle {
  _InMemoryBundle(this._files);

  final Map<String, String> _files;

  @override
  Future<ByteData> load(String key) async {
    final value = _files[key];
    if (value == null) {
      throw StateError('Asset not in bundle: $key');
    }
    final bytes = utf8.encode(value);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

http.Request _stubRequest() =>
    http.Request('POST', Uri.parse('stub://playback'));

Future<String> _stream(StubLlmService service) async {
  final response = await service.buildClient().send(_stubRequest());
  final events = await plainSseAdapter()(response.stream).toList();
  final buffer = StringBuffer();
  for (final event in events) {
    if (event is AssistantTextDelta) buffer.write(event.delta);
  }
  return buffer.toString();
}

void main() {
  group('StubLlmService', () {
    test(
      'streams a multi-line script faithfully through plainSseAdapter',
      () async {
        const source = '''
root = Card(children: [
  CardHeader(title: "Hi"),
  TextContent(text: "Body")
])
''';
        final service = StubLlmService(
          scriptPath: 'demo.txt',
          tokenDelay: Duration.zero,
          bundle: _InMemoryBundle(const {'demo.txt': source}),
        );

        expect(
          await _stream(service),
          source,
          reason:
              'Every character of the source must round-trip through '
              'the framer. A regression here means embedded newlines '
              'are again being treated as event boundaries.',
        );
      },
    );

    test('preserves embedded blank lines in the source', () async {
      const source = 'a = 1\n\nb = 2\n';
      final service = StubLlmService(
        scriptPath: 'blanks.txt',
        tokenDelay: Duration.zero,
        bundle: _InMemoryBundle(const {'blanks.txt': source}),
      );

      // The blank line between statements is preserved verbatim.
      expect((await _stream(service)).contains('\n\n'), isTrue);
    });

    test(
      'switching scriptPath flips the script the next send replays',
      () async {
        final service = StubLlmService(
          scriptPath: 'a.txt',
          tokenDelay: Duration.zero,
          bundle: _InMemoryBundle(const {
            'a.txt': 'one\n',
            'b.txt': 'two\n',
          }),
        );

        expect(await _stream(service), 'one\n');
        service.scriptPath = 'b.txt';
        expect(await _stream(service), 'two\n');
      },
    );
  });
}
