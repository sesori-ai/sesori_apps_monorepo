import "dart:io" show File;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

sealed class const OmpLinuxLibcEvidence();

final class const OmpAlpineMarkerEvidence() extends OmpLinuxLibcEvidence;

final class const OmpLddEvidence({required final CommandResult result}) extends OmpLinuxLibcEvidence;

class const OmpLinuxLibcProbeApi({
  required final CommandExecutor _commandExecutor,
  required final String _alpineMarkerPath,
  required final Duration _timeout,
}) {
  Future<OmpLinuxLibcEvidence> probe() async {
    if (File(_alpineMarkerPath).existsSync()) {
      return const OmpAlpineMarkerEvidence();
    }
    final result = await _commandExecutor.run("ldd", const ["--version"], timeout: _timeout);
    return OmpLddEvidence(result: result);
  }
}
