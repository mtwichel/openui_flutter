import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/src/eval/evaluator.dart';
import 'package:openui_core/src/parser/parser.dart';

/// Render callback for one component definition.
///
/// `W` is the rendered widget / element type. `openui_core` is
/// pure-Dart, so it stays generic; `openui` (the Flutter package)
/// will define `typedef ComponentRenderer = ComponentRender<Widget>`
/// over this type.
///
/// Parameters:
///
/// - [context] — the live [EvalContext] for the surrounding render
///   pass (statement map, store, query results, iteration scope).
/// - [props] — already-evaluated prop values (the renderer walks the
///   `CompCall.args` and evaluates each value before invoking the
///   component). Reactive props arrive as a [ReactiveAssign] marker
///   instead of a resolved value; consumers check via
///   [isReactiveAssign] and set up two-way binding.
/// - [renderNode] — recursive child renderer. Components that
///   accept inline child ASTs (e.g. a `Stack`'s children list) call
///   this to render each child against the same context.
/// - [statementId] — id of the statement this element materializes
///   from. Carried so the renderer can attribute render-time errors
///   back to the source line.
///
/// Marked `@experimental` per D12.
@experimental
typedef ComponentRender<W> =
    W Function(
      EvalContext context,
      Map<String, Object?> props,
      W Function(AstNode node, EvalContext context) renderNode,
      String statementId,
    );

/// One component definition: a name (matching the `TYPE` token in
/// source), a JSON-schema describing its props, and a render
/// callback.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class Component<W> {
  /// Creates a [Component] definition.
  const Component({
    required this.name,
    required this.schema,
    required this.render,
  });

  /// The TYPE-token name used in source (e.g. `'Stack'`, `'Card'`).
  final String name;

  /// Prop schema. The `properties` map drives prop coercion and the
  /// `x-reactive` keyword (set via [reactive]) marks a prop as
  /// two-way bound.
  final Schema schema;

  /// Render callback invoked when the renderer dispatches a
  /// matching `CompCall`.
  final ComponentRender<W> render;
}

/// Sugar over the [Component] constructor.
///
/// Marked `@experimental` per D12.
@experimental
Component<W> defineComponent<W>({
  required String name,
  required Schema schema,
  required ComponentRender<W> render,
}) {
  return Component<W>(name: name, schema: schema, render: render);
}

/// Registry of [Component]s keyed by name.
///
/// Construct from a list of definitions; lookups go through `[]`.
/// `Library` is parameterised over the rendered widget type so the
/// pure-Dart core can hold typed definitions without depending on
/// Flutter.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class Library<W> {
  /// Creates a [Library] from the given component definitions.
  /// Last-write-wins on duplicate names.
  Library(List<Component<W>> components)
    : _byName = Map<String, Component<W>>.unmodifiable(<String, Component<W>>{
        for (final c in components) c.name: c,
      });

  final Map<String, Component<W>> _byName;

  /// Returns the component with the given [name], or `null` when no
  /// matching component is registered.
  Component<W>? operator [](String name) => _byName[name];

  /// Names of every registered component, in registration order.
  Iterable<String> get names => _byName.keys;

  /// Returns a new library that adds [extra]'s components on top of
  /// this one's. Last-write-wins on duplicate names.
  Library<W> extend(List<Component<W>> extra) =>
      Library<W>(<Component<W>>[..._byName.values, ...extra]);
}

/// Wraps [inner] with the `x-reactive: true` extension keyword,
/// marking the prop as two-way bound to a `$state` variable.
///
/// Spike S0.1 confirmed `json_schema_builder ^0.1.3` preserves
/// custom extension keywords through `toJson()`, so a one-line
/// spread merge is enough — no wrapper class is needed.
///
/// Marked `@experimental` per D12.
@experimental
Schema reactive(Schema inner) =>
    Schema.fromMap(<String, Object?>{...inner.value, 'x-reactive': true});

/// Marker emitted by the props-evaluator when a reactive prop
/// resolves to a `$varName` reference.
///
/// Components consuming the prop check via [isReactiveAssign] and
/// set up two-way binding to the store. The marker carries both the
/// `$`-prefixed [target] (so the component knows what state-var to
/// write on edit) and the [value] currently in the store (so the
/// component can render the right thing right now).
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ReactiveAssign {
  /// Creates a [ReactiveAssign] marker.
  const ReactiveAssign({required this.target, required this.value});

  /// `$`-prefixed state-var the component should write back to.
  final String target;

  /// Current value of [target] in the store, for read-side render.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactiveAssign && other.target == target && other.value == value;

  @override
  int get hashCode => Object.hash(ReactiveAssign, target, value);

  @override
  String toString() => 'ReactiveAssign($target = $value)';
}

/// Returns `true` when [value] is a [ReactiveAssign] marker.
///
/// Marked `@experimental` per D12.
@experimental
bool isReactiveAssign(Object? value) => value is ReactiveAssign;

/// Walks the named args of [call], evaluates each value against
/// [context], and returns a map of prop name to resolved value.
///
/// Special-case: when a prop is marked reactive in [schema] (via
/// [reactive] / the `x-reactive` extension keyword) AND the arg's
/// value is a bare [StateRef], the entry is a [ReactiveAssign]
/// marker carrying the current store value. The receiving component
/// renders [ReactiveAssign.value] and writes user edits back to
/// [ReactiveAssign.target].
///
/// Positional args (no `name`) are dropped — v0.1 components only
/// accept named props.
///
/// Marked `@experimental` per D12.
@experimental
Map<String, Object?> evaluateElementProps({
  required CompCall call,
  required Schema schema,
  required EvalContext context,
}) {
  final properties = schema.value['properties'];
  final props = <String, Object?>{};
  for (final arg in call.args) {
    final propName = arg.name;
    if (propName == null) continue;

    final value = arg.value;
    if (_isReactiveProp(properties, propName) && value is StateRef) {
      final fullName = '\$${value.name}';
      props[propName] = ReactiveAssign(
        target: fullName,
        value: context.store.get(fullName),
      );
    } else {
      props[propName] = evaluate(value, context);
    }
  }
  return props;
}

bool _isReactiveProp(Object? properties, String propName) {
  if (properties is! Map<String, Object?>) return false;
  final propSchema = properties[propName];
  if (propSchema is! Map<String, Object?>) return false;
  return propSchema['x-reactive'] == true;
}
