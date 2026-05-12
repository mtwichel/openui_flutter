// The example app consumes openui_chat experimental types — the
// entire openui_chat surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:openui_chat/openui_chat.dart';

/// One pre-recorded LLM script keyed by display name and asset path.
class StubScript {
  /// Creates a [StubScript].
  const StubScript({required this.name, required this.assetPath});

  /// Display name in the picker.
  final String name;

  /// Asset path under `assets/scripts/`.
  final String assetPath;
}

/// The five reference scripts shipped with the example app.
const List<StubScript> kStubScripts = <StubScript>[
  StubScript(name: '1. Hello', assetPath: 'assets/scripts/01_hello.txt'),
  StubScript(name: '2. Counter', assetPath: 'assets/scripts/02_counter.txt'),
  StubScript(name: '3. Table', assetPath: 'assets/scripts/03_table.txt'),
  StubScript(name: '4. Form', assetPath: 'assets/scripts/04_form.txt'),
  StubScript(name: '5. Charts', assetPath: 'assets/scripts/05_charts.txt'),
];

/// Pre-records OpenUI Lang programs and streams them token-by-token as
/// `plainSseAdapter`-friendly SSE bytes. Plugged into the chat
/// controller via `clientFactory`.
class StubLlmService {
  /// Creates a [StubLlmService] that always returns the script at
  /// [scriptPath]. Used by the example app's chat surface to switch
  /// scripts; each click reassigns the active path.
  StubLlmService({
    required this.scriptPath,
    Duration tokenDelay = const Duration(milliseconds: 12),
    AssetBundle? bundle,
  }) : _tokenDelay = tokenDelay,
       _bundle = bundle ?? rootBundle;

  /// The script the next `sendMessage` will replay. Mutable so the
  /// chat screen can swap scripts at runtime.
  String scriptPath;

  final Duration _tokenDelay;
  final AssetBundle _bundle;

  /// Returns a fake `http.Client` that ignores the request body and
  /// streams the active script as SSE-framed bytes.
  http.Client buildClient() => _StubHttpClient(_emit);

  Stream<List<int>> _emit() async* {
    final raw = await _bundle.loadString(scriptPath);
    final tokens = _tokenize(raw);
    for (final token in tokens) {
      yield utf8.encode(_frame(token));
      await Future<void>.delayed(_tokenDelay);
    }
  }

  /// Wraps [token] in one SSE event. Embedded `\n`s become separate
  /// `data:` lines so the framer joins them back with `\n` instead of
  /// treating each as an event boundary.
  String _frame(String token) {
    final buffer = StringBuffer();
    for (final line in token.split('\n')) {
      buffer
        ..write('data: ')
        ..write(line)
        ..write('\n');
    }
    buffer.write('\n');
    return buffer.toString();
  }

  /// Splits [source] into chunks that match the way a typical LLM
  /// would stream OpenUI Lang — fixed-size windows, never breaking on
  /// the middle of a punctuation pair. Cheaper than a real tokenizer
  /// and good enough for a demo.
  List<String> _tokenize(String source) {
    const chunkSize = 24;
    final out = <String>[];
    for (var i = 0; i < source.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, source.length);
      out.add(source.substring(i, end));
    }
    return out;
  }
}

class _StubHttpClient extends http.BaseClient {
  _StubHttpClient(this._stream);

  final Stream<List<int>> Function() _stream;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(_stream(), 200);
  }

  @override
  void close() {
    _closed = true;
  }

  /// Test seam — whether anyone called close on this client.
  bool get closed => _closed;
}

/// Wires a fresh [OpenUiChatController] backed by [StubLlmService].
OpenUiChatController buildStubChatController({
  required StubLlmService service,
}) {
  return OpenUiChatController(
    requestBuilder: defaultRequestBuilder(Uri.parse('stub://playback')),
    adapter: plainSseAdapter(),
    clientFactory: service.buildClient,
  );
}
