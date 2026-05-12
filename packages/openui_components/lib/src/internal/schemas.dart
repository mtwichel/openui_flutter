import 'package:openui_core/openui_core.dart';

/// Sugar for the `Schema.object(...)` shape that every component
/// definition emits. Keeps the per-component file body short.
///
/// Pass [required] to mark mandatory props; they render without `?`
/// in generated prompts.
Schema objectSchema(
  Map<String, Object?> properties, {
  List<String>? required,
}) {
  return Schema.fromMap(<String, Object?>{
    'type': 'object',
    'properties': properties,
    if (required != null && required.isNotEmpty) 'required': required,
  });
}

/// Reactive-prop schema fragment.
Map<String, Object?> reactiveProp(String type) => <String, Object?>{
  'type': type,
  'x-reactive': true,
};
