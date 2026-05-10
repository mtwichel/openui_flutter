// Walking-skeleton lexer contract tests (Spike S0.2 deliverable).
//
// These tests are intentionally narrow. They lock in the token stream for
// the canonical OpenUI Lang shapes the streaming parser will rely on, and
// they exercise the recoverable mode that the streaming parser uses on the
// pending tail. The full contract suite (mid-string truncation, mid-bracket,
// etc.) lands alongside the streaming parser in Phase 1.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('tokenize', () {
    test('emits a single EOF for empty input', () {
      final tokens = tokenize('').toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.eof);
      expect(tokens.single.value, '');
    });

    test('classifies idents, types, statevars, and builtins', () {
      final tokens = tokenize(
        r'foo Stack $count @Each',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [
        TokenKind.ident,
        TokenKind.type,
        TokenKind.stateVar,
        TokenKind.builtin,
      ]);
      expect(tokens.map((t) => t.value), ['foo', 'Stack', r'$count', '@Each']);
    });

    test('classifies keywords distinctly from idents', () {
      final tokens = tokenize(
        'true false null nullish',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [
        TokenKind.keyword,
        TokenKind.keyword,
        TokenKind.keyword,
        TokenKind.ident,
      ]);
    });

    test('parses double-quoted strings with escapes', () {
      final tokens = tokenize(
        r'"hello\nworld" "quote\""',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [TokenKind.string, TokenKind.string]);
      expect(tokens.map((t) => t.value), ['hello\nworld', 'quote"']);
    });

    test('decodes the full string-escape table', () {
      final tokens = tokenize(
        r'"\t\r\\" "\@unknown"',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(2));
      // \t -> tab, \r -> carriage return, \\ -> backslash.
      expect(tokens[0].value, '\t\r\\');
      // Unknown escapes survive verbatim minus the backslash.
      expect(tokens[1].value, '@unknown');
    });

    test('parses single-character binary operators', () {
      final tokens = tokenize(
        '1 + 2 - 3 * 4 / 5 % 6',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(
        tokens.where((t) => t.kind == TokenKind.op).map((t) => t.value),
        ['+', '-', '*', '/', '%'],
      );
    });

    test('parses integer and decimal numbers', () {
      final tokens = tokenize(
        '42 3.14',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [TokenKind.number, TokenKind.number]);
      expect(tokens.map((t) => t.value), ['42', '3.14']);
    });

    test('emits multi-char operators as single tokens', () {
      final tokens = tokenize(
        '== != <= >= && ||',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.every((t) => t.kind == TokenKind.op), isTrue);
      expect(tokens.map((t) => t.value), ['==', '!=', '<=', '>=', '&&', '||']);
    });

    test('does not double-count physical newlines', () {
      final tokens = tokenize(
        'a\n\n\nb',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [
        TokenKind.ident,
        TokenKind.newline,
        TokenKind.ident,
      ]);
    });

    test('handles a complete state-assignment statement', () {
      final tokens = tokenize(
        r'$count = 0',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [
        TokenKind.stateVar,
        TokenKind.punct,
        TokenKind.number,
      ]);
      expect(tokens.map((t) => t.value), [r'$count', '=', '0']);
    });

    test('handles a comp_call with positional and named args', () {
      final tokens = tokenize(
        'root = Stack(direction: "row", [a, b])',
      ).where((t) => t.kind != TokenKind.eof).toList();
      // Just check the shape; the parser will validate the structure.
      expect(tokens.map((t) => t.kind), [
        TokenKind.ident, // root
        TokenKind.punct, // =
        TokenKind.type, // Stack
        TokenKind.punct, // (
        TokenKind.ident, // direction
        TokenKind.punct, // :
        TokenKind.string, // "row"
        TokenKind.punct, // ,
        TokenKind.punct, // [
        TokenKind.ident, // a
        TokenKind.punct, // ,
        TokenKind.ident, // b
        TokenKind.punct, // ]
        TokenKind.punct, // )
      ]);
    });

    test('preserves source offsets for error messages', () {
      final tokens = tokenize('foo bar').toList();
      expect(tokens[0].offset, 0);
      expect(tokens[1].offset, 4);
    });
  });

  group('tokenize (eager mode)', () {
    test('throws on unterminated string', () {
      expect(() => tokenize('"oh no').toList(), throwsA(isA<LexException>()));
    });

    test(r'throws on dangling $', () {
      expect(() => tokenize(r'$').toList(), throwsA(isA<LexException>()));
    });

    test('throws on dangling @', () {
      expect(() => tokenize('@').toList(), throwsA(isA<LexException>()));
    });

    test('throws on unexpected char', () {
      expect(() => tokenize('#').toList(), throwsA(isA<LexException>()));
    });

    test('throws on dangling backslash inside a string', () {
      expect(
        () => tokenize(r'"oops\').toList(),
        throwsA(isA<LexException>()),
      );
    });
  });

  group('LexException', () {
    test('toString includes offset and message', () {
      final ex = LexException('boom', 42);
      expect(ex.toString(), 'LexException at offset 42: boom');
    });
  });

  group('tokenize (recoverable mode)', () {
    test('emits a string token for unterminated string', () {
      final tokens = tokenize(
        '"oh no',
        recoverable: true,
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.string);
      expect(tokens.single.value, 'oh no');
    });

    test(r'emits a stateVar token for dangling $', () {
      final tokens = tokenize(
        r'$',
        recoverable: true,
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.stateVar);
      expect(tokens.single.value, r'$');
    });

    test('emits a builtin token for dangling @', () {
      final tokens = tokenize(
        '@',
        recoverable: true,
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.builtin);
      expect(tokens.single.value, '@');
    });

    test('emits punct token for unexpected char', () {
      final tokens = tokenize(
        '#',
        recoverable: true,
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.punct);
      expect(tokens.single.value, '#');
    });

    test('emits the prefix string up to a dangling backslash at EOF', () {
      final tokens = tokenize(
        r'"hello\',
        recoverable: true,
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.string);
      expect(tokens.single.value, 'hello');
    });
  });

  group('whitespace handling', () {
    test('treats tabs and carriage returns as in-line whitespace', () {
      final tokens = tokenize(
        'foo\tbar\rbaz',
      ).where((t) => t.kind != TokenKind.eof).toList();
      expect(tokens.map((t) => t.kind), [
        TokenKind.ident,
        TokenKind.ident,
        TokenKind.ident,
      ]);
      expect(tokens.map((t) => t.value), ['foo', 'bar', 'baz']);
    });

    test('input that is only whitespace and newlines yields just EOF', () {
      // Mixed alternating spaces and newlines should not blow the stack and
      // should not emit a leading newline token.
      final tokens = tokenize(' \n \n \n').toList();
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.eof);
    });
  });

  group('Token equality', () {
    test('compares by kind, value, and offset', () {
      const a = Token(TokenKind.ident, 'foo', 0);
      const b = Token(TokenKind.ident, 'foo', 0);
      const c = Token(TokenKind.ident, 'foo', 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString truncates long values for diagnostics', () {
      const longValue = 'a really very rather long token value here';
      const t = Token(TokenKind.string, longValue, 0);
      final repr = t.toString();
      // Repr keeps the leading 21 chars verbatim, then '...' as the suffix
      // before the closing quote.
      expect(repr, contains('"${longValue.substring(0, 21)}..."'));
      expect(repr, isNot(contains(longValue.substring(21))));
    });

    test('toString shows short values verbatim without truncation', () {
      const t = Token(TokenKind.ident, 'short', 7);
      expect(t.toString(), 'Token(TokenKind.ident, "short", @7)');
    });
  });
}
