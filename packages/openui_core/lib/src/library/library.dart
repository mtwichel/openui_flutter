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

/// Walks the named args of [call], evaluates each value against
/// [context], and returns a map of prop name to resolved value.
///
/// Special-case: when a prop is marked reactive in [schema]
/// the `x-reactive` extension keyword) AND the arg's
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
