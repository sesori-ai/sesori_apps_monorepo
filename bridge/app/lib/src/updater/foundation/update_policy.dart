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

/// Whether the updater must not run for this install: supervised by the
/// desktop GUI, explicitly disabled, a CI environment, an npm-owned payload,
/// or simply not the managed binary. Gates BOTH the periodic update cycle and
/// startup reconciliation so neither touches the managed install's state when
/// this process is not the managed runtime.
///
/// A supervised (GUI-spawned) bridge never rewrites its own install: the
/// desktop app owns update delivery for the whole bundle, so in-place
/// self-update or reconciliation from the helper would fight the bundle's
/// updater and could corrupt a signed install.
bool shouldSkipUpdates({
  required Map<String, String> environment,
  required String executablePath,
  required String managedExecutablePath,
  required bool isSupervised,
}) {
  return isSupervised ||
      isUpdateDisabled(environment: environment) ||
      isCiEnvironment(environment: environment) ||
      isNpmInstall(executablePath: executablePath) ||
      !isManagedInstall(
        executablePath: executablePath,
        managedExecutablePath: managedExecutablePath,
      );
}

/// Whether an HTTP status from a release check or artifact download is a
/// transient, retryable outage (server-side errors, request timeout, or
/// throttling) rather than a genuine failure. The best-effort updater stays
/// quiet on these and retries on the next cycle; other non-2xx statuses (404,
/// auth rejections, etc.) are genuine and surfaced with reinstall guidance.
bool isRetryableHttpStatus(int statusCode) {
  return statusCode >= 500 || statusCode == 429 || statusCode == 408;
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
