import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/host/plugin_state_directory.dart';
import 'package:sesori_bridge/src/updater/models/managed_runtime_paths.dart';
import 'package:test/test.dart';

void main() {
  group('pluginStateDirectoryPath', () {
    // Distinct values on purpose: production sets these equal today, and an
    // installRoot/cacheDirectory mix-up must not pass these tests.
    const paths = ManagedRuntimePaths(
      installRoot: '/home/alex/.local/share/sesori',
      binaryPath: '/home/alex/.local/share/sesori/bin/sesori-bridge',
      cacheDirectory: '/home/alex/.cache/sesori',
    );

    test('plugins live under <installRoot>/plugins/<id>', () {
      expect(
        pluginStateDirectoryPath(paths: paths, pluginId: 'acp'),
        p.join('/home/alex/.local/share/sesori', 'plugins', 'acp'),
      );
    });

    test('opencode is handed the frozen <cacheDirectory>/runtime directory', () {
      expect(
        pluginStateDirectoryPath(paths: paths, pluginId: openCodePluginId),
        p.join('/home/alex/.cache/sesori', 'runtime'),
      );
    });

    test('rejects plugin ids that are not plain directory names', () {
      const invalidIds = <String>['', '.', '..', 'a/b', r'a\b'];

      for (final pluginId in invalidIds) {
        expect(
          () => pluginStateDirectoryPath(paths: paths, pluginId: pluginId),
          throwsArgumentError,
          reason: pluginId,
        );
      }
    });
  });
}
