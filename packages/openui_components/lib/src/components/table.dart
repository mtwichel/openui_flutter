// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/widgets.dart';
import 'package:openui_components/src/components/callout.dart';
import 'package:openui_core/openui_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// `Table(columns, rows)` — a paginated `DataTable`. Each row is a
/// `Map<String, Object?>` keyed by column name. Page size fixed at
/// 10 for v0.1.
class TableWidget extends StatefulWidget {
  /// Creates a [TableWidget].
  const TableWidget({required this.columns, required this.rows, super.key});

  /// Column definitions. Each entry is `{name: String, label: String?}`.
  final List<Map<String, Object?>> columns;

  /// Row data.
  final List<Map<String, Object?>> rows;

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  static const int _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.columns.isEmpty) {
      return const CalloutWidget(
        text:
            'Table requires at least one column. Pass '
            'columns: [{name: "..."}] or columns: ["..."].',
        variant: 'error',
      );
    }
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.rows.length);
    final pageRows = widget.rows.sublist(start, end);
    final lastPage = (widget.rows.length / _pageSize).ceil() - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ShadTable.list(
            header: [
              for (final col in widget.columns)
                ShadTableCell.header(
                  child: Text(
                    (col['label'] ?? col['name'] ?? '').toString(),
                  ),
                ),
            ],
            children: [
              for (final row in pageRows)
                [
                  for (final col in widget.columns)
                    ShadTableCell(
                      child: Text('${row[col['name']] ?? ''}'),
                    ),
                ],
            ],
          ),
        ),
        if (widget.rows.length > _pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                ShadIconButton.outline(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${_page + 1} / ${lastPage + 1}'),
                ),
                ShadIconButton.outline(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: _page < lastPage
                      ? () => setState(() => _page++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Registration for `Table`. Accepts either `{name, label?}` column
/// objects or bare strings, and either map-keyed or positional rows.
RenderComponent<Widget> tableComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Table',
      description: 'paginated data table',
      schema: Schema.object(
        properties: {
          'columns': Schema.list(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'label': Schema.string(),
              },
            ),
          ),
          'rows': Schema.list(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'value': Schema.any(),
              },
            ),
          ),
        },
        required: ['columns', 'rows'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      final rawCols = (props['columns'] as List<Object?>?) ?? const <Object?>[];
      final rawRows = (props['rows'] as List<Object?>?) ?? const <Object?>[];
      final columns = _normalizeColumns(rawCols);
      return TableWidget(
        columns: columns,
        rows: _normalizeRows(rawRows, columns),
      );
    },
  );
}

List<Map<String, Object?>> _normalizeColumns(List<Object?> raw) {
  final out = <Map<String, Object?>>[];
  for (final c in raw) {
    if (_coerceStringKeyMap(c) case final map?) {
      if (map['name'] is String) out.add(map);
    } else if (c is String) {
      out.add(<String, Object?>{'name': c, 'label': c});
    }
  }
  return out;
}

List<Map<String, Object?>> _normalizeRows(
  List<Object?> raw,
  List<Map<String, Object?>> columns,
) {
  final out = <Map<String, Object?>>[];
  for (final r in raw) {
    if (_coerceStringKeyMap(r) case final map?) {
      out.add(map);
    } else if (r is List<Object?>) {
      final entry = <String, Object?>{};
      final limit = r.length < columns.length ? r.length : columns.length;
      for (var i = 0; i < limit; i++) {
        final name = columns[i]['name'];
        if (name is String) entry[name] = r[i];
      }
      out.add(entry);
    }
  }
  return out;
}

Map<String, Object?>? _coerceStringKeyMap(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key case final String key) key: entry.value,
  };
}

/// `Col(name, label?)` resolves to a literal `Map<String, Object?>`.
/// The renderer's evaluator handles object args directly; this
/// component just defines the schema so the parser recognises the
/// shape.
RenderComponent<Widget> colComponent() {
  return RenderComponent<Widget>(
    spec: Component(
      name: 'Col',
      internal: true,
      schema: Schema.object(
        properties: {
          'name': Schema.string(),
          'label': Schema.string(),
        },
        required: ['name'],
      ),
    ),
    render: (ctx, props, renderNode, id) {
      // Col is a definitional helper; in practice consumers build the
      // columns list as object literals. If a `Col(...)` actually
      // renders, surface its name as a single-line text fallback.
      return Text('Col(${props['name'] ?? ''})');
    },
  );
}
