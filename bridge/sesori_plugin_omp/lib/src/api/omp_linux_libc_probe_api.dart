import "dart:io" show File;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

sealed class OmpLinuxLibcEvidence {
  const OmpLinuxLibcEvidence();
}

final class OmpAlpineMarkerEvidence extends OmpLinuxLibcEvidence {
  const OmpAlpineMarkerEvidence();
}

final class OmpLddEvidence extends OmpLinuxLibcEvidence {
  const OmpLddEvidence({required this.result});

  final CommandResult result;
}

class OmpLinuxLibcProbeApi {
  const OmpLinuxLibcProbeApi({
    required CommandExecutor commandExecutor,
    required String alpineMarkerPath,
    required Duration timeout,
  }) : _commandExecutor = commandExecutor,
       _alpineMarkerPath = alpineMarkerPath,
       _timeout = timeout;

  final CommandExecutor _commandExecutor;
  final String _alpineMarkerPath;
  final Duration _timeout;

  Future<OmpLinuxLibcEvidence> probe() async {
    if (File(_alpineMarkerPath).existsSync()) {
      return const OmpAlpineMarkerEvidence();
    }
    final result = await _commandExecutor.run("ldd", const ["--version"], timeout: _timeout);
    return OmpLddEvidence(result: result);
  }
}
