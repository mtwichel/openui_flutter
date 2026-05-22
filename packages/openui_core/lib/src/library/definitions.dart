import 'package:collection/collection.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/src/library/schema_mapper.dart';
import 'package:openui_core/src/prompt/prompt.dart';

part 'definitions.mapper.dart';

/// Metadata for one OpenUI component: name, prop schema, and LLM description.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class ComponentDefinition with ComponentDefinitionMappable {
  /// Creates a [ComponentDefinition].
  const ComponentDefinition({
    required this.name,
    required this.schema,
    this.description,
    this.internal = false,
  });

  /// The TYPE-token name used in source (e.g. `'Stack'`, `'Card'`).
  final String name;

  /// Prop schema for coercion, prompt generation, and reactive markers.
  @MappableField(hook: SchemaMappingHook())
  final Schema schema;

  /// Optional LLM-facing description for generated prompts.
  final String? description;

  /// When `true`, excluded from generated prompts.
  final bool internal;
}

/// Metadata for one OpenUI tool: name, description, and input/output schemas.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class ToolDefinition with ToolDefinitionMappable {
  /// Creates a [ToolDefinition].
  const ToolDefinition({
    required this.name,
    required this.description,
    this.input,
    this.output,
  });

  /// Tool name as it appears in source and prompts.
  final String name;

  /// Human-facing description for generated prompts.
  final String description;

  /// JSON schema describing tool input.
  @MappableField(hook: SchemaMappingHook())
  final Schema? input;

  /// JSON schema describing tool output, or `null` when not applicable.
  @MappableField(hook: SchemaMappingHook())
  final Schema? output;
}

/// Registry of component and tool definitions for prompts and schema lookup.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class LibraryDefinition with LibraryDefinitionMappable {
  /// Creates a [LibraryDefinition].
  const LibraryDefinition({
    this.components = const [],
    this.tools = const [],
    this.libraryPrompt,
  });

  /// Deserializes a [LibraryDefinition] from JSON.
  factory LibraryDefinition.fromJson(String json) =>
      LibraryDefinitionMapper.fromJson(json);

  /// Registered component definitions.
  final List<ComponentDefinition> components;

  /// Registered tool definitions.
  final List<ToolDefinition> tools;

  /// Optional guidance appended to generated prompts.
  final String? libraryPrompt;

  /// Returns the component with [name], or `null` when not registered.
  ComponentDefinition? component(String name) =>
      components.reversed.firstWhereOrNull((c) => c.name == name);

  /// Returns the tool with [name], or `null` when not registered.
  ToolDefinition? tool(String name) =>
      tools.reversed.firstWhereOrNull((t) => t.name == name);

  /// Returns a new library with additional definitions layered on top.
  ///
  /// Last-write-wins on duplicate names.
  LibraryDefinition extend({
    List<ComponentDefinition> components = const [],
    List<ToolDefinition> tools = const [],
  }) => LibraryDefinition(
    components: [...this.components, ...components],
    tools: [...this.tools, ...tools],
    libraryPrompt: libraryPrompt,
  );

  /// Generates a system prompt from all non-internal registered components.
  String prompt({
    String? preamble,
    List<String> examples = const [],
    List<String> additionalRules = const [],
  }) {
    final filtered = components.where((c) => !c.internal).toList();
    return generatePrompt(
      LibraryDefinition(
        components: filtered,
        tools: tools,
        libraryPrompt: libraryPrompt,
      ),
      preamble: preamble,
      examples: examples,
      additionalRules: additionalRules,
    );
  }
}
