import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Cache of [TextEditingController]s keyed by `(formName, fieldName)`.
///
/// The cache is owned by the renderer (not by individual `Form` /
/// `Input` widgets) so that focus and cursor position survive the
/// mid-stream rebuilds that follow each parser tick. The JS reference's
/// 250 ms "stability" check is encoded here as a per-field debounce
/// timer.
///
/// Pass lifecycle (called by the renderer's `build`):
///
/// 1. [beginPass] — clear the active-keys set for the new render pass.
/// 2. Components call [controllerFor] during build; each call marks the
///    field active for this pass.
/// 3. [endPass] — schedule disposal for every key not touched this pass.
///    A controller is kept alive for [graceDuration] before disposal,
///    so a field that reappears within the window keeps its existing
///    controller.
///
/// Marked `@experimental` per D12.
@experimental
class FormStateCache {
  /// Creates a [FormStateCache] with an optional [graceDuration]
  /// (default 250 ms — Decision D6).
  FormStateCache({this.graceDuration = const Duration(milliseconds: 250)});

  /// How long a controller for a field that has disappeared from the
  /// active set is kept alive before disposal.
  final Duration graceDuration;

  final Map<_Key, TextEditingController> _controllers =
      <_Key, TextEditingController>{};
  final Map<_Key, Timer> _pending = <_Key, Timer>{};
  Set<_Key>? _activeKeys;

  /// Resets the active-keys set for a new build pass. Idempotent within
  /// a pass; safe to call from the start of `build()`.
  void beginPass() {
    _activeKeys = <_Key>{};
  }

  /// Returns the [TextEditingController] for `(formName, fieldName)`,
  /// allocating one on first use and marking the field active for the
  /// current build pass.
  TextEditingController controllerFor({
    required String formName,
    required String fieldName,
    String initialValue = '',
  }) {
    final key = _Key(formName, fieldName);
    _activeKeys?.add(key);
    final pending = _pending.remove(key);
    pending?.cancel();
    final existing = _controllers[key];
    if (existing != null) return existing;
    final created = TextEditingController(text: initialValue);
    _controllers[key] = created;
    return created;
  }

  /// Schedules disposal for every controller not touched between the
  /// most recent [beginPass] and now. A field that reappears within
  /// [graceDuration] cancels its pending disposal in [controllerFor].
  ///
  /// No-op when [beginPass] was never called (defensive: tests that
  /// reach into the cache without driving a pass don't crash).
  void endPass() {
    final active = _activeKeys;
    if (active == null) return;
    _activeKeys = null;
    for (final key in _controllers.keys.toList(growable: false)) {
      if (active.contains(key)) continue;
      if (_pending.containsKey(key)) continue;
      _pending[key] = Timer(graceDuration, () => _disposeKey(key));
    }
  }

  /// Test seam — schedule disposal for every key not in [activeKeys],
  /// bypassing [beginPass] / [controllerFor]'s implicit tracking.
  @visibleForTesting
  void reap(Set<({String formName, String fieldName})> activeKeys) {
    _activeKeys = <_Key>{
      for (final k in activeKeys) _Key(k.formName, k.fieldName),
    };
    endPass();
  }

  /// Disposes every controller and cancels every pending timer.
  /// Idempotent.
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  /// Number of live controllers. Test seam.
  @visibleForTesting
  int get controllerCount => _controllers.length;

  /// Number of pending disposal timers. Test seam.
  @visibleForTesting
  int get pendingDisposalCount => _pending.length;

  void _disposeKey(_Key key) {
    _pending.remove(key);
    final controller = _controllers.remove(key);
    controller?.dispose();
  }
}

@immutable
class _Key {
  const _Key(this.form, this.field);

  final String form;
  final String field;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Key && other.form == form && other.field == field;

  @override
  int get hashCode => Object.hash(form, field);
}
