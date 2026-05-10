import 'package:meta/meta.dart';
import 'package:openui_core/src/parser/materialize.dart';
import 'package:openui_core/src/parser/parser.dart';

/// Merges a [patch] program into an [existing] program, returning a
/// new program string suitable for re-parsing.
///
/// This is the LLM "edit, don't rewrite" pathway:
///
/// 1. Strip Markdown code fences from [patch].
/// 2. Parse both inputs.
/// 3. If [existing] has no statements, return [patch]'s statements
///    re-emitted from their raw source spans.
/// 4. If [patch] has no statements, return [existing] unchanged.
/// 5. Build per-statement `(raw, ast)` maps and an ordered id list
///    from [existing] (last-write-wins on duplicates within [existing]).
/// 6. For each [patch] statement: if the RHS is a [NullLiteral],
///    delete; otherwise upsert and append to the order if new.
/// 7. Drop orphans — value-kind statements unreachable from [rootId]
///    via the materializer's reachability walk. State, query, and
///    mutation declarations are preserved even when unreachable.
/// 8. Re-emit the surviving statements, in order, joined by
///    newlines.
///
/// "Raw" text per statement is the source slice between its offset
/// and the next statement's offset (or end-of-source), trimmed.
/// Whitespace inside a statement — multi-line bracket layouts,
/// indentation — is preserved verbatim. The renderer never invokes
/// this function automatically (Acceptance Gap A17); it is meant to
/// be called by tools that drive the LLM to emit edits rather than
/// full programs.
///
/// Marked `@experimental` per D12.
@experimental
String mergeStatements(
  String existing,
  String patch, {
  String rootId = 'root',
}) {
  final cleanedPatch = _stripFences(patch);
  final existingProgram = parseProgram(existing, recoverable: true);
  final patchProgram = parseProgram(cleanedPatch, recoverable: true);

  if (existingProgram.statements.isEmpty) {
    return _annotate(
      cleanedPatch,
      patchProgram.statements,
    ).map((e) => e.raw).join('\n');
  }
  if (patchProgram.statements.isEmpty) {
    return _annotate(
      existing,
      existingProgram.statements,
    ).map((e) => e.raw).join('\n');
  }

  final order = <String>[];
  final raw = <String, String>{};
  final asts = <String, AstNode>{};

  for (final e in _annotate(existing, existingProgram.statements)) {
    if (!asts.containsKey(e.id)) order.add(e.id);
    raw[e.id] = e.raw;
    asts[e.id] = e.expression;
  }

  for (final e in _annotate(cleanedPatch, patchProgram.statements)) {
    if (e.expression is NullLiteral) {
      raw.remove(e.id);
      asts.remove(e.id);
      order.remove(e.id);
    } else {
      if (!asts.containsKey(e.id)) order.add(e.id);
      raw[e.id] = e.raw;
      asts[e.id] = e.expression;
    }
  }

  _gcUnreachable(order, raw, asts, rootId);

  return order.where(raw.containsKey).map((id) => raw[id]!).join('\n');
}

class _AnnotatedStatement {
  const _AnnotatedStatement({
    required this.id,
    required this.raw,
    required this.expression,
  });

  final String id;
  final String raw;
  final AstNode expression;
}

List<_AnnotatedStatement> _annotate(String source, List<Statement> stmts) {
  final result = <_AnnotatedStatement>[];
  for (var i = 0; i < stmts.length; i++) {
    final start = stmts[i].offset;
    final end = (i + 1 < stmts.length) ? stmts[i + 1].offset : source.length;
    final slice = source.substring(start, end).trim();
    result.add(
      _AnnotatedStatement(
        id: stmts[i].name,
        raw: slice,
        expression: stmts[i].expression,
      ),
    );
  }
  return result;
}

void _gcUnreachable(
  List<String> order,
  Map<String, String> raw,
  Map<String, AstNode> asts,
  String rootId,
) {
  // Synthesize Statements from the merged maps so the materializer
  // can run its standard reachability walk. Offsets are throwaway
  // (zero) — they don't affect reachability.
  final stmts = <Statement>[
    for (final id in order)
      if (asts.containsKey(id))
        Statement(
          name: id,
          kind: classifyStatement(id, asts[id]!),
          expression: asts[id]!,
          offset: 0,
        ),
  ];
  final orphans = materialize(
    rootName: rootId,
    statements: stmts,
  ).orphaned.toSet();
  for (final id in orphans) {
    raw.remove(id);
    asts.remove(id);
    order.remove(id);
  }
}

String _stripFences(String source) {
  var s = source.trim();
  if (s.startsWith('```')) {
    final firstNewline = s.indexOf('\n');
    if (firstNewline != -1) {
      s = s.substring(firstNewline + 1);
    } else {
      // Single-line fence with no newline — drop the whole line so
      // the parser doesn't choke on backticks.
      s = '';
    }
  }
  if (s.endsWith('```')) {
    s = s.substring(0, s.length - 3).trimRight();
  }
  return s;
}
