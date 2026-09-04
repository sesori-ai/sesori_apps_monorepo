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
    if (context.basename(serverPath) != AntigravityRelease.serverFileName(target: target)) {
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
      if (context.basename(resolvedServer) != AntigravityRelease.serverFileName(target: target)) {
        return const AntigravityRuntimePairInvalid(
          component: AntigravityRuntimeComponent.server,
          reason: AntigravityRuntimePairInvalidReason.wrongName,
        );
      }
      if (context.basename(resolvedHarness) != AntigravityRelease.harnessFileName(target: target)) {
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
    for (final directory in rawPath.split(separator)) {
      if (directory.isEmpty) continue;
      final result = inspectPair(
        serverPath: context.join(directory, AntigravityRelease.serverFileName(target: target)),
        target: target,
      );
      if (result is! AntigravityRuntimePairMissing || result.component != AntigravityRuntimeComponent.server) {
        return result;
      }
    }
    return const AntigravityRuntimePairMissing(component: AntigravityRuntimeComponent.server);
  }

  String? _environmentPath({required Map<String, String> environment, required PlatformTarget target}) {
    if (target.os != PlatformOs.windows) return environment["PATH"];
    for (final entry in environment.entries) {
      if (entry.key.toLowerCase() == "path") return entry.value;
    }
    return null;
  }

  p.Context _pathContext({required PlatformTarget target}) =>
      p.Context(style: target.os == PlatformOs.windows ? p.Style.windows : p.Style.posix);
}
