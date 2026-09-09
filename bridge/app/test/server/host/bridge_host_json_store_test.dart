import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/runtime_file_api.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_json_store.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeHostJsonStore', () {
    late Directory tempDir;
    late BridgeHostJsonStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bridge-host-json-store-test-');
      store = BridgeHostJsonStore(
        fileApi: RuntimeFileApi(runtimeDirectory: tempDir.path),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('child selection is inert and nested writes stay scoped and atomic', () async {
      final child = store.scope(directoryName: 'profile').scope(directoryName: 'agent');
      expect(tempDir.listSync(), isEmpty);
      await child.write(name: 'settings.json', contents: '{"auth":{}}');
      expect(await child.read(name: 'settings.json'), '{"auth":{}}');
      expect(await store.read(name: 'settings.json'), isNull);
      expect(File(p.join(tempDir.path, 'profile', 'agent', 'settings.json.tmp')).existsSync(), isFalse);
      await expectLater(
        child.update(name: 'settings.json', transform: (_) => throw StateError('interrupted')),
        throwsStateError,
      );
      expect(await child.read(name: 'settings.json'), '{"auth":{}}');
    });

    test('child scopes keep bare name and reserved file restrictions', () async {
      for (final name in [
        '',
        '.',
        '..',
        '../outside',
        r'a\b',
        '/root',
        'C:root',
        'a\u0000b',
        'bridge-startup.lock',
        'state.tmp',
        'state.update-lock',
      ]) {
        expect(() => store.scope(directoryName: name), throwsArgumentError, reason: name);
      }
      final child = store.scope(directoryName: 'profile');
      expect(() => child.read(name: '../settings.json'), throwsArgumentError);
      expect(() => child.scope(directoryName: '..'), throwsArgumentError);
      expect(tempDir.listSync(), isEmpty);
    });

    test('repeated child selection shares the update lock owner', () async {
      final first = store.scope(directoryName: 'profile').scope(directoryName: 'agent');
      final second = store.scope(directoryName: 'profile').scope(directoryName: 'agent');
      final entered = Completer<void>();
      final release = Completer<void>();
      final one = first.update(
        name: 'settings.json',
        transform: (_) async {
          entered.complete();
          await release.future;
          return 'one';
        },
      );
      await entered.future;
      var secondEntered = false;
      final two = second.update(
        name: 'settings.json',
        transform: (current) {
          secondEntered = true;
          expect(current, 'one');
          return 'two';
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondEntered, isFalse);
      release.complete();
      await Future.wait([one, two]);
      expect(await first.read(name: 'settings.json'), 'two');
    });

    test('read returns null for a missing file', () async {
      expect(await store.read(name: 'absent.json'), isNull);
    });

    test('write then read round-trips contents without leaving a temp file', () async {
      await store.write(name: 'state.json', contents: '{"a":1}');

      expect(await store.read(name: 'state.json'), '{"a":1}');
      expect(File(p.join(tempDir.path, 'state.json.tmp')).existsSync(), isFalse);
    });

    test('delete removes the file and ignores missing files', () async {
      await store.write(name: 'state.json', contents: '{}');

      await store.delete(name: 'state.json');
      await store.delete(name: 'state.json');

      expect(File(p.join(tempDir.path, 'state.json')).existsSync(), isFalse);
    });

    test('quarantine moves contents aside', () async {
      await store.write(name: 'state.json', contents: '{ corrupt');

      await store.quarantine(name: 'state.json', quarantinedName: 'state.invalid.json');

      expect(await store.read(name: 'state.json'), isNull);
      expect(await store.read(name: 'state.invalid.json'), '{ corrupt');
    });

    test('quarantine is a no-op when the file does not exist', () async {
      await store.quarantine(name: 'absent.json', quarantinedName: 'absent.invalid.json');

      expect(File(p.join(tempDir.path, 'absent.invalid.json')).existsSync(), isFalse);
    });

    test('update creates the file when absent and returns what was written', () async {
      final written = await store.update(
        name: 'state.json',
        transform: (current) {
          expect(current, isNull);
          return '{"generation":1}';
        },
      );

      expect(written, '{"generation":1}');
      expect(await store.read(name: 'state.json'), '{"generation":1}');
    });

    test('update deletes the file when transform returns null', () async {
      await store.write(name: 'state.json', contents: '{}');

      expect(await store.update(name: 'state.json', transform: (current) => null), isNull);
      expect(File(p.join(tempDir.path, 'state.json')).existsSync(), isFalse);
    });

    test('update serializes concurrent mutators for the same name', () async {
      await store.write(name: 'state.json', contents: '[]');

      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final transformCalls = <String>[];

      final first = store.update(
        name: 'state.json',
        transform: (current) async {
          transformCalls.add('first:$current');
          firstEntered.complete();
          await releaseFirst.future;
          return '["first"]';
        },
      );
      await firstEntered.future;

      final second = store.update(
        name: 'state.json',
        transform: (current) {
          transformCalls.add('second:$current');
          return '["first","second"]';
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transformCalls, equals(<String>['first:[]']));

      releaseFirst.complete();
      expect(await first, '["first"]');
      expect(await second, '["first","second"]');
      expect(transformCalls, equals(<String>['first:[]', 'second:["first"]']));
    });

    test('accepts the frozen ownership file name', () async {
      await store.write(name: 'opencode-processes.json', contents: '{}');

      expect(await store.read(name: 'opencode-processes.json'), '{}');
    });

    test('rejects reserved and non-plain names on every operation', () {
      const invalidNames = <String>[
        '',
        '.',
        '..',
        'nested/state.json',
        r'nested\state.json',
        'bridge-startup.lock',
        'bridge-startup.intent.json',
        'state.json.tmp',
        'state.json.update-lock',
      ];

      for (final name in invalidNames) {
        expect(() => store.read(name: name), throwsArgumentError, reason: name);
        expect(
          () => store.write(name: name, contents: '{}'),
          throwsArgumentError,
          reason: name,
        );
        expect(() => store.delete(name: name), throwsArgumentError, reason: name);
        expect(
          () => store.update(name: name, transform: (current) => current),
          throwsArgumentError,
          reason: name,
        );
        expect(
          () => store.quarantine(name: name, quarantinedName: 'aside.json'),
          throwsArgumentError,
          reason: name,
        );
        expect(
          () => store.quarantine(name: 'state.json', quarantinedName: name),
          throwsArgumentError,
          reason: name,
        );
      }
    });
  });
}
