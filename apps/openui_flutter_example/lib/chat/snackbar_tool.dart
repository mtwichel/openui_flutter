import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:openui_core/openui_core.dart';

/// {@template snackbar_tool}
/// A tool that shows a snackbar with the given message.
/// {@endtemplate}
class SnackbarTool implements Tool {
  /// {@macro snackbar_tool}
  SnackbarTool();

  @override
  String get name => 'snackbar';

  @override
  String get description => 'Show a snackbar with the given message';

  @override
  Schema? get input => Schema.object(properties: {'message': Schema.string()});

  @override
  Schema? get output => null;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async {
    debugPrint(args['message']! as String);
    return const ToolResult(null);
  }
}
