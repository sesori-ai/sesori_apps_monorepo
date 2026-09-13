import 'package:sesori_bridge/src/server/foundation/bridge_restart_env.dart';
import 'package:sesori_bridge/src/server/services/windows_restart_successor_launcher.dart';
import 'package:test/test.dart';

void main() {
  test('starts the real successor, strips its marker, and exits the launcher', () async {
    final calls = <({String executable, List<String> arguments, Map<String, String> environment})>[];
    final exitCodes = <int>[];
    final launcher = WindowsRestartSuccessorLauncher(
      isWindows: true,
      environment: const <String, String>{
        sesoriRestartPredecessorPidEnvVar: '7777',
        sesoriRestartLauncherEnvVar: sesoriRestartLauncherEnvValue,
        'PRESERVED': 'value',
      },
      executable: r'C:\Sesori\sesori-bridge.exe',
      start: ({required executable, required arguments, required environment}) async {
        calls.add((executable: executable, arguments: arguments, environment: environment));
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
    expect(call.environment, containsPair(sesoriRestartPredecessorPidEnvVar, '7777'));
    expect(call.environment, containsPair('PRESERVED', 'value'));
    expect(call.environment.containsKey(sesoriRestartLauncherEnvVar), isFalse);
  });

  test('is inert without its marked Windows process', () async {
    final launcher = WindowsRestartSuccessorLauncher(
      isWindows: true,
      environment: const <String, String>{},
      executable: r'C:\Sesori\sesori-bridge.exe',
      start: ({required executable, required arguments, required environment}) async {
        fail('an unmarked process must not launch a successor');
      },
      exitLauncher: ({required code}) => fail('an unmarked process must not exit'),
    );

    expect(await launcher.launchIfRequested(arguments: const <String>['run']), isFalse);
  });
}
