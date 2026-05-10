// Spike S0.1: confirm json_schema_builder preserves extension keywords
// (e.g. x-reactive) through toJson() round-trip.

import 'dart:convert';

import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  // Build a schema the way `defineComponent` will — object with children list +
  // a reactive value field.
  final base = S.object(
    properties: {
      'children': S.list(items: S.string()),
      'value': S.string(),
    },
    required: ['value'],
  );

  // Merge custom keywords into the underlying map. The extension type's
  // `value` getter is the same `Map<String, Object?>` that backs the schema,
  // so mutating it is safe.
  final tagged = Schema.fromMap({
    ...base.value,
    'format': 'openui-component',
    'x-reactive': true,
    'x-component-name': 'Input',
  });

  // toJson serializes whatever is in the backing map.
  final encoded = tagged.toJson();
  print('--- encoded ---');
  print(encoded);

  // Round-trip back through jsonDecode -> Schema.fromMap.
  final decoded = Schema.fromMap(jsonDecode(encoded) as Map<String, Object?>);

  // Assert keywords survived.
  final survived = <String, bool>{
    'format': decoded.value['format'] == 'openui-component',
    'x-reactive': decoded.value['x-reactive'] == true,
    'x-component-name': decoded.value['x-component-name'] == 'Input',
    'properties.children.type':
        (decoded.value['properties'] as Map?)?['children'] is Map &&
        ((decoded.value['properties'] as Map)['children'] as Map)['type'] ==
            'array',
  };

  print('--- round-trip survival ---');
  for (final entry in survived.entries) {
    print('${entry.key}: ${entry.value ? 'OK' : 'FAIL'}');
  }

  final allSurvived = survived.values.every((v) => v);
  print('--- result ---');
  print(allSurvived ? 'PASS: extension keywords preserved' : 'FAIL');
}
