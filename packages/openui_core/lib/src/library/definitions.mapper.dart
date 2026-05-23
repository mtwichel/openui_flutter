// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'definitions.dart';

class ComponentDefinitionMapper extends ClassMapperBase<ComponentDefinition> {
  ComponentDefinitionMapper._();

  static ComponentDefinitionMapper? _instance;
  static ComponentDefinitionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentDefinitionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentDefinition';

  static String _$name(ComponentDefinition v) => v.name;
  static const Field<ComponentDefinition, String> _f$name = Field(
    'name',
    _$name,
  );
  static Schema _$schema(ComponentDefinition v) => v.schema;
  static const Field<ComponentDefinition, Schema> _f$schema = Field(
    'schema',
    _$schema,
    hook: SchemaMappingHook(),
  );
  static String? _$description(ComponentDefinition v) => v.description;
  static const Field<ComponentDefinition, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static bool _$internal(ComponentDefinition v) => v.internal;
  static const Field<ComponentDefinition, bool> _f$internal = Field(
    'internal',
    _$internal,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<ComponentDefinition> fields = const {
    #name: _f$name,
    #schema: _f$schema,
    #description: _f$description,
    #internal: _f$internal,
  };

  static ComponentDefinition _instantiate(DecodingData data) {
    return ComponentDefinition(
      name: data.dec(_f$name),
      schema: data.dec(_f$schema),
      description: data.dec(_f$description),
      internal: data.dec(_f$internal),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentDefinition fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentDefinition>(map);
  }

  static ComponentDefinition fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentDefinition>(json);
  }
}

mixin ComponentDefinitionMappable {
  String toJson() {
    return ComponentDefinitionMapper.ensureInitialized()
        .encodeJson<ComponentDefinition>(this as ComponentDefinition);
  }

  Map<String, dynamic> toMap() {
    return ComponentDefinitionMapper.ensureInitialized()
        .encodeMap<ComponentDefinition>(this as ComponentDefinition);
  }

  ComponentDefinitionCopyWith<
    ComponentDefinition,
    ComponentDefinition,
    ComponentDefinition
  >
  get copyWith =>
      _ComponentDefinitionCopyWithImpl<
        ComponentDefinition,
        ComponentDefinition
      >(this as ComponentDefinition, $identity, $identity);
  @override
  String toString() {
    return ComponentDefinitionMapper.ensureInitialized().stringifyValue(
      this as ComponentDefinition,
    );
  }

  @override
  bool operator ==(Object other) {
    return ComponentDefinitionMapper.ensureInitialized().equalsValue(
      this as ComponentDefinition,
      other,
    );
  }

  @override
  int get hashCode {
    return ComponentDefinitionMapper.ensureInitialized().hashValue(
      this as ComponentDefinition,
    );
  }
}

extension ComponentDefinitionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ComponentDefinition, $Out> {
  ComponentDefinitionCopyWith<$R, ComponentDefinition, $Out>
  get $asComponentDefinition => $base.as(
    (v, t, t2) => _ComponentDefinitionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ComponentDefinitionCopyWith<
  $R,
  $In extends ComponentDefinition,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, Schema? schema, String? description, bool? internal});
  ComponentDefinitionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ComponentDefinitionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ComponentDefinition, $Out>
    implements ComponentDefinitionCopyWith<$R, ComponentDefinition, $Out> {
  _ComponentDefinitionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ComponentDefinition> $mapper =
      ComponentDefinitionMapper.ensureInitialized();
  @override
  $R call({
    String? name,
    Schema? schema,
    Object? description = $none,
    bool? internal,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (schema != null) #schema: schema,
      if (description != $none) #description: description,
      if (internal != null) #internal: internal,
    }),
  );
  @override
  ComponentDefinition $make(CopyWithData data) => ComponentDefinition(
    name: data.get(#name, or: $value.name),
    schema: data.get(#schema, or: $value.schema),
    description: data.get(#description, or: $value.description),
    internal: data.get(#internal, or: $value.internal),
  );

  @override
  ComponentDefinitionCopyWith<$R2, ComponentDefinition, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ComponentDefinitionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolDefinitionMapper extends ClassMapperBase<ToolDefinition> {
  ToolDefinitionMapper._();

  static ToolDefinitionMapper? _instance;
  static ToolDefinitionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolDefinitionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ToolDefinition';

  static String _$name(ToolDefinition v) => v.name;
  static const Field<ToolDefinition, String> _f$name = Field('name', _$name);
  static String _$description(ToolDefinition v) => v.description;
  static const Field<ToolDefinition, String> _f$description = Field(
    'description',
    _$description,
  );
  static Schema? _$input(ToolDefinition v) => v.input;
  static const Field<ToolDefinition, Schema> _f$input = Field(
    'input',
    _$input,
    opt: true,
    hook: SchemaMappingHook(),
  );
  static Schema? _$output(ToolDefinition v) => v.output;
  static const Field<ToolDefinition, Schema> _f$output = Field(
    'output',
    _$output,
    opt: true,
    hook: SchemaMappingHook(),
  );

  @override
  final MappableFields<ToolDefinition> fields = const {
    #name: _f$name,
    #description: _f$description,
    #input: _f$input,
    #output: _f$output,
  };

  static ToolDefinition _instantiate(DecodingData data) {
    return ToolDefinition(
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      input: data.dec(_f$input),
      output: data.dec(_f$output),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolDefinition fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolDefinition>(map);
  }

  static ToolDefinition fromJson(String json) {
    return ensureInitialized().decodeJson<ToolDefinition>(json);
  }
}

mixin ToolDefinitionMappable {
  String toJson() {
    return ToolDefinitionMapper.ensureInitialized().encodeJson<ToolDefinition>(
      this as ToolDefinition,
    );
  }

  Map<String, dynamic> toMap() {
    return ToolDefinitionMapper.ensureInitialized().encodeMap<ToolDefinition>(
      this as ToolDefinition,
    );
  }

  ToolDefinitionCopyWith<ToolDefinition, ToolDefinition, ToolDefinition>
  get copyWith => _ToolDefinitionCopyWithImpl<ToolDefinition, ToolDefinition>(
    this as ToolDefinition,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ToolDefinitionMapper.ensureInitialized().stringifyValue(
      this as ToolDefinition,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolDefinitionMapper.ensureInitialized().equalsValue(
      this as ToolDefinition,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolDefinitionMapper.ensureInitialized().hashValue(
      this as ToolDefinition,
    );
  }
}

extension ToolDefinitionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolDefinition, $Out> {
  ToolDefinitionCopyWith<$R, ToolDefinition, $Out> get $asToolDefinition =>
      $base.as((v, t, t2) => _ToolDefinitionCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolDefinitionCopyWith<$R, $In extends ToolDefinition, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? description, Schema? input, Schema? output});
  ToolDefinitionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolDefinitionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolDefinition, $Out>
    implements ToolDefinitionCopyWith<$R, ToolDefinition, $Out> {
  _ToolDefinitionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolDefinition> $mapper =
      ToolDefinitionMapper.ensureInitialized();
  @override
  $R call({
    String? name,
    String? description,
    Object? input = $none,
    Object? output = $none,
  }) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (description != null) #description: description,
      if (input != $none) #input: input,
      if (output != $none) #output: output,
    }),
  );
  @override
  ToolDefinition $make(CopyWithData data) => ToolDefinition(
    name: data.get(#name, or: $value.name),
    description: data.get(#description, or: $value.description),
    input: data.get(#input, or: $value.input),
    output: data.get(#output, or: $value.output),
  );

  @override
  ToolDefinitionCopyWith<$R2, ToolDefinition, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolDefinitionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LibraryDefinitionMapper extends ClassMapperBase<LibraryDefinition> {
  LibraryDefinitionMapper._();

  static LibraryDefinitionMapper? _instance;
  static LibraryDefinitionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LibraryDefinitionMapper._());
      ComponentDefinitionMapper.ensureInitialized();
      ToolDefinitionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LibraryDefinition';

  static List<ComponentDefinition> _$components(LibraryDefinition v) =>
      v.components;
  static const Field<LibraryDefinition, List<ComponentDefinition>>
  _f$components = Field('components', _$components, opt: true, def: const []);
  static List<ToolDefinition> _$tools(LibraryDefinition v) => v.tools;
  static const Field<LibraryDefinition, List<ToolDefinition>> _f$tools = Field(
    'tools',
    _$tools,
    opt: true,
    def: const [],
  );
  static String? _$libraryPrompt(LibraryDefinition v) => v.libraryPrompt;
  static const Field<LibraryDefinition, String> _f$libraryPrompt = Field(
    'libraryPrompt',
    _$libraryPrompt,
    opt: true,
  );

  @override
  final MappableFields<LibraryDefinition> fields = const {
    #components: _f$components,
    #tools: _f$tools,
    #libraryPrompt: _f$libraryPrompt,
  };

  static LibraryDefinition _instantiate(DecodingData data) {
    return LibraryDefinition(
      components: data.dec(_f$components),
      tools: data.dec(_f$tools),
      libraryPrompt: data.dec(_f$libraryPrompt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LibraryDefinition fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LibraryDefinition>(map);
  }

  static LibraryDefinition fromJson(String json) {
    return ensureInitialized().decodeJson<LibraryDefinition>(json);
  }
}

mixin LibraryDefinitionMappable {
  String toJson() {
    return LibraryDefinitionMapper.ensureInitialized()
        .encodeJson<LibraryDefinition>(this as LibraryDefinition);
  }

  Map<String, dynamic> toMap() {
    return LibraryDefinitionMapper.ensureInitialized()
        .encodeMap<LibraryDefinition>(this as LibraryDefinition);
  }

  LibraryDefinitionCopyWith<
    LibraryDefinition,
    LibraryDefinition,
    LibraryDefinition
  >
  get copyWith =>
      _LibraryDefinitionCopyWithImpl<LibraryDefinition, LibraryDefinition>(
        this as LibraryDefinition,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LibraryDefinitionMapper.ensureInitialized().stringifyValue(
      this as LibraryDefinition,
    );
  }

  @override
  bool operator ==(Object other) {
    return LibraryDefinitionMapper.ensureInitialized().equalsValue(
      this as LibraryDefinition,
      other,
    );
  }

  @override
  int get hashCode {
    return LibraryDefinitionMapper.ensureInitialized().hashValue(
      this as LibraryDefinition,
    );
  }
}

extension LibraryDefinitionValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LibraryDefinition, $Out> {
  LibraryDefinitionCopyWith<$R, LibraryDefinition, $Out>
  get $asLibraryDefinition => $base.as(
    (v, t, t2) => _LibraryDefinitionCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class LibraryDefinitionCopyWith<
  $R,
  $In extends LibraryDefinition,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ComponentDefinition,
    ComponentDefinitionCopyWith<$R, ComponentDefinition, ComponentDefinition>
  >
  get components;
  ListCopyWith<
    $R,
    ToolDefinition,
    ToolDefinitionCopyWith<$R, ToolDefinition, ToolDefinition>
  >
  get tools;
  $R call({
    List<ComponentDefinition>? components,
    List<ToolDefinition>? tools,
    String? libraryPrompt,
  });
  LibraryDefinitionCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LibraryDefinitionCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LibraryDefinition, $Out>
    implements LibraryDefinitionCopyWith<$R, LibraryDefinition, $Out> {
  _LibraryDefinitionCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LibraryDefinition> $mapper =
      LibraryDefinitionMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ComponentDefinition,
    ComponentDefinitionCopyWith<$R, ComponentDefinition, ComponentDefinition>
  >
  get components => ListCopyWith(
    $value.components,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(components: v),
  );
  @override
  ListCopyWith<
    $R,
    ToolDefinition,
    ToolDefinitionCopyWith<$R, ToolDefinition, ToolDefinition>
  >
  get tools => ListCopyWith(
    $value.tools,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(tools: v),
  );
  @override
  $R call({
    List<ComponentDefinition>? components,
    List<ToolDefinition>? tools,
    Object? libraryPrompt = $none,
  }) => $apply(
    FieldCopyWithData({
      if (components != null) #components: components,
      if (tools != null) #tools: tools,
      if (libraryPrompt != $none) #libraryPrompt: libraryPrompt,
    }),
  );
  @override
  LibraryDefinition $make(CopyWithData data) => LibraryDefinition(
    components: data.get(#components, or: $value.components),
    tools: data.get(#tools, or: $value.tools),
    libraryPrompt: data.get(#libraryPrompt, or: $value.libraryPrompt),
  );

  @override
  LibraryDefinitionCopyWith<$R2, LibraryDefinition, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LibraryDefinitionCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

