import 'package:meta/meta.dart';

/// Base class for every error surfaced through OpenUI.
///
/// `OpenUIError` is sealed: every concrete error is a subclass defined
/// in this file. Errors are surfaced two ways depending on phase —
///
/// - **Parse-time and eval-time** errors flow through `ParseMeta.errors`;
///   the streaming pipeline never throws. The renderer's error
///   boundary then routes them to `Renderer.onError`.
/// - **Tool-time and adapter-time** errors are thrown by the components
///   that detect them ([McpToolError] from `extractToolResult`,
///   [AdapterMismatchError] from a stream adapter, etc.) and caught
///   one layer up before re-surfacing through `onError`.
///
/// Equality is structural and includes every field the subclass
/// declares, so `Renderer.onError`'s "fire only when the set changes"
/// dedup rule (Plan §Phase 2) reduces to a `listEquals` over the new
/// vs. previous lists.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
sealed class OpenUIError implements Exception {
  /// Creates an [OpenUIError] with the given structured fields.
  const OpenUIError({
    required this.code,
    this.message,
    this.hint,
    this.statementId,
  });

  /// Stable machine-readable code (e.g. `'parse'`, `'cycle'`,
  /// `'mcp_tool'`). Useful for filtering or dispatching without a
  /// runtime type check.
  final String code;

  /// Human-readable description. Optional because some subclasses
  /// (e.g. [CyclicStateError]) compose their own message from
  /// structured fields and may leave this `null`.
  final String? message;

  /// Optional hint about how to fix the underlying issue. Surfaced in
  /// dev-tools and error-boundary UI.
  final String? hint;

  /// Statement id this error is attributed to, when known.
  final String? statementId;

  String get _typeName;

  @override
  String toString() {
    final parts = <String>['code: $code'];
    if (message != null) parts.add('message: $message');
    if (hint != null) parts.add('hint: $hint');
    if (statementId != null) parts.add('statementId: $statementId');
    return '$_typeName(${parts.join(', ')})';
  }
}

/// Lexer or parser failure on a *completed* statement. The autoclose
/// pass swallows tail-truncation errors, so a `ParseError` always
/// represents a syntactically real problem in the source.
///
/// Marked `@experimental` per D12.
@experimental
final class ParseError extends OpenUIError {
  /// Creates a [ParseError].
  const ParseError({
    required String message,
    required this.offset,
    super.statementId,
    super.hint,
  }) : super(code: 'parse', message: message);

  /// Byte offset in the source where the error was detected.
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParseError &&
          message == other.message &&
          offset == other.offset &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(ParseError, message, offset, statementId, hint);

  @override
  String get _typeName => 'ParseError';
}

/// The evaluator hit an unresolvable expression: member access on
/// `null`, a binary op with mismatched types, an out-of-range index,
/// etc. The cycle case has its own subclass ([CyclicStateError]).
///
/// Marked `@experimental` per D12.
@experimental
final class EvaluationError extends OpenUIError {
  /// Creates an [EvaluationError].
  const EvaluationError({
    required String message,
    super.statementId,
    super.hint,
  }) : super(code: 'evaluation', message: message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationError &&
          message == other.message &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(EvaluationError, message, statementId, hint);

  @override
  String get _typeName => 'EvaluationError';
}

/// A reactive-state cycle was detected during evaluation, e.g.
/// `a = $b` and `b = $a`. Per Decision D15 the cycle resolves to
/// `null` instead of recursing; the error is surfaced as data so the
/// process keeps running.
///
/// Marked `@experimental` per D12.
@experimental
final class CyclicStateError extends OpenUIError {
  /// Creates a [CyclicStateError]. [cycle] lists the `$state`
  /// identifiers in traversal order, with the first identifier
  /// repeated at the end (`['$a', '$b', '$a']`).
  const CyclicStateError({
    required this.cycle,
    super.statementId,
    super.hint,
  }) : super(code: 'cycle');

  /// The `$state` identifiers participating in the cycle.
  final List<String> cycle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CyclicStateError &&
          _listEquals(cycle, other.cycle) &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(CyclicStateError, Object.hashAll(cycle), statementId, hint);

  @override
  String toString() {
    final parts = <String>[
      'code: $code',
      'cycle: ${cycle.join(' -> ')}',
    ];
    if (hint != null) parts.add('hint: $hint');
    if (statementId != null) parts.add('statementId: $statementId');
    return '$_typeName(${parts.join(', ')})';
  }

  @override
  String get _typeName => 'CyclicStateError';
}

/// The RHS comp call referenced a name not registered in the active
/// `Library`. Recovered by rendering an error placeholder for that
/// element only; the rest of the tree continues to render.
///
/// Marked `@experimental` per D12.
@experimental
final class UnknownComponentError extends OpenUIError {
  /// Creates an [UnknownComponentError] for [component].
  const UnknownComponentError({
    required this.component,
    super.statementId,
    super.hint,
  }) : super(code: 'unknown_component');

  /// The component name that failed to resolve.
  final String component;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownComponentError &&
          component == other.component &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(UnknownComponentError, component, statementId, hint);

  @override
  String toString() {
    final parts = <String>['code: $code', 'component: $component'];
    if (hint != null) parts.add('hint: $hint');
    if (statementId != null) parts.add('statementId: $statementId');
    return '$_typeName(${parts.join(', ')})';
  }

  @override
  String get _typeName => 'UnknownComponentError';
}

/// The MCP server reported a tool-execution failure
/// (`CallToolResult.isError == true`). Thrown by `extractToolResult`
/// in `openui_mcp` and caught by the query/mutation manager in
/// `openui_core` before re-surfacing through `Renderer.onError`.
///
/// Marked `@experimental` per D12.
@experimental
final class McpToolError extends OpenUIError {
  /// Creates an [McpToolError] with the joined tool error message.
  const McpToolError({
    required String message,
    super.statementId,
    super.hint,
  }) : super(code: 'mcp_tool', message: message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpToolError &&
          message == other.message &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(McpToolError, message, statementId, hint);

  @override
  String get _typeName => 'McpToolError';
}

/// The `Query` or `Mutation` referenced a tool name not registered on
/// the active `ToolProvider`. Surfaces as data; the dependent element
/// renders an error placeholder.
///
/// Marked `@experimental` per D12.
@experimental
final class ToolNotFoundError extends OpenUIError {
  /// Creates a [ToolNotFoundError] for [toolName].
  const ToolNotFoundError({
    required this.toolName,
    super.statementId,
    super.hint,
  }) : super(code: 'tool_not_found');

  /// The tool name that was requested but not available.
  final String toolName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolNotFoundError &&
          toolName == other.toolName &&
          statementId == other.statementId &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(ToolNotFoundError, toolName, statementId, hint);

  @override
  String toString() {
    final parts = <String>['code: $code', 'toolName: $toolName'];
    if (hint != null) parts.add('hint: $hint');
    if (statementId != null) parts.add('statementId: $statementId');
    return '$_typeName(${parts.join(', ')})';
  }

  @override
  String get _typeName => 'ToolNotFoundError';
}

/// A stream adapter encountered a malformed event on its first decode
/// pass — the wire format does not match what the adapter expects
/// (e.g. an `agUiAdapter` connected to an OpenAI Responses endpoint).
/// Per Decision D5 the adapter throws this immediately rather than
/// silently producing no output.
///
/// Marked `@experimental` per D12.
@experimental
final class AdapterMismatchError extends OpenUIError {
  /// Creates an [AdapterMismatchError] tagging the adapter that
  /// failed and a short preview of the offending payload.
  const AdapterMismatchError({
    required this.adapterName,
    required this.payloadPreview,
    super.hint,
  }) : super(code: 'adapter_mismatch');

  /// The adapter that failed to decode (e.g. `'agUiAdapter'`).
  final String adapterName;

  /// First ~200 characters of the offending payload, for logs.
  final String payloadPreview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdapterMismatchError &&
          adapterName == other.adapterName &&
          payloadPreview == other.payloadPreview &&
          hint == other.hint;

  @override
  int get hashCode =>
      Object.hash(AdapterMismatchError, adapterName, payloadPreview, hint);

  @override
  String toString() {
    final parts = <String>[
      'code: $code',
      'adapter: $adapterName',
      'payload: $payloadPreview',
    ];
    if (hint != null) parts.add('hint: $hint');
    return '$_typeName(${parts.join(', ')})';
  }

  @override
  String get _typeName => 'AdapterMismatchError';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
