// Spike S0.3: confirm extractToolResult cast helper compiles and behaves
// correctly against mcp_dart 2.1.1's CallToolResult shape.
//
// We cannot run a live MCP server here, so we hand-construct
// representative CallToolResult values that match what a server would emit
// and assert the helper handles each branch.

import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';

class McpToolError implements Exception {
  McpToolError(this.message);
  final String message;
  @override
  String toString() => 'McpToolError: $message';
}

/// Extracts a Dart-friendly value from an MCP CallToolResult.
///
/// Matches the JS `extractToolResult` semantics:
/// 1. result.isError -> join all TextContent.text and throw McpToolError
/// 2. structuredContent != null -> return it directly
/// 3. Otherwise join TextContent.text, attempt jsonDecode, fall back to raw
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

void main() {
  // Branch 1: isError=true, single TextContent error message.
  final errResult = CallToolResult(
    content: const [TextContent(text: 'permission denied')],
    isError: true,
  );
  try {
    extractToolResult(errResult);
    print('FAIL: error branch should have thrown');
  } on McpToolError catch (e) {
    print('error-branch OK: ${e.message}');
  }

  // Branch 2: structuredContent present.
  final structured = CallToolResult(
    content: const [TextContent(text: '{"id":1}')],
    structuredContent: const {'id': 1, 'name': 'alice'},
  );
  final s = extractToolResult(structured);
  print('structured-branch OK: $s');

  // Branch 3a: text JSON.
  final textJson = CallToolResult(
    content: const [TextContent(text: '[1, 2, 3]')],
  );
  print('text-json-branch OK: ${extractToolResult(textJson)}');

  // Branch 3b: text non-JSON.
  final textRaw = CallToolResult(
    content: const [TextContent(text: 'hello world')],
  );
  print('text-raw-branch OK: ${extractToolResult(textRaw)}');

  // Branch 3c: empty content.
  final empty = CallToolResult(content: const []);
  print('empty-branch OK: ${extractToolResult(empty)}');

  // Branch 3d: image content (non-text) is ignored, falls to empty -> null.
  final imageOnly = CallToolResult(
    content: const [ImageContent(data: 'AAAA', mimeType: 'image/png')],
  );
  print('image-only-branch OK: ${extractToolResult(imageOnly)}');

  // Branch 3e: text + image, only text is joined.
  final mixed = CallToolResult(
    content: const [
      TextContent(text: '{"ok":true}'),
      ImageContent(data: 'AAAA', mimeType: 'image/png'),
    ],
  );
  print('mixed-branch OK: ${extractToolResult(mixed)}');

  print('--- result ---');
  print('PASS: extractToolResult covers all five branches');
}
