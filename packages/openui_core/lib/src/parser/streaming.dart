import 'package:meta/meta.dart';
import 'package:openui_core/src/parser/parser.dart';

/// Output of one parse pass.
///
/// The streaming parser produces a [ParseResult] every time
/// [StreamParser.push] or [StreamParser.set] is called. The
/// [statements] list is the parsed program (in source order); [meta]
/// carries the side-channel information consumers need to drive UI,
/// dispatch queries, and surface errors.
///
/// The [meta] field intentionally omits `unresolved`, `orphaned`, and
/// the materialized `root` element tree. Those are produced by the
/// materializer (separate Phase 1 task) and will be added back to this
/// type once that lands. Marked `@experimental` per D12.
@experimental
@immutable
class ParseResult {
  /// Creates a [ParseResult].
  ParseResult({required List<Statement> statements, required this.meta})
    : statements = List.unmodifiable(statements);

  /// All successfully parsed statements, in source order. A statement
  /// re-defined later in the buffer appears twice — overwrite semantics
  /// are decided by downstream consumers (the materializer).
  final List<Statement> statements;

  /// Side-channel parse metadata.
  final ParseMeta meta;
}

/// Side-channel data attached to a [ParseResult].
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ParseMeta {
  /// Creates a [ParseMeta].
  ParseMeta({
    required List<String> incomplete,
    required List<ParseException> errors,
    required List<StateDecl> stateDecls,
    required List<QueryDecl> queries,
    required List<MutationDecl> mutations,
  }) : incomplete = List.unmodifiable(incomplete),
       errors = List.unmodifiable(errors),
       stateDecls = List.unmodifiable(stateDecls),
       queries = List.unmodifiable(queries),
       mutations = List.unmodifiable(mutations);

  /// Statement ids whose source lives in the *pending tail* — the
  /// portion of the buffer after the last bracket-depth-zero newline.
  /// These statements may be syntactically complete after `autoClose`
  /// patched up the tail, but the LLM has not yet produced their
  /// terminator. UI should treat them as in-flight (e.g. disable taps,
  /// fade interactive controls).
  final List<String> incomplete;

  /// Per-statement parse failures. The statement that errored is absent
  /// from [ParseResult.statements]; recovery skipped to the next
  /// newline before continuing, so subsequent statements are unaffected.
  final List<ParseException> errors;

  /// Reactive state declarations (`$name = expr` where the RHS is not a
  /// `Query` / `Mutation` builtin). Used to seed the reactive store.
  final List<StateDecl> stateDecls;

  /// Query declarations (`name = Query(...)` or `$name = Query(...)`).
  /// Used to drive the query manager.
  final List<QueryDecl> queries;

  /// Mutation declarations (`name = Mutation(...)`). Used to populate
  /// the action dispatcher.
  final List<MutationDecl> mutations;
}

/// A `$state` declaration extracted from a parse pass.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class StateDecl {
  /// Creates a [StateDecl].
  const StateDecl({required this.name, required this.defaultValue});

  /// The state-variable name **including** the leading `$`.
  final String name;

  /// The unevaluated AST of the RHS. The reactive store evaluates this
  /// against an empty context to produce the initial value; tests stub
  /// the evaluator and compare ASTs directly.
  final AstNode defaultValue;
}

/// A `Query(...)` declaration extracted from a parse pass.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class QueryDecl {
  /// Creates a [QueryDecl].
  const QueryDecl({required this.statementId, required this.args});

  /// The LHS identifier the query is bound to (the query's id).
  final String statementId;

  /// The `Query(...)` argument list verbatim. Most call sites use the
  /// `name: "..."` and `args: { ... }` named arguments.
  final List<Argument> args;
}

/// A `Mutation(...)` declaration extracted from a parse pass.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class MutationDecl {
  /// Creates a [MutationDecl].
  const MutationDecl({required this.statementId, required this.args});

  /// The LHS identifier the mutation is bound to.
  final String statementId;

  /// The `Mutation(...)` argument list verbatim.
  final List<Argument> args;
}

/// Streaming parser. Construct with [createStreamingParser].
///
/// The contract is intentionally narrow: append text via [push], or
/// replace the buffer entirely via [set]. Each call returns the latest
/// [ParseResult]. The internal buffer split, [autoClose] pass on the
/// pending tail, and per-pass `parseProgram` invocation are all
/// repeated each call — there is no per-statement caching in v0.1, in
/// keeping with Decision D2's "split at the last bracket-depth-zero
/// newline" approach but deferring the textual-hash cache to Phase 5.
///
/// Marked `@experimental` per D12.
@experimental
class StreamParser {
  StreamParser._({required this.rootName});

  /// The id of the root statement. Used by the materializer to pick the
  /// entry-point of the rendered tree. The streaming parser itself does
  /// not consult [rootName]; it is stored here so the materializer can
  /// read it without re-threading the value.
  final String rootName;

  String _buffer = '';

  /// Appends [chunk] to the internal buffer and returns the latest
  /// parse.
  ParseResult push(String chunk) {
    _buffer = '$_buffer$chunk';
    return _compute();
  }

  /// Replaces the internal buffer with [fullText] and returns the
  /// latest parse. The diff against the previous buffer is implicit —
  /// `_compute` re-parses the new buffer from scratch.
  ParseResult set(String fullText) {
    _buffer = fullText;
    return _compute();
  }

  ParseResult _compute() {
    final split = _splitBuffer(_buffer);
    final closedTail = autoClose(split.tail);
    final effective = '${split.prefix}$closedTail';
    final program = parseProgram(effective, recoverable: true);

    final incomplete = <String>[];
    final stateDecls = <StateDecl>[];
    final queries = <QueryDecl>[];
    final mutations = <MutationDecl>[];

    for (final s in program.statements) {
      // A statement whose first token sits at or beyond the prefix
      // boundary came from the (possibly autoClose-patched) tail. Such
      // a statement is *in flight* even if the closer made it
      // syntactically valid.
      if (s.offset >= split.prefix.length) incomplete.add(s.name);

      switch (s.kind) {
        case StatementKind.state:
          stateDecls.add(
            StateDecl(name: s.name, defaultValue: s.expression),
          );
        case StatementKind.query:
          if (s.expression is QueryCall) {
            queries.add(
              QueryDecl(
                statementId: s.name,
                args: (s.expression as QueryCall).args,
              ),
            );
          }
        case StatementKind.mutation:
          if (s.expression is MutationCall) {
            mutations.add(
              MutationDecl(
                statementId: s.name,
                args: (s.expression as MutationCall).args,
              ),
            );
          }
        case StatementKind.value:
          break;
      }
    }

    return ParseResult(
      statements: program.statements,
      meta: ParseMeta(
        incomplete: incomplete,
        errors: program.errors,
        stateDecls: stateDecls,
        queries: queries,
        mutations: mutations,
      ),
    );
  }
}

/// Constructs a [StreamParser].
///
/// [rootName] defaults to `'root'` and is held for the materializer.
/// The streaming parser itself does not consult it.
@experimental
StreamParser createStreamingParser({String rootName = 'root'}) {
  return StreamParser._(rootName: rootName);
}

/// Splits [buffer] at the last bracket-depth-zero newline.
///
/// The prefix (everything up to and including that newline) is the
/// "completed" region — every bracket and string is balanced, so
/// `parseProgram` will see well-formed statements. The tail is the
/// "pending" region; it is fed through [autoClose] before re-parse so
/// that an unterminated string or unmatched bracket does not poison the
/// whole pass.
///
/// String regions are skipped during the depth walk: a `"` opens a
/// string in which `\\`-escapes consume the next character and only
/// `"` closes the region. This matches the lexer's tokenization rules
/// and keeps brackets that appear inside string literals from
/// influencing the depth counter.
({String prefix, String tail}) _splitBuffer(String buffer) {
  var depth = 0;
  var inString = false;
  var lastBalancedNewlineEnd = 0;
  var i = 0;
  while (i < buffer.length) {
    final c = buffer.codeUnitAt(i);
    if (inString) {
      if (c == _backslash) {
        // Skip the escape sequence; if the backslash is the last char,
        // we'll exit the loop on the next iteration's bounds check.
        i += 2;
        continue;
      }
      if (c == _doubleQuote) inString = false;
      i++;
      continue;
    }
    switch (c) {
      case _doubleQuote:
        inString = true;
      case _lparen || _lbracket || _lbrace:
        depth++;
      case _rparen || _rbracket || _rbrace:
        if (depth > 0) depth--;
      case _newline:
        if (depth == 0) lastBalancedNewlineEnd = i + 1;
    }
    i++;
  }
  return (
    prefix: buffer.substring(0, lastBalancedNewlineEnd),
    tail: buffer.substring(lastBalancedNewlineEnd),
  );
}

const int _backslash = 0x5C;
const int _doubleQuote = 0x22;
const int _newline = 0x0A;
const int _lparen = 0x28;
const int _rparen = 0x29;
const int _lbracket = 0x5B;
const int _rbracket = 0x5D;
const int _lbrace = 0x7B;
const int _rbrace = 0x7D;
