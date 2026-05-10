/// Pure-Dart core for the OpenUI Flutter port.
///
/// This is the only file consumers should import from `openui_core`. The
/// `src/` tree is private. AST node types and `ParseResult` are
/// exported but marked `@experimental` — their shape may change between v0.1
/// and v0.2.
library;

export 'src/parser/lexer.dart' show LexException, Token, TokenKind, tokenize;
