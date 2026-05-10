import 'package:meta/meta.dart';

import 'package:openui_core/src/parser/lexer.dart';

part 'ast.dart';
part 'expressions.dart';
part 'statements.dart';

/// Thrown when the parser cannot interpret a completed statement.
///
/// The streaming parser preprocesses the pending tail through
/// [autoClose] before tokenizing, so this exception is reserved for
/// completed statements (everything up to the last bracket-depth-zero
/// newline). Higher-level callers catch it, record the error against the
/// statement's offset, and skip to the next newline.
@experimental
class ParseException implements Exception {
  /// Creates a [ParseException].
  ParseException(this.message, this.offset);

  /// Human-readable description of the failure.
  final String message;

  /// Zero-based UTF-16 code-unit offset where the parser stopped.
  final int offset;

  @override
  String toString() => 'ParseException at offset $offset: $message';
}

/// The result of parsing a complete OpenUI Lang program.
///
/// Contains every successfully parsed [Statement] in source order, plus a
/// list of [ParseException]s captured during per-statement recovery. The
/// streaming parser merges this into the richer `ParseResult.meta` shape;
/// for now the bare program is enough to drive evaluator tests.
@experimental
@immutable
class Program {
  /// Creates a [Program].
  Program({
    required List<Statement> statements,
    required List<ParseException> errors,
  }) : statements = List.unmodifiable(statements),
       errors = List.unmodifiable(errors);

  /// Statements in source order. Re-assignments to the same id appear as
  /// distinct entries; downstream layers (the streaming parser, the
  /// materializer) decide on overwrite vs. append semantics.
  final List<Statement> statements;

  /// Per-statement parse errors. Statements that errored are absent from
  /// [statements] — recovery skips to the next newline before continuing.
  final List<ParseException> errors;
}

/// Parses [source] into a [Program].
///
/// Newline-delimited statements are parsed independently. A failure on
/// one statement is recorded in [Program.errors] and the parser resumes
/// at the next newline; subsequent statements still parse cleanly.
///
/// Use [parseExpression] when only an RHS is needed (tests, fixtures).
/// Use the streaming parser (Phase 1, separate file) when feeding tokens
/// chunk-by-chunk.
@experimental
Program parseProgram(String source) {
  final tokens = tokenize(source).toList(growable: false);
  final statements = <Statement>[];
  final errors = <ParseException>[];
  var pos = 0;
  while (pos < tokens.length && tokens[pos].kind != TokenKind.eof) {
    try {
      final result = _parseStatement(tokens, pos);
      statements.add(result.statement);
      pos = result.next;
    } on ParseException catch (e) {
      errors.add(e);
      pos = _skipToNextStatement(tokens, pos);
    }
  }
  return Program(statements: statements, errors: errors);
}

/// Parses [source] as a single expression (no `name = ` prefix).
///
/// Throws [ParseException] on the first error — there is no per-statement
/// recovery for a bare expression. Used by tests and by the action
/// dispatcher when a `SetStep.valueAst` was originally serialized as
/// just the RHS.
@experimental
AstNode parseExpression(String source) {
  final tokens = tokenize(source).toList(growable: false);
  final parser = _ExpressionParser(tokens);
  final node = parser.parse();
  // Verify nothing trails the expression except newlines and EOF.
  while (parser._pos < tokens.length) {
    final t = tokens[parser._pos];
    if (t.kind == TokenKind.eof || t.kind == TokenKind.newline) {
      parser._pos++;
      continue;
    }
    throw ParseException(
      'unexpected token after expression: ${t.value}',
      t.offset,
    );
  }
  return node;
}

/// Inserts synthetic closers for unmatched `"`, `(`, `[`, `{` in [text].
///
/// Used by the streaming parser on the **pending tail** (everything
/// after the last bracket-depth-zero newline) so partial input is
/// renderable mid-stream. Completed statements never pass through this
/// function — they are tokenized as-is.
///
/// The pass is bracket-balanced and string-aware: a `"` opens a string
/// region in which `\\`-escapes consume the next character, and only `"`
/// closes it. The closer stack is appended in reverse so the result is
/// well-balanced. An unterminated string is closed first, then the
/// bracket stack drains.
@experimental
String autoClose(String text) {
  final stack = <int>[];
  var inString = false;
  var i = 0;
  while (i < text.length) {
    final code = text.codeUnitAt(i);
    if (inString) {
      if (code == _backslash) {
        // Skip the escape sequence; if the backslash is the very last
        // character, exit the loop. The caller will close the string.
        i += 2;
        continue;
      }
      if (code == _doubleQuote) {
        inString = false;
      }
      i++;
      continue;
    }
    if (code == _doubleQuote) {
      inString = true;
    } else if (code == _lparen) {
      stack.add(_rparen);
    } else if (code == _lbracket) {
      stack.add(_rbracket);
    } else if (code == _lbrace) {
      stack.add(_rbrace);
    } else if (code == _rparen || code == _rbracket || code == _rbrace) {
      if (stack.isNotEmpty && stack.last == code) {
        stack.removeLast();
      }
    }
    i++;
  }
  if (!inString && stack.isEmpty) return text;
  final buf = StringBuffer(text);
  if (inString) buf.writeCharCode(_doubleQuote);
  for (var j = stack.length - 1; j >= 0; j--) {
    buf.writeCharCode(stack[j]);
  }
  return buf.toString();
}

int _skipToNextStatement(List<Token> tokens, int start) {
  var pos = start;
  while (pos < tokens.length) {
    final k = tokens[pos].kind;
    if (k == TokenKind.eof) return pos;
    if (k == TokenKind.newline) return pos + 1;
    pos++;
  }
  return pos;
}

// ASCII char codes used by autoClose. Duplicated from the lexer rather
// than imported because the lexer's table is private to that file and
// re-exporting would widen its surface for no real win.
const int _backslash = 0x5C;
const int _doubleQuote = 0x22;
const int _lparen = 0x28;
const int _rparen = 0x29;
const int _lbracket = 0x5B;
const int _rbracket = 0x5D;
const int _lbrace = 0x7B;
const int _rbrace = 0x7D;
