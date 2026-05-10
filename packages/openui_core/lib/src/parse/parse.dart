import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';
import 'package:openui_core/src/parser/parser.dart';

/// One parameter slot in a component's [ParamMap] entry.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ParamSpec {
  /// Creates a [ParamSpec].
  const ParamSpec({
    required this.name,
    required this.required,
    this.defaultValue,
  });

  /// Named prop the positional arg maps to.
  final String name;

  /// Whether the slot must be present (and non-null) for the component
  /// to materialize. Missing or null-valued required props emit a
  /// `missing-required` / `null-required` error and drop the
  /// component from the tree.
  final bool required;

  /// Fallback value applied when the arg is missing and the slot is
  /// required. Mirrors the JS reference's `defaultValue` field.
  final Object? defaultValue;
}

/// Maps a component name to its ordered positional-arg → named-prop
/// spec. The integration-style [parse] uses this to (a) map positional
/// args to named props, (b) detect unknown components, (c) validate
/// required props, and (d) report excess-arg errors.
///
/// Marked `@experimental` per D12.
@experimental
typedef ParamMap = Map<String, List<ParamSpec>>;

/// A fully-resolved element node from the integration-style [parse].
///
/// Each entry in [props] is one of:
///   - a primitive (`int`, `double`, `bool`, `String`),
///   - `null`,
///   - a `List<Object?>` of nested values / [ResolvedElement]s,
///   - a `Map<String, Object?>` from an `ObjectLit`,
///   - another [ResolvedElement] (child component),
///   - an [AstNode] when the value carries a runtime expression that
///     can't be fully resolved at parse time.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ResolvedElement {
  /// Creates a [ResolvedElement].
  ResolvedElement({
    required this.typeName,
    required Map<String, Object?> props,
    this.statementId,
    this.partial = false,
  }) : props = Map<String, Object?>.unmodifiable(props);

  /// Component type name (the TYPE token in source).
  final String typeName;

  /// Resolved props, keyed by the schema's `name`.
  final Map<String, Object?> props;

  /// Statement id this element materializes from. Tracks the
  /// enclosing statement at construction time — the materializer
  /// updates `currentStatementId` before recursing into a referenced
  /// statement, so refs naturally pick up the right id.
  final String? statementId;

  /// `true` when this element's statement source was truncated at
  /// parse time. Passed down from the parse context.
  final bool partial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedElement &&
          other.typeName == typeName &&
          other.statementId == statementId &&
          other.partial == partial &&
          _mapEquals(props, other.props);

  @override
  int get hashCode => Object.hash(
    ResolvedElement,
    typeName,
    statementId,
    partial,
    _mapHash(props),
  );

  @override
  String toString() =>
      'ResolvedElement($typeName, props: $props, statementId: $statementId)';
}

/// Output of one integration-style [parse] pass — the JS reference's
/// `ParseResult` shape.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class CompiledProgram {
  /// Creates a [CompiledProgram].
  CompiledProgram({
    required this.root,
    required this.meta,
    Map<String, Object?>? stateDeclarations,
  }) : stateDeclarations = Map<String, Object?>.unmodifiable(
         stateDeclarations ?? const <String, Object?>{},
       );

  /// Materialized root element, or `null` when the root is missing,
  /// invalid (e.g. unknown component), or the source is empty.
  final ResolvedElement? root;

  /// Side-channel metadata for the pass.
  final CompiledMeta meta;

  /// State declarations with their default values evaluated at parse
  /// time. Any `$var` referenced without an explicit declaration is
  /// auto-declared with a `null` default (matching the JS reference's
  /// auto-declare behavior).
  final Map<String, Object?> stateDeclarations;
}

/// Side-channel meta for a [CompiledProgram].
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class CompiledMeta {
  /// Creates a [CompiledMeta].
  CompiledMeta({
    this.incomplete = false,
    List<String> unresolved = const [],
    List<String> orphaned = const [],
    List<OpenUIError> errors = const [],
    this.statementCount = 0,
  }) : unresolved = List.unmodifiable(unresolved),
       orphaned = List.unmodifiable(orphaned),
       errors = List.unmodifiable(errors);

  /// Whether the source was truncated mid-statement at parse time.
  final bool incomplete;

  /// Bare-identifier references that did not bind to any parsed
  /// statement.
  final List<String> unresolved;

  /// Value-kind statement ids that were defined but not reachable
  /// from the root. State, query, and mutation declarations are
  /// excluded.
  final List<String> orphaned;

  /// Validation errors collected during materialization
  /// (`unknown-component`, `excess-args`, `missing-required`,
  /// `null-required`).
  final List<OpenUIError> errors;

  /// Number of unique statement ids after dedup.
  final int statementCount;
}

/// Strips a Markdown code fence (`'```dart\n...\n'``'```)from [input].
String _stripFences(String input) {
  var s = input.trim();
  if (s.startsWith('```')) {
    final firstNewline = s.indexOf('\n');
    s = firstNewline == -1 ? '' : s.substring(firstNewline + 1);
  }
  if (s.endsWith('```')) {
    s = s.substring(0, s.length - 3).trimRight();
  }
  return s;
}

/// Parses [source] against [paramMap] and materializes the
/// root-element tree.
///
/// Behaviorally mirrors the JS reference's `parse(input, cat, rootName)`:
///
/// 1. Strip Markdown fences from [source].
/// 2. Parse the residue with the standard parser.
/// 3. Pick the entry-point statement (`root` by default, or the
///    first component statement if no `root` exists).
/// 4. Recursively materialize the entry statement's AST: resolve
///    references against the statement map, map positional args to
///    named props via [paramMap], validate required props, drop
///    invalid children from arrays.
/// 5. Collect `unresolved`, `orphaned`, and validation errors into
///    [CompiledMeta].
///
/// Marked `@experimental` per D12.
@experimental
CompiledProgram parse(
  String source,
  ParamMap paramMap, {
  String rootName = 'root',
}) {
  final cleaned = _stripFences(source);
  if (cleaned.isEmpty) {
    return CompiledProgram(root: null, meta: CompiledMeta(incomplete: true));
  }

  final program = parseProgram(cleaned, recoverable: true);
  if (program.statements.isEmpty) {
    return CompiledProgram(root: null, meta: CompiledMeta());
  }

  // Build dedup'd statement map (last-write-wins on duplicate ids).
  final stmtMap = <String, Statement>{};
  for (final s in program.statements) {
    stmtMap[s.name] = s;
  }
  final entryId = _pickEntryId(stmtMap, rootName);

  // `_pickEntryId` always returns a key present in `stmtMap` (the
  // last branch falls back to `stmtMap.keys.first`), so we skip a
  // defensive lookup here.

  // Pre-seed `unreached` with every value-kind statement except the
  // entry. As we recurse through refs we delete from it; the
  // remainder are orphans.
  final unreached = <String>{
    for (final entry in stmtMap.entries)
      if (entry.key != entryId && entry.value.kind == StatementKind.value)
        entry.key,
  };

  final ctx = _MatCtx(
    statements: stmtMap,
    paramMap: paramMap,
    unreached: unreached,
    currentStatementId: entryId,
  );

  final materialized = _materializeValue(stmtMap[entryId]!.expression, ctx);
  final root = materialized is ResolvedElement ? materialized : null;

  return CompiledProgram(
    root: root,
    meta: CompiledMeta(
      unresolved: ctx.unresolved.toList(),
      orphaned: unreached.toList(),
      errors: ctx.errors,
      statementCount: stmtMap.length,
    ),
    stateDeclarations: _collectStateDeclarations(stmtMap, ctx),
  );
}

String _pickEntryId(Map<String, Statement> stmtMap, String rootName) {
  if (stmtMap.containsKey(rootName)) return rootName;
  // Fallback: first value-kind statement.
  for (final entry in stmtMap.entries) {
    if (entry.value.kind == StatementKind.value) return entry.key;
  }
  // Fallback: the first statement, whatever its kind.
  return stmtMap.keys.first;
}

Map<String, Object?> _collectStateDeclarations(
  Map<String, Statement> stmtMap,
  _MatCtx ctx,
) {
  final out = <String, Object?>{};
  for (final s in stmtMap.values) {
    if (s.kind != StatementKind.state) continue;
    // Best-effort: materialize the default for a primitive value.
    out[s.name] = _materializeValue(s.expression, ctx);
  }
  // Auto-declare any $var referenced without explicit declaration.
  final referenced = <String>{};
  for (final s in stmtMap.values) {
    _collectStateRefs(s.expression, referenced);
  }
  for (final name in referenced) {
    if (!out.containsKey(name)) out[name] = null;
  }
  return out;
}

void _collectStateRefs(AstNode node, Set<String> out) {
  switch (node) {
    case StateRef(:final name):
      out.add('\$$name');
    case StateAssign(:final target, :final value):
      // Assigning to a state var counts as referencing it for the
      // auto-declare scan, even if the target itself isn't a
      // separate StateRef node.
      out.add('\$$target');
      _collectStateRefs(value, out);
    case BinaryOp(:final left, :final right):
      _collectStateRefs(left, out);
      _collectStateRefs(right, out);
    case UnaryOp(:final operand):
      _collectStateRefs(operand, out);
    case Ternary(:final condition, :final then, :final otherwise):
      _collectStateRefs(condition, out);
      _collectStateRefs(then, out);
      _collectStateRefs(otherwise, out);
    case MemberAccess(:final target):
      _collectStateRefs(target, out);
    case IndexAccess(:final target, :final index):
      _collectStateRefs(target, out);
      _collectStateRefs(index, out);
    case ArrayLit(:final elements):
      for (final e in elements) {
        _collectStateRefs(e, out);
      }
    case ObjectLit(:final entries):
      for (final e in entries) {
        _collectStateRefs(e.value, out);
      }
    case CompCall(:final args):
    case BuiltinCall(:final args):
    case QueryCall(:final args):
    case MutationCall(:final args):
      for (final a in args) {
        _collectStateRefs(a.value, out);
      }
    case Literal():
    case NullLiteral():
    case Reference():
      break;
  }
}

class _MatCtx {
  _MatCtx({
    required this.statements,
    required this.paramMap,
    required this.unreached,
    required this.currentStatementId,
  });

  final Map<String, Statement> statements;
  final ParamMap paramMap;
  final Set<String> unreached;
  final Set<String> unresolved = <String>{};
  final Set<String> visited = <String>{};
  final List<OpenUIError> errors = <OpenUIError>[];
  String? currentStatementId;
}

Object? _materializeValue(AstNode node, _MatCtx ctx) {
  switch (node) {
    case Literal(:final value):
      return value;
    case NullLiteral():
      return null;
    case Reference(:final name):
      return _resolveRef(name, ctx);
    case ArrayLit(:final elements):
      final items = <Object?>[];
      for (final e in elements) {
        final v = _materializeValue(e, ctx);
        if (v == null && (e is CompCall || e is Reference)) continue;
        items.add(v);
      }
      return items;
    case ObjectLit(:final entries):
      return <String, Object?>{
        for (final e in entries) e.key: _materializeValue(e.value, ctx),
      };
    case final CompCall comp:
      return _materializeComp(comp, ctx);
    case StateRef():
    case StateAssign():
    case BinaryOp():
    case UnaryOp():
    case Ternary():
    case MemberAccess():
    case IndexAccess():
    case BuiltinCall():
      // Runtime expression — preserve as AST for the evaluator.
      return node;
    case QueryCall():
    case MutationCall():
      // Inline Query/Mutation in expression position — surface as an
      // error and drop. They must be top-level statements.
      final kind = node is QueryCall ? 'Query' : 'Mutation';
      ctx.errors.add(
        EvaluationError(
          message: '$kind() must be a top-level statement',
          statementId: ctx.currentStatementId,
        ),
      );
      return null;
  }
}

Object? _resolveRef(String name, _MatCtx ctx) {
  if (ctx.visited.contains(name)) {
    ctx.unresolved.add(name);
    return null;
  }
  final target = ctx.statements[name];
  if (target == null) {
    ctx.unresolved.add(name);
    return null;
  }
  ctx.unreached.remove(name);
  // Query/Mutation refs resolve at runtime, not parse time.
  if (target.kind == StatementKind.query ||
      target.kind == StatementKind.mutation) {
    return null;
  }
  ctx.visited.add(name);
  final prevId = ctx.currentStatementId;
  ctx.currentStatementId = name;
  final result = _materializeValue(target.expression, ctx);
  ctx.currentStatementId = prevId;
  ctx.visited.remove(name);
  return result;
}

ResolvedElement? _materializeComp(CompCall node, _MatCtx ctx) {
  final name = node.type;
  // `Query` and `Mutation` are surfaced by the lexer/parser as
  // [QueryCall] / [MutationCall], not [CompCall], so the inline-call
  // error for them is handled in [_materializeValue]'s
  // `case QueryCall()` / `case MutationCall()` arm.
  final params = ctx.paramMap[name];
  if (params == null) {
    ctx.errors.add(
      UnknownComponentError(
        component: name,
        statementId: ctx.currentStatementId,
      ),
    );
    return null;
  }

  final props = <String, Object?>{};
  final positional = <Argument>[
    for (final a in node.args)
      if (a.name == null) a,
  ];
  for (var i = 0; i < params.length && i < positional.length; i++) {
    props[params[i].name] = _materializeValue(positional[i].value, ctx);
  }

  if (positional.length > params.length) {
    final excess = positional.length - params.length;
    ctx.errors.add(
      EvaluationError(
        message:
            '$name takes ${params.length} arg(s), '
            'got ${positional.length} ($excess excess dropped)',
        statementId: ctx.currentStatementId,
      ),
    );
  }

  // Named args layer on top of positional mappings; allows callers to
  // mix `Stack(name: "...", children: [...])` style.
  for (final a in node.args) {
    if (a.name != null) props[a.name!] = _materializeValue(a.value, ctx);
  }

  // Required-prop validation. Try defaultValue before erroring.
  var hasFatal = false;
  for (final p in params) {
    if (!p.required) continue;
    if (!props.containsKey(p.name) || props[p.name] == null) {
      if (p.defaultValue != null) {
        props[p.name] = p.defaultValue;
        continue;
      }
      final isNull = props.containsKey(p.name);
      ctx.errors.add(
        EvaluationError(
          message: isNull
              ? 'required field "${p.name}" cannot be null'
              : 'missing required field "${p.name}"',
          statementId: ctx.currentStatementId,
        ),
      );
      hasFatal = true;
    }
  }
  if (hasFatal) return null;

  return ResolvedElement(
    typeName: name,
    props: props,
    statementId: ctx.currentStatementId,
  );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    if (a[k] != b[k]) return false;
  }
  return true;
}

int _mapHash(Map<String, Object?> m) {
  var h = 0;
  for (final e in m.entries) {
    h = h ^ Object.hash(e.key, e.value);
  }
  return h;
}
