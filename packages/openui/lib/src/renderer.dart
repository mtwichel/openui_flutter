// Internal package imports cross openui_core experimental types
// (the entire openui_core surface is marked @experimental in v0.1).
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:openui/src/action_event.dart';
import 'package:openui/src/error_boundary.dart';
import 'package:openui/src/form_state_cache.dart';
import 'package:openui/src/query_manager.dart';
import 'package:openui/src/renderer_scope.dart';
import 'package:openui_core/openui_core.dart';

/// Render callback alias for the Flutter renderer's library.
///
/// `Renderer.library` is a `Library<Widget>`; component definitions
/// against this library use [ComponentWidgetRenderer] as their render
/// signature.
typedef ComponentWidgetRenderer = ComponentRender<Widget>;

/// The Flutter renderer for OpenUI Lang.
///
/// Mirrors the JS reference's `<Renderer />` shape: pass the cumulative
/// streamed response, the active component library, and the optional
/// hook bag, and the widget keeps an internal parser / store / query
/// cache / form-state cache in sync.
///
/// Marked `@experimental` per D12.
@experimental
class Renderer extends StatefulWidget {
  /// Creates a [Renderer].
  const Renderer({
    required this.library,
    this.response,
    this.isStreaming = false,
    this.onAction,
    this.onStateUpdate,
    this.initialState,
    this.onParseResult,
    this.toolProvider,
    this.queryLoader,
    this.onError,
    this.rootName = 'root',
    super.key,
  });

  /// Cumulative streamed source. Replacing this triggers a fresh
  /// parse pass (`StreamParser.set`).
  final String? response;

  /// Component library used to dispatch each `CompCall`.
  final Library<Widget> library;

  /// Whether `response` is still being appended to by the upstream
  /// stream. Propagated to component implementations via
  /// `RendererScope.isStreaming`.
  final bool isStreaming;

  /// Notified when an action plan fires. Receives the parsed plan plus
  /// the component-emitted payload (e.g. form submit values).
  final void Function(ActionEvent event)? onAction;

  /// Notified after every write to the internal [Store], with the
  /// full post-write snapshot.
  final void Function(Map<String, Object?> snapshot)? onStateUpdate;

  /// Initial state seed. Keys must include the leading `$`.
  final Map<String, Object?>? initialState;

  /// Notified after every parse pass with the latest [ParseResult].
  final void Function(ParseResult result)? onParseResult;

  /// Tool transport for `Query` / `Mutation` statements. Mutually
  /// exclusive with [queryLoader] in practice — when both are set,
  /// [queryLoader] wins.
  final ToolProvider? toolProvider;

  /// Test seam — receives the statement id and raw arg list and
  /// returns the resolved value directly.
  final QueryLoader? queryLoader;

  /// Notified when the active [OpenUIError] set changes. Errors are
  /// deduplicated structurally — repeated identical sets do not fire
  /// twice.
  final void Function(List<OpenUIError> errors)? onError;

  /// Name of the entry-point statement. Defaults to `'root'`.
  final String rootName;

  @override
  State<Renderer> createState() => _RendererState();
}

class _RendererState extends State<Renderer> {
  late StreamParser _parser;
  late Store _store;
  late FormStateCache _formStateCache;
  QueryManager? _queryManager;
  ParseResult? _lastResult;
  List<OpenUIError> _lastReportedErrors = const <OpenUIError>[];
  void Function()? _storeUnsubscribe;

  // "Last good root" cache. Mid-stream, autoClose patches the pending
  // tail differently on every chunk, so a single tick can produce a
  // null or misshapen root while neighboring ticks parse cleanly. When
  // `isStreaming` is true, prefer the cached root over a degraded new
  // parse so the visible tree doesn't flicker between bad shapes.
  // Mirrors the JS reference's completed-statement caching strategy
  // (lang-core/src/parser/parser.ts, completedStmtMap).
  ElementNode? _lastGoodRoot;
  String _previousResponse = '';

  @override
  void initState() {
    super.initState();
    _parser = createStreamingParser(rootName: widget.rootName);
    _store = Store();
    _formStateCache = FormStateCache();
    _storeUnsubscribe = _store.subscribe(_handleStoreChange);
    _queryManager = _buildQueryManager();
    _queryManager?.onChange = _handleQueryChange;
    _runPipeline();
  }

  @override
  void didUpdateWidget(Renderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final providerChanged =
        widget.toolProvider != oldWidget.toolProvider ||
        widget.queryLoader != oldWidget.queryLoader;
    if (providerChanged) {
      _queryManager?.dispose();
      _queryManager = _buildQueryManager();
      _queryManager?.onChange = _handleQueryChange;
    }
    if (widget.rootName != oldWidget.rootName) {
      _parser = createStreamingParser(rootName: widget.rootName);
    }
    if (widget.response != oldWidget.response ||
        widget.rootName != oldWidget.rootName ||
        providerChanged) {
      _runPipeline();
    }
  }

  @override
  void dispose() {
    _storeUnsubscribe?.call();
    _queryManager?.dispose();
    _formStateCache.dispose();
    _store.dispose();
    super.dispose();
  }

  QueryManager? _buildQueryManager() {
    if (widget.toolProvider == null && widget.queryLoader == null) return null;
    return QueryManager(
      toolProvider: widget.toolProvider,
      loader: widget.queryLoader,
    );
  }

  void _handleStoreChange() {
    if (!mounted) return;
    widget.onStateUpdate?.call(_store.getSnapshot());
    setState(() {});
  }

  void _handleQueryChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _runPipeline() {
    final response = widget.response ?? '';
    // Reset the last-good cache when the new buffer can't be a
    // continuation of the previous one (shorter, or starts differently).
    // Matches the JS reference's StreamParser.set reset rule.
    if (response.length < _previousResponse.length ||
        !response.startsWith(_previousResponse)) {
      _lastGoodRoot = null;
    }
    _previousResponse = response;
    final result = _parser.set(response);
    _lastResult = result;
    if (result.root != null && result.meta.errors.isEmpty) {
      _lastGoodRoot = result.root;
    }

    // Eval state defaults against a throwaway store so the seed values
    // can reference plain (non-state) statements but cannot read from
    // the user-facing store mid-initialization.
    final seedStore = Store();
    final seedCtx = EvalContext(
      statements: result.statements,
      store: seedStore,
      builtins: functionalBuiltins,
    );
    final defaults = <String, Object?>{
      for (final decl in result.meta.stateDecls)
        decl.name: evaluate(decl.defaultValue, seedCtx),
    };
    seedStore.dispose();
    _store.initialize(defaults, widget.initialState);

    final manager = _queryManager;
    if (manager != null) {
      for (final query in result.meta.queries) {
        manager.ensureFired(query.statementId, query.args);
      }
    }

    widget.onParseResult?.call(result);
    _maybeReportErrors(result);
  }

  void _maybeReportErrors(ParseResult result) {
    final onError = widget.onError;
    if (onError == null) return;
    final errors = <OpenUIError>[
      for (final parseError in result.meta.errors)
        ParseError(
          message: parseError.message,
          offset: parseError.offset,
        ),
    ];
    final queryErrors = _queryManager?.errors() ?? const <OpenUIError>[];
    errors.addAll(queryErrors);
    if (!_errorListsEqual(errors, _lastReportedErrors)) {
      _lastReportedErrors = List.unmodifiable(errors);
      onError(errors);
    }
  }

  Future<void> _dispatch(
    AstNode actionAst,
    String statementId, {
    Object? payload,
  }) async {
    final plan = actionPlanFromAst(actionAst);
    if (plan == null || plan.steps.isEmpty) return;
    final result = _lastResult;
    final ctx = _buildEvalContext(result);
    final stateDefaults = <String, AstNode>{
      if (result != null)
        for (final decl in result.meta.stateDecls) decl.name: decl.defaultValue,
    };
    final manager = _queryManager;
    await dispatchAction(
      plan: plan,
      context: ctx,
      stateDefaults: stateDefaults,
      onRun: manager == null
          ? null
          : (id) async {
              final args = _argsForRunnable(result, id);
              if (args == null) return;
              manager.invalidate(id, args);
            },
    );
    // dispatchAction collects @Reset-target-not-declared and similar
    // category errors in `ctx.errors`; surface them so they're not
    // silently swallowed.
    ctx.errors.forEach(_reportError);
    widget.onAction?.call(
      ActionEvent(plan: plan, statementId: statementId, payload: payload),
    );
    _maybeReportErrors(result ?? _lastResult!);
  }

  EvalContext _buildEvalContext(ParseResult? result) {
    final statements = result?.statements ?? const <Statement>[];
    return EvalContext(
      statements: statements,
      store: _store,
      queryResults:
          _queryManager?.snapshotValues() ?? const <String, Object?>{},
      builtins: functionalBuiltins,
    );
  }

  @override
  Widget build(BuildContext context) {
    _formStateCache.beginPass();
    final result = _lastResult;
    // Mid-stream the parser can produce a null root for one tick and a
    // non-null root the next; falling back to the cached good root
    // keeps the rendered tree mounted across those gaps. After the
    // stream finishes, the cache is irrelevant — the final parse wins.
    final root = result?.root ?? (widget.isStreaming ? _lastGoodRoot : null);
    final incomplete = <String>{...?result?.meta.incomplete};

    Widget body;
    if (root == null) {
      body = const SizedBox.shrink();
    } else {
      final ctx = _buildEvalContext(result);
      body = _renderAst(
        root.expression,
        ctx,
        statementHint: root.statementId,
      );
    }

    // Reap form fields that didn't get a controllerFor call this pass.
    // Schedule for end-of-frame so build-time mutations don't fight with
    // Flutter's diagnostics.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formStateCache.endPass();
    });

    return RendererScope(
      store: _store,
      formStateCache: _formStateCache,
      isStreaming: widget.isStreaming,
      incomplete: incomplete,
      onActionAst: _dispatch,
      child: body,
    );
  }

  // Reference names currently being expanded — guards against cycles
  // like `a = b\nb = a`. Reset on every top-level build pass.
  final Set<String> _expanding = <String>{};

  Widget _renderAst(AstNode node, EvalContext ctx, {String? statementHint}) {
    switch (node) {
      case Reference(:final name):
        if (_expanding.contains(name)) {
          final error = CyclicStateError(
            cycle: [..._expanding, name],
            statementId: statementHint,
          );
          _reportError(error);
          return _OpenUiErrorPlaceholder(error: error);
        }
        final stmt = ctx.statements[name];
        if (stmt == null) return const SizedBox.shrink();
        _expanding.add(name);
        try {
          return _renderAst(stmt.expression, ctx, statementHint: name);
        } finally {
          _expanding.remove(name);
        }
      case CompCall():
        return _renderComp(node, ctx, statementHint: statementHint);
      case BuiltinCall():
        return _renderBuiltinAsWidget(node, ctx, statementHint: statementHint);
      case Literal(:final value):
        return _wrapPrimitive(value);
      case StateRef(:final name):
        return _wrapPrimitive(ctx.store.get('\$$name'));
      case ArrayLit(:final elements):
        return _wrapList(
          [
            for (final e in elements)
              _renderAst(e, ctx, statementHint: statementHint),
          ],
        );
      case NullLiteral():
        return const SizedBox.shrink();
      case StateAssign():
      case BinaryOp():
      case UnaryOp():
      case Ternary():
      case MemberAccess():
      case IndexAccess():
      case ObjectLit():
      case QueryCall():
      case MutationCall():
        final value = evaluate(node, ctx);
        return _wrapPrimitive(value);
    }
  }

  List<Argument>? _argsForRunnable(ParseResult? result, String id) {
    if (result == null) return null;
    for (final q in result.meta.queries) {
      if (q.statementId == id) return q.args;
    }
    for (final m in result.meta.mutations) {
      if (m.statementId == id) return m.args;
    }
    return null;
  }

  Widget _renderComp(
    CompCall call,
    EvalContext ctx, {
    String? statementHint,
  }) {
    final component = widget.library[call.type];
    if (component == null) {
      return _errorPlaceholder(
        UnknownComponentError(
          component: call.type,
          statementId: statementHint,
        ),
      );
    }
    final id = statementHint ?? '';
    // No explicit key: relying on tree-position identity. Adding a
    // ValueKey('${call.type}#$id') would collide when an `ArrayLit` lists
    // multiple siblings of the same component type at the same parent
    // statement id.
    return ErrorBoundary(
      statementId: id,
      onError: _reportError,
      builder: (context) {
        final props = _resolveProps(call, component.schema, ctx, id);
        return component.render(ctx, props, _renderAst, id);
      },
    );
  }

  Widget _renderBuiltinAsWidget(
    BuiltinCall call,
    EvalContext ctx, {
    String? statementHint,
  }) {
    if (_isIterating(call)) {
      final widgets = _renderIteration(call, ctx, statementHint: statementHint);
      if (widgets == null) return const SizedBox.shrink();
      return _wrapList(widgets);
    }
    return _wrapPrimitive(evaluate(call, ctx));
  }

  /// Evaluates an `@Each`/`@Map` call and renders its template once per
  /// item with `$item`/`$index` in scope. Returns `null` when the call
  /// isn't shaped right (missing args, non-list list).
  List<Widget>? _renderIteration(
    BuiltinCall call,
    EvalContext ctx, {
    String? statementHint,
  }) {
    if (call.args.length < 2) return null;
    final listVal = evaluate(call.args[0].value, ctx);
    if (listVal is! List<Object?>) return null;
    final template = call.args[1].value;
    return [
      for (var i = 0; i < listVal.length; i++)
        _renderAst(
          template,
          ctx.withIteration(<String, Object?>{
            r'$item': listVal[i],
            r'$index': i,
          }),
          statementHint: statementHint,
        ),
    ];
  }

  Map<String, Object?> _resolveProps(
    CompCall call,
    Schema schema,
    EvalContext ctx,
    String statementId,
  ) {
    final properties =
        (schema.value['properties'] as Map<String, Object?>?) ??
        const <String, Object?>{};
    final props = <String, Object?>{};
    for (final arg in call.args) {
      final propName = arg.name;
      if (propName == null) continue;
      final value = arg.value;
      final isReactive = _isReactivePropName(properties, propName);
      if (isReactive && value is StateRef) {
        final fullName = '\$${value.name}';
        props[propName] = ReactiveAssign(
          target: fullName,
          value: _store.get(fullName),
        );
        continue;
      }
      props[propName] = _resolvePropValue(value, ctx, statementId);
    }
    return props;
  }

  Object? _resolvePropValue(
    AstNode value,
    EvalContext ctx,
    String statementId,
  ) {
    final asAction = actionPlanFromAst(value);
    if (asAction != null && asAction.steps.isNotEmpty) {
      // Disable interactivity while the containing statement is still
      // being streamed (Acceptance Gap A6).
      final result = _lastResult;
      final disabled = result?.meta.incomplete.contains(statementId) ?? false;
      if (disabled) return null;
      return () => _dispatch(value, statementId);
    }
    if (value is CompCall) {
      return _renderAst(value, ctx, statementHint: statementId);
    }
    if (value is ArrayLit) {
      // `Reference` counts as widget-like because the JS reference's
      // canonical idiom is `root = Column(children: [a, b])` with
      // `a = Card(...)`. The reference target is most often a CompCall
      // and renderNode follows it to the right widget.
      final hasComp = value.elements.any(
        (e) =>
            e is CompCall ||
            e is Reference ||
            (e is BuiltinCall && _isIterating(e)),
      );
      if (hasComp) {
        return [
          for (final e in value.elements)
            _renderAst(e, ctx, statementHint: statementId),
        ];
      }
      return evaluate(value, ctx);
    }
    if (value is BuiltinCall && _isIterating(value)) {
      // @Each/@Map producing widgets — pre-render when the template is
      // a component call.
      if (value.args.length >= 2 && value.args[1].value is CompCall) {
        final widgets = _renderIteration(
          value,
          ctx,
          statementHint: statementId,
        );
        if (widgets != null) return widgets;
      }
      return evaluate(value, ctx);
    }
    return evaluate(value, ctx);
  }

  bool _isIterating(BuiltinCall call) =>
      call.name == '@Each' || call.name == '@Map';

  bool _isReactivePropName(Map<String, Object?> properties, String name) {
    final spec = properties[name];
    if (spec is! Map<String, Object?>) return false;
    return spec['x-reactive'] == true;
  }

  /// Routes [error] through the [Renderer.onError] callback with the
  /// renderer-wide structural-equality dedup. Called from the error
  /// boundary (build-time component throws), the reference-cycle guard
  /// in [_renderAst], and [_errorPlaceholder] (unknown component, etc).
  /// All call sites land here so the reporting policy lives in one
  /// place.
  void _reportError(OpenUIError error) {
    final next = <OpenUIError>[..._lastReportedErrors, error];
    if (_errorListsEqual(next, _lastReportedErrors)) return;
    _lastReportedErrors = List.unmodifiable(next);
    final onError = widget.onError;
    if (onError == null) return;
    onError(_lastReportedErrors);
  }

  Widget _errorPlaceholder(OpenUIError error) {
    _reportError(error);
    return _OpenUiErrorPlaceholder(error: error);
  }

  Widget _wrapPrimitive(Object? value) {
    if (value == null) return const SizedBox.shrink();
    if (value is Widget) return value;
    return Text('$value');
  }

  Widget _wrapList(List<Widget> children) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

bool _errorListsEqual(List<OpenUIError> a, List<OpenUIError> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _OpenUiErrorPlaceholder extends StatelessWidget {
  const _OpenUiErrorPlaceholder({required this.error});

  final OpenUIError error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        '${error.code}: ${error.message ?? ''}',
        style: const TextStyle(color: Color(0xFFB00020)),
      ),
    );
  }
}
