import 'package:meta/meta.dart';
import 'package:openui_core/src/parser/parser.dart';

/// A node in the materialized render tree.
///
/// Each [ElementNode] wraps the RHS expression of one [Statement] plus
/// the side data the renderer needs to dispatch and recover. The
/// renderer evaluates [expression] at render time, walking through any
/// nested [Reference]s back through the statement map; [ElementNode]
/// itself carries no pre-resolved children (forward references hoist
/// naturally through the per-render evaluator).
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ElementNode {
  /// Creates an [ElementNode].
  const ElementNode({
    required this.expression,
    required this.statementId,
    required this.partial,
  });

  /// The unevaluated RHS expression of the owning statement.
  final AstNode expression;

  /// The id of the statement this element was materialized from.
  /// Carried so the renderer can attribute render-time errors back to
  /// the source line.
  final String statementId;

  /// `true` when [statementId] is in the latest `meta.incomplete` set
  /// — i.e. the statement's source was truncated at parse time.
  /// Interactive components disable their tap targets while their
  /// containing element is partial (Acceptance Gap A6).
  final bool partial;

  /// The component, builtin, or pseudo-call type name, if any.
  ///
  /// Returns `null` for plain literals, references, and operators.
  /// `Mutation` — normally a distinct AST type — surfaces here under
  /// its canonical name so the renderer can dispatch uniformly.
  String? get typeName => switch (expression) {
    CompCall(:final type) => type,
    BuiltinCall(:final name) => name,
    MutationCall() => 'Mutation',
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElementNode &&
          other.expression == expression &&
          other.statementId == statementId &&
          other.partial == partial;

  @override
  int get hashCode =>
      Object.hash(ElementNode, expression, statementId, partial);

  @override
  String toString() {
    final partialMark = partial ? ' partial' : '';
    return 'ElementNode($statementId: $expression$partialMark)';
  }
}

/// Outcome of one materialization pass.
///
/// Marked `@experimental` per D12.
@experimental
typedef MaterializedResult = ({
  ElementNode? root,
  List<String> unresolved,
  List<String> orphaned,
});

/// Materializes a render tree rooted at [rootName] from [statements].
///
/// The materializer's job is graph-shaped, not evaluative: it builds
/// the statement-id map, traverses references reachable from the root,
/// and partitions the statement set into reachable, unresolved (named
/// but absent), and orphaned (defined but unreachable). The single
/// [ElementNode] it returns wraps the root statement's RHS verbatim;
/// sub-elements are resolved by the evaluator at render time, which is
/// what makes forward references work — `root = Stack([chart])` may
/// appear before `chart = ...` because the statement map is fully
/// populated before the walk starts.
///
/// [incomplete] is the set of statement ids the streaming parser has
/// flagged as in-flight. The returned root carries `partial: true` if
/// its id is in that set; deeper partial flagging happens at render
/// time when the renderer descends into a referenced statement.
///
/// Re-assignment ("last write wins") is encoded in the statement map:
/// `a = 1\na = 2` yields a single map entry `a → Statement(...= 2)`.
///
/// Statements of kind `state`, `query`, and `mutation` are **excluded
/// from orphan analysis**: they are tracked separately in
/// `meta.stateDecls` / `meta.queries` / `meta.mutations` and are not
/// expected to be reachable through the render tree (state decls in
/// particular use `$`-prefixed names that bare-identifier `Reference`s
/// cannot match). Only `value` statements are flagged orphaned.
@experimental
MaterializedResult materialize({
  required String rootName,
  required List<Statement> statements,
  Set<String> incomplete = const <String>{},
}) {
  // Build the statement map. Last write wins on duplicate ids.
  final stmts = <String, Statement>{};
  for (final s in statements) {
    stmts[s.name] = s;
  }

  // BFS reachability + unresolved collection.
  final reachable = <String>{};
  final unresolved = <String>{};
  final visited = <String>{};
  final queue = <String>[rootName];
  while (queue.isNotEmpty) {
    final name = queue.removeAt(0);
    if (!visited.add(name)) continue;
    final stmt = stmts[name];
    if (stmt == null) {
      unresolved.add(name);
      continue;
    }
    reachable.add(name);
    final refs = <String>{};
    _collectReferences(stmt.expression, refs);
    for (final ref in refs) {
      if (!visited.contains(ref)) queue.add(ref);
    }
  }

  // Orphan analysis — only over value-kind statements.
  final orphaned = <String>[];
  for (final entry in stmts.entries) {
    if (reachable.contains(entry.key)) continue;
    if (entry.value.kind != StatementKind.value) continue;
    orphaned.add(entry.key);
  }

  ElementNode? root;
  final rootStmt = stmts[rootName];
  if (rootStmt != null) {
    root = ElementNode(
      expression: rootStmt.expression,
      statementId: rootName,
      partial: incomplete.contains(rootName),
    );
  }

  return (
    root: root,
    unresolved: unresolved.toList(),
    orphaned: orphaned,
  );
}

/// Walks [node] and adds every bare-identifier [Reference] name to
/// [out].
///
/// State refs (`$x`) are runtime lookups, not statement-graph edges,
/// so they do not contribute to reachability or unresolved analysis.
/// Literals contribute nothing.
void _collectReferences(AstNode node, Set<String> out) {
  switch (node) {
    case Reference(:final name):
      out.add(name);
    case BinaryOp(:final left, :final right):
      _collectReferences(left, out);
      _collectReferences(right, out);
    case UnaryOp(:final operand):
      _collectReferences(operand, out);
    case Ternary(:final condition, :final then, :final otherwise):
      _collectReferences(condition, out);
      _collectReferences(then, out);
      _collectReferences(otherwise, out);
    case MemberAccess(:final target):
      _collectReferences(target, out);
    case IndexAccess(:final target, :final index):
      _collectReferences(target, out);
      _collectReferences(index, out);
    case StateAssign(:final value):
      _collectReferences(value, out);
    case ArrayLit(:final elements):
      for (final e in elements) {
        _collectReferences(e, out);
      }
    case ObjectLit(:final entries):
      for (final e in entries) {
        _collectReferences(e.value, out);
      }
    case CompCall(:final args):
    case BuiltinCall(:final args):
    case MutationCall(:final args):
      for (final a in args) {
        _collectReferences(a.value, out);
      }
    case Literal():
    case NullLiteral():
    case StateRef():
      break;
  }
}
