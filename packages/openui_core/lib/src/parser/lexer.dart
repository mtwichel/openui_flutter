import 'package:meta/meta.dart';

/// Token categories produced by [tokenize].
///
/// Marked `@experimental` because the wire format of [Token] may evolve
/// between v0.1 and v0.2 (e.g. new operator precedence rules might add
/// distinct token kinds).
@experimental
enum TokenKind {
  /// `[a-z_][a-zA-Z0-9_]*` — variable, prop name, builtin name (after `@`).
  ident,

  /// `[A-Z][a-zA-Z0-9_]*` — component name.
  type,

  /// `\$[a-zA-Z_][a-zA-Z0-9_]*` — reactive state reference.
  stateVar,

  /// `@[a-zA-Z_][a-zA-Z0-9_]*` — builtin sigil (e.g. `@Each`, `@Set`).
  builtin,

  /// Decimal integer or float (no scientific notation in v0.1).
  number,

  /// Double-quoted string with `\\` escapes; the surrounding quotes are
  /// stripped from [Token.value].
  string,

  /// One of `+ - * / % == != < > <= >= && || !`.
  ///
  /// Multi-char operators are emitted as a single token; single-char
  /// operators may also appear as part of [TokenKind.punct] when the
  /// position is unambiguous (e.g. `=` between an identifier and an
  /// expression).
  op,

  /// One of `( ) [ ] { } , . ? : =`.
  punct,

  /// Logical newline. Multiple physical newlines collapse into a single
  /// [TokenKind.newline] when they are adjacent.
  newline,

  /// Reserved word: `true`, `false`, or `null`.
  keyword,

  /// End of input. The tokenizer always emits this last.
  eof,
}

/// A single lexer-emitted token.
///
/// The [value] is the canonical textual form: identifiers and types match
/// the input verbatim; string literals have their surrounding quotes
/// stripped and escape sequences resolved; the synthetic `eof` token has
/// an empty [value].
@experimental
@immutable
class Token {
  /// Creates a token. Use [tokenize] in normal code.
  const Token(this.kind, this.value, this.offset);

  /// The token's category.
  final TokenKind kind;

  /// The canonical textual form (see class docs for normalization rules).
  final String value;

  /// Zero-based UTF-16 code-unit offset into the source where this token
  /// starts. Useful for error messages.
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          other.kind == kind &&
          other.value == value &&
          other.offset == offset;

  @override
  int get hashCode => Object.hash(kind, value, offset);

  @override
  String toString() => 'Token($kind, ${_truncate(value)}, @$offset)';

  static String _truncate(String s) {
    if (s.length <= 24) return '"$s"';
    return '"${s.substring(0, 21)}..."';
  }
}

/// Thrown when the lexer hits an input it cannot recover from when
/// `recoverable: false` is requested.
///
/// The streaming parser will call [tokenize] with `recoverable: true`, so
/// this exception is reserved for the eager mode used by tests and
/// diagnostics. The recoverable mode is the v0.1 contract for partial-tail
/// recovery; the streaming parser that consumes it lands in Phase 1.
@experimental
class LexException implements Exception {
  /// Creates a [LexException].
  LexException(this.message, this.offset);

  /// Human-readable description.
  final String message;

  /// Zero-based UTF-16 code-unit offset where the failure occurred.
  final int offset;

  @override
  String toString() => 'LexException at offset $offset: $message';
}

/// Lazily tokenizes [source] into the OpenUI Lang token stream.
///
/// Always emits a final [TokenKind.eof] token. By default malformed input
/// throws [LexException]; pass `recoverable: true` to coerce broken tails
/// (unterminated strings, dangling backslashes) into best-effort tokens
/// instead. The streaming parser uses recoverable mode.
///
/// The lexer is whitespace-insensitive within a line; newlines collapse
/// into a single [TokenKind.newline] when consecutive.
@experimental
Iterable<Token> tokenize(String source, {bool recoverable = false}) sync* {
  final lex = _Lexer(source, recoverable: recoverable);
  while (true) {
    final token = lex.next();
    yield token;
    if (token.kind == TokenKind.eof) return;
  }
}

class _Lexer {
  _Lexer(this._source, {required this.recoverable});

  final String _source;
  final bool recoverable;
  int _pos = 0;
  bool _justEmittedNewline = true; // suppress leading blank newlines

  static const _keywords = {'true', 'false', 'null'};

  Token next() {
    while (true) {
      _skipNonNewlineWhitespace();
      if (_pos >= _source.length) return Token(TokenKind.eof, '', _pos);

      final ch = _source.codeUnitAt(_pos);
      if (ch != _newline) break;

      final start = _pos;
      while (_pos < _source.length && _source.codeUnitAt(_pos) == _newline) {
        _pos++;
      }
      if (_justEmittedNewline) {
        // Collapse leading blank lines and runs of consecutive newlines.
        // Loop body re-checks position; this is bounded by input length.
        continue;
      }
      _justEmittedNewline = true;
      return Token(TokenKind.newline, '\n', start);
    }

    final ch = _source.codeUnitAt(_pos);
    _justEmittedNewline = false;

    if (ch == _doubleQuote) return _scanString();
    if (_isDigit(ch)) return _scanNumber();
    if (ch == _at) return _scanBuiltin();
    if (ch == _dollar) return _scanStateVar();
    if (_isIdentStart(ch)) return _scanIdentOrType();

    return _scanPunctOrOp();
  }

  // -------- scanners --------

  Token _scanString() {
    final start = _pos;
    _pos++; // opening quote
    final buf = StringBuffer();
    var closed = false;
    while (_pos < _source.length) {
      final c = _source.codeUnitAt(_pos);
      if (c == _doubleQuote) {
        _pos++;
        closed = true;
        break;
      }
      if (c == _backslash) {
        _pos++;
        if (_pos >= _source.length) {
          if (recoverable) break;
          throw LexException('dangling backslash in string', _pos);
        }
        final esc = _source.codeUnitAt(_pos);
        switch (esc) {
          case _doubleQuote:
            buf.writeCharCode(_doubleQuote);
          case _backslash:
            buf.writeCharCode(_backslash);
          case _n:
            buf.writeCharCode(_newline);
          case _r:
            buf.writeCharCode(_carriageReturn);
          case _t:
            buf.writeCharCode(_tab);
          default:
            // Unknown escape — keep verbatim, so `\@` round-trips.
            buf.writeCharCode(esc);
        }
        _pos++;
        continue;
      }
      buf.writeCharCode(c);
      _pos++;
    }
    if (!closed && !recoverable) {
      throw LexException('unterminated string', start);
    }
    return Token(TokenKind.string, buf.toString(), start);
  }

  Token _scanNumber() {
    final start = _pos;
    while (_pos < _source.length && _isDigit(_source.codeUnitAt(_pos))) {
      _pos++;
    }
    if (_pos < _source.length &&
        _source.codeUnitAt(_pos) == _dot &&
        _pos + 1 < _source.length &&
        _isDigit(_source.codeUnitAt(_pos + 1))) {
      _pos++; // dot
      while (_pos < _source.length && _isDigit(_source.codeUnitAt(_pos))) {
        _pos++;
      }
    }
    return Token(TokenKind.number, _source.substring(start, _pos), start);
  }

  Token _scanBuiltin() {
    final start = _pos;
    _pos++; // '@'
    if (_pos >= _source.length || !_isIdentStart(_source.codeUnitAt(_pos))) {
      if (recoverable) {
        return Token(TokenKind.builtin, '@', start);
      }
      throw LexException('expected identifier after @', _pos);
    }
    final nameStart = _pos;
    while (_pos < _source.length && _isIdentPart(_source.codeUnitAt(_pos))) {
      _pos++;
    }
    return Token(
      TokenKind.builtin,
      '@${_source.substring(nameStart, _pos)}',
      start,
    );
  }

  Token _scanStateVar() {
    final start = _pos;
    _pos++; // '$'
    if (_pos >= _source.length || !_isIdentStart(_source.codeUnitAt(_pos))) {
      if (recoverable) return Token(TokenKind.stateVar, r'$', start);
      throw LexException(r'expected identifier after $', _pos);
    }
    final nameStart = _pos;
    while (_pos < _source.length && _isIdentPart(_source.codeUnitAt(_pos))) {
      _pos++;
    }
    return Token(
      TokenKind.stateVar,
      '\$${_source.substring(nameStart, _pos)}',
      start,
    );
  }

  Token _scanIdentOrType() {
    final start = _pos;
    while (_pos < _source.length && _isIdentPart(_source.codeUnitAt(_pos))) {
      _pos++;
    }
    final word = _source.substring(start, _pos);
    if (_keywords.contains(word)) return Token(TokenKind.keyword, word, start);
    final firstChar = word.codeUnitAt(0);
    final isUpper = firstChar >= _upperA && firstChar <= _upperZ;
    return Token(isUpper ? TokenKind.type : TokenKind.ident, word, start);
  }

  Token _scanPunctOrOp() {
    final start = _pos;
    final ch = _source.codeUnitAt(_pos);
    final next = _pos + 1 < _source.length ? _source.codeUnitAt(_pos + 1) : 0;

    // Two-character operators.
    if (ch == _eq && next == _eq) return _emitOp('==', 2);
    if (ch == _bang && next == _eq) return _emitOp('!=', 2);
    if (ch == _lt && next == _eq) return _emitOp('<=', 2);
    if (ch == _gt && next == _eq) return _emitOp('>=', 2);
    if (ch == _amp && next == _amp) return _emitOp('&&', 2);
    if (ch == _pipe && next == _pipe) return _emitOp('||', 2);

    // Single-character operators (binary or unary).
    const opSet = <int>{
      _plus, _minus, _star, _slash, _percent,
      _bang, _lt, _gt, //
    };
    if (opSet.contains(ch)) {
      _pos++;
      return Token(TokenKind.op, String.fromCharCode(ch), start);
    }

    // Punctuation.
    const punctSet = <int>{
      _lparen, _rparen, _lbracket, _rbracket, //
      _lbrace, _rbrace, _comma, _dot, //
      _question, _colon, _eq, //
    };
    if (punctSet.contains(ch)) {
      _pos++;
      return Token(TokenKind.punct, String.fromCharCode(ch), start);
    }

    if (recoverable) {
      _pos++;
      return Token(TokenKind.punct, String.fromCharCode(ch), start);
    }
    throw LexException('unexpected character ${String.fromCharCode(ch)}', _pos);
  }

  Token _emitOp(String value, int length) {
    final start = _pos;
    _pos += length;
    return Token(TokenKind.op, value, start);
  }

  // -------- helpers --------

  void _skipNonNewlineWhitespace() {
    while (_pos < _source.length) {
      final c = _source.codeUnitAt(_pos);
      if (c == _space || c == _tab || c == _carriageReturn) {
        _pos++;
        continue;
      }
      break;
    }
  }

  static bool _isDigit(int c) => c >= _zero && c <= _nine;
  static bool _isIdentStart(int c) =>
      (c >= _a && c <= _z) ||
      (c >= _upperA && c <= _upperZ) ||
      c == _underscore;
  static bool _isIdentPart(int c) => _isIdentStart(c) || _isDigit(c);
}

// -------- ASCII char code constants --------
const int _newline = 0x0A;
const int _carriageReturn = 0x0D;
const int _tab = 0x09;
const int _space = 0x20;
const int _bang = 0x21;
const int _doubleQuote = 0x22;
const int _dollar = 0x24;
const int _percent = 0x25;
const int _amp = 0x26;
const int _lparen = 0x28;
const int _rparen = 0x29;
const int _star = 0x2A;
const int _plus = 0x2B;
const int _comma = 0x2C;
const int _minus = 0x2D;
const int _dot = 0x2E;
const int _slash = 0x2F;
const int _zero = 0x30;
const int _nine = 0x39;
const int _colon = 0x3A;
const int _lt = 0x3C;
const int _eq = 0x3D;
const int _gt = 0x3E;
const int _question = 0x3F;
const int _at = 0x40;
const int _upperA = 0x41;
const int _upperZ = 0x5A;
const int _lbracket = 0x5B;
const int _backslash = 0x5C;
const int _rbracket = 0x5D;
const int _underscore = 0x5F;
const int _a = 0x61;
const int _z = 0x7A;
const int _n = 0x6E;
const int _r = 0x72;
const int _t = 0x74;
const int _lbrace = 0x7B;
const int _pipe = 0x7C;
const int _rbrace = 0x7D;
