// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'tools.dart';

class ToolMapper extends ClassMapperBase<Tool> {
  ToolMapper._();

  static ToolMapper? _instance;
  static ToolMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Tool';

  static String _$name(Tool v) => v.name;
  static const Field<Tool, String> _f$name = Field('name', _$name);
  static String _$description(Tool v) => v.description;
  static const Field<Tool, String> _f$description = Field(
    'description',
    _$description,
  );
  static Schema? _$input(Tool v) => v.input;
  static const Field<Tool, Schema> _f$input = Field(
    'input',
    _$input,
    opt: true,
  );
  static Schema? _$output(Tool v) => v.output;
  static const Field<Tool, Schema> _f$output = Field(
    'output',
    _$output,
    opt: true,
  );

  @override
  final MappableFields<Tool> fields = const {
    #name: _f$name,
    #description: _f$description,
    #input: _f$input,
    #output: _f$output,
  };

  static Tool _instantiate(DecodingData data) {
    return Tool(
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      input: data.dec(_f$input),
      output: data.dec(_f$output),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Tool fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Tool>(map);
  }

  static Tool fromJson(String json) {
    return ensureInitialized().decodeJson<Tool>(json);
  }
}

mixin ToolMappable {
  String toJson() {
    return ToolMapper.ensureInitialized().encodeJson<Tool>(this as Tool);
  }

  Map<String, dynamic> toMap() {
    return ToolMapper.ensureInitialized().encodeMap<Tool>(this as Tool);
  }

  ToolCopyWith<Tool, Tool, Tool> get copyWith =>
      _ToolCopyWithImpl<Tool, Tool>(this as Tool, $identity, $identity);
  @override
  String toString() {
    return ToolMapper.ensureInitialized().stringifyValue(this as Tool);
  }

  @override
  bool operator ==(Object other) {
    return ToolMapper.ensureInitialized().equalsValue(this as Tool, other);
  }

  @override
  int get hashCode {
    return ToolMapper.ensureInitialized().hashValue(this as Tool);
  }
}

extension ToolValueCopy<$R, $Out> on ObjectCopyWith<$R, Tool, $Out> {
  ToolCopyWith<$R, Tool, $Out> get $asTool =>
      $base.as((v, t, t2) => _ToolCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolCopyWith<$R, $In extends Tool, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? description, Schema? input, Schema? output});
  ToolCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ToolCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Tool, $Out>
    implements ToolCopyWith<$R, Tool, $Out> {
  _ToolCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Tool> $mapper = ToolMapper.ensureInitialized();
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
  Tool $make(CopyWithData data) => Tool(
    name: data.get(#name, or: $value.name),
    description: data.get(#description, or: $value.description),
    input: data.get(#input, or: $value.input),
    output: data.get(#output, or: $value.output),
  );

  @override
  ToolCopyWith<$R2, Tool, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ToolCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolResultMapper extends ClassMapperBase<ToolResult> {
  ToolResultMapper._();

  static ToolResultMapper? _instance;
  static ToolResultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolResultMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ToolResult';

  static Object? _$result(ToolResult v) => v.result;
  static const Field<ToolResult, Object> _f$result = Field('result', _$result);
  static bool _$isError(ToolResult v) => v.isError;
  static const Field<ToolResult, bool> _f$isError = Field(
    'isError',
    _$isError,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<ToolResult> fields = const {
    #result: _f$result,
    #isError: _f$isError,
  };

  static ToolResult _instantiate(DecodingData data) {
    return ToolResult(data.dec(_f$result), isError: data.dec(_f$isError));
  }

  @override
  final Function instantiate = _instantiate;

  static ToolResult fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolResult>(map);
  }

  static ToolResult fromJson(String json) {
    return ensureInitialized().decodeJson<ToolResult>(json);
  }
}

mixin ToolResultMappable {
  String toJson() {
    return ToolResultMapper.ensureInitialized().encodeJson<ToolResult>(
      this as ToolResult,
    );
  }

  Map<String, dynamic> toMap() {
    return ToolResultMapper.ensureInitialized().encodeMap<ToolResult>(
      this as ToolResult,
    );
  }

  ToolResultCopyWith<ToolResult, ToolResult, ToolResult> get copyWith =>
      _ToolResultCopyWithImpl<ToolResult, ToolResult>(
        this as ToolResult,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ToolResultMapper.ensureInitialized().stringifyValue(
      this as ToolResult,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolResultMapper.ensureInitialized().equalsValue(
      this as ToolResult,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolResultMapper.ensureInitialized().hashValue(this as ToolResult);
  }
}

extension ToolResultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolResult, $Out> {
  ToolResultCopyWith<$R, ToolResult, $Out> get $asToolResult =>
      $base.as((v, t, t2) => _ToolResultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolResultCopyWith<$R, $In extends ToolResult, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({Object? result, bool? isError});
  ToolResultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ToolResultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolResult, $Out>
    implements ToolResultCopyWith<$R, ToolResult, $Out> {
  _ToolResultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolResult> $mapper =
      ToolResultMapper.ensureInitialized();
  @override
  $R call({Object? result = $none, bool? isError}) => $apply(
    FieldCopyWithData({
      if (result != $none) #result: result,
      if (isError != null) #isError: isError,
    }),
  );
  @override
  ToolResult $make(CopyWithData data) => ToolResult(
    data.get(#result, or: $value.result),
    isError: data.get(#isError, or: $value.isError),
  );

  @override
  ToolResultCopyWith<$R2, ToolResult, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolResultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

