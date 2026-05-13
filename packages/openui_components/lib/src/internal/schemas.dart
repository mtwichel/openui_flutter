import 'package:openui_core/openui_core.dart';

/// Marks a schema as reactive by adding the `x-reactive` extension keyword.
extension SchemaXReactive on Schema {
  /// Returns a new schema with the `x-reactive` extension keyword added.
  Schema xReactive() => Schema.fromMap({...value, 'x-reactive': true});
}
