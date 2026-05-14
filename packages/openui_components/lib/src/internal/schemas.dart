import 'package:openui_core/openui_core.dart';

/// Marks a schema as reactive by adding the `x-reactive` extension keyword.
extension SchemaXReactive on Schema {
  /// Returns a new schema with the `x-reactive` extension keyword added.
  Schema xReactive() => Schema.fromMap({...value, 'x-reactive': true});
}

/// Marks a schema as an action prop by adding `x-action: true`.
extension SchemaXAction on Schema {
  /// Returns a new schema with the `x-action` extension keyword added.
  Schema xAction() => Schema.fromMap({...value, 'x-action': true});
}
