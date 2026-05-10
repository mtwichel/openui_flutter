// Internal use of openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';

import 'package:openui_components/src/internal/schemas.dart';
import 'package:openui_core/openui_core.dart';

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
          child: DataTable(
            columns: <DataColumn>[
              for (final col in widget.columns)
                DataColumn(
                  label: Text(
                    (col['label'] ?? col['name'] ?? '').toString(),
                  ),
                ),
            ],
            rows: <DataRow>[
              for (final row in pageRows)
                DataRow(
                  cells: <DataCell>[
                    for (final col in widget.columns)
                      DataCell(Text('${row[col['name']] ?? ''}')),
                  ],
                ),
            ],
          ),
        ),
        if (widget.rows.length > _pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                Text('${_page + 1} / ${lastPage + 1}'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
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

/// Registration for `Table`. Column definitions come from inline
/// `Col(name, label?)` calls in the source.
Component<Widget> tableComponent() {
  return defineComponent<Widget>(
    name: 'Table',
    schema: objectSchema(const <String, Object?>{
      'columns': <String, Object?>{'type': 'array'},
      'rows': <String, Object?>{'type': 'array'},
    }),
    render: (ctx, props, renderNode, id) {
      final cols = (props['columns'] as List<Object?>?) ?? const <Object?>[];
      final rows = (props['rows'] as List<Object?>?) ?? const <Object?>[];
      return TableWidget(
        columns: <Map<String, Object?>>[
          for (final c in cols)
            if (c is Map<String, Object?>) c,
        ],
        rows: <Map<String, Object?>>[
          for (final r in rows)
            if (r is Map<String, Object?>) r,
        ],
      );
    },
  );
}

/// `Col(name, label?)` resolves to a literal `Map<String, Object?>`.
/// The renderer's evaluator handles object args directly; this
/// component just defines the schema so the parser recognises the
/// shape.
Component<Widget> colComponent() {
  return defineComponent<Widget>(
    name: 'Col',
    schema: objectSchema(const <String, Object?>{
      'name': <String, Object?>{'type': 'string'},
      'label': <String, Object?>{'type': 'string'},
    }),
    render: (ctx, props, renderNode, id) {
      // Col is a definitional helper; in practice consumers build the
      // columns list as object literals. If a `Col(...)` actually
      // renders, surface its name as a single-line text fallback.
      return Text('Col(${props['name'] ?? ''})');
    },
  );
}
