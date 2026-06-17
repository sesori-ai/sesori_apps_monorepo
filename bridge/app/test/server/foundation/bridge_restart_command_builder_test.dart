import 'package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeRestartCommandBuilder', () {
    test('builds the command from the managed binary and cli args', () {
      final command = const BridgeRestartCommandBuilder().build(
        binaryPath: '/opt/sesori/bin/sesori-bridge',
        cliArgs: ['run', '--relay', 'wss://relay.example.com'],
      );

      expect(command.executable, '/opt/sesori/bin/sesori-bridge');
      expect(command.arguments, ['run', '--relay', 'wss://relay.example.com']);
    });

    test('arguments are an unmodifiable copy of the input', () {
      final args = ['run'];
      final command = const BridgeRestartCommandBuilder().build(binaryPath: '/x', cliArgs: args);

      args.add('mutated');
      expect(command.arguments, ['run']);
      expect(() => command.arguments.add('nope'), throwsUnsupportedError);
    });
  });
}
