# openui_core

[![Pub](https://img.shields.io/pub/v/openui_core.svg)](https://pub.dev/packages/openui_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Pure-Dart core for the [OpenUI Flutter](../../README.md) port.

This package will own the OpenUI Lang language layer: lexer, parser, AST,
streaming parser, evaluator, reactive store, library DSL, action steps,
`mergeStatements`, and the tool-provider interface. It runs in any Dart
context — Flutter app, server, Cloudflare Worker, CLI.

## Status

v0.1 is in active development. The current package contains the Phase 0
walking-skeleton lexer with the full v0.1 token set and a 24-test contract
suite. Subsequent phases land the parser, evaluator, store, library DSL, and
the rest of the runtime.

## Install

```yaml
dependencies:
  openui_core: ^0.1.0
```

## What ships today

- `tokenize(source, {recoverable})` — yields a `Token` stream over OpenUI
  Lang source. Eager mode (`recoverable: false`, the default) throws
  `LexException` on malformed input. Recoverable mode emits best-effort
  tokens for partial-tail inputs the streaming parser will pass through.
- `Token`, `TokenKind`, `LexException` — value types and the error class.

```dart
import 'package:openui_core/openui_core.dart';

void main() {
  for (final t in tokenize(r'$count = 0')) {
    print(t);
  }
}
```

The barrel `lib/openui_core.dart` is the only file consumers should import.
Everything under `lib/src/**` is private. AST node types and `ParseResult`
are exported but marked `@experimental` — their shape may change between
v0.1 and v0.2.

See [`docs/lang-reference.md`](../../docs/lang-reference.md) for the language
grammar and semantics.

## License

MIT — see [LICENSE](LICENSE).
