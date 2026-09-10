import 'dart:io';

import 'package:antigravity_plugin/antigravity_plugin.dart';
import 'package:sesori_bridge/src/foundation/process_runner.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_process_service.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  test('internal browser mode is recognized only as the first argument', () {
    expect(BrowserNoop.matches(arguments: []), isFalse);
    expect(BrowserNoop.matches(arguments: ['run', BrowserNoop.argument]), isFalse);
    expect(BrowserNoop.matches(arguments: [BrowserNoop.argument]), isTrue);
  });

  for (final explicitPackages in [false, true]) {
    test('actual source entrypoint exits silently with explicit packages: $explicitPackages', () async {
      final temp = Directory.systemTemp.createTempSync('browser-noop-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      const clock = ServerClock();
      final storage = AntigravityProfileStorage(
        geminiHome: temp.path,
        settingsStore: const _UnusedProfileStore(),
        commands: HostProcessCommandExecutor(
          processes: BridgeHostProcessService(
            processStarter:
                (
                  executable,
                  arguments, {
                  environment,
                  workingDirectory,
                  runInShell = false,
                  required includeParentEnvironment,
                }) => Process.start(
                  executable,
                  arguments,
                  environment: environment,
                  workingDirectory: temp.path,
                  runInShell: runInShell,
                  includeParentEnvironment: includeParentEnvironment,
                ),
            processRepository: ProcessRepository(
              api: SystemProcessApi(
                processRunner: ProcessRunner(),
                clock: clock,
                isWindows: Platform.isWindows,
                platform: Platform.operatingSystem,
              ),
              currentUser: null,
            ),
            clock: clock,
            currentUser: null,
            isWindows: Platform.isWindows,
            platform: Platform.operatingSystem,
          ),
          runInShell: false,
          includeParentEnvironment: false,
          maxCapturedOutputCharactersPerStream: 4096,
        ),
        target: PlatformTarget.current(),
      );
      final result = await storage.runBrowserPreflight(
        budget: AntigravityAuthenticationBudget(
          timeout: const Duration(minutes: 2),
          abortSignal: StartAbortSignal.never,
        ),
        executable: Platform.resolvedExecutable,
        arguments: [
          if (explicitPackages) '--packages=${File('../.dart_tool/package_config.json').absolute.path}',
          File('bin/bridge.dart').absolute.path,
          BrowserNoop.argument,
          'https://example.invalid/synthetic?code=not-a-credential',
          '--deliberately-invalid-option',
        ],
        environment: {'HOME': temp.path, 'USERPROFILE': temp.path},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
      expect(temp.listSync(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

class const _UnusedProfileStore() implements HostJsonStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
