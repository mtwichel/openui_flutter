# openui_mcp

[![Pub](https://img.shields.io/pub/v/openui_mcp.svg)](https://pub.dev/packages/openui_mcp)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

MCP tools for OpenUI Flutter.

Wraps `mcp_dart`'s `McpClient` as `Tool` specs plus `ToolHandler`
callbacks compatible with `RenderLibrary.toolHandlers`. Each `McpTool`
maps MCP input/output JSON schemas to `openui_core` `Schema` objects and
forwards `callTool` to the client.

## Status

v0.1, Phase 4 complete.

## Install

```yaml
dependencies:
  openui_mcp: ^0.0.1-dev.2
  openui: ^0.0.1-dev.2
  openui_components: ^0.0.1-dev.2
```

## Quick start

```dart
import 'package:mcp_dart/mcp_dart.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_mcp/openui_mcp.dart';

final client = McpClient(...);
await client.connect();

final mcpTools = await client.asOpenUITools();

final library = standardLibrary().extend(
  tools: mcpTools,
  toolHandlers: {
    for (final t in mcpTools) t.name: t.callTool,
  },
);

Renderer(
  response: response,
  library: library,
);
```

`@Query` assignments in OpenUI Lang call `library.toolHandler(toolName)`; results
are written to the reactive store under the query statement id. Use
`library.prompt()` so the model sees the MCP tool names and input shapes.

## License

MIT — see [LICENSE](LICENSE).
