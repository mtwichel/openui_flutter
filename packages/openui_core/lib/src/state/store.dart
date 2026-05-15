import 'package:meta/meta.dart';

/// Why [Store] subscribers were notified — see [Store.lastNotifyOrigin].
enum StoreChangeOrigin {
  /// Bindings changed via [Store.initialize] (declarative defaults,
  /// hydration, streaming refresh).
  declarativeSeed,

  /// A binding changed via [Store.set] (field edits, `@Set`, etc.).
  mutation,
}

/// Reactive key/value bag backing OpenUI Lang's `$state` variables.
///
/// `Store` notifies subscribers whenever a [set] actually changes a
/// binding. Shallow equality (`==`) short-circuits no-op writes — the
/// renderer drives a tight notify loop, so a `set($count, $count)`
/// that happens to round-trip the same value must not retrigger
/// every component that depends on `$count`.
///
/// Per Decision D4, sibling renderers do not share state. A `Store`
/// is created with a `Renderer`, lives for that renderer's lifetime,
/// and is disposed in the renderer's `dispose()`. After [dispose] is
/// called, every other method throws [StateError]; [dispose] itself is
/// idempotent.
///
/// [initialize] seeds bindings: `persisted` is filled first for keys
/// still absent, then `defaults`. By default existing keys are left
/// untouched so an LLM re-emission does not clobber user edits; see
/// [Store.initialize] `refreshDeclarativeDefaults` for progressive
/// streaming.
///
/// Marked `@experimental` per D12.
@experimental
class Store {
  /// Creates an empty [Store].
  Store();

  final Map<String, Object?> _state = <String, Object?>{};
  final Set<void Function(StoreChangeOrigin)> _listeners =
      <void Function(StoreChangeOrigin)>{};
  bool _disposed = false;

  StoreChangeOrigin _lastNotifyOrigin = StoreChangeOrigin.declarativeSeed;

  /// The [StoreChangeOrigin] recorded for the last notification pass.
  ///
  /// UI such as text fields uses this to decide whether to reconcile a
  /// cached text field controller with the store: after a declarative
  /// seed the visible field may legitimately diverge until the user
  /// edits again, whereas after a [StoreChangeOrigin.mutation] the
  /// controller should follow [Store] (for example `@Set`).
  StoreChangeOrigin get lastNotifyOrigin => _lastNotifyOrigin;

  /// Returns the current value at [key], or `null` if absent.
  ///
  /// Throws [StateError] if the store has been disposed.
  Object? get(String key) {
    _checkNotDisposed();
    return _state[key];
  }

  /// Stores [value] at [key].
  ///
  /// No-op when the existing binding is `==` to [value]; subscribers
  /// are notified only on a real change. Setting a previously-absent
  /// key — even to `null` — counts as a change because the snapshot
  /// shape changes. Throws [StateError] if the store has been disposed.
  void set(String key, Object? value) {
    _checkNotDisposed();
    if (_state.containsKey(key) && _state[key] == value) return;
    _state[key] = value;
    _notify(StoreChangeOrigin.mutation);
  }

  /// Subscribes [listener] to change notifications.
  ///
  /// Returns an idempotent unsubscribe callback. A listener added
  /// while a notify pass is in flight does not fire on that pass; a
  /// listener removed during a notify pass is skipped if its turn has
  /// not yet come. Throws [StateError] if the store has been disposed.
  void Function() subscribe(void Function(StoreChangeOrigin origin) listener) {
    _checkNotDisposed();
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Returns an unmodifiable snapshot of the current bindings.
  ///
  /// The returned map is decoupled from later writes — modifying the
  /// store after the call does not mutate the snapshot. Throws
  /// [StateError] if the store has been disposed.
  Map<String, Object?> getSnapshot() {
    _checkNotDisposed();
    return Map<String, Object?>.unmodifiable(_state);
  }

  /// Seeds bindings without overwriting existing keys.
  ///
  /// [persisted] is applied first; any keys still absent are then
  /// filled from [defaults]. Existing keys are interpreted as
  /// user-modified and left untouched — unless [refreshDeclarativeDefaults]
  /// is true (progressive streaming): then declarative defaults overwrite
  /// existing values for keys **not** listed in [persisted], so partial
  /// parses can grow arrays/objects until the buffer catches up.
  ///
  /// Keys present in [persisted] never receive updates from [defaults],
  /// even when [refreshDeclarativeDefaults] is true.
  ///
  /// A single notification fires when at least one binding is added or
  /// changed; nothing fires when every key is already present and
  /// unchanged. Throws [StateError] if the store has been disposed.
  void initialize(
    Map<String, Object?> defaults, {
    Map<String, Object?>? persisted,
    bool refreshDeclarativeDefaults = false,
  }) {
    _checkNotDisposed();
    var changed = false;
    final hydratedKeys = persisted?.keys.toSet() ?? const <String>{};
    if (persisted != null) {
      for (final entry in persisted.entries) {
        if (_state.containsKey(entry.key)) continue;
        _state[entry.key] = entry.value;
        changed = true;
      }
    }
    for (final entry in defaults.entries) {
      if (hydratedKeys.contains(entry.key)) {
        continue;
      }
      if (!_state.containsKey(entry.key)) {
        _state[entry.key] = entry.value;
        changed = true;
        continue;
      }
      if (!refreshDeclarativeDefaults) {
        continue;
      }
      if (_state[entry.key] == entry.value) continue;
      _state[entry.key] = entry.value;
      changed = true;
    }
    if (changed) _notify(StoreChangeOrigin.declarativeSeed);
  }

  /// Releases all listeners and marks the store unusable.
  ///
  /// Idempotent. After [dispose], every other method throws
  /// [StateError]; further calls to [dispose] return normally.
  void dispose() {
    if (_disposed) return;
    _listeners.clear();
    _disposed = true;
  }

  void _notify(StoreChangeOrigin origin) {
    _lastNotifyOrigin = origin;
    for (final listener in _listeners.toList(growable: false)) {
      // A listener removed by an earlier listener in this same pass
      // must not fire; check membership before invoking.
      if (!_listeners.contains(listener)) continue;
      listener(origin);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Store has been disposed');
  }
}
