# openui_mcp

[![Pub](https://img.shields.io/pub/v/openui_mcp.svg)](https://pub.dev/packages/openui_mcp)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![style: very_good_analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

MCP `ToolProvider` for OpenUI Flutter.

Wraps `mcp_dart`'s `McpClient` and exposes a `ToolProvider` to the OpenUI Lang
runtime. The `extractToolResult` envelope unwrap mirrors the JS reference:

1. `result.isError` → throw `McpToolError(messageJoinedFromTextContent)`
2. `result.structuredContent != null` → return it
3. otherwise join `TextContent.text`, attempt `jsonDecode`, fall back to raw
   string

## Status

v0.1 in development. Phase 0 scaffold only.

## Install

```yaml
dependencies:
  openui_mcp: ^0.1.0
```

## License

MIT — see [LICENSE](LICENSE).
