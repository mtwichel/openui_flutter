part of 'parser.dart';

/// Root of the OpenUI Lang abstract-syntax tree.
///
/// Marked `@experimental` per D12: the shape may change between v0.1 and
/// v0.2 as the evaluator and `mergeStatements` mature.
///
/// Equality on AST nodes is **structural and offset-insensitive** — two
/// nodes are equal if their kind and child structure match, regardless of
/// where they came from in the source. This keeps test fixtures portable
/// (you can construct an expected AST without computing offsets) and lets
/// `mergeStatements` detect identical statements across edits without
/// caring about whitespace shifts.
@experimental
sealed class AstNode {
  const AstNode({required this.offset});

  /// Zero-based UTF-16 code-unit offset of the first character of this
  /// node in the source. Diagnostic only — not part of equality.
  final int offset;
}

/// String, number, or boolean literal.
///
/// `null` is represented by [NullLiteral] (a separate variant so
/// `mergeStatements` can detect "delete this statement" intent without a
/// runtime-type guard against `value == null`).
@experimental
@immutable
final class Literal extends AstNode {
  /// Creates a literal node carrying [value].
  const Literal(this.value, {required super.offset});

  /// One of `String`, `num`, or `bool`.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Literal && other.value == value;

  @override
  int get hashCode => Object.hash(Literal, value);

  @override
  String toString() {
    final v = value;
    if (v is String) return 'Literal("$v")';
    return 'Literal($v)';
  }
}

/// The keyword `null`.
///
/// Distinct from `Literal(null)` because `mergeStatements` uses a
/// `NullLiteral` RHS as the "delete this statement" sentinel.
@experimental
@immutable
final class NullLiteral extends AstNode {
  /// Creates a null literal at [offset].
  const NullLiteral({required super.offset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NullLiteral;

  @override
  int get hashCode => (NullLiteral).hashCode;

  @override
  String toString() => 'NullLiteral';
}

/// A bare identifier reference (`IDENT` or `TYPE`) used as an expression.
///
/// Refers to another statement by id. Resolved during materialization;
/// unresolved names land in `meta.unresolved`.
@experimental
@immutable
final class Reference extends AstNode {
  /// Creates a reference to the statement named [name].
  const Reference(this.name, {required super.offset});

  /// The referenced identifier — preserves the original casing.
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Reference && other.name == name;

  @override
  int get hashCode => Object.hash(Reference, name);

  @override
  String toString() => 'Reference($name)';
}

/// A reactive state read (`$name`).
///
/// [name] does **not** include the leading `$`.
@experimental
@immutable
final class StateRef extends AstNode {
  /// Creates a state-ref to `\$[name]`.
  const StateRef(this.name, {required super.offset});

  /// The state-variable name (without the leading `$`).
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StateRef && other.name == name;

  @override
  int get hashCode => Object.hash(StateRef, name);

  @override
  String toString() => 'StateRef(\$$name)';
}

/// `$name = expression` used as an expression (e.g. inside an action arg).
///
/// Top-level state declarations are represented as a [Statement] whose
/// LHS is a `STATEVAR`, not as a [StateAssign] sub-expression.
@experimental
@immutable
final class StateAssign extends AstNode {
  /// Creates a state-assignment expression.
  const StateAssign(this.target, this.value, {required super.offset});

  /// The state-variable name (without the leading `$`).
  final String target;

  /// The right-hand-side expression.
  final AstNode value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateAssign && other.target == target && other.value == value;

  @override
  int get hashCode => Object.hash(StateAssign, target, value);

  @override
  String toString() => 'StateAssign(\$$target = $value)';
}

/// Array literal: `[a, b, c]`.
@experimental
@immutable
final class ArrayLit extends AstNode {
  /// Creates an array literal whose element list is [elements].
  ArrayLit(List<AstNode> elements, {required super.offset})
    : elements = List.unmodifiable(elements);

  /// The element expressions, in source order.
  final List<AstNode> elements;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrayLit && _listEq(other.elements, elements);

  @override
  int get hashCode => Object.hash(ArrayLit, Object.hashAll(elements));

  @override
  String toString() => 'ArrayLit($elements)';
}

/// Object literal: `{ key: value, "quoted": value }`.
@experimental
@immutable
final class ObjectLit extends AstNode {
  /// Creates an object literal whose entries are [entries].
  ObjectLit(List<ObjectEntry> entries, {required super.offset})
    : entries = List.unmodifiable(entries);

  /// The key/value pairs, in source order. Duplicate keys are preserved
  /// at parse time; downstream consumers (the evaluator) decide whether
  /// last-write-wins or first-write-wins.
  final List<ObjectEntry> entries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectLit && _listEq(other.entries, entries);

  @override
  int get hashCode => Object.hash(ObjectLit, Object.hashAll(entries));

  @override
  String toString() => 'ObjectLit($entries)';
}

/// A single `key: value` pair inside an [ObjectLit].
///
/// Not an [AstNode] — entries can only appear inside an object literal.
@experimental
@immutable
final class ObjectEntry {
  /// Creates an entry mapping [key] to [value].
  const ObjectEntry(this.key, this.value, {required this.offset});

  /// The literal key text. Both bare-identifier and string-literal keys
  /// are flattened into this `String` field; the surrounding quotes are
  /// stripped from string keys.
  final String key;

  /// The value expression.
  final AstNode value;

  /// Source offset of the key.
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectEntry && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(ObjectEntry, key, value);

  @override
  String toString() => '$key: $value';
}

/// A binary operation: `left op right`.
///
/// [op] is the canonical operator text — one of
/// `+ - * / % == != < <= > >= && ||`.
@experimental
@immutable
final class BinaryOp extends AstNode {
  /// Creates a binary-op node.
  const BinaryOp(
    this.op,
    this.left,
    this.right, {
    required super.offset,
  });

  /// The operator symbol.
  final String op;

  /// Left operand.
  final AstNode left;

  /// Right operand.
  final AstNode right;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryOp &&
          other.op == op &&
          other.left == left &&
          other.right == right;

  @override
  int get hashCode => Object.hash(BinaryOp, op, left, right);

  @override
  String toString() => 'BinaryOp($left $op $right)';
}

/// A unary operation: `op operand`.
///
/// [op] is `!` or `-`.
@experimental
@immutable
final class UnaryOp extends AstNode {
  /// Creates a unary-op node.
  const UnaryOp(this.op, this.operand, {required super.offset});

  /// The operator symbol.
  final String op;

  /// The operand expression.
  final AstNode operand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnaryOp && other.op == op && other.operand == operand;

  @override
  int get hashCode => Object.hash(UnaryOp, op, operand);

  @override
  String toString() => 'UnaryOp($op$operand)';
}

/// A ternary: `condition ? then : otherwise`.
///
/// Right-associative: `a ? b : c ? d : e` parses as
/// `a ? b : (c ? d : e)`.
@experimental
@immutable
final class Ternary extends AstNode {
  /// Creates a ternary node.
  const Ternary(
    this.condition,
    this.then,
    this.otherwise, {
    required super.offset,
  });

  /// The condition expression.
  final AstNode condition;

  /// The "then" branch.
  final AstNode then;

  /// The "else" branch.
  final AstNode otherwise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ternary &&
          other.condition == condition &&
          other.then == then &&
          other.otherwise == otherwise;

  @override
  int get hashCode => Object.hash(Ternary, condition, then, otherwise);

  @override
  String toString() => 'Ternary($condition ? $then : $otherwise)';
}

/// A dotted member access: `target.name`.
@experimental
@immutable
final class MemberAccess extends AstNode {
  /// Creates a member-access node.
  const MemberAccess(this.target, this.name, {required super.offset});

  /// The receiver.
  final AstNode target;

  /// The member name.
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAccess && other.target == target && other.name == name;

  @override
  int get hashCode => Object.hash(MemberAccess, target, name);

  @override
  String toString() => 'MemberAccess($target.$name)';
}

/// A bracketed index access: `target[index]`.
@experimental
@immutable
final class IndexAccess extends AstNode {
  /// Creates an index-access node.
  const IndexAccess(this.target, this.index, {required super.offset});

  /// The receiver.
  final AstNode target;

  /// The index expression.
  final AstNode index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexAccess && other.target == target && other.index == index;

  @override
  int get hashCode => Object.hash(IndexAccess, target, index);

  @override
  String toString() => 'IndexAccess($target[$index])';
}

/// A component call: `Type(arg, named: arg, ...)`.
///
/// Distinct from [BuiltinCall] (no `@` sigil) and from [MutationCall]
/// (which the parser emits when [type] is exactly `Mutation`).
@experimental
@immutable
final class CompCall extends AstNode {
  /// Creates a comp-call node.
  CompCall(this.type, List<Argument> args, {required super.offset})
    : args = List.unmodifiable(args);

  /// The component type name (`TYPE`).
  final String type;

  /// Positional and named arguments, in source order.
  final List<Argument> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompCall && other.type == type && _listEq(other.args, args);

  @override
  int get hashCode => Object.hash(CompCall, type, Object.hashAll(args));

  @override
  String toString() => 'CompCall($type, $args)';
}

/// A builtin call: `@Each(list, "name", template)`, `@Set(target, value)`, ...
@experimental
@immutable
final class BuiltinCall extends AstNode {
  /// Creates a builtin-call node.
  BuiltinCall(this.name, List<Argument> args, {required super.offset})
    : args = List.unmodifiable(args);

  /// The builtin name **including** the leading `@` (e.g. `@Each`). The
  /// `@` is preserved so error messages and serialization round-trip
  /// without re-injecting the sigil.
  final String name;

  /// Positional and named arguments, in source order.
  final List<Argument> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuiltinCall && other.name == name && _listEq(other.args, args);

  @override
  int get hashCode => Object.hash(BuiltinCall, name, Object.hashAll(args));

  @override
  String toString() => 'BuiltinCall($name, $args)';
}

/// A `Mutation(name: ..., args: ...)` call.
///
/// Emitted by the parser when a comp-call's type is exactly `Mutation`.
@experimental
@immutable
final class MutationCall extends AstNode {
  /// Creates a mutation-call node.
  MutationCall(List<Argument> args, {required super.offset})
    : args = List.unmodifiable(args);

  /// Positional and named arguments, in source order.
  final List<Argument> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationCall && _listEq(other.args, args);

  @override
  int get hashCode => Object.hash(MutationCall, Object.hashAll(args));

  @override
  String toString() => 'MutationCall($args)';
}

/// A single argument inside a [CompCall], [BuiltinCall], or
/// [MutationCall].
///
/// Positional args have `name == null`; `key: expr` syntax produces
/// named args.
@experimental
@immutable
final class Argument {
  /// Creates an argument.
  const Argument({required this.value, required this.offset, this.name});

  /// The argument label, or `null` for positional args.
  final String? name;

  /// The argument value expression.
  final AstNode value;

  /// Source offset of the argument's first token.
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Argument && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(Argument, name, value);

  @override
  String toString() => name == null ? '$value' : '$name: $value';
}

/// Top-level statement: `name = expression`.
///
/// The [name] doubles as the statement id. Re-assignment to the same
/// name overwrites in the streaming parser's index; the AST node here
/// just captures one occurrence.
@experimental
@immutable
final class Statement {
  /// Creates a statement.
  const Statement({
    required this.name,
    required this.kind,
    required this.expression,
    required this.offset,
  });

  /// The LHS identifier — `IDENT`, `TYPE`, or `STATEVAR` (with the `$`
  /// preserved for state declarations so the id round-trips).
  final String name;

  /// Classification: value, state, query, or mutation.
  final StatementKind kind;

  /// The RHS expression.
  final AstNode expression;

  /// Source offset of the LHS identifier.
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Statement &&
          other.name == name &&
          other.kind == kind &&
          other.expression == expression;

  @override
  int get hashCode => Object.hash(Statement, name, kind, expression);

  @override
  String toString() => '$name = $expression  // $kind';
}

/// Statement classification per `docs/lang-reference.md`.
///
/// Order of checks (in [classifyStatement]):
/// 1. RHS is a `MutationCall` → [mutation]
/// 2. RHS is `@Query(...)` (a `BuiltinCall` named `@Query`) → [query]
/// 3. LHS is a `STATEVAR` → [state]
/// 4. otherwise → [value]
@experimental
enum StatementKind {
  /// Plain value binding (default).
  value,

  /// `$name = ...` where the RHS is not a query or mutation.
  state,

  /// `$name = @Query(tool, ...)`.
  query,

  /// `name = Mutation(...)`.
  mutation,
}

/// Computes the [StatementKind] for an LHS [name] / RHS [expression] pair.
@experimental
StatementKind classifyStatement(String name, AstNode expression) {
  if (expression is MutationCall) return StatementKind.mutation;
  if (expression is BuiltinCall && expression.name == '@Query') {
    return StatementKind.query;
  }
  if (name.startsWith(r'$')) return StatementKind.state;
  return StatementKind.value;
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
