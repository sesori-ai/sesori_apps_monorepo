import 'bridge_restart_command.dart';

/// Builds the spawn command for a successor bridge.
///
/// The successor runs the managed binary directly with the same CLI arguments
/// the current process was launched with. This is the single place OS-specific
/// command shaping would live; today the command is identical on every platform.
class BridgeRestartCommandBuilder {
  const BridgeRestartCommandBuilder();

  BridgeRestartCommand build({required String binaryPath, required List<String> cliArgs}) {
    return BridgeRestartCommand(
      executable: binaryPath,
      arguments: List<String>.unmodifiable(cliArgs),
    );
  }
}
