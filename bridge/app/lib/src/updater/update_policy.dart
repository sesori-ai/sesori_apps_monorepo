import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns true if the executable is running from a node_modules directory.
///
/// This indicates an npm-based installation (e.g., via `npx @sesori/bridge`).
bool isNpmInstall({required String executablePath}) {
  return executablePath.contains('node_modules');
}

/// Returns true when the current executable already points at the managed
/// install location for sesori-bridge.
bool isManagedInstall({
  required String executablePath,
  required String managedExecutablePath,
}) {
  if (executablePath.isEmpty || managedExecutablePath.isEmpty) {
    return false;
  }

  final String normalizedExecutablePath = p.normalize(p.absolute(executablePath));
  final String normalizedManagedExecutablePath = p.normalize(
    p.absolute(managedExecutablePath),
  );

  if (Platform.isWindows) {
    return normalizedExecutablePath.toLowerCase() == normalizedManagedExecutablePath.toLowerCase();
  }

  return normalizedExecutablePath == normalizedManagedExecutablePath;
}

/// Returns true if running in a CI environment.
///
/// Checks for common CI environment variables:
/// - CI
/// - GITHUB_ACTIONS
/// - JENKINS_URL
/// - CIRCLECI
/// - GITLAB_CI
/// - CODESPACES
/// - TF_BUILD
bool isCiEnvironment({required Map<String, String> environment}) {
  const ciVars = [
    'CI',
    'GITHUB_ACTIONS',
    'JENKINS_URL',
    'CIRCLECI',
    'GITLAB_CI',
    'CODESPACES',
    'TF_BUILD',
  ];

  return ciVars.any((varName) => environment.containsKey(varName));
}

/// Returns true if stdout is connected to an interactive terminal.
bool isInteractiveTerminal() {
  return stdout.hasTerminal;
}

/// Returns true if auto-update is disabled via the SESORI_NO_UPDATE environment variable.
bool isUpdateDisabled({required Map<String, String> environment}) {
  return environment.containsKey('SESORI_NO_UPDATE');
}
