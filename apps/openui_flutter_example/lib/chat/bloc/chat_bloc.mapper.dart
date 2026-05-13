// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'chat_bloc.dart';

class ChatStatusMapper extends EnumMapper<ChatStatus> {
  ChatStatusMapper._();

  static ChatStatusMapper? _instance;
  static ChatStatusMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ChatStatusMapper._());
    }
    return _instance!;
  }

  static ChatStatus fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ChatStatus decode(dynamic value) {
    switch (value) {
      case r'idle':
        return ChatStatus.idle;
      case r'streaming':
        return ChatStatus.streaming;
      case r'error':
        return ChatStatus.error;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ChatStatus self) {
    switch (self) {
      case ChatStatus.idle:
        return r'idle';
      case ChatStatus.streaming:
        return r'streaming';
      case ChatStatus.error:
        return r'error';
    }
  }
}

extension ChatStatusMapperExtension on ChatStatus {
  String toValue() {
    ChatStatusMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ChatStatus>(this) as String;
  }
}

class LlmDebugPanelMapper extends EnumMapper<LlmDebugPanel> {
  LlmDebugPanelMapper._();

  static LlmDebugPanelMapper? _instance;
  static LlmDebugPanelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlmDebugPanelMapper._());
    }
    return _instance!;
  }

  static LlmDebugPanel fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LlmDebugPanel decode(dynamic value) {
    switch (value) {
      case r'generatedOpenUiCode':
        return LlmDebugPanel.generatedOpenUiCode;
      case r'storeInspector':
        return LlmDebugPanel.storeInspector;
      case r'actionLog':
        return LlmDebugPanel.actionLog;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LlmDebugPanel self) {
    switch (self) {
      case LlmDebugPanel.generatedOpenUiCode:
        return r'generatedOpenUiCode';
      case LlmDebugPanel.storeInspector:
        return r'storeInspector';
      case LlmDebugPanel.actionLog:
        return r'actionLog';
    }
  }
}

extension LlmDebugPanelMapperExtension on LlmDebugPanel {
  String toValue() {
    LlmDebugPanelMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LlmDebugPanel>(this) as String;
  }
}

class UiMessageRoleMapper extends EnumMapper<UiMessageRole> {
  UiMessageRoleMapper._();

  static UiMessageRoleMapper? _instance;
  static UiMessageRoleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UiMessageRoleMapper._());
    }
    return _instance!;
  }

  static UiMessageRole fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  UiMessageRole decode(dynamic value) {
    switch (value) {
      case r'user':
        return UiMessageRole.user;
      case r'assistant':
        return UiMessageRole.assistant;
      case r'thinking':
        return UiMessageRole.thinking;
      case r'tool':
        return UiMessageRole.tool;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(UiMessageRole self) {
    switch (self) {
      case UiMessageRole.user:
        return r'user';
      case UiMessageRole.assistant:
        return r'assistant';
      case UiMessageRole.thinking:
        return r'thinking';
      case UiMessageRole.tool:
        return r'tool';
    }
  }
}

extension UiMessageRoleMapperExtension on UiMessageRole {
  String toValue() {
    UiMessageRoleMapper.ensureInitialized();
    return MapperContainer.globals.toValue<UiMessageRole>(this) as String;
  }
}

class MessageSubmittedMapper extends ClassMapperBase<MessageSubmitted> {
  MessageSubmittedMapper._();

  static MessageSubmittedMapper? _instance;
  static MessageSubmittedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MessageSubmittedMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'MessageSubmitted';

  static String _$text(MessageSubmitted v) => v.text;
  static const Field<MessageSubmitted, String> _f$text = Field('text', _$text);

  @override
  final MappableFields<MessageSubmitted> fields = const {#text: _f$text};

  static MessageSubmitted _instantiate(DecodingData data) {
    return MessageSubmitted(data.dec(_f$text));
  }

  @override
  final Function instantiate = _instantiate;

  static MessageSubmitted fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MessageSubmitted>(map);
  }

  static MessageSubmitted fromJson(String json) {
    return ensureInitialized().decodeJson<MessageSubmitted>(json);
  }
}

mixin MessageSubmittedMappable {
  String toJson() {
    return MessageSubmittedMapper.ensureInitialized()
        .encodeJson<MessageSubmitted>(this as MessageSubmitted);
  }

  Map<String, dynamic> toMap() {
    return MessageSubmittedMapper.ensureInitialized()
        .encodeMap<MessageSubmitted>(this as MessageSubmitted);
  }

  MessageSubmittedCopyWith<MessageSubmitted, MessageSubmitted, MessageSubmitted>
  get copyWith =>
      _MessageSubmittedCopyWithImpl<MessageSubmitted, MessageSubmitted>(
        this as MessageSubmitted,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MessageSubmittedMapper.ensureInitialized().stringifyValue(
      this as MessageSubmitted,
    );
  }

  @override
  bool operator ==(Object other) {
    return MessageSubmittedMapper.ensureInitialized().equalsValue(
      this as MessageSubmitted,
      other,
    );
  }

  @override
  int get hashCode {
    return MessageSubmittedMapper.ensureInitialized().hashValue(
      this as MessageSubmitted,
    );
  }
}

extension MessageSubmittedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MessageSubmitted, $Out> {
  MessageSubmittedCopyWith<$R, MessageSubmitted, $Out>
  get $asMessageSubmitted =>
      $base.as((v, t, t2) => _MessageSubmittedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MessageSubmittedCopyWith<$R, $In extends MessageSubmitted, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? text});
  MessageSubmittedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _MessageSubmittedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MessageSubmitted, $Out>
    implements MessageSubmittedCopyWith<$R, MessageSubmitted, $Out> {
  _MessageSubmittedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MessageSubmitted> $mapper =
      MessageSubmittedMapper.ensureInitialized();
  @override
  $R call({String? text}) =>
      $apply(FieldCopyWithData({if (text != null) #text: text}));
  @override
  MessageSubmitted $make(CopyWithData data) =>
      MessageSubmitted(data.get(#text, or: $value.text));

  @override
  MessageSubmittedCopyWith<$R2, MessageSubmitted, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MessageSubmittedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ChatClearedMapper extends ClassMapperBase<ChatCleared> {
  ChatClearedMapper._();

  static ChatClearedMapper? _instance;
  static ChatClearedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ChatClearedMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ChatCleared';

  @override
  final MappableFields<ChatCleared> fields = const {};

  static ChatCleared _instantiate(DecodingData data) {
    return ChatCleared();
  }

  @override
  final Function instantiate = _instantiate;

  static ChatCleared fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ChatCleared>(map);
  }

  static ChatCleared fromJson(String json) {
    return ensureInitialized().decodeJson<ChatCleared>(json);
  }
}

mixin ChatClearedMappable {
  String toJson() {
    return ChatClearedMapper.ensureInitialized().encodeJson<ChatCleared>(
      this as ChatCleared,
    );
  }

  Map<String, dynamic> toMap() {
    return ChatClearedMapper.ensureInitialized().encodeMap<ChatCleared>(
      this as ChatCleared,
    );
  }

  ChatClearedCopyWith<ChatCleared, ChatCleared, ChatCleared> get copyWith =>
      _ChatClearedCopyWithImpl<ChatCleared, ChatCleared>(
        this as ChatCleared,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ChatClearedMapper.ensureInitialized().stringifyValue(
      this as ChatCleared,
    );
  }

  @override
  bool operator ==(Object other) {
    return ChatClearedMapper.ensureInitialized().equalsValue(
      this as ChatCleared,
      other,
    );
  }

  @override
  int get hashCode {
    return ChatClearedMapper.ensureInitialized().hashValue(this as ChatCleared);
  }
}

extension ChatClearedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ChatCleared, $Out> {
  ChatClearedCopyWith<$R, ChatCleared, $Out> get $asChatCleared =>
      $base.as((v, t, t2) => _ChatClearedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ChatClearedCopyWith<$R, $In extends ChatCleared, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  ChatClearedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ChatClearedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ChatCleared, $Out>
    implements ChatClearedCopyWith<$R, ChatCleared, $Out> {
  _ChatClearedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ChatCleared> $mapper =
      ChatClearedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  ChatCleared $make(CopyWithData data) => ChatCleared();

  @override
  ChatClearedCopyWith<$R2, ChatCleared, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ChatClearedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class RenderStoreSnapshotUpdatedMapper
    extends ClassMapperBase<RenderStoreSnapshotUpdated> {
  RenderStoreSnapshotUpdatedMapper._();

  static RenderStoreSnapshotUpdatedMapper? _instance;
  static RenderStoreSnapshotUpdatedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = RenderStoreSnapshotUpdatedMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'RenderStoreSnapshotUpdated';

  static Map<String, Object?> _$snapshot(RenderStoreSnapshotUpdated v) =>
      v.snapshot;
  static const Field<RenderStoreSnapshotUpdated, Map<String, Object?>>
  _f$snapshot = Field('snapshot', _$snapshot);

  @override
  final MappableFields<RenderStoreSnapshotUpdated> fields = const {
    #snapshot: _f$snapshot,
  };

  static RenderStoreSnapshotUpdated _instantiate(DecodingData data) {
    return RenderStoreSnapshotUpdated(data.dec(_f$snapshot));
  }

  @override
  final Function instantiate = _instantiate;

  static RenderStoreSnapshotUpdated fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RenderStoreSnapshotUpdated>(map);
  }

  static RenderStoreSnapshotUpdated fromJson(String json) {
    return ensureInitialized().decodeJson<RenderStoreSnapshotUpdated>(json);
  }
}

mixin RenderStoreSnapshotUpdatedMappable {
  String toJson() {
    return RenderStoreSnapshotUpdatedMapper.ensureInitialized()
        .encodeJson<RenderStoreSnapshotUpdated>(
          this as RenderStoreSnapshotUpdated,
        );
  }

  Map<String, dynamic> toMap() {
    return RenderStoreSnapshotUpdatedMapper.ensureInitialized()
        .encodeMap<RenderStoreSnapshotUpdated>(
          this as RenderStoreSnapshotUpdated,
        );
  }

  RenderStoreSnapshotUpdatedCopyWith<
    RenderStoreSnapshotUpdated,
    RenderStoreSnapshotUpdated,
    RenderStoreSnapshotUpdated
  >
  get copyWith =>
      _RenderStoreSnapshotUpdatedCopyWithImpl<
        RenderStoreSnapshotUpdated,
        RenderStoreSnapshotUpdated
      >(this as RenderStoreSnapshotUpdated, $identity, $identity);
  @override
  String toString() {
    return RenderStoreSnapshotUpdatedMapper.ensureInitialized().stringifyValue(
      this as RenderStoreSnapshotUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    return RenderStoreSnapshotUpdatedMapper.ensureInitialized().equalsValue(
      this as RenderStoreSnapshotUpdated,
      other,
    );
  }

  @override
  int get hashCode {
    return RenderStoreSnapshotUpdatedMapper.ensureInitialized().hashValue(
      this as RenderStoreSnapshotUpdated,
    );
  }
}

extension RenderStoreSnapshotUpdatedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RenderStoreSnapshotUpdated, $Out> {
  RenderStoreSnapshotUpdatedCopyWith<$R, RenderStoreSnapshotUpdated, $Out>
  get $asRenderStoreSnapshotUpdated => $base.as(
    (v, t, t2) => _RenderStoreSnapshotUpdatedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class RenderStoreSnapshotUpdatedCopyWith<
  $R,
  $In extends RenderStoreSnapshotUpdated,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get snapshot;
  $R call({Map<String, Object?>? snapshot});
  RenderStoreSnapshotUpdatedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _RenderStoreSnapshotUpdatedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RenderStoreSnapshotUpdated, $Out>
    implements
        RenderStoreSnapshotUpdatedCopyWith<
          $R,
          RenderStoreSnapshotUpdated,
          $Out
        > {
  _RenderStoreSnapshotUpdatedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RenderStoreSnapshotUpdated> $mapper =
      RenderStoreSnapshotUpdatedMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get snapshot => MapCopyWith(
    $value.snapshot,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(snapshot: v),
  );
  @override
  $R call({Map<String, Object?>? snapshot}) =>
      $apply(FieldCopyWithData({if (snapshot != null) #snapshot: snapshot}));
  @override
  RenderStoreSnapshotUpdated $make(CopyWithData data) =>
      RenderStoreSnapshotUpdated(data.get(#snapshot, or: $value.snapshot));

  @override
  RenderStoreSnapshotUpdatedCopyWith<$R2, RenderStoreSnapshotUpdated, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _RenderStoreSnapshotUpdatedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class OpenUiHostActionLoggedMapper
    extends ClassMapperBase<OpenUiHostActionLogged> {
  OpenUiHostActionLoggedMapper._();

  static OpenUiHostActionLoggedMapper? _instance;
  static OpenUiHostActionLoggedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = OpenUiHostActionLoggedMapper._());
      OpenUiActionLogEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'OpenUiHostActionLogged';

  static OpenUiActionLogEntry _$entry(OpenUiHostActionLogged v) => v.entry;
  static const Field<OpenUiHostActionLogged, OpenUiActionLogEntry> _f$entry =
      Field('entry', _$entry);

  @override
  final MappableFields<OpenUiHostActionLogged> fields = const {
    #entry: _f$entry,
  };

  static OpenUiHostActionLogged _instantiate(DecodingData data) {
    return OpenUiHostActionLogged(data.dec(_f$entry));
  }

  @override
  final Function instantiate = _instantiate;

  static OpenUiHostActionLogged fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<OpenUiHostActionLogged>(map);
  }

  static OpenUiHostActionLogged fromJson(String json) {
    return ensureInitialized().decodeJson<OpenUiHostActionLogged>(json);
  }
}

mixin OpenUiHostActionLoggedMappable {
  String toJson() {
    return OpenUiHostActionLoggedMapper.ensureInitialized()
        .encodeJson<OpenUiHostActionLogged>(this as OpenUiHostActionLogged);
  }

  Map<String, dynamic> toMap() {
    return OpenUiHostActionLoggedMapper.ensureInitialized()
        .encodeMap<OpenUiHostActionLogged>(this as OpenUiHostActionLogged);
  }

  OpenUiHostActionLoggedCopyWith<
    OpenUiHostActionLogged,
    OpenUiHostActionLogged,
    OpenUiHostActionLogged
  >
  get copyWith =>
      _OpenUiHostActionLoggedCopyWithImpl<
        OpenUiHostActionLogged,
        OpenUiHostActionLogged
      >(this as OpenUiHostActionLogged, $identity, $identity);
  @override
  String toString() {
    return OpenUiHostActionLoggedMapper.ensureInitialized().stringifyValue(
      this as OpenUiHostActionLogged,
    );
  }

  @override
  bool operator ==(Object other) {
    return OpenUiHostActionLoggedMapper.ensureInitialized().equalsValue(
      this as OpenUiHostActionLogged,
      other,
    );
  }

  @override
  int get hashCode {
    return OpenUiHostActionLoggedMapper.ensureInitialized().hashValue(
      this as OpenUiHostActionLogged,
    );
  }
}

extension OpenUiHostActionLoggedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, OpenUiHostActionLogged, $Out> {
  OpenUiHostActionLoggedCopyWith<$R, OpenUiHostActionLogged, $Out>
  get $asOpenUiHostActionLogged => $base.as(
    (v, t, t2) => _OpenUiHostActionLoggedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class OpenUiHostActionLoggedCopyWith<
  $R,
  $In extends OpenUiHostActionLogged,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, OpenUiActionLogEntry>
  get entry;
  $R call({OpenUiActionLogEntry? entry});
  OpenUiHostActionLoggedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _OpenUiHostActionLoggedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, OpenUiHostActionLogged, $Out>
    implements
        OpenUiHostActionLoggedCopyWith<$R, OpenUiHostActionLogged, $Out> {
  _OpenUiHostActionLoggedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<OpenUiHostActionLogged> $mapper =
      OpenUiHostActionLoggedMapper.ensureInitialized();
  @override
  OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, OpenUiActionLogEntry>
  get entry => $value.entry.copyWith.$chain((v) => call(entry: v));
  @override
  $R call({OpenUiActionLogEntry? entry}) =>
      $apply(FieldCopyWithData({if (entry != null) #entry: entry}));
  @override
  OpenUiHostActionLogged $make(CopyWithData data) =>
      OpenUiHostActionLogged(data.get(#entry, or: $value.entry));

  @override
  OpenUiHostActionLoggedCopyWith<$R2, OpenUiHostActionLogged, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _OpenUiHostActionLoggedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class OpenUiActionLogEntryMapper extends ClassMapperBase<OpenUiActionLogEntry> {
  OpenUiActionLogEntryMapper._();

  static OpenUiActionLogEntryMapper? _instance;
  static OpenUiActionLogEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = OpenUiActionLogEntryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'OpenUiActionLogEntry';

  static DateTime _$loggedAt(OpenUiActionLogEntry v) => v.loggedAt;
  static const Field<OpenUiActionLogEntry, DateTime> _f$loggedAt = Field(
    'loggedAt',
    _$loggedAt,
  );
  static String _$type(OpenUiActionLogEntry v) => v.type;
  static const Field<OpenUiActionLogEntry, String> _f$type = Field(
    'type',
    _$type,
  );
  static String? _$humanFriendlyMessage(OpenUiActionLogEntry v) =>
      v.humanFriendlyMessage;
  static const Field<OpenUiActionLogEntry, String> _f$humanFriendlyMessage =
      Field('humanFriendlyMessage', _$humanFriendlyMessage, opt: true);
  static Map<String, Object?> _$params(OpenUiActionLogEntry v) => v.params;
  static const Field<OpenUiActionLogEntry, Map<String, Object?>> _f$params =
      Field('params', _$params, opt: true, def: const <String, Object?>{});

  @override
  final MappableFields<OpenUiActionLogEntry> fields = const {
    #loggedAt: _f$loggedAt,
    #type: _f$type,
    #humanFriendlyMessage: _f$humanFriendlyMessage,
    #params: _f$params,
  };

  static OpenUiActionLogEntry _instantiate(DecodingData data) {
    return OpenUiActionLogEntry(
      loggedAt: data.dec(_f$loggedAt),
      type: data.dec(_f$type),
      humanFriendlyMessage: data.dec(_f$humanFriendlyMessage),
      params: data.dec(_f$params),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static OpenUiActionLogEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<OpenUiActionLogEntry>(map);
  }

  static OpenUiActionLogEntry fromJson(String json) {
    return ensureInitialized().decodeJson<OpenUiActionLogEntry>(json);
  }
}

mixin OpenUiActionLogEntryMappable {
  String toJson() {
    return OpenUiActionLogEntryMapper.ensureInitialized()
        .encodeJson<OpenUiActionLogEntry>(this as OpenUiActionLogEntry);
  }

  Map<String, dynamic> toMap() {
    return OpenUiActionLogEntryMapper.ensureInitialized()
        .encodeMap<OpenUiActionLogEntry>(this as OpenUiActionLogEntry);
  }

  OpenUiActionLogEntryCopyWith<
    OpenUiActionLogEntry,
    OpenUiActionLogEntry,
    OpenUiActionLogEntry
  >
  get copyWith =>
      _OpenUiActionLogEntryCopyWithImpl<
        OpenUiActionLogEntry,
        OpenUiActionLogEntry
      >(this as OpenUiActionLogEntry, $identity, $identity);
  @override
  String toString() {
    return OpenUiActionLogEntryMapper.ensureInitialized().stringifyValue(
      this as OpenUiActionLogEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return OpenUiActionLogEntryMapper.ensureInitialized().equalsValue(
      this as OpenUiActionLogEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return OpenUiActionLogEntryMapper.ensureInitialized().hashValue(
      this as OpenUiActionLogEntry,
    );
  }
}

extension OpenUiActionLogEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, OpenUiActionLogEntry, $Out> {
  OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, $Out>
  get $asOpenUiActionLogEntry => $base.as(
    (v, t, t2) => _OpenUiActionLogEntryCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class OpenUiActionLogEntryCopyWith<
  $R,
  $In extends OpenUiActionLogEntry,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get params;
  $R call({
    DateTime? loggedAt,
    String? type,
    String? humanFriendlyMessage,
    Map<String, Object?>? params,
  });
  OpenUiActionLogEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _OpenUiActionLogEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, OpenUiActionLogEntry, $Out>
    implements OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, $Out> {
  _OpenUiActionLogEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<OpenUiActionLogEntry> $mapper =
      OpenUiActionLogEntryMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get params => MapCopyWith(
    $value.params,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(params: v),
  );
  @override
  $R call({
    DateTime? loggedAt,
    String? type,
    Object? humanFriendlyMessage = $none,
    Map<String, Object?>? params,
  }) => $apply(
    FieldCopyWithData({
      if (loggedAt != null) #loggedAt: loggedAt,
      if (type != null) #type: type,
      if (humanFriendlyMessage != $none)
        #humanFriendlyMessage: humanFriendlyMessage,
      if (params != null) #params: params,
    }),
  );
  @override
  OpenUiActionLogEntry $make(CopyWithData data) => OpenUiActionLogEntry(
    loggedAt: data.get(#loggedAt, or: $value.loggedAt),
    type: data.get(#type, or: $value.type),
    humanFriendlyMessage: data.get(
      #humanFriendlyMessage,
      or: $value.humanFriendlyMessage,
    ),
    params: data.get(#params, or: $value.params),
  );

  @override
  OpenUiActionLogEntryCopyWith<$R2, OpenUiActionLogEntry, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _OpenUiActionLogEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class OpenUiActionLogClearedMapper
    extends ClassMapperBase<OpenUiActionLogCleared> {
  OpenUiActionLogClearedMapper._();

  static OpenUiActionLogClearedMapper? _instance;
  static OpenUiActionLogClearedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = OpenUiActionLogClearedMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'OpenUiActionLogCleared';

  @override
  final MappableFields<OpenUiActionLogCleared> fields = const {};

  static OpenUiActionLogCleared _instantiate(DecodingData data) {
    return OpenUiActionLogCleared();
  }

  @override
  final Function instantiate = _instantiate;

  static OpenUiActionLogCleared fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<OpenUiActionLogCleared>(map);
  }

  static OpenUiActionLogCleared fromJson(String json) {
    return ensureInitialized().decodeJson<OpenUiActionLogCleared>(json);
  }
}

mixin OpenUiActionLogClearedMappable {
  String toJson() {
    return OpenUiActionLogClearedMapper.ensureInitialized()
        .encodeJson<OpenUiActionLogCleared>(this as OpenUiActionLogCleared);
  }

  Map<String, dynamic> toMap() {
    return OpenUiActionLogClearedMapper.ensureInitialized()
        .encodeMap<OpenUiActionLogCleared>(this as OpenUiActionLogCleared);
  }

  OpenUiActionLogClearedCopyWith<
    OpenUiActionLogCleared,
    OpenUiActionLogCleared,
    OpenUiActionLogCleared
  >
  get copyWith =>
      _OpenUiActionLogClearedCopyWithImpl<
        OpenUiActionLogCleared,
        OpenUiActionLogCleared
      >(this as OpenUiActionLogCleared, $identity, $identity);
  @override
  String toString() {
    return OpenUiActionLogClearedMapper.ensureInitialized().stringifyValue(
      this as OpenUiActionLogCleared,
    );
  }

  @override
  bool operator ==(Object other) {
    return OpenUiActionLogClearedMapper.ensureInitialized().equalsValue(
      this as OpenUiActionLogCleared,
      other,
    );
  }

  @override
  int get hashCode {
    return OpenUiActionLogClearedMapper.ensureInitialized().hashValue(
      this as OpenUiActionLogCleared,
    );
  }
}

extension OpenUiActionLogClearedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, OpenUiActionLogCleared, $Out> {
  OpenUiActionLogClearedCopyWith<$R, OpenUiActionLogCleared, $Out>
  get $asOpenUiActionLogCleared => $base.as(
    (v, t, t2) => _OpenUiActionLogClearedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class OpenUiActionLogClearedCopyWith<
  $R,
  $In extends OpenUiActionLogCleared,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  OpenUiActionLogClearedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _OpenUiActionLogClearedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, OpenUiActionLogCleared, $Out>
    implements
        OpenUiActionLogClearedCopyWith<$R, OpenUiActionLogCleared, $Out> {
  _OpenUiActionLogClearedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<OpenUiActionLogCleared> $mapper =
      OpenUiActionLogClearedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  OpenUiActionLogCleared $make(CopyWithData data) => OpenUiActionLogCleared();

  @override
  OpenUiActionLogClearedCopyWith<$R2, OpenUiActionLogCleared, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _OpenUiActionLogClearedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GeminiApiKeySubmittedMapper
    extends ClassMapperBase<GeminiApiKeySubmitted> {
  GeminiApiKeySubmittedMapper._();

  static GeminiApiKeySubmittedMapper? _instance;
  static GeminiApiKeySubmittedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GeminiApiKeySubmittedMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'GeminiApiKeySubmitted';

  static String _$apiKey(GeminiApiKeySubmitted v) => v.apiKey;
  static const Field<GeminiApiKeySubmitted, String> _f$apiKey = Field(
    'apiKey',
    _$apiKey,
  );

  @override
  final MappableFields<GeminiApiKeySubmitted> fields = const {
    #apiKey: _f$apiKey,
  };

  static GeminiApiKeySubmitted _instantiate(DecodingData data) {
    return GeminiApiKeySubmitted(data.dec(_f$apiKey));
  }

  @override
  final Function instantiate = _instantiate;

  static GeminiApiKeySubmitted fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GeminiApiKeySubmitted>(map);
  }

  static GeminiApiKeySubmitted fromJson(String json) {
    return ensureInitialized().decodeJson<GeminiApiKeySubmitted>(json);
  }
}

mixin GeminiApiKeySubmittedMappable {
  String toJson() {
    return GeminiApiKeySubmittedMapper.ensureInitialized()
        .encodeJson<GeminiApiKeySubmitted>(this as GeminiApiKeySubmitted);
  }

  Map<String, dynamic> toMap() {
    return GeminiApiKeySubmittedMapper.ensureInitialized()
        .encodeMap<GeminiApiKeySubmitted>(this as GeminiApiKeySubmitted);
  }

  GeminiApiKeySubmittedCopyWith<
    GeminiApiKeySubmitted,
    GeminiApiKeySubmitted,
    GeminiApiKeySubmitted
  >
  get copyWith =>
      _GeminiApiKeySubmittedCopyWithImpl<
        GeminiApiKeySubmitted,
        GeminiApiKeySubmitted
      >(this as GeminiApiKeySubmitted, $identity, $identity);
  @override
  String toString() {
    return GeminiApiKeySubmittedMapper.ensureInitialized().stringifyValue(
      this as GeminiApiKeySubmitted,
    );
  }

  @override
  bool operator ==(Object other) {
    return GeminiApiKeySubmittedMapper.ensureInitialized().equalsValue(
      this as GeminiApiKeySubmitted,
      other,
    );
  }

  @override
  int get hashCode {
    return GeminiApiKeySubmittedMapper.ensureInitialized().hashValue(
      this as GeminiApiKeySubmitted,
    );
  }
}

extension GeminiApiKeySubmittedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GeminiApiKeySubmitted, $Out> {
  GeminiApiKeySubmittedCopyWith<$R, GeminiApiKeySubmitted, $Out>
  get $asGeminiApiKeySubmitted => $base.as(
    (v, t, t2) => _GeminiApiKeySubmittedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class GeminiApiKeySubmittedCopyWith<
  $R,
  $In extends GeminiApiKeySubmitted,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? apiKey});
  GeminiApiKeySubmittedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _GeminiApiKeySubmittedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GeminiApiKeySubmitted, $Out>
    implements GeminiApiKeySubmittedCopyWith<$R, GeminiApiKeySubmitted, $Out> {
  _GeminiApiKeySubmittedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GeminiApiKeySubmitted> $mapper =
      GeminiApiKeySubmittedMapper.ensureInitialized();
  @override
  $R call({String? apiKey}) =>
      $apply(FieldCopyWithData({if (apiKey != null) #apiKey: apiKey}));
  @override
  GeminiApiKeySubmitted $make(CopyWithData data) =>
      GeminiApiKeySubmitted(data.get(#apiKey, or: $value.apiKey));

  @override
  GeminiApiKeySubmittedCopyWith<$R2, GeminiApiKeySubmitted, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _GeminiApiKeySubmittedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class GeminiSessionApiKeyClearedMapper
    extends ClassMapperBase<GeminiSessionApiKeyCleared> {
  GeminiSessionApiKeyClearedMapper._();

  static GeminiSessionApiKeyClearedMapper? _instance;
  static GeminiSessionApiKeyClearedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = GeminiSessionApiKeyClearedMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'GeminiSessionApiKeyCleared';

  @override
  final MappableFields<GeminiSessionApiKeyCleared> fields = const {};

  static GeminiSessionApiKeyCleared _instantiate(DecodingData data) {
    return GeminiSessionApiKeyCleared();
  }

  @override
  final Function instantiate = _instantiate;

  static GeminiSessionApiKeyCleared fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GeminiSessionApiKeyCleared>(map);
  }

  static GeminiSessionApiKeyCleared fromJson(String json) {
    return ensureInitialized().decodeJson<GeminiSessionApiKeyCleared>(json);
  }
}

mixin GeminiSessionApiKeyClearedMappable {
  String toJson() {
    return GeminiSessionApiKeyClearedMapper.ensureInitialized()
        .encodeJson<GeminiSessionApiKeyCleared>(
          this as GeminiSessionApiKeyCleared,
        );
  }

  Map<String, dynamic> toMap() {
    return GeminiSessionApiKeyClearedMapper.ensureInitialized()
        .encodeMap<GeminiSessionApiKeyCleared>(
          this as GeminiSessionApiKeyCleared,
        );
  }

  GeminiSessionApiKeyClearedCopyWith<
    GeminiSessionApiKeyCleared,
    GeminiSessionApiKeyCleared,
    GeminiSessionApiKeyCleared
  >
  get copyWith =>
      _GeminiSessionApiKeyClearedCopyWithImpl<
        GeminiSessionApiKeyCleared,
        GeminiSessionApiKeyCleared
      >(this as GeminiSessionApiKeyCleared, $identity, $identity);
  @override
  String toString() {
    return GeminiSessionApiKeyClearedMapper.ensureInitialized().stringifyValue(
      this as GeminiSessionApiKeyCleared,
    );
  }

  @override
  bool operator ==(Object other) {
    return GeminiSessionApiKeyClearedMapper.ensureInitialized().equalsValue(
      this as GeminiSessionApiKeyCleared,
      other,
    );
  }

  @override
  int get hashCode {
    return GeminiSessionApiKeyClearedMapper.ensureInitialized().hashValue(
      this as GeminiSessionApiKeyCleared,
    );
  }
}

extension GeminiSessionApiKeyClearedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, GeminiSessionApiKeyCleared, $Out> {
  GeminiSessionApiKeyClearedCopyWith<$R, GeminiSessionApiKeyCleared, $Out>
  get $asGeminiSessionApiKeyCleared => $base.as(
    (v, t, t2) => _GeminiSessionApiKeyClearedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class GeminiSessionApiKeyClearedCopyWith<
  $R,
  $In extends GeminiSessionApiKeyCleared,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  GeminiSessionApiKeyClearedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _GeminiSessionApiKeyClearedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, GeminiSessionApiKeyCleared, $Out>
    implements
        GeminiSessionApiKeyClearedCopyWith<
          $R,
          GeminiSessionApiKeyCleared,
          $Out
        > {
  _GeminiSessionApiKeyClearedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<GeminiSessionApiKeyCleared> $mapper =
      GeminiSessionApiKeyClearedMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  GeminiSessionApiKeyCleared $make(CopyWithData data) =>
      GeminiSessionApiKeyCleared();

  @override
  GeminiSessionApiKeyClearedCopyWith<$R2, GeminiSessionApiKeyCleared, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _GeminiSessionApiKeyClearedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LlmDebugPanelExpansionChangedMapper
    extends ClassMapperBase<LlmDebugPanelExpansionChanged> {
  LlmDebugPanelExpansionChangedMapper._();

  static LlmDebugPanelExpansionChangedMapper? _instance;
  static LlmDebugPanelExpansionChangedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = LlmDebugPanelExpansionChangedMapper._(),
      );
      LlmDebugPanelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LlmDebugPanelExpansionChanged';

  static LlmDebugPanel _$panel(LlmDebugPanelExpansionChanged v) => v.panel;
  static const Field<LlmDebugPanelExpansionChanged, LlmDebugPanel> _f$panel =
      Field('panel', _$panel);
  static bool _$expanded(LlmDebugPanelExpansionChanged v) => v.expanded;
  static const Field<LlmDebugPanelExpansionChanged, bool> _f$expanded = Field(
    'expanded',
    _$expanded,
  );

  @override
  final MappableFields<LlmDebugPanelExpansionChanged> fields = const {
    #panel: _f$panel,
    #expanded: _f$expanded,
  };

  static LlmDebugPanelExpansionChanged _instantiate(DecodingData data) {
    return LlmDebugPanelExpansionChanged(
      panel: data.dec(_f$panel),
      expanded: data.dec(_f$expanded),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LlmDebugPanelExpansionChanged fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LlmDebugPanelExpansionChanged>(map);
  }

  static LlmDebugPanelExpansionChanged fromJson(String json) {
    return ensureInitialized().decodeJson<LlmDebugPanelExpansionChanged>(json);
  }
}

mixin LlmDebugPanelExpansionChangedMappable {
  String toJson() {
    return LlmDebugPanelExpansionChangedMapper.ensureInitialized()
        .encodeJson<LlmDebugPanelExpansionChanged>(
          this as LlmDebugPanelExpansionChanged,
        );
  }

  Map<String, dynamic> toMap() {
    return LlmDebugPanelExpansionChangedMapper.ensureInitialized()
        .encodeMap<LlmDebugPanelExpansionChanged>(
          this as LlmDebugPanelExpansionChanged,
        );
  }

  LlmDebugPanelExpansionChangedCopyWith<
    LlmDebugPanelExpansionChanged,
    LlmDebugPanelExpansionChanged,
    LlmDebugPanelExpansionChanged
  >
  get copyWith =>
      _LlmDebugPanelExpansionChangedCopyWithImpl<
        LlmDebugPanelExpansionChanged,
        LlmDebugPanelExpansionChanged
      >(this as LlmDebugPanelExpansionChanged, $identity, $identity);
  @override
  String toString() {
    return LlmDebugPanelExpansionChangedMapper.ensureInitialized()
        .stringifyValue(this as LlmDebugPanelExpansionChanged);
  }

  @override
  bool operator ==(Object other) {
    return LlmDebugPanelExpansionChangedMapper.ensureInitialized().equalsValue(
      this as LlmDebugPanelExpansionChanged,
      other,
    );
  }

  @override
  int get hashCode {
    return LlmDebugPanelExpansionChangedMapper.ensureInitialized().hashValue(
      this as LlmDebugPanelExpansionChanged,
    );
  }
}

extension LlmDebugPanelExpansionChangedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LlmDebugPanelExpansionChanged, $Out> {
  LlmDebugPanelExpansionChangedCopyWith<$R, LlmDebugPanelExpansionChanged, $Out>
  get $asLlmDebugPanelExpansionChanged => $base.as(
    (v, t, t2) =>
        _LlmDebugPanelExpansionChangedCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class LlmDebugPanelExpansionChangedCopyWith<
  $R,
  $In extends LlmDebugPanelExpansionChanged,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({LlmDebugPanel? panel, bool? expanded});
  LlmDebugPanelExpansionChangedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LlmDebugPanelExpansionChangedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LlmDebugPanelExpansionChanged, $Out>
    implements
        LlmDebugPanelExpansionChangedCopyWith<
          $R,
          LlmDebugPanelExpansionChanged,
          $Out
        > {
  _LlmDebugPanelExpansionChangedCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<LlmDebugPanelExpansionChanged> $mapper =
      LlmDebugPanelExpansionChangedMapper.ensureInitialized();
  @override
  $R call({LlmDebugPanel? panel, bool? expanded}) => $apply(
    FieldCopyWithData({
      if (panel != null) #panel: panel,
      if (expanded != null) #expanded: expanded,
    }),
  );
  @override
  LlmDebugPanelExpansionChanged $make(CopyWithData data) =>
      LlmDebugPanelExpansionChanged(
        panel: data.get(#panel, or: $value.panel),
        expanded: data.get(#expanded, or: $value.expanded),
      );

  @override
  LlmDebugPanelExpansionChangedCopyWith<
    $R2,
    LlmDebugPanelExpansionChanged,
    $Out2
  >
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _LlmDebugPanelExpansionChangedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ChatStateMapper extends ClassMapperBase<ChatState> {
  ChatStateMapper._();

  static ChatStateMapper? _instance;
  static ChatStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ChatStateMapper._());
      ChatStatusMapper.ensureInitialized();
      UiMessageMapper.ensureInitialized();
      OpenUiActionLogEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ChatState';

  static ChatStatus _$status(ChatState v) => v.status;
  static const Field<ChatState, ChatStatus> _f$status = Field(
    'status',
    _$status,
    opt: true,
    def: ChatStatus.idle,
  );
  static List<UiMessage> _$messages(ChatState v) => v.messages;
  static const Field<ChatState, List<UiMessage>> _f$messages = Field(
    'messages',
    _$messages,
    opt: true,
    def: const [],
  );
  static String? _$error(ChatState v) => v.error;
  static const Field<ChatState, String> _f$error = Field(
    'error',
    _$error,
    opt: true,
  );
  static Map<String, Object?> _$renderStoreSnapshot(ChatState v) =>
      v.renderStoreSnapshot;
  static const Field<ChatState, Map<String, Object?>> _f$renderStoreSnapshot =
      Field(
        'renderStoreSnapshot',
        _$renderStoreSnapshot,
        opt: true,
        def: const <String, Object?>{},
      );
  static List<OpenUiActionLogEntry> _$actionLog(ChatState v) => v.actionLog;
  static const Field<ChatState, List<OpenUiActionLogEntry>> _f$actionLog =
      Field(
        'actionLog',
        _$actionLog,
        opt: true,
        def: const <OpenUiActionLogEntry>[],
      );
  static bool _$isGeneratedOpenUiCodePanelExpanded(ChatState v) =>
      v.isGeneratedOpenUiCodePanelExpanded;
  static const Field<ChatState, bool> _f$isGeneratedOpenUiCodePanelExpanded =
      Field(
        'isGeneratedOpenUiCodePanelExpanded',
        _$isGeneratedOpenUiCodePanelExpanded,
        opt: true,
        def: false,
      );
  static bool _$isStoreInspectorPanelExpanded(ChatState v) =>
      v.isStoreInspectorPanelExpanded;
  static const Field<ChatState, bool> _f$isStoreInspectorPanelExpanded = Field(
    'isStoreInspectorPanelExpanded',
    _$isStoreInspectorPanelExpanded,
    opt: true,
    def: false,
  );
  static bool _$isActionLogPanelExpanded(ChatState v) =>
      v.isActionLogPanelExpanded;
  static const Field<ChatState, bool> _f$isActionLogPanelExpanded = Field(
    'isActionLogPanelExpanded',
    _$isActionLogPanelExpanded,
    opt: true,
    def: false,
  );
  static bool _$geminiConfigured(ChatState v) => v.geminiConfigured;
  static const Field<ChatState, bool> _f$geminiConfigured = Field(
    'geminiConfigured',
    _$geminiConfigured,
    opt: true,
    def: true,
  );
  static bool _$sessionKeyActive(ChatState v) => v.sessionKeyActive;
  static const Field<ChatState, bool> _f$sessionKeyActive = Field(
    'sessionKeyActive',
    _$sessionKeyActive,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<ChatState> fields = const {
    #status: _f$status,
    #messages: _f$messages,
    #error: _f$error,
    #renderStoreSnapshot: _f$renderStoreSnapshot,
    #actionLog: _f$actionLog,
    #isGeneratedOpenUiCodePanelExpanded: _f$isGeneratedOpenUiCodePanelExpanded,
    #isStoreInspectorPanelExpanded: _f$isStoreInspectorPanelExpanded,
    #isActionLogPanelExpanded: _f$isActionLogPanelExpanded,
    #geminiConfigured: _f$geminiConfigured,
    #sessionKeyActive: _f$sessionKeyActive,
  };

  static ChatState _instantiate(DecodingData data) {
    return ChatState(
      status: data.dec(_f$status),
      messages: data.dec(_f$messages),
      error: data.dec(_f$error),
      renderStoreSnapshot: data.dec(_f$renderStoreSnapshot),
      actionLog: data.dec(_f$actionLog),
      isGeneratedOpenUiCodePanelExpanded: data.dec(
        _f$isGeneratedOpenUiCodePanelExpanded,
      ),
      isStoreInspectorPanelExpanded: data.dec(_f$isStoreInspectorPanelExpanded),
      isActionLogPanelExpanded: data.dec(_f$isActionLogPanelExpanded),
      geminiConfigured: data.dec(_f$geminiConfigured),
      sessionKeyActive: data.dec(_f$sessionKeyActive),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ChatState fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ChatState>(map);
  }

  static ChatState fromJson(String json) {
    return ensureInitialized().decodeJson<ChatState>(json);
  }
}

mixin ChatStateMappable {
  String toJson() {
    return ChatStateMapper.ensureInitialized().encodeJson<ChatState>(
      this as ChatState,
    );
  }

  Map<String, dynamic> toMap() {
    return ChatStateMapper.ensureInitialized().encodeMap<ChatState>(
      this as ChatState,
    );
  }

  ChatStateCopyWith<ChatState, ChatState, ChatState> get copyWith =>
      _ChatStateCopyWithImpl<ChatState, ChatState>(
        this as ChatState,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ChatStateMapper.ensureInitialized().stringifyValue(
      this as ChatState,
    );
  }

  @override
  bool operator ==(Object other) {
    return ChatStateMapper.ensureInitialized().equalsValue(
      this as ChatState,
      other,
    );
  }

  @override
  int get hashCode {
    return ChatStateMapper.ensureInitialized().hashValue(this as ChatState);
  }
}

extension ChatStateValueCopy<$R, $Out> on ObjectCopyWith<$R, ChatState, $Out> {
  ChatStateCopyWith<$R, ChatState, $Out> get $asChatState =>
      $base.as((v, t, t2) => _ChatStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ChatStateCopyWith<$R, $In extends ChatState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, UiMessage, UiMessageCopyWith<$R, UiMessage, UiMessage>>
  get messages;
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get renderStoreSnapshot;
  ListCopyWith<
    $R,
    OpenUiActionLogEntry,
    OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, OpenUiActionLogEntry>
  >
  get actionLog;
  $R call({
    ChatStatus? status,
    List<UiMessage>? messages,
    String? error,
    Map<String, Object?>? renderStoreSnapshot,
    List<OpenUiActionLogEntry>? actionLog,
    bool? isGeneratedOpenUiCodePanelExpanded,
    bool? isStoreInspectorPanelExpanded,
    bool? isActionLogPanelExpanded,
    bool? geminiConfigured,
    bool? sessionKeyActive,
  });
  ChatStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ChatStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ChatState, $Out>
    implements ChatStateCopyWith<$R, ChatState, $Out> {
  _ChatStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ChatState> $mapper =
      ChatStateMapper.ensureInitialized();
  @override
  ListCopyWith<$R, UiMessage, UiMessageCopyWith<$R, UiMessage, UiMessage>>
  get messages => ListCopyWith(
    $value.messages,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(messages: v),
  );
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get renderStoreSnapshot => MapCopyWith(
    $value.renderStoreSnapshot,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(renderStoreSnapshot: v),
  );
  @override
  ListCopyWith<
    $R,
    OpenUiActionLogEntry,
    OpenUiActionLogEntryCopyWith<$R, OpenUiActionLogEntry, OpenUiActionLogEntry>
  >
  get actionLog => ListCopyWith(
    $value.actionLog,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(actionLog: v),
  );
  @override
  $R call({
    ChatStatus? status,
    List<UiMessage>? messages,
    Object? error = $none,
    Map<String, Object?>? renderStoreSnapshot,
    List<OpenUiActionLogEntry>? actionLog,
    bool? isGeneratedOpenUiCodePanelExpanded,
    bool? isStoreInspectorPanelExpanded,
    bool? isActionLogPanelExpanded,
    bool? geminiConfigured,
    bool? sessionKeyActive,
  }) => $apply(
    FieldCopyWithData({
      if (status != null) #status: status,
      if (messages != null) #messages: messages,
      if (error != $none) #error: error,
      if (renderStoreSnapshot != null)
        #renderStoreSnapshot: renderStoreSnapshot,
      if (actionLog != null) #actionLog: actionLog,
      if (isGeneratedOpenUiCodePanelExpanded != null)
        #isGeneratedOpenUiCodePanelExpanded: isGeneratedOpenUiCodePanelExpanded,
      if (isStoreInspectorPanelExpanded != null)
        #isStoreInspectorPanelExpanded: isStoreInspectorPanelExpanded,
      if (isActionLogPanelExpanded != null)
        #isActionLogPanelExpanded: isActionLogPanelExpanded,
      if (geminiConfigured != null) #geminiConfigured: geminiConfigured,
      if (sessionKeyActive != null) #sessionKeyActive: sessionKeyActive,
    }),
  );
  @override
  ChatState $make(CopyWithData data) => ChatState(
    status: data.get(#status, or: $value.status),
    messages: data.get(#messages, or: $value.messages),
    error: data.get(#error, or: $value.error),
    renderStoreSnapshot: data.get(
      #renderStoreSnapshot,
      or: $value.renderStoreSnapshot,
    ),
    actionLog: data.get(#actionLog, or: $value.actionLog),
    isGeneratedOpenUiCodePanelExpanded: data.get(
      #isGeneratedOpenUiCodePanelExpanded,
      or: $value.isGeneratedOpenUiCodePanelExpanded,
    ),
    isStoreInspectorPanelExpanded: data.get(
      #isStoreInspectorPanelExpanded,
      or: $value.isStoreInspectorPanelExpanded,
    ),
    isActionLogPanelExpanded: data.get(
      #isActionLogPanelExpanded,
      or: $value.isActionLogPanelExpanded,
    ),
    geminiConfigured: data.get(#geminiConfigured, or: $value.geminiConfigured),
    sessionKeyActive: data.get(#sessionKeyActive, or: $value.sessionKeyActive),
  );

  @override
  ChatStateCopyWith<$R2, ChatState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ChatStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class UiMessageMapper extends ClassMapperBase<UiMessage> {
  UiMessageMapper._();

  static UiMessageMapper? _instance;
  static UiMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UiMessageMapper._());
      UiMessageRoleMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'UiMessage';

  static String _$id(UiMessage v) => v.id;
  static const Field<UiMessage, String> _f$id = Field('id', _$id);
  static UiMessageRole _$role(UiMessage v) => v.role;
  static const Field<UiMessage, UiMessageRole> _f$role = Field('role', _$role);
  static String _$text(UiMessage v) => v.text;
  static const Field<UiMessage, String> _f$text = Field('text', _$text);

  @override
  final MappableFields<UiMessage> fields = const {
    #id: _f$id,
    #role: _f$role,
    #text: _f$text,
  };

  static UiMessage _instantiate(DecodingData data) {
    return UiMessage(
      id: data.dec(_f$id),
      role: data.dec(_f$role),
      text: data.dec(_f$text),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static UiMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UiMessage>(map);
  }

  static UiMessage fromJson(String json) {
    return ensureInitialized().decodeJson<UiMessage>(json);
  }
}

mixin UiMessageMappable {
  String toJson() {
    return UiMessageMapper.ensureInitialized().encodeJson<UiMessage>(
      this as UiMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return UiMessageMapper.ensureInitialized().encodeMap<UiMessage>(
      this as UiMessage,
    );
  }

  UiMessageCopyWith<UiMessage, UiMessage, UiMessage> get copyWith =>
      _UiMessageCopyWithImpl<UiMessage, UiMessage>(
        this as UiMessage,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return UiMessageMapper.ensureInitialized().stringifyValue(
      this as UiMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    return UiMessageMapper.ensureInitialized().equalsValue(
      this as UiMessage,
      other,
    );
  }

  @override
  int get hashCode {
    return UiMessageMapper.ensureInitialized().hashValue(this as UiMessage);
  }
}

extension UiMessageValueCopy<$R, $Out> on ObjectCopyWith<$R, UiMessage, $Out> {
  UiMessageCopyWith<$R, UiMessage, $Out> get $asUiMessage =>
      $base.as((v, t, t2) => _UiMessageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class UiMessageCopyWith<$R, $In extends UiMessage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, UiMessageRole? role, String? text});
  UiMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _UiMessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UiMessage, $Out>
    implements UiMessageCopyWith<$R, UiMessage, $Out> {
  _UiMessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UiMessage> $mapper =
      UiMessageMapper.ensureInitialized();
  @override
  $R call({String? id, UiMessageRole? role, String? text}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (role != null) #role: role,
      if (text != null) #text: text,
    }),
  );
  @override
  UiMessage $make(CopyWithData data) => UiMessage(
    id: data.get(#id, or: $value.id),
    role: data.get(#role, or: $value.role),
    text: data.get(#text, or: $value.text),
  );

  @override
  UiMessageCopyWith<$R2, UiMessage, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _UiMessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

