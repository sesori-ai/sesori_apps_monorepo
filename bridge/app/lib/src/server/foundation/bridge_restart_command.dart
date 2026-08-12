import 'package:meta/meta.dart';

/// The platform-resolved command used to spawn a successor bridge on restart.
@immutable
class const BridgeRestartCommand({required final String executable, required final List<String> arguments});
