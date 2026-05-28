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
///
/// Set [recoverable] when feeding the parser an `autoClose`-patched
/// tail: it switches the lexer into truncation-tolerant mode so a
/// dangling `\` or other partial token escapes through as a best-effort
/// token instead of throwing `LexException`. The grammar layer still
/// records [ParseException]s for genuine syntax errors.
@experimental
Program parseProgram(
  String source, {
  bool recoverable = false,
  bool validateBuiltinShapes = true,
}) {
  final tokens = tokenize(source, recoverable: recoverable).toList(
    growable: false,
  );
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
  if (validateBuiltinShapes) {
    for (final s in statements) {
      errors
        ..addAll(validateEachShape(s))
        ..addAll(validateQueryShape(s))
        ..addAll(validateComponentArgShape(s));
    }
  }
  return Program(statements: statements, errors: errors);
}

/// Walks [statement]'s expression for `@Each` builtin calls and returns
/// a `ParseException` for every call that does not match the spec shape
/// `@Each(list, "name", template)`.
///
/// When [committedOffsetBoundary] is non-null, calls whose statement's
/// `offset` is at or beyond the boundary are skipped. The streaming
/// parser uses that gate to suppress shape errors from the
/// autoClose-patched pending tail, where the third arg may still be
/// in flight.
///
/// Internal: re-used by the streaming parser to gate per-keystroke
/// validation. Not part of the public API.
@internal
List<ParseException> validateEachShape(
  Statement statement, {
  int? committedOffsetBoundary,
}) {
  if (committedOffsetBoundary != null &&
      statement.offset >= committedOffsetBoundary) {
    return const <ParseException>[];
  }
  final errors = <ParseException>[];
  _collectEachShapeErrors(statement.expression, errors);
  return errors;
}

void _collectEachShapeErrors(AstNode node, List<ParseException> out) {
  switch (node) {
    case final BuiltinCall b:
      if (b.name == '@Each') {
        final problem = _validateEachCall(b);
        if (problem != null) out.add(problem);
      }
      for (final arg in b.args) {
        _collectEachShapeErrors(arg.value, out);
      }
    case CompCall(:final args):
      for (final arg in args) {
        _collectEachShapeErrors(arg.value, out);
      }
    case MutationCall(:final args):
    case QueryCall(:final args):
      for (final arg in args) {
        _collectEachShapeErrors(arg.value, out);
      }
    case ArrayLit(:final elements):
      for (final e in elements) {
        _collectEachShapeErrors(e, out);
      }
    case ObjectLit(:final entries):
      for (final e in entries) {
        _collectEachShapeErrors(e.value, out);
      }
    case BinaryOp(:final left, :final right):
      _collectEachShapeErrors(left, out);
      _collectEachShapeErrors(right, out);
    case UnaryOp(:final operand):
      _collectEachShapeErrors(operand, out);
    case Ternary(:final condition, :final then, :final otherwise):
      _collectEachShapeErrors(condition, out);
      _collectEachShapeErrors(then, out);
      _collectEachShapeErrors(otherwise, out);
    case MemberAccess(:final target):
      _collectEachShapeErrors(target, out);
    case IndexAccess(:final target, :final index):
      _collectEachShapeErrors(target, out);
      _collectEachShapeErrors(index, out);
    case StateAssign(:final value):
      _collectEachShapeErrors(value, out);
    case Literal():
    case NullLiteral():
    case Reference():
    case StateRef():
      break;
  }
}

/// Walks [statement] for component calls with named arguments.
///
/// OpenUI Lang v0.5 uses positional-only component args. Named args
/// (`prop: expr`) are rejected with a clear parse error.
///
/// When [committedOffsetBoundary] is non-null, statements at or beyond
/// the boundary are skipped (streaming parser).
@internal
List<ParseException> validateComponentArgShape(
  Statement statement, {
  int? committedOffsetBoundary,
}) {
  if (committedOffsetBoundary != null &&
      statement.offset >= committedOffsetBoundary) {
    return const <ParseException>[];
  }
  final errors = <ParseException>[];
  _collectComponentArgShapeErrors(statement.expression, errors);
  return errors;
}

void _collectComponentArgShapeErrors(AstNode node, List<ParseException> out) {
  switch (node) {
    case CompCall(:final args):
      for (final arg in args) {
        if (arg.name != null) {
          out.add(
            ParseException(
              'component arguments must be positional; '
              'named arguments are not supported',
              arg.offset,
            ),
          );
        }
        _collectComponentArgShapeErrors(arg.value, out);
      }
    case BuiltinCall(:final args):
      for (final arg in args) {
        _collectComponentArgShapeErrors(arg.value, out);
      }
    case MutationCall(:final args):
    case QueryCall(:final args):
      for (final arg in args) {
        _collectComponentArgShapeErrors(arg.value, out);
      }
    case ArrayLit(:final elements):
      for (final e in elements) {
        _collectComponentArgShapeErrors(e, out);
      }
    case ObjectLit(:final entries):
      for (final e in entries) {
        _collectComponentArgShapeErrors(e.value, out);
      }
    case BinaryOp(:final left, :final right):
      _collectComponentArgShapeErrors(left, out);
      _collectComponentArgShapeErrors(right, out);
    case UnaryOp(:final operand):
      _collectComponentArgShapeErrors(operand, out);
    case Ternary(:final condition, :final then, :final otherwise):
      _collectComponentArgShapeErrors(condition, out);
      _collectComponentArgShapeErrors(then, out);
      _collectComponentArgShapeErrors(otherwise, out);
    case MemberAccess(:final target):
      _collectComponentArgShapeErrors(target, out);
    case IndexAccess(:final target, :final index):
      _collectComponentArgShapeErrors(target, out);
      _collectComponentArgShapeErrors(index, out);
    case StateAssign(:final value):
      _collectComponentArgShapeErrors(value, out);
    case Literal():
    case NullLiteral():
    case Reference():
    case StateRef():
      break;
  }
}

/// Walks [statement] for `Query(...)` calls and returns shape violations.
///
/// Rules:
/// - `Query(...)` may only appear as the entire RHS of a top-level query
///   statement (`name = Query(...)` with a non-`$` LHS).
/// - `$name = Query(...)` is rejected.
/// - Positional args only: string tool name, args object, defaults object,
///   optional refresh interval.
///
/// When [committedOffsetBoundary] is non-null, statements whose offset
/// is at or beyond the boundary are skipped.
///
/// Internal: re-used by the streaming parser.
@internal
List<ParseException> validateQueryShape(
  Statement statement, {
  int? committedOffsetBoundary,
}) {
  if (committedOffsetBoundary != null &&
      statement.offset >= committedOffsetBoundary) {
    return const <ParseException>[];
  }
  final errors = <ParseException>[];
  final rhs = statement.expression;
  if (rhs is QueryCall) {
    if (statement.name.startsWith(r'$')) {
      errors.add(
        ParseException(
          'Query results must use regular identifiers: '
          r'`metrics = Query(...)` not `$metrics = Query(...)`',
          statement.offset,
        ),
      );
    } else if (statement.kind == StatementKind.query) {
      final problem = _validateCanonicalQueryCall(rhs);
      if (problem != null) errors.add(problem);
    }
    return errors;
  }
  _collectNestedQueryCalls(rhs, errors);
  return errors;
}

/// Collects `$`-prefixed state variable names referenced inside [argsAst].
@internal
List<String> collectQueryDeps(AstNode? argsAst) {
  if (argsAst == null) return const <String>[];
  final refs = <String>{};
  void walk(AstNode node) {
    switch (node) {
      case StateRef(:final name):
        refs.add(name);
      case BuiltinCall(:final args):
      case CompCall(:final args):
      case MutationCall(:final args):
      case QueryCall(:final args):
        for (final arg in args) {
          walk(arg.value);
        }
      case ArrayLit(:final elements):
        elements.forEach(walk);
      case ObjectLit(:final entries):
        for (final e in entries) {
          walk(e.value);
        }
      case BinaryOp(:final left, :final right):
        walk(left);
        walk(right);
      case UnaryOp(:final operand):
        walk(operand);
      case Ternary(:final condition, :final then, :final otherwise):
        walk(condition);
        walk(then);
        walk(otherwise);
      case MemberAccess(:final target):
        walk(target);
      case IndexAccess(:final target, :final index):
        walk(target);
        walk(index);
      case StateAssign(:final value):
        walk(value);
      case Literal():
      case NullLiteral():
      case Reference():
        break;
    }
  }

  walk(argsAst);
  return refs.toList();
}

void _collectNestedQueryCalls(AstNode node, List<ParseException> out) {
  if (node is QueryCall) {
    out.add(
      ParseException(
        'Query(...) must be the entire RHS of a top-level assignment',
        node.offset,
      ),
    );
    return;
  }
  if (node is BuiltinCall && node.name == '@Query') {
    out.add(
      ParseException(
        '@Query is no longer supported — use '
        'data = Query("tool_name", {arg: value}, {defaults: []})',
        node.offset,
      ),
    );
    return;
  }
  switch (node) {
    case BuiltinCall(:final args):
    case CompCall(:final args):
    case MutationCall(:final args):
    case QueryCall(:final args):
      for (final arg in args) {
        _collectNestedQueryCalls(arg.value, out);
      }
    case ArrayLit(:final elements):
      for (final e in elements) {
        _collectNestedQueryCalls(e, out);
      }
    case ObjectLit(:final entries):
      for (final e in entries) {
        _collectNestedQueryCalls(e.value, out);
      }
    case BinaryOp(:final left, :final right):
      _collectNestedQueryCalls(left, out);
      _collectNestedQueryCalls(right, out);
    case UnaryOp(:final operand):
      _collectNestedQueryCalls(operand, out);
    case Ternary(:final condition, :final then, :final otherwise):
      _collectNestedQueryCalls(condition, out);
      _collectNestedQueryCalls(then, out);
      _collectNestedQueryCalls(otherwise, out);
    case MemberAccess(:final target):
      _collectNestedQueryCalls(target, out);
    case IndexAccess(:final target, :final index):
      _collectNestedQueryCalls(target, out);
      _collectNestedQueryCalls(index, out);
    case StateAssign(:final value):
      _collectNestedQueryCalls(value, out);
    case Literal():
    case NullLiteral():
    case Reference():
    case StateRef():
      break;
  }
}

ParseException? _validateCanonicalQueryCall(QueryCall call) {
  if (call.args.isEmpty) {
    return ParseException(
      'Query requires a string tool name as the first positional argument',
      call.offset,
    );
  }
  if (call.args.length > 4) {
    return ParseException(
      'Query accepts at most 4 positional arguments '
      '(tool, args, defaults, refreshSec)',
      call.offset,
    );
  }
  for (final arg in call.args) {
    if (arg.name != null) {
      return ParseException(
        'Query(...) only accepts positional arguments',
        arg.offset,
      );
    }
  }
  final first = call.args.first.value;
  if (first is! Literal || first.value is! String) {
    return ParseException(
      'Query requires a string literal tool name as the first argument',
      call.args.first.offset,
    );
  }
  return null;
}

ParseException? _validateEachCall(BuiltinCall call) {
  if (call.args.length != 3) {
    return ParseException(
      '@Each requires 3 args (list, "name", template) — got '
      '${call.args.length}',
      call.offset,
    );
  }
  final nameArg = call.args[1].value;
  if (nameArg is! Literal || nameArg.value is! String) {
    return ParseException(
      '@Each requires a string identifier literal as the second arg',
      call.args[1].offset,
    );
  }
  final value = nameArg.value! as String;
  if (!isValidLoopVarName(value)) {
    return ParseException(
      '@Each loop name "$value" is not a valid string identifier',
      call.args[1].offset,
    );
  }
  return null;
}

/// Whether [name] is a legal `@Each` loop variable: matches the IDENT
/// rule (`[a-z_][a-zA-Z0-9_]*`), is non-empty, is not a reserved
/// literal keyword (`true`, `false`, `null`), and does not begin with
/// `$` (which would mask the STATEVAR convention and `$item`/`$index`).
///
/// Shared between the parser-level shape validator and the evaluator
/// backstop in `builtins.dart` so the rule has a single source of
/// truth.
@internal
bool isValidLoopVarName(String name) {
  if (name.isEmpty) return false;
  if (name.startsWith(r'$')) return false;
  if (name == 'true' || name == 'false' || name == 'null') return false;
  return _loopVarNamePattern.hasMatch(name);
}

final RegExp _loopVarNamePattern = RegExp(r'^[a-z_][a-zA-Z0-9_]*$');

/// Parses [source] as a single expression (no `name = ` prefix).
///
/// Throws [ParseException] on the first error — there is no per-statement
/// recovery for a bare expression. Used by tests and by callers that need
/// an isolated RHS [AstNode] (for example `SetStep.valueAst` serialized as
/// the RHS only).
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
