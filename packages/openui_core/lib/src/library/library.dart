import 'package:collection/collection.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';
import '../tools/tools.dart';

part 'library.mapper.dart';

/// Render callback for one component definition.
///
/// `W` is the rendered widget / element type. `openui_core` is
/// pure-Dart, so it stays generic; `openui` (the Flutter package)
/// will define `typedef ComponentRenderer = ComponentRender<Widget>`
/// over this type.
///
/// Parameters:
///
/// - [context] — the live [EvalContext] for the surrounding render
///   pass (statement map, store, query results, iteration scope).
/// - [props] — already-evaluated prop values (the renderer walks the
///   `CompCall.args` and evaluates each value before invoking the
///   component). Reactive props arrive as a [ReactiveAssign] marker
///   instead of a resolved value; consumers check via
///   [isReactiveAssign] and set up two-way binding.
/// - [renderNode] — recursive child renderer. Components that
///   accept inline child ASTs (e.g. a `Stack`'s children list) call
///   this to render each child against the same context.
/// - [statementId] — id of the statement this element materializes
///   from. Carried so the renderer can attribute render-time errors
///   back to the source line.
///
/// Marked `@experimental` per D12.
@experimental
typedef ComponentRender<W> =
    W Function(
      EvalContext context,
      Map<String, Object?> props,
      W Function(AstNode node, EvalContext context) renderNode,
      String statementId,
    );

/// One component definition: a name (matching the `TYPE` token in
/// source) and a JSON-schema describing its props.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class Component with ComponentMappable {
  /// Creates a [Component] definition.
  const Component({
    required this.name,
    required this.schema,
    this.description,
    this.internal = false,
  });

  /// The TYPE-token name used in source (e.g. `'Stack'`, `'Card'`).
  final String name;

  /// Prop schema. The `properties` map drives prop coercion and the
  /// `x-reactive` keyword marks a prop as
  /// two-way bound.
  final Schema schema;

  /// Optional LLM-facing description, rendered in generated prompts.
  final String? description;

  /// When `true`, this component is excluded from generated prompts.
  /// Use for definitional helpers (e.g. `Col`) or components only
  /// valid as children of another (e.g. `TabItem`).
  final bool internal;
}

/// Registry of [Component]s keyed by name.
///
/// Construct from a list of definitions; lookups go through `[]`.
///
/// Marked `@experimental` per D12.
@experimental
@MappableClass()
class Library with LibraryMappable {
  /// Creates a [Library] from the given component definitions.
  /// Last-write-wins on duplicate names.
  const Library({
    required this.components,
    required this.tools,
    this.libraryPrompt,
  });

  /// The components in the library.
  final List<Component> components;

  /// The tools in the library.
  final List<Tool> tools;

  /// Explains to the LLM how to use the components and tools in the library.
  final String? libraryPrompt;

  /// Returns the component with the given [name], or `null` when no
  /// matching component is registered.
  Component? component(String name) =>
      components.reversed.firstWhereOrNull((c) => c.name == name);

  /// Returns the tool with the given [name], or `null` when no
  /// matching tool is registered.
  Tool? tool(String name) =>
      tools.reversed.firstWhereOrNull((t) => t.name == name);

  /// Returns a new library that adds components on top of
  /// this one's and  tools on top of this one's.
  /// Last-write-wins on duplicate names.
  Library extend({
    List<Component> components = const [],
    List<Tool> tools = const [],
  }) => Library(
    components: [...this.components, ...components],
    tools: [...this.tools, ...tools],
  );

  /// Generates a system prompt from all non-internal registered components.
  String prompt({
    String? preamble,
    List<String> examples = const [],
    List<String> additionalRules = const [],
  }) {
    final filtered = components.where((c) => !c.internal).toList();
    return generatePrompt(
      Library(components: filtered, tools: tools),
      preamble: preamble,
      examples: examples,
      additionalRules: additionalRules,
    );
  }
}

/// Integrates a spec [Library] with its runtime renderers and execution handlers.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class RenderLibrary<W> {
  /// Creates a [RenderLibrary].
  const RenderLibrary({
    required this.spec,
    required this.renderers,
    required this.toolHandlers,
  });

  /// The non-generic spec library containing components and tools metadata.
  final Library spec;

  /// Map of component names to their platform-specific renderers.
  final Map<String, ComponentRender<W>> renderers;

  /// Map of tool names to their execution handlers.
  final Map<String, ToolHandler> toolHandlers;

  /// The spec components.
  List<Component> get components => spec.components;

  /// The spec tools.
  List<Tool> get tools => spec.tools;

  /// Explains to the LLM how to use the components and tools in the library.
  String? get libraryPrompt => spec.libraryPrompt;

  /// Returns the component spec with [name], or `null` if not registered.
  Component? component(String name) => spec.component(name);

  /// Returns the tool spec with [name], or `null` if not registered.
  Tool? tool(String name) => spec.tool(name);

  /// Returns the renderer callback for the component with [name].
  ComponentRender<W>? renderer(String name) => renderers[name];

  /// Returns the tool execution callback for the tool with [name].
  ToolHandler? toolHandler(String name) => toolHandlers[name];

  /// Returns a new RenderLibrary extending this one.
  RenderLibrary<W> extend({
    List<Component> components = const [],
    List<Tool> tools = const [],
    Map<String, ComponentRender<W>> renderers = const {},
    Map<String, ToolHandler> toolHandlers = const {},
  }) {
    return RenderLibrary<W>(
      spec: spec.extend(components: components, tools: tools),
      renderers: {...this.renderers, ...renderers},
      toolHandlers: {...this.toolHandlers, ...toolHandlers},
    );
  }

  /// Generates a system prompt.
  String prompt({
    String? preamble,
    List<String> examples = const [],
    List<String> additionalRules = const [],
  }) {
    return spec.prompt(
      preamble: preamble,
      examples: examples,
      additionalRules: additionalRules,
    );
  }
}

/// A helper container that bundles a [Component] spec and its platform-specific [render] callback.
///
/// Marked `@experimental` per D12.
@experimental
class RenderComponent<W> {
  /// Creates a [RenderComponent] wrapper.
  const RenderComponent({
    required this.spec,
    required this.render,
  });

  /// The component spec.
  final Component spec;

  /// The component's render function.
  final ComponentRender<W> render;

  /// Convenience getter for the component name.
  String get name => spec.name;
}

/// Marker emitted by the props-evaluator when a reactive prop
/// resolves to a `$varName` reference.
///
/// Components consuming the prop check via [isReactiveAssign] and
/// set up two-way binding to the store. The marker carries both the
/// `$`-prefixed [target] (so the component knows what state-var to
/// write on edit) and the [value] currently in the store (so the
/// component can render the right thing right now).
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ReactiveAssign {
  /// Creates a [ReactiveAssign] marker.
  const ReactiveAssign({required this.target, required this.value});

  /// `$`-prefixed state-var the component should write back to.
  final String target;

  /// Current value of [target] in the store, for read-side render.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactiveAssign && other.target == target && other.value == value;

  @override
  int get hashCode => Object.hash(ReactiveAssign, target, value);

  @override
  String toString() => 'ReactiveAssign($target = $value)';
}

/// Returns `true` when [value] is a [ReactiveAssign] marker.
///
/// Marked `@experimental` per D12.
@experimental
bool isReactiveAssign(Object? value) => value is ReactiveAssign;

/// Walks the named args of [call], evaluates each value against
/// [context], and returns a map of prop name to resolved value.
///
/// Special-case: when a prop is marked reactive in [schema]
/// the `x-reactive` extension keyword) AND the arg's
/// value is a bare [StateRef], the entry is a [ReactiveAssign]
/// marker carrying the current store value. The receiving component
/// renders [ReactiveAssign.value] and writes user edits back to
/// [ReactiveAssign.target].
///
/// Positional args (no `name`) are dropped — v0.1 components only
/// accept named props.
///
/// Marked `@experimental` per D12.
@experimental
Map<String, Object?> evaluateElementProps({
  required CompCall call,
  required Schema schema,
  required EvalContext context,
}) {
  final properties = schema.value['properties'];
  final props = <String, Object?>{};
  for (final arg in call.args) {
    final propName = arg.name;
    if (propName == null) continue;

    final value = arg.value;
    if (_isReactiveProp(properties, propName) && value is StateRef) {
      final fullName = '\$${value.name}';
      props[propName] = ReactiveAssign(
        target: fullName,
        value: context.store.get(fullName),
      );
    } else {
      props[propName] = evaluate(value, context);
    }
  }
  return props;
}

bool _isReactiveProp(Object? properties, String propName) {
  if (properties is! Map<String, Object?>) return false;
  final propSchema = properties[propName];
  if (propSchema is! Map<String, Object?>) return false;
  return propSchema['x-reactive'] == true;
}
