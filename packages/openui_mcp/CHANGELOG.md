## 0.1.0

- **feat**: `McpToolProvider` — implements `openui_core`'s
  `ToolProvider` over `mcp_dart`'s `McpClient`. Wraps every call
  through `extractToolResult`, mirroring the JS reference envelope
  semantics (`isError` → throws `McpToolError`; `structuredContent`
  takes precedence over text; text is JSON-decoded, falling back to
  the raw string).
- **feat**: `McpToolProvider.from(mcp.McpClient)` convenience factory
  for the common case.
- **chore**: package scaffold (Phase 0).
