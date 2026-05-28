# openui_mcp

[![Pub](https://img.shields.io/pub/v/openui_mcp.svg)](https://pub.dev/packages/openui_mcp)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

MCP adapter for OpenUI Flutter.

Wraps `mcp_dart`'s `McpClient` and produces `OpenUIToolPair` values — each
pair bundles a `ToolDefinition` (metadata for the library and prompt) with
an async executor that forwards to MCP and returns a `ToolResult`.

## Status

v0.1, Phase 4 complete.

## Install

```yaml
dependencies:
  openui_mcp: ^0.1.0
  openui: ^0.1.0
  openui_components: ^0.1.0
```

## Quick start

```dart
import 'package:mcp_dart/mcp_dart.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_mcp/openui_mcp.dart';

final client = McpClient(...);
await client.connect();

final pairs = await client.asOpenUIToolPairs();
final library = standardLibraryDefinition().extend(
  tools: pairs.map((p) => p.definition).toList(),
);
final componentRegistry = standardComponentRegistry();
final toolRegistry = ToolRegistry(executors: {
  for (final p in pairs) p.definition.name: p.execute,
});

Renderer(
  response: response,
  library: library,
  componentRegistry: componentRegistry,
  toolRegistry: toolRegistry,
);
```

The renderer routes `Query(...)` declarations through `ToolRegistry` lookup
after confirming the tool exists on the `LibraryDefinition`.

## License

MIT — see [LICENSE](LICENSE).
