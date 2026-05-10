---
title: "Spike S0.3: mcp_dart CallToolResult envelope shape"
date: 2026-05-10
status: PASS (against package source; live MCP server not run)
---

# Spike S0.3 result

**Goal.** Confirm that `mcp_dart 2.1.1`'s `CallToolResult` shape lets us implement an `extractToolResult` that mirrors the JS reference. Document the exact cast helper.

**Outcome: PASS.** The Dart `CallToolResult` matches the JS shape. `Content` is a sealed Dart class; the cast to `TextContent` is a clean `switch` arm, no dynamic checks. The helper compiles against the public surface and behaves correctly across all five branches.

## Caveat: no live server

The plan's S0.3 description calls for running `mcp_dart` against a local MCP echo server. We did not have a server in the Phase 0 environment. Instead we:

1. Read the `mcp_dart 2.1.1` source (`lib/src/types/content.dart` and `lib/src/types/tools.dart`) to confirm the shape.
2. Built representative `CallToolResult` values in a throwaway script and exercised the helper against them.
3. Verified all five branches output the expected value.

A live-server validation is recommended before v0.1.0 publish; see follow-ups at the end of this note.

## CallToolResult shape (mcp_dart 2.1.1)

```dart
class CallToolResult implements BaseResultData {
  final List<Content> content;
  final bool isError;                       // default false
  final Map<String, dynamic>? structuredContent;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? extra;        // forward-compat passthrough
}
```

`Content` is a `sealed` class with five known subclasses plus `UnknownContent`:

```text
Content
├── TextContent       (text: String)
├── ImageContent      (data: String, mimeType: String)
├── AudioContent      (data: String, mimeType: String)
├── ResourceLink      (uri, name, ...)
├── EmbeddedResource  (resource: ResourceContents)
└── UnknownContent    (type: String, no payload)
```

The seal lets us use exhaustive `switch` without a fallback case warning.

## Cast helper

```dart
import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';

class McpToolError implements Exception {
  McpToolError(this.message);
  final String message;
  @override
  String toString() => 'McpToolError: $message';
}

Object? extractToolResult(CallToolResult result) {
  if (result.isError) {
    final message = _joinText(result.content);
    throw McpToolError(message.isEmpty ? 'tool reported error' : message);
  }
  if (result.structuredContent != null) {
    return result.structuredContent;
  }
  final text = _joinText(result.content);
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

String _joinText(List<Content> content) {
  final buffer = StringBuffer();
  for (final c in content) {
    switch (c) {
      case TextContent t:
        buffer.write(t.text);
      case ImageContent _:
      case AudioContent _:
      case ResourceLink _:
      case EmbeddedResource _:
      case UnknownContent _:
        break;
    }
  }
  return buffer.toString();
}
```

## Recorded output

The throwaway script in `tools/spikes/s0-3-mcp-dart-envelope/` exercised six representative results:

```text
error-branch OK: permission denied
structured-branch OK: {id: 1, name: alice}
text-json-branch OK: [1, 2, 3]
text-raw-branch OK: hello world
empty-branch OK: null
image-only-branch OK: null
mixed-branch OK: {ok: true}
PASS: extractToolResult covers all five branches
```

| Branch | Input | Output |
|---|---|---|
| isError | `[TextContent("permission denied")]`, `isError: true` | throws `McpToolError("permission denied")` |
| structuredContent | `structuredContent: {id:1, name:'alice'}` plus a JSON-mirrored TextContent | returns the map |
| text JSON | `[TextContent("[1,2,3]")]` | returns `[1, 2, 3]` |
| text non-JSON | `[TextContent("hello world")]` | returns `"hello world"` |
| empty | `content: []` | returns `null` |
| image-only | `[ImageContent(...)]` | returns `null` (no text to join) |
| text + image | `[TextContent('{"ok":true}'), ImageContent(...)]` | returns `{ok: true}` (text decoded, image ignored) |

## Decision

Per [Phase 0 decision register](../decisions/2026-05-10-phase0-decisions.md) entry **D11**: ship the helper above as `extractToolResult` in `openui_core` (the JS reference also keeps it in core, not in MCP). `openui_mcp`'s `McpToolProvider` calls into it.

## Follow-ups

- **Live-server validation before v0.1.0 publish.** Spin up either a local MCP echo server (the `mcp_dart` examples include one) or use the official MCP Inspector. Assert behavior on three real tools: one returning `structuredContent`, one returning text JSON, one returning `isError: true`.
- **Tool errors with non-text content.** `_joinText` discards image/audio when isError is true. The JS reference does the same. If a server emits `isError: true` with only image content, the thrown `McpToolError("tool reported error")` is the fallback. Document in `openui_mcp`'s README.
- **`UnknownContent` forward compat.** `mcp_dart` deserializes unknown content types into `UnknownContent`. We treat it as no-op text (skipped in `_joinText`); a future MCP content type that is text-bearing will need a `mcp_dart` upgrade plus a switch-arm addition.
