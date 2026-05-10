---
title: "Spike S0.1: json_schema_builder extension keyword preservation"
date: 2026-05-10
status: PASS
---

# Spike S0.1 result

**Goal.** Confirm that `json_schema_builder ^0.1.3` preserves custom extension keywords (e.g. `x-reactive`, `format: openui-component`) through `toJson()` and a `jsonDecode → Schema.fromMap` round trip. If it strips them, we need a wrapper class.

**Outcome: PASS.** Extension keywords survive verbatim. No wrapper class is needed; a one-line spread merge is enough.

## How `json_schema_builder` works

`Schema` is a [Dart 3 extension type](https://dart.dev/language/extension-types) wrapping `Map<String, Object?>`:

```dart
extension type Schema.fromMap(Map<String, Object?> _value) { ... }
```

The factory constructors (`S.object`, `S.string`, `S.list`, ...) all build a fresh `Map<String, Object?>` and wrap it with `Schema.fromMap`. The exposed `value` getter returns the same backing map. `toJson()` is `JsonEncoder.convert(_value)` — it serializes whatever is in the map, including unknown keys.

## Spike script

The full script is in this PR under `tools/spikes/s0-1-json-schema-builder/` (kept for reproducibility); the core is:

```dart
final base = S.object(
  properties: {
    'children': S.list(items: S.string()),
    'value': S.string(),
  },
  required: ['value'],
);

// Merge custom keywords into a fresh map.
final tagged = Schema.fromMap({
  ...base.value,
  'format': 'openui-component',
  'x-reactive': true,
  'x-component-name': 'Input',
});

final encoded = tagged.toJson();
final decoded = Schema.fromMap(jsonDecode(encoded) as Map<String, Object?>);

// All four checks pass:
// - decoded['format'] == 'openui-component'
// - decoded['x-reactive'] == true
// - decoded['x-component-name'] == 'Input'
// - decoded['properties']['children']['type'] == 'array'
```

## Recorded output

```text
--- encoded ---
{"type":"object","properties":{"children":{"type":"array","items":{"type":"string"}},"value":{"type":"string"}},"required":["value"],"format":"openui-component","x-reactive":true,"x-component-name":"Input"}
--- round-trip survival ---
format: OK
x-reactive: OK
x-component-name: OK
properties.children.type: OK
--- result ---
PASS: extension keywords preserved
```

## Decision

Per [Phase 0 decision register](../decisions/2026-05-10-phase0-decisions.md) entry **D10**:

- Use `json_schema_builder ^0.1.3` directly.
- Wrap custom keywords with a one-line spread:

  ```dart
  Schema reactive(Schema inner) => Schema.fromMap({
        ...inner.value,
        'x-reactive': true,
      });
  ```

- No wrapper class; no shadow type; no fork.
- The fallback (hand-roll a minimal `JSONSchema` covering object/string/integer/number/boolean/array/union/format/x-extensions) remains documented as an escape hatch but is unused.

## Caveats

- The `value` getter and the underlying map are the same object; mutating `schema.value['foo'] = 'bar'` mutates the schema. The spread-merge approach above does not mutate `inner`, so it is safe to call `reactive()` on a schema that is shared between definitions.
- `additionalProperties: false` on an `S.object` does not strip extension keywords from the *schema itself* (only from instances being validated). Verified: `S.object(additionalProperties: false, properties: {...})` followed by spreading `'x-reactive': true` round-trips fine.
- Validation behavior of unknown keywords is unspecified by the JSON Schema 2020-12 spec; `json_schema_builder` ignores them (no error, no validation effect). That is exactly what we want — the runtime, not the schema validator, interprets `x-reactive`.
