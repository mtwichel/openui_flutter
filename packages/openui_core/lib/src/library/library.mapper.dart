// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'library.dart';

class ComponentMapper extends ClassMapperBase<Component> {
  ComponentMapper._();

  static ComponentMapper? _instance;
  static ComponentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Component';

  static String _$name(Component v) => v.name;
  static const Field<Component, String> _f$name = Field('name', _$name);
  static Schema _$schema(Component v) => v.schema;
  static const Field<Component, Schema> _f$schema = Field('schema', _$schema);
  static String? _$description(Component v) => v.description;
  static const Field<Component, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static bool _$internal(Component v) => v.internal;
  static const Field<Component, bool> _f$internal = Field(
    'internal',
    _$internal,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<Component> fields = const {
    #name: _f$name,
    #schema: _f$schema,
    #description: _f$description,
    #internal: _f$internal,
  };

  static Component _instantiate(DecodingData data) {
    return Component(
      name: data.dec(_f$name),
      schema: data.dec(_f$schema),
      description: data.dec(_f$description),
      internal: data.dec(_f$internal),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Component fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Component>(map);
  }

  static Component fromJson(String json) {
    return ensureInitialized().decodeJson<Component>(json);
  }
}

mixin ComponentMappable {
  String toJson() {
    return ComponentMapper.ensureInitialized().encodeJson<Component>(
      this as Component,
    );
  }

  Map<String, dynamic> toMap() {
    return ComponentMapper.ensureInitialized().encodeMap<Component>(
      this as Component,
    );
  }

  ComponentCopyWith<Component, Component, Component> get copyWith =>
      _ComponentCopyWithImpl<Component, Component>(
        this as Component,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ComponentMapper.ensureInitialized().stringifyValue(
      this as Component,
    );
  }

  @override
  bool operator ==(Object other) {
    return ComponentMapper.ensureInitialized().equalsValue(
      this as Component,
      other,
    );
  }

  @override
  int get hashCode {
    return ComponentMapper.ensureInitialized().hashValue(this as Component);
  }
}

extension ComponentValueCopy<$R, $Out> on ObjectCopyWith<$R, Component, $Out> {
  ComponentCopyWith<$R, Component, $Out> get $asComponent =>
      $base.as((v, t, t2) => _ComponentCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ComponentCopyWith<$R, $In extends Component, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, Schema? schema, String? description, bool? internal});
  ComponentCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ComponentCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Component, $Out>
    implements ComponentCopyWith<$R, Component, $Out> {
  _ComponentCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Component> $mapper =
      ComponentMapper.ensureInitialized();
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
  Component $make(CopyWithData data) => Component(
    name: data.get(#name, or: $value.name),
    schema: data.get(#schema, or: $value.schema),
    description: data.get(#description, or: $value.description),
    internal: data.get(#internal, or: $value.internal),
  );

  @override
  ComponentCopyWith<$R2, Component, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ComponentCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LibraryMapper extends ClassMapperBase<Library> {
  LibraryMapper._();

  static LibraryMapper? _instance;
  static LibraryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LibraryMapper._());
      ComponentMapper.ensureInitialized();
      ToolMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Library';

  static List<Component> _$components(Library v) => v.components;
  static const Field<Library, List<Component>> _f$components = Field(
    'components',
    _$components,
  );
  static List<Tool> _$tools(Library v) => v.tools;
  static const Field<Library, List<Tool>> _f$tools = Field('tools', _$tools);
  static String? _$libraryPrompt(Library v) => v.libraryPrompt;
  static const Field<Library, String> _f$libraryPrompt = Field(
    'libraryPrompt',
    _$libraryPrompt,
    opt: true,
  );

  @override
  final MappableFields<Library> fields = const {
    #components: _f$components,
    #tools: _f$tools,
    #libraryPrompt: _f$libraryPrompt,
  };

  static Library _instantiate(DecodingData data) {
    return Library(
      components: data.dec(_f$components),
      tools: data.dec(_f$tools),
      libraryPrompt: data.dec(_f$libraryPrompt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Library fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Library>(map);
  }

  static Library fromJson(String json) {
    return ensureInitialized().decodeJson<Library>(json);
  }
}

mixin LibraryMappable {
  String toJson() {
    return LibraryMapper.ensureInitialized().encodeJson<Library>(
      this as Library,
    );
  }

  Map<String, dynamic> toMap() {
    return LibraryMapper.ensureInitialized().encodeMap<Library>(
      this as Library,
    );
  }

  LibraryCopyWith<Library, Library, Library> get copyWith =>
      _LibraryCopyWithImpl<Library, Library>(
        this as Library,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LibraryMapper.ensureInitialized().stringifyValue(this as Library);
  }

  @override
  bool operator ==(Object other) {
    return LibraryMapper.ensureInitialized().equalsValue(
      this as Library,
      other,
    );
  }

  @override
  int get hashCode {
    return LibraryMapper.ensureInitialized().hashValue(this as Library);
  }
}

extension LibraryValueCopy<$R, $Out> on ObjectCopyWith<$R, Library, $Out> {
  LibraryCopyWith<$R, Library, $Out> get $asLibrary =>
      $base.as((v, t, t2) => _LibraryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LibraryCopyWith<$R, $In extends Library, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Component, ComponentCopyWith<$R, Component, Component>>
  get components;
  ListCopyWith<$R, Tool, ToolCopyWith<$R, Tool, Tool>> get tools;
  $R call({
    List<Component>? components,
    List<Tool>? tools,
    String? libraryPrompt,
  });
  LibraryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LibraryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Library, $Out>
    implements LibraryCopyWith<$R, Library, $Out> {
  _LibraryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Library> $mapper =
      LibraryMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Component, ComponentCopyWith<$R, Component, Component>>
  get components => ListCopyWith(
    $value.components,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(components: v),
  );
  @override
  ListCopyWith<$R, Tool, ToolCopyWith<$R, Tool, Tool>> get tools =>
      ListCopyWith(
        $value.tools,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(tools: v),
      );
  @override
  $R call({
    List<Component>? components,
    List<Tool>? tools,
    Object? libraryPrompt = $none,
  }) => $apply(
    FieldCopyWithData({
      if (components != null) #components: components,
      if (tools != null) #tools: tools,
      if (libraryPrompt != $none) #libraryPrompt: libraryPrompt,
    }),
  );
  @override
  Library $make(CopyWithData data) => Library(
    components: data.get(#components, or: $value.components),
    tools: data.get(#tools, or: $value.tools),
    libraryPrompt: data.get(#libraryPrompt, or: $value.libraryPrompt),
  );

  @override
  LibraryCopyWith<$R2, Library, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LibraryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

