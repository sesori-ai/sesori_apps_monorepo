import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../foundation/antigravity_release.dart";
import "../models/antigravity_runtime_pair.dart";

/// Layer-1 filesystem and PATH boundary for the official Antigravity pair.
class const AntigravityRuntimeStorage() {
  AntigravityRuntimePairReadResult inspectPair({
    required String serverPath,
    required PlatformTarget target,
  }) {
    if (!AntigravityRelease.supportsTarget(target: target)) {
      return AntigravityRuntimeTargetUnsupported(target: target);
    }

    final context = _pathContext(target: target);
    if (!context.equals(context.basename(serverPath), AntigravityRelease.serverFileName(target: target))) {
      return const AntigravityRuntimePairInvalid(
        component: AntigravityRuntimeComponent.server,
        reason: AntigravityRuntimePairInvalidReason.wrongName,
      );
    }

    try {
      final requestedServer = File(context.normalize(context.absolute(serverPath)));
      final serverType = FileSystemEntity.typeSync(requestedServer.path, followLinks: true);
      if (serverType == FileSystemEntityType.notFound) {
        return const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.server);
      }
      if (serverType != FileSystemEntityType.file) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.server,
          reason: AntigravityRuntimePairInvalidReason.notAFile,
        );
      }

      final requestedHarness = File(
        context.join(
          context.dirname(requestedServer.path),
          AntigravityRelease.harnessFileName(target: target),
        ),
      );
      final harnessType = FileSystemEntity.typeSync(requestedHarness.path, followLinks: true);
      if (harnessType == FileSystemEntityType.notFound) {
        return const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.harness);
      }
      if (harnessType != FileSystemEntityType.file) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.harness,
          reason: AntigravityRuntimePairInvalidReason.notAFile,
        );
      }

      final resolvedServer = requestedServer.resolveSymbolicLinksSync();
      final resolvedHarness = requestedHarness.resolveSymbolicLinksSync();
      if (FileSystemEntity.identicalSync(resolvedServer, resolvedHarness)) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.harness,
          reason: AntigravityRuntimePairInvalidReason.notDistinct,
        );
      }
      if (!context.equals(context.basename(resolvedServer), AntigravityRelease.serverFileName(target: target))) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.server,
          reason: AntigravityRuntimePairInvalidReason.wrongName,
        );
      }
      if (!context.equals(context.basename(resolvedHarness), AntigravityRelease.harnessFileName(target: target))) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.harness,
          reason: AntigravityRuntimePairInvalidReason.wrongName,
        );
      }
      if (!context.equals(context.dirname(resolvedServer), context.dirname(resolvedHarness))) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.harness,
          reason: AntigravityRuntimePairInvalidReason.notSiblings,
        );
      }
      return AntigravityRuntimePairFound(
        pair: AntigravityRuntimePair(
          serverPath: resolvedServer,
          harnessPath: resolvedHarness,
          target: target,
        ),
      );
    } on FileSystemException catch (error, stackTrace) {
      return AntigravityRuntimeStorageFailure(cause: error, stackTrace: stackTrace);
    }
  }

  AntigravityRuntimePairReadResult findOnPath({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    if (!AntigravityRelease.supportsTarget(target: target)) {
      return AntigravityRuntimeTargetUnsupported(target: target);
    }
    final rawPath = _environmentPath(environment: environment, target: target);
    if (rawPath == null) {
      return const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.server);
    }

    final context = _pathContext(target: target);
    final separator = target.os == PlatformOs.windows ? ";" : ":";
    final directories = [
      if (target.os == PlatformOs.windows) Directory.current.path,
      ...rawPath.split(separator),
    ];
    AntigravityRuntimePairInvalid? harnessOnly;
    for (final rawDirectory in directories) {
      final directory = _pathDirectory(rawDirectory: rawDirectory, target: target);
      final result = inspectPair(
        serverPath: context.join(directory, AntigravityRelease.serverFileName(target: target)),
        target: target,
      );
      if (result is! AntigravityRuntimePairMissing || result.component != AntigravityRuntimeComponent.server) {
        return result;
      }
      try {
        final harnessType = FileSystemEntity.typeSync(
          context.join(directory, AntigravityRelease.harnessFileName(target: target)),
          followLinks: false,
        );
        if (harnessType != FileSystemEntityType.notFound) {
          harnessOnly ??= const AntigravityRuntimePairInvalid(
            component: AntigravityRuntimeComponent.harness,
            reason: AntigravityRuntimePairInvalidReason.notSiblings,
          );
        }
      } on FileSystemException catch (error, stackTrace) {
        return AntigravityRuntimeStorageFailure(cause: error, stackTrace: stackTrace);
      }
    }
    return harnessOnly ?? const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.server);
  }

  HostExecutablePresence inspectPathServerPresence({
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    if (!AntigravityRelease.supportsTarget(target: target) ||
        _environmentPath(environment: environment, target: target) == null) {
      return HostExecutablePresence.unknown;
    }
    return IoHostExecutableLocator(platformIsWindows: target.os == PlatformOs.windows).locate(
      executable: AntigravityRelease.serverFileName(target: target),
      environment: environment,
      workingDirectory: null,
    );
  }

  String? _environmentPath({required Map<String, String> environment, required PlatformTarget target}) {
    if (target.os != PlatformOs.windows) return environment["PATH"];
    for (final entry in environment.entries) {
      if (entry.key.toLowerCase() == "path") return entry.value;
    }
    return null;
  }

  String _pathDirectory({required String rawDirectory, required PlatformTarget target}) {
    if (target.os != PlatformOs.windows) return rawDirectory;
    final directory = rawDirectory.trim();
    if (directory.length >= 2 && directory.startsWith('"') && directory.endsWith('"')) {
      return directory.substring(1, directory.length - 1);
    }
    return directory;
  }

  p.Context _pathContext({required PlatformTarget target}) => p.Context(
    style: target.os == PlatformOs.windows ? p.Style.windows : p.Style.posix,
    current: Directory.current.path,
  );
}
