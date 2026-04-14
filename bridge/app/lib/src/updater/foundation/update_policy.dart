import 'dart:io';

import 'package:path/path.dart' as p;

bool isNpmInstall({required String executablePath}) {
  return executablePath.contains('node_modules');
}

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

bool isInteractiveTerminal() {
  return stdout.hasTerminal;
}

bool isUpdateDisabled({required Map<String, String> environment}) {
  return environment.containsKey('SESORI_NO_UPDATE');
}

String? unsupportedPackageRuntimeMessage({
  required String executablePath,
  required String managedExecutablePath,
}) {
  if (!isNpmInstall(executablePath: executablePath) ||
      isManagedInstall(
        executablePath: executablePath,
        managedExecutablePath: managedExecutablePath,
      )) {
    return null;
  }

  return 'sesori-bridge: Direct execution from npm-owned package payloads is unsupported. '
      'Run `npx @sesori/bridge` to bootstrap or refresh the managed install, then use '
      '`sesori-bridge` from your PATH.';
}
