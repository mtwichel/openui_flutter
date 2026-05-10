part of 'parser.dart';

/// Parses a single statement starting at [tokens][[start]].
///
/// On success, returns the parsed [Statement] and the index immediately
/// after the trailing newline (or `tokens.length` if the statement is the
/// last one and no newline follows). Throws [ParseException] on malformed
/// input; the caller is responsible for skipping to the next newline and
/// resuming.
({Statement statement, int next}) _parseStatement(
  List<Token> tokens,
  int start,
) {
  // The caller (parseProgram) gates on `tokens[start].kind != eof` and
  // never lands on a newline (the lexer collapses runs and never emits
  // a leading one), so we can read the LHS directly.
  var pos = start;
  final lhs = tokens[pos];
  if (lhs.kind != TokenKind.ident &&
      lhs.kind != TokenKind.type &&
      lhs.kind != TokenKind.stateVar) {
    throw ParseException(
      'expected identifier (got ${lhs.kind.name})',
      lhs.offset,
    );
  }
  pos++;

  if (pos >= tokens.length ||
      tokens[pos].kind != TokenKind.punct ||
      tokens[pos].value != '=') {
    throw ParseException(
      'expected "=" after identifier',
      tokens[pos].offset,
    );
  }
  pos++;

  // Parse the RHS expression. Build a tail-only token slice so the
  // expression parser's state (cursor, bracket depth) is local and
  // doesn't have to coordinate with the statement loop.
  final rest = tokens.sublist(pos);
  final exprParser = _ExpressionParser(rest);
  final expr = exprParser.parse();
  final consumed = exprParser._pos;
  pos += consumed;

  // The expression must be followed by a newline or EOF — anything else
  // means we stopped at an unexpected token (most often the user wrote
  // two statements on one line).
  if (pos < tokens.length &&
      tokens[pos].kind != TokenKind.newline &&
      tokens[pos].kind != TokenKind.eof) {
    throw ParseException(
      'unexpected token after expression: ${tokens[pos].value}',
      tokens[pos].offset,
    );
  }

  // Consume the trailing newline if present so the caller's `next` index
  // points at the first token of the following statement.
  if (pos < tokens.length && tokens[pos].kind == TokenKind.newline) {
    pos++;
  }

  return (
    statement: Statement(
      name: lhs.value,
      kind: classifyStatement(lhs.value, expr),
      expression: expr,
      offset: lhs.offset,
    ),
    next: pos,
  );
}
