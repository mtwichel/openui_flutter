import 'package:openui_core/openui_core.dart';

/// Sugar for the `Schema.object(...)` shape that every component
/// definition emits. Keeps the per-component file body short.
Schema objectSchema(Map<String, Object?> properties) {
  return Schema.fromMap(<String, Object?>{
    'type': 'object',
    'properties': properties,
  });
}

/// Reactive-prop schema fragment.
Map<String, Object?> reactiveProp(String type) => <String, Object?>{
  'type': type,
  'x-reactive': true,
};
