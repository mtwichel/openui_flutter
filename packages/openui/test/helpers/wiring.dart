// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

import 'test_components.dart';

/// Bundles the triple wiring used by renderer tests.
class TestOpenUiHarness {
  /// Creates a harness with optional [tools].
  TestOpenUiHarness({List<StubToolSpec> tools = const []})
    : library = LibraryDefinition(
        components: testComponentDefinitions,
        tools: [for (final tool in tools) tool.definition],
      ),
      componentRegistry = ComponentRegistry(
        renderers: testComponentRenderers,
      ),
      toolRegistry = ToolRegistry(
        executors: {
          for (final tool in tools) tool.definition.name: tool.execute,
        },
      );

  /// Component and tool definitions for schema lookup.
  final LibraryDefinition library;

  /// Render callbacks for test components.
  final ComponentRegistry componentRegistry;

  /// Tool executors registered for this harness.
  final ToolRegistry toolRegistry;
}

/// Tool definition plus executor for test harnesses.
class StubToolSpec {
  /// Creates a [StubToolSpec].
  StubToolSpec({
    required this.name,
    required this.description,
    required this.execute,
  });

  /// Tool name.
  final String name;

  /// Tool description.
  final String description;

  /// Executor invoked when the tool runs.
  final ToolExecutor execute;

  /// Metadata registered on the library.
  ToolDefinition get definition => ToolDefinition(
    name: name,
    description: description,
  );
}

/// Returns wiring issues between [library] and the registries.
List<String> assertLibraryWiring({
  required LibraryDefinition library,
  required ComponentRegistry componentRegistry,
  required ToolRegistry toolRegistry,
}) {
  final issues = <String>[];
  for (final component in library.components) {
    if (component.internal) continue;
    if (componentRegistry[component.name] == null) {
      issues.add('missing renderer for component "${component.name}"');
    }
  }
  for (final tool in library.tools) {
    if (toolRegistry[tool.name] == null) {
      issues.add('missing executor for tool "${tool.name}"');
    }
  }
  return issues;
}
