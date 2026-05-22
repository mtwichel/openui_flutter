import 'package:dart_mappable/dart_mappable.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// [MappingHook] for serializing [Schema] values as JSON schema maps.
class SchemaMappingHook extends MappingHook {
  /// Creates a [SchemaMappingHook].
  const SchemaMappingHook();

  @override
  Object? beforeDecode(Object? value) {
    if (value is Map) {
      return Schema.fromMap(Map<String, dynamic>.from(value));
    }
    throw StateError('Expected Map for Schema, got $value');
  }

  @override
  Object? beforeEncode(Object? value) {
    if (value is Schema) {
      return value.value;
    }
    return value;
  }
}
