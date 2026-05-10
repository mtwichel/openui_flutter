import 'package:meta/meta.dart';

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
/// [initialize] seeds bindings without overwriting existing ones:
/// `persisted` (e.g. a hydrated session) is filled first, then any
/// keys still absent are filled from `defaults`. This matches the JS
/// reference's hydration semantics so that an LLM response which
/// re-emits a `$state` declaration does not clobber the user's input.
///
/// Marked `@experimental` per D12.
@experimental
class Store {
  /// Creates an empty [Store].
  Store();

  final Map<String, Object?> _state = <String, Object?>{};
  final Set<void Function()> _listeners = <void Function()>{};
  bool _disposed = false;

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
    _notify();
  }

  /// Subscribes [listener] to change notifications.
  ///
  /// Returns an idempotent unsubscribe callback. A listener added
  /// while a notify pass is in flight does not fire on that pass; a
  /// listener removed during a notify pass is skipped if its turn has
  /// not yet come. Throws [StateError] if the store has been disposed.
  void Function() subscribe(void Function() listener) {
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
  /// user-modified and left untouched. A single notification fires
  /// when at least one binding is added; nothing fires when every key
  /// is already present. Throws [StateError] if the store has been
  /// disposed.
  void initialize(
    Map<String, Object?> defaults, [
    Map<String, Object?>? persisted,
  ]) {
    _checkNotDisposed();
    var changed = false;
    if (persisted != null) {
      for (final entry in persisted.entries) {
        if (_state.containsKey(entry.key)) continue;
        _state[entry.key] = entry.value;
        changed = true;
      }
    }
    for (final entry in defaults.entries) {
      if (_state.containsKey(entry.key)) continue;
      _state[entry.key] = entry.value;
      changed = true;
    }
    if (changed) _notify();
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

  void _notify() {
    for (final listener in _listeners.toList(growable: false)) {
      // A listener removed by an earlier listener in this same pass
      // must not fire; check membership before invoking.
      if (!_listeners.contains(listener)) continue;
      listener();
    }
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('Store has been disposed');
  }
}
