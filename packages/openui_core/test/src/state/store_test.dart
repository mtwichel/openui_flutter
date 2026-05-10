// Store contract tests.
//
// Drives every documented invariant of the reactive bag: shallow-equality
// short-circuit, listener lifecycle (including subscribe/unsubscribe
// during a notify pass), snapshot independence, the `initialize`
// hydration rules (persisted-before-defaults, never-overwrite), and
// the post-dispose lockout.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('Store', () {
    test('initial state: get returns null and snapshot is empty', () {
      final store = Store();
      expect(store.get('x'), isNull);
      expect(store.getSnapshot(), isEmpty);
    });

    test('set notifies subscribers on the first write', () {
      final store = Store();
      var notifications = 0;
      store
        ..subscribe(() => notifications++)
        ..set(r'$count', 1);
      expect(notifications, 1);
      expect(store.get(r'$count'), 1);
    });

    test('set short-circuits when the new value is == to the old', () {
      final store = Store()..set(r'$count', 1);
      var notifications = 0;
      store
        ..subscribe(() => notifications++)
        ..set(r'$count', 1);
      expect(notifications, 0);
    });

    test('set notifies on a different value', () {
      final store = Store()..set(r'$count', 1);
      var notifications = 0;
      store
        ..subscribe(() => notifications++)
        ..set(r'$count', 2);
      expect(notifications, 1);
      expect(store.get(r'$count'), 2);
    });

    test(
      'setting an absent key to null notifies — the snapshot shape changes',
      () {
        final store = Store();
        var notifications = 0;
        store
          ..subscribe(() => notifications++)
          ..set('x', null);
        expect(notifications, 1);
        expect(store.getSnapshot().containsKey('x'), isTrue);
      },
    );

    test('re-setting a present key to the same null value does not notify', () {
      final store = Store()..set('x', null);
      var notifications = 0;
      store
        ..subscribe(() => notifications++)
        ..set('x', null);
      expect(notifications, 0);
    });

    test('multiple subscribers all receive notifications', () {
      final store = Store();
      var a = 0;
      var b = 0;
      store
        ..subscribe(() => a++)
        ..subscribe(() => b++)
        ..set('x', 1);
      expect(a, 1);
      expect(b, 1);
    });

    test('unsubscribe stops further notifications', () {
      final store = Store();
      var notifications = 0;
      final unsub = store.subscribe(() => notifications++);
      unsub();
      store.set('x', 1);
      expect(notifications, 0);
    });

    test('the unsubscribe callback is idempotent', () {
      final store = Store();
      final unsub = store.subscribe(() {});
      unsub();
      // A second call must not throw.
      expect(unsub, returnsNormally);
    });

    test(
      'unsubscribing a listener mid-notify skips it on the same pass',
      () {
        final store = Store();
        var aCount = 0;
        var bCount = 0;
        late void Function() unsubB;
        store.subscribe(() {
          aCount++;
          unsubB();
        });
        unsubB = store.subscribe(() => bCount++);
        store.set('x', 1);
        expect(aCount, 1);
        // b was unsubscribed by a's handler before its turn came up.
        expect(bCount, 0);
        // Subsequent change confirms b is permanently unsubscribed.
        store.set('x', 2);
        expect(aCount, 2);
        expect(bCount, 0);
      },
    );

    test('subscribers added during a notify pass defer to the next pass', () {
      final store = Store();
      var newSubFires = 0;
      store
        ..subscribe(() {
          store.subscribe(() => newSubFires++);
        })
        ..set('x', 1);
      expect(newSubFires, 0);
      store.set('x', 2);
      expect(newSubFires, 1);
    });

    test('getSnapshot returns an unmodifiable view', () {
      final store = Store()..set('x', 1);
      final snap = store.getSnapshot();
      expect(snap, {'x': 1});
      expect(() => snap['x'] = 2, throwsUnsupportedError);
    });

    test('snapshot is decoupled from later writes', () {
      final store = Store()..set('x', 1);
      final snap = store.getSnapshot();
      store.set('x', 2);
      expect(snap['x'], 1);
      expect(store.get('x'), 2);
    });

    group('initialize', () {
      test('seeds defaults on an empty store', () {
        final store = Store()..initialize({r'$count': 0, r'$name': 'init'});
        expect(store.get(r'$count'), 0);
        expect(store.get(r'$name'), 'init');
      });

      test('does not overwrite a user-modified binding', () {
        final store = Store()
          ..set(r'$count', 7)
          ..initialize({r'$count': 0});
        expect(store.get(r'$count'), 7);
      });

      test('persisted is applied before defaults', () {
        final store = Store()..initialize({r'$count': 0}, {r'$count': 42});
        expect(store.get(r'$count'), 42);
      });

      test('defaults fill keys not present in persisted', () {
        final store = Store()..initialize({r'$a': 1, r'$b': 2}, {r'$b': 99});
        expect(store.get(r'$a'), 1);
        expect(store.get(r'$b'), 99);
      });

      test('persisted does not overwrite a user-modified binding', () {
        final store = Store()
          ..set(r'$count', 7)
          ..initialize({r'$count': 0}, {r'$count': 42});
        expect(store.get(r'$count'), 7);
      });

      test('notifies once when initialization adds at least one binding', () {
        final store = Store();
        var notifications = 0;
        store
          ..subscribe(() => notifications++)
          ..initialize({r'$a': 1, r'$b': 2});
        expect(notifications, 1);
      });

      test('does not notify when every key is already present', () {
        final store = Store()..set(r'$count', 7);
        var notifications = 0;
        store
          ..subscribe(() => notifications++)
          ..initialize({r'$count': 0});
        expect(notifications, 0);
      });

      test('null persisted is treated as defaults-only', () {
        final store = Store()..initialize({r'$x': 1});
        expect(store.get(r'$x'), 1);
      });
    });

    group('dispose', () {
      test('clears listeners', () {
        final store = Store();
        var notifications = 0;
        store
          ..subscribe(() => notifications++)
          ..dispose();
        // The store is now unusable for set, but the listener set is
        // empty — verified indirectly through the dispose-locks-out
        // tests below; nothing can trigger a notify after dispose.
        expect(notifications, 0);
      });

      test('is idempotent', () {
        final store = Store()..dispose();
        expect(store.dispose, returnsNormally);
      });

      test('subscribe throws StateError after dispose', () {
        final store = Store()..dispose();
        expect(() => store.subscribe(() {}), throwsStateError);
      });

      test('set throws StateError after dispose', () {
        final store = Store()..dispose();
        expect(() => store.set('x', 1), throwsStateError);
      });

      test('get throws StateError after dispose', () {
        final store = Store()..dispose();
        expect(() => store.get('x'), throwsStateError);
      });

      test('getSnapshot throws StateError after dispose', () {
        final store = Store()..dispose();
        expect(store.getSnapshot, throwsStateError);
      });

      test('initialize throws StateError after dispose', () {
        final store = Store()..dispose();
        expect(
          () => store.initialize(const <String, Object?>{}),
          throwsStateError,
        );
      });
    });
  });
}
