# openui_mcp

[![Pub](https://img.shields.io/pub/v/openui_mcp.svg)](https://pub.dev/packages/openui_mcp)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

MCP `ToolProvider` for OpenUI Flutter.

Wraps `mcp_dart`'s `McpClient` and exposes a `ToolProvider` to the
OpenUI Lang runtime. The `extractToolResult` envelope unwrap from
`openui_core` mirrors the JS reference:

1. `result.isError` → throw `McpToolError(messageJoinedFromTextContent)`
2. `result.structuredContent != null` → return it
3. otherwise join `TextContent.text`, attempt `jsonDecode`, fall back
   to the raw string

## Status

v0.1, Phase 4 complete.

## Install

```yaml
dependencies:
  openui_mcp: ^0.1.0
```

## Quick start

```dart
import 'package:mcp_dart/mcp_dart.dart';
import 'package:openui/openui.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_mcp/openui_mcp.dart';

final client = McpClient(...);                  // connect your transport
await client.connect();
final provider = McpToolProvider.from(client);

Renderer(
  response: response,
  library: openuiLibrary(),
  toolProvider: provider,                       // → Query / Mutation calls
);
```

The renderer routes `Query(name: "...", args: {...})` statements
through `provider.callTool`, which forwards to `mcp.McpClient.callTool`
and runs the result through `extractToolResult` before caching the
value under the statement id.

## License

MIT — see [LICENSE](LICENSE).
