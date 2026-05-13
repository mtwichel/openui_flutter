import 'dart:async';

import 'package:flutter/services.dart';

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

/// Pre-records OpenUI Lang programs and streams them token-by-token.
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

  /// Streams the active script in small chunks to mimic tokenized output.
  Stream<String> streamScript() async* {
    final raw = await _bundle.loadString(scriptPath);
    final tokens = _tokenize(raw);
    for (final token in tokens) {
      yield token;
      await Future<void>.delayed(_tokenDelay);
    }
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
