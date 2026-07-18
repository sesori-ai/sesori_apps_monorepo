import 'package:codex_plugin/codex_plugin.dart' show CodexPluginDescriptor;
import 'package:opencode_plugin/opencode_plugin.dart' show OpenCodePluginDescriptor;
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/host/plugin_state_directory.dart';
import 'package:sesori_bridge/src/updater/models/managed_runtime_paths.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show PluginStateStorage;
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
        pluginStateDirectoryPath(
          paths: paths,
          pluginId: 'acp',
          stateStorage: PluginStateStorage.isolated,
        ),
        p.join('/home/alex/.local/share/sesori', 'plugins', 'acp'),
      );
    });

    test('OpenCode and Codex keep the frozen <cacheDirectory>/runtime directory', () {
      const descriptors = [OpenCodePluginDescriptor(), CodexPluginDescriptor()];

      for (final descriptor in descriptors) {
        expect(
          pluginStateDirectoryPath(
            paths: paths,
            pluginId: descriptor.id,
            stateStorage: descriptor.stateStorage,
          ),
          p.join('/home/alex/.cache/sesori', 'runtime'),
          reason: descriptor.id,
        );
      }
    });

    test('legacy shared plugins namespace files and managed runtime subdirectories', () {
      final sharedDirectory = p.join('/home/alex/.cache/sesori', 'runtime');

      expect(OpenCodePluginDescriptor.ownershipFileName, isNot(CodexPluginDescriptor.ownershipFileName));
      expect(OpenCodePluginDescriptor.startIntentFileName, isNot(CodexPluginDescriptor.startIntentFileName));
      expect(
        p.join(sharedDirectory, const OpenCodePluginDescriptor().id),
        isNot(p.join(sharedDirectory, const CodexPluginDescriptor().id)),
      );
    });

    test('rejects plugin ids that are not plain directory names', () {
      const invalidIds = <String>['', '.', '..', 'a/b', r'a\b'];

      for (final pluginId in invalidIds) {
        for (final stateStorage in PluginStateStorage.values) {
          expect(
            () => pluginStateDirectoryPath(
              paths: paths,
              pluginId: pluginId,
              stateStorage: stateStorage,
            ),
            throwsArgumentError,
            reason: '$pluginId/$stateStorage',
          );
        }
      }
    });
  });
}
