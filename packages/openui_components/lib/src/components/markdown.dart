// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:openui/openui.dart';
import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

/// Renders Markdown with a streaming-friendly debounce.
///
/// While [isStreaming] is true, re-parses are scheduled on a 16 ms
/// trailing-edge debounce so the parser doesn't run on every chunk —
/// avoids visible jank during fast deltas. When streaming ends, the
/// final parse fires immediately.
class MarkDownRendererWidget extends StatefulWidget {
  /// Creates a [MarkDownRendererWidget].
  const MarkDownRendererWidget({
    required this.source,
    this.isStreaming = false,
    super.key,
  });

  /// Markdown source.
  final String source;

  /// `true` while the containing statement is partial — enables the
  /// debounce.
  final bool isStreaming;

  @override
  State<MarkDownRendererWidget> createState() => _MarkDownRendererState();
}

class _MarkDownRendererState extends State<MarkDownRendererWidget> {
  late String _rendered = widget.source;
  Timer? _debounce;

  @override
  void didUpdateWidget(MarkDownRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source == oldWidget.source &&
        widget.isStreaming == oldWidget.isStreaming) {
      return;
    }
    if (!widget.isStreaming) {
      _debounce?.cancel();
      _debounce = null;
      _rendered = widget.source;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      setState(() => _rendered = widget.source);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: widget.isStreaming,
      child: MarkdownBody(data: _rendered, selectable: true),
    );
  }
}

/// Registration for the `MarkDownRenderer` component.
Component<Widget> markdownComponent() {
  return defineComponent<Widget>(
    name: 'MarkDownRenderer',
    description: 'renders Markdown source text',
    schema: objectSchema(
      const <String, Object?>{
        'source': <String, Object?>{'type': 'string'},
      },
      required: const ['source'],
    ),
    render: (ctx, props, renderNode, id) {
      return Builder(
        builder: (context) {
          final scope = RendererScope.maybeFind(context);
          final streaming =
              scope?.isStreaming == true &&
              (scope?.incomplete.contains(id) ?? false);
          return MarkDownRendererWidget(
            source: props['source']?.toString() ?? '',
            isStreaming: streaming,
          );
        },
      );
    },
  );
}
