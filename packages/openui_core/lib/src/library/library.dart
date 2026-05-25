import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

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

/// Ordered prop names from a component [Schema] (`properties` key order).
///
/// Marked `@experimental` per D12.
@experimental
List<String> orderedPropertyNames(Schema schema) {
  final properties = schema.value['properties'];
  if (properties is! Map<String, Object?>) return const [];
  return properties.keys.toList(growable: false);
}

/// Maps positional [CompCall] args to prop names by index.
///
/// Extra positionals beyond [propNames].length are ignored (lenient).
///
/// Marked `@experimental` per D12.
@experimental
Map<String, Object?> bindPositionalProps({
  required CompCall call,
  required List<String> propNames,
  required Object? Function(Argument arg, String propName) resolveArg,
}) {
  final positional = <Argument>[
    for (final a in call.args)
      if (a.name == null) a,
  ];
  final props = <String, Object?>{};
  final bound = propNames.length < positional.length
      ? propNames.length
      : positional.length;
  for (var i = 0; i < bound; i++) {
    props[propNames[i]] = resolveArg(positional[i], propNames[i]);
  }
  return props;
}

/// Walks the positional args of [call], evaluates each value against
/// [context], and returns a map of prop name to resolved value.
///
/// Special-case: when a prop is marked reactive in [schema]
/// the `x-reactive` extension keyword) AND the arg's
/// value is a bare [StateRef], the entry is a [ReactiveAssign]
/// marker carrying the current store value. The receiving component
/// renders [ReactiveAssign.value] and writes user edits back to
/// [ReactiveAssign.target].
///
/// Component calls must use positional args only; named args are
/// rejected at parse time.
///
/// Marked `@experimental` per D12.
@experimental
Map<String, Object?> evaluateElementProps({
  required CompCall call,
  required Schema schema,
  required EvalContext context,
}) {
  final properties = schema.value['properties'];
  final propNames = orderedPropertyNames(schema);
  return bindPositionalProps(
    call: call,
    propNames: propNames,
    resolveArg: (arg, propName) {
      final value = arg.value;
      if (_isReactiveProp(properties, propName) && value is StateRef) {
        final fullName = '\$${value.name}';
        return ReactiveAssign(
          target: fullName,
          value: context.store.get(fullName),
        );
      }
      return evaluate(value, context);
    },
  );
}

bool _isReactiveProp(Object? properties, String propName) {
  if (properties is! Map<String, Object?>) return false;
  final propSchema = properties[propName];
  if (propSchema is! Map<String, Object?>) return false;
  return propSchema['x-reactive'] == true;
}
