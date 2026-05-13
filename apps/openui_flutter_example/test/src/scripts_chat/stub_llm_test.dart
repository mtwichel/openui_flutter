import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<String> _stream(StubLlmService service) async {
  final buffer = StringBuffer();
  await for (final delta in service.streamScript()) {
    buffer.write(delta);
  }
  return buffer.toString();
}

void main() {
  group('StubLlmService', () {
    test(
      'streams a multi-line script faithfully',
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
              'the local stream playback path.',
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
