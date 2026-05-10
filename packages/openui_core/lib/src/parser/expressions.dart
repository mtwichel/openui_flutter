part of 'parser.dart';

// Pratt-parser binding powers.
//
// The convention: each binary operator has a `(leftBp, rightBp)` pair.
// `leftBp` is the threshold the surrounding context must clear to pull
// the operator in; `rightBp` is the threshold passed to the recursive
// call when the operator's right operand is parsed. `leftBp == rightBp`
// is left-associative; `leftBp > rightBp` is right-associative.
//
// Higher numbers bind tighter. Postfix (member/index) is the tightest
// at 80; unary prefix sits below it at 70 so that `-foo.bar` parses as
// `-(foo.bar)`. Ternary is the loosest at 5/4 (right-associative): a
// chain like `a ? b : c ? d : e` reads as `a ? b : (c ? d : e)`.
const int _bpPostfix = 80;
const int _bpUnary = 70;

class _ExpressionParser {
  _ExpressionParser(this._tokens);

  final List<Token> _tokens;
  int _pos = 0;

  /// Tracks whether the cursor is inside a `(`, `[`, or `{` group.
  ///
  /// When non-zero, [_peek] silently skips newline tokens — newlines
  /// inside brackets are insignificant. At the top level (depth 0) a
  /// newline ends the expression, mirroring the JS reference.
  int _bracketDepth = 0;

  AstNode parse() {
    final node = _parseExpr(0);
    return node;
  }

  Token _peek() {
    while (_pos < _tokens.length) {
      final t = _tokens[_pos];
      if (t.kind == TokenKind.newline && _bracketDepth > 0) {
        _pos++;
        continue;
      }
      return t;
    }
    // Defensive: the lexer always emits an EOF token last, so this
    // fallback is unreachable. Kept as a safety net.
    return _tokens.last; // coverage:ignore-line
  }

  Token _advance() {
    final t = _peek();
    _pos++;
    return t;
  }

  bool _atExpressionEnd(Token t) =>
      t.kind == TokenKind.eof || t.kind == TokenKind.newline;

  AstNode _parseExpr(int minBp) {
    var left = _parseUnit();
    while (true) {
      final tok = _peek();
      if (_atExpressionEnd(tok)) break;

      if (_isPostfixStart(tok)) {
        if (_bpPostfix < minBp) break;
        left = _parsePostfix(left);
        continue;
      }

      final bp = _binaryBp(tok);
      if (bp == null) break;
      if (bp.$1 < minBp) break;

      if (tok.kind == TokenKind.punct && tok.value == '?') {
        _advance();
        final thenExpr = _parseExpr(0);
        _expectPunct(':');
        final elseExpr = _parseExpr(bp.$2);
        left = Ternary(left, thenExpr, elseExpr, offset: left.offset);
        continue;
      }

      final opTok = _advance();
      final right = _parseExpr(bp.$2);
      left = BinaryOp(opTok.value, left, right, offset: left.offset);
    }
    return left;
  }

  AstNode _parseUnit() {
    final t = _peek();
    switch (t.kind) {
      case TokenKind.number:
        _advance();
        return Literal(_parseNumber(t.value), offset: t.offset);

      case TokenKind.string:
        _advance();
        return Literal(t.value, offset: t.offset);

      case TokenKind.keyword:
        _advance();
        switch (t.value) {
          case 'true':
            return Literal(true, offset: t.offset);
          case 'false':
            return Literal(false, offset: t.offset);
          case 'null':
            return NullLiteral(offset: t.offset);
        }
        // Unreachable — the lexer's `_keywords` set is exactly these three.
        // coverage:ignore-start
        throw ParseException('unknown keyword ${t.value}', t.offset);
      // coverage:ignore-end

      case TokenKind.stateVar:
        _advance();
        final name = t.value.substring(1);
        final next = _peek();
        if (next.kind == TokenKind.punct && next.value == '=') {
          _advance();
          final value = _parseExpr(0);
          return StateAssign(name, value, offset: t.offset);
        }
        return StateRef(name, offset: t.offset);

      case TokenKind.builtin:
        _advance();
        _expectPunct('(');
        final args = _parseArgList(')');
        return BuiltinCall(t.value, args, offset: t.offset);

      case TokenKind.type:
        _advance();
        _expectPunct('(');
        final args = _parseArgList(')');
        if (t.value == 'Query') return QueryCall(args, offset: t.offset);
        if (t.value == 'Mutation') return MutationCall(args, offset: t.offset);
        return CompCall(t.value, args, offset: t.offset);

      case TokenKind.ident:
        _advance();
        return Reference(t.value, offset: t.offset);

      case TokenKind.op:
        if (t.value == '!' || t.value == '-') {
          _advance();
          final operand = _parseExpr(_bpUnary);
          return UnaryOp(t.value, operand, offset: t.offset);
        }
        throw ParseException(
          'unexpected operator ${t.value}',
          t.offset,
        );

      case TokenKind.punct:
        if (t.value == '(') {
          _advance();
          _bracketDepth++;
          final inner = _parseExpr(0);
          _expectPunct(')');
          _bracketDepth--;
          return inner;
        }
        if (t.value == '[') return _parseArrayLit();
        if (t.value == '{') return _parseObjectLit();
        throw ParseException(
          'unexpected punctuation ${t.value}',
          t.offset,
        );

      case TokenKind.newline:
      case TokenKind.eof:
        throw ParseException('expected expression', t.offset);
    }
  }

  AstNode _parsePostfix(AstNode left) {
    final t = _peek();
    if (t.value == '.') {
      _advance();
      final nameTok = _advance();
      if (nameTok.kind != TokenKind.ident && nameTok.kind != TokenKind.type) {
        throw ParseException(
          'expected member name after .',
          nameTok.offset,
        );
      }
      return MemberAccess(left, nameTok.value, offset: left.offset);
    }
    // Index access: '['.
    _advance();
    _bracketDepth++;
    final index = _parseExpr(0);
    _expectPunct(']');
    _bracketDepth--;
    return IndexAccess(left, index, offset: left.offset);
  }

  bool _isPostfixStart(Token t) {
    if (t.kind != TokenKind.punct) return false;
    return t.value == '.' || t.value == '[';
  }

  (int, int)? _binaryBp(Token tok) {
    if (tok.kind == TokenKind.op) {
      switch (tok.value) {
        case '||':
          return (10, 11);
        case '&&':
          return (20, 21);
        case '==':
        case '!=':
          return (30, 31);
        case '<':
        case '<=':
        case '>':
        case '>=':
          return (40, 41);
        case '+':
        case '-':
          return (50, 51);
        case '*':
        case '/':
        case '%':
          return (60, 61);
      }
      return null;
    }
    if (tok.kind == TokenKind.punct && tok.value == '?') {
      return (5, 4);
    }
    return null;
  }

  List<Argument> _parseArgList(String closer) {
    _bracketDepth++;
    final args = <Argument>[];
    var first = _peek();
    if (first.kind == TokenKind.punct && first.value == closer) {
      _advance();
      _bracketDepth--;
      return args;
    }
    while (true) {
      first = _peek();
      String? name;
      if (first.kind == TokenKind.ident) {
        final saved = _pos;
        _advance();
        final next = _peek();
        if (next.kind == TokenKind.punct && next.value == ':') {
          name = first.value;
          _advance();
        } else {
          _pos = saved;
        }
      }
      final value = _parseExpr(0);
      args.add(Argument(name: name, value: value, offset: first.offset));

      final sep = _peek();
      if (sep.kind == TokenKind.punct && sep.value == ',') {
        _advance();
        // Trailing-comma support: `f(a,)`.
        final after = _peek();
        if (after.kind == TokenKind.punct && after.value == closer) {
          _advance();
          _bracketDepth--;
          return args;
        }
        continue;
      }
      if (sep.kind == TokenKind.punct && sep.value == closer) {
        _advance();
        _bracketDepth--;
        return args;
      }
      throw ParseException('expected , or $closer', sep.offset);
    }
  }

  AstNode _parseArrayLit() {
    final start = _advance();
    _bracketDepth++;
    final elements = <AstNode>[];
    final first = _peek();
    if (first.kind == TokenKind.punct && first.value == ']') {
      _advance();
      _bracketDepth--;
      return ArrayLit(elements, offset: start.offset);
    }
    while (true) {
      elements.add(_parseExpr(0));
      final sep = _peek();
      if (sep.kind == TokenKind.punct && sep.value == ',') {
        _advance();
        final after = _peek();
        if (after.kind == TokenKind.punct && after.value == ']') {
          _advance();
          _bracketDepth--;
          return ArrayLit(elements, offset: start.offset);
        }
        continue;
      }
      if (sep.kind == TokenKind.punct && sep.value == ']') {
        _advance();
        _bracketDepth--;
        return ArrayLit(elements, offset: start.offset);
      }
      throw ParseException('expected , or ]', sep.offset);
    }
  }

  AstNode _parseObjectLit() {
    final start = _advance();
    _bracketDepth++;
    final entries = <ObjectEntry>[];
    final first = _peek();
    if (first.kind == TokenKind.punct && first.value == '}') {
      _advance();
      _bracketDepth--;
      return ObjectLit(entries, offset: start.offset);
    }
    while (true) {
      final keyTok = _advance();
      final String key;
      if (keyTok.kind == TokenKind.ident || keyTok.kind == TokenKind.string) {
        key = keyTok.value;
      } else {
        throw ParseException(
          'expected object key (ident or string)',
          keyTok.offset,
        );
      }
      _expectPunct(':');
      final value = _parseExpr(0);
      entries.add(ObjectEntry(key, value, offset: keyTok.offset));
      final sep = _peek();
      if (sep.kind == TokenKind.punct && sep.value == ',') {
        _advance();
        final after = _peek();
        if (after.kind == TokenKind.punct && after.value == '}') {
          _advance();
          _bracketDepth--;
          return ObjectLit(entries, offset: start.offset);
        }
        continue;
      }
      if (sep.kind == TokenKind.punct && sep.value == '}') {
        _advance();
        _bracketDepth--;
        return ObjectLit(entries, offset: start.offset);
      }
      throw ParseException('expected , or }', sep.offset);
    }
  }

  void _expectPunct(String value) {
    final t = _peek();
    if (t.kind != TokenKind.punct || t.value != value) {
      throw ParseException('expected "$value"', t.offset);
    }
    _advance();
  }

  /// Parses a number literal as `int` when possible, else `double`.
  ///
  /// The lexer admits decimal integers and floats with a fractional part.
  /// `int.parse` / `double.parse` will not throw because the text comes
  /// straight from the lexer's `_scanNumber`, which only emits matching
  /// characters.
  static num _parseNumber(String value) {
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    return double.parse(value);
  }
}
