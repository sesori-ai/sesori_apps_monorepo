import 'package:meta/meta.dart';

/// The platform-resolved command used to spawn a successor bridge on restart.
@immutable
class BridgeRestartCommand {
  const BridgeRestartCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}
