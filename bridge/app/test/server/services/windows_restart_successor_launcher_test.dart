import 'package:sesori_bridge/src/server/foundation/bridge_restart_env.dart';
import 'package:sesori_bridge/src/server/services/windows_restart_successor_launcher.dart';
import 'package:test/test.dart';

void main() {
  test('starts the real successor with inherited environment and an inert marker', () async {
    final calls =
        <
          ({
            String executable,
            List<String> arguments,
            Map<String, String> environment,
            bool includeParentEnvironment,
          })
        >[];
    final exitCodes = <int>[];
    final launcher = WindowsRestartSuccessorLauncher(
      isWindows: true,
      environment: const <String, String>{
        sesoriRestartPredecessorPidEnvVar: '7777',
        sesoriRestartLauncherEnvVar: sesoriRestartLauncherEnvValue,
        'UNICODE_VALUE': 'café',
      },
      executable: r'C:\Sesori\sesori-bridge.exe',
      start:
          ({required executable, required arguments, required environment, required includeParentEnvironment}) async {
            calls.add((
              executable: executable,
              arguments: arguments,
              environment: environment,
              includeParentEnvironment: includeParentEnvironment,
            ));
          },
      exitLauncher: ({required code}) => exitCodes.add(code),
    );

    expect(
      await launcher.launchIfRequested(arguments: const <String>['run', '--relay', 'wss://relay.example']),
      isTrue,
    );
    expect(exitCodes, const <int>[0]);
    expect(calls, hasLength(1));
    final call = calls.single;
    expect(call.executable, r'C:\Sesori\sesori-bridge.exe');
    expect(call.arguments, const <String>['run', '--relay', 'wss://relay.example']);
    expect(call.includeParentEnvironment, isTrue);
    expect(call.environment, const <String, String>{
      sesoriRestartLauncherEnvVar: sesoriRestartLauncherConsumedEnvValue,
    });
    expect(call.environment.containsKey(sesoriRestartPredecessorPidEnvVar), isFalse);
    expect(call.environment.containsKey('UNICODE_VALUE'), isFalse);
  });

  test('is inert without its marked Windows process', () async {
    final launcher = WindowsRestartSuccessorLauncher(
      isWindows: true,
      environment: const <String, String>{},
      executable: r'C:\Sesori\sesori-bridge.exe',
      start:
          ({required executable, required arguments, required environment, required includeParentEnvironment}) async {
            fail('an unmarked process must not launch a successor');
          },
      exitLauncher: ({required code}) => fail('an unmarked process must not exit'),
    );

    expect(await launcher.launchIfRequested(arguments: const <String>['run']), isFalse);
  });
}
