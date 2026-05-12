import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';

void main() {
  group('FormStateCache', () {
    test('allocates a controller on first lookup and reuses it', () {
      final cache = FormStateCache();
      addTearDown(cache.dispose);

      final a = cache.controllerFor(formName: 'f', fieldName: 'name');
      final b = cache.controllerFor(formName: 'f', fieldName: 'name');

      expect(identical(a, b), isTrue);
      expect(cache.controllerCount, 1);
    });

    test('seeds initialValue only on first allocation', () {
      final cache = FormStateCache();
      addTearDown(cache.dispose);

      final c = cache.controllerFor(
        formName: 'f',
        fieldName: 'name',
        initialValue: 'seed',
      );
      expect(c.text, 'seed');

      // initialValue is ignored once the controller exists — user typing
      // wins on every subsequent lookup.
      c.text = 'typed';
      final again = cache.controllerFor(
        formName: 'f',
        fieldName: 'name',
        initialValue: 'seed',
      );
      expect(again.text, 'typed');
    });

    test('reap schedules disposal after grace window', () {
      fakeAsync((async) {
        final cache = FormStateCache(graceDuration: const Duration(seconds: 1))
          ..controllerFor(formName: 'f', fieldName: 'a')
          ..controllerFor(formName: 'f', fieldName: 'b');
        addTearDown(cache.dispose);

        cache.reap({(formName: 'f', fieldName: 'b')});
        expect(cache.controllerCount, 2, reason: 'still in grace window');
        expect(cache.pendingDisposalCount, 1);

        async.elapse(const Duration(seconds: 1));
        expect(cache.controllerCount, 1);
        expect(cache.pendingDisposalCount, 0);
      });
    });

    test('re-appearing field cancels its pending disposal', () {
      fakeAsync((async) {
        final cache = FormStateCache();
        addTearDown(cache.dispose);
        final original = cache.controllerFor(formName: 'f', fieldName: 'a');
        cache.reap(<({String formName, String fieldName})>{});
        expect(cache.pendingDisposalCount, 1);

        // The field comes back before the grace window expires.
        async.elapse(const Duration(milliseconds: 100));
        final restored = cache.controllerFor(formName: 'f', fieldName: 'a');
        expect(identical(original, restored), isTrue);
        expect(cache.pendingDisposalCount, 0);

        // Advancing past the original window must not dispose the
        // restored controller.
        async.elapse(const Duration(milliseconds: 500));
        expect(cache.controllerCount, 1);
      });
    });

    group('snapshot', () {
      test('returns null when formName is null', () {
        final cache = FormStateCache();
        addTearDown(cache.dispose);
        expect(cache.snapshot(null), isNull);
      });

      test('returns an empty unmodifiable map when the form has no '
          'matching fields', () {
        final cache = FormStateCache();
        addTearDown(cache.dispose);
        final snap = cache.snapshot('missing');
        expect(snap, isNotNull);
        expect(snap, isEmpty);
        expect(() => snap!['x'] = 'v', throwsUnsupportedError);
      });

      test("returns each field's text value keyed by field name", () {
        final cache = FormStateCache()
          ..controllerFor(
            formName: 'f',
            fieldName: 'a',
            initialValue: 'x',
          );
        addTearDown(cache.dispose);
        expect(cache.snapshot('f'), <String, Object?>{'a': 'x'});
      });

      test('reflects post-edit controller text', () {
        final cache = FormStateCache();
        addTearDown(cache.dispose);
        final controller = cache.controllerFor(
          formName: 'f',
          fieldName: 'a',
          initialValue: 'x',
        )..text = 'y';
        expect(cache.snapshot('f'), <String, Object?>{'a': 'y'});
        expect(controller.text, 'y');
      });

      test('forms with the same field name do not bleed', () {
        final cache = FormStateCache()
          ..controllerFor(
            formName: 'a',
            fieldName: 'shared',
            initialValue: '1',
          )
          ..controllerFor(
            formName: 'b',
            fieldName: 'shared',
            initialValue: '2',
          );
        addTearDown(cache.dispose);
        expect(cache.snapshot('a'), <String, Object?>{'shared': '1'});
        expect(cache.snapshot('b'), <String, Object?>{'shared': '2'});
      });

      test('returned map is unmodifiable', () {
        final cache = FormStateCache()
          ..controllerFor(formName: 'f', fieldName: 'a');
        addTearDown(cache.dispose);
        final snap = cache.snapshot('f');
        expect(() => snap!['x'] = 'v', throwsUnsupportedError);
      });
    });

    test('dispose tears everything down', () {
      final cache = FormStateCache()
        ..controllerFor(formName: 'f', fieldName: 'a')
        ..controllerFor(formName: 'f', fieldName: 'b')
        ..reap(<({String formName, String fieldName})>{});
      expect(cache.pendingDisposalCount, 2);

      cache.dispose();

      expect(cache.controllerCount, 0);
      expect(cache.pendingDisposalCount, 0);
    });
  });
}
