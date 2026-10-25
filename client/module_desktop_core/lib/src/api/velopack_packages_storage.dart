import "dart:ffi";
import "dart:io";
import "dart:isolate";
import "dart:typed_data";

import "package:ffi/ffi.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../foundation/platform/desktop_application_support_directory.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";
import "../foundation/velopack/velopack_bindings.dart";

/// A newer full package that the staged feed names.
class const VelopackStagedRelease({required final String fileName, required final String version});

/// Layer-1 owner of the staging directory that Velopack reads as its file
/// source, and of every Velopack update-manager call.
///
/// Only a signature-verified feed is staged. The package is downloaded beside
/// it, then Velopack copies it into its own packages directory and refuses it
/// unless its size and SHA-256 match that feed. Writing straight into the
/// packages directory would skip that check, because Velopack trusts packages
/// already there. Each call opens the library in a short-lived isolate, so its
/// blocking disk work never runs on the UI isolate.
@lazySingleton
class VelopackPackagesStorage({
  required final InstalledDesktopBundleSource _bundleSource,
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
}) {
  static const String _directoryName = "velopack-feed";

  /// The version Velopack has downloaded and will apply on the next exit.
  Future<String?> readPendingVersion() async {
    final _VelopackCall call = await _call();
    return await Isolate.run(call.readPendingVersion);
  }

  /// Replaces the staging directory with the verified [feed] and asks
  /// Velopack whether it names a full package newer than the running version.
  Future<VelopackStagedRelease?> stageFeed({required Uint8List feed}) async {
    final _VelopackCall call = await _call();
    final Directory directory = Directory(call.feedDirectory);
    await directory.delete(recursive: true);
    await directory.create(recursive: true);
    await File(
      path.join(directory.path, "releases.${_bundleSource.channel.name}.json"),
    ).writeAsBytes(feed, flush: true);
    return await Isolate.run(call.checkStagedFeed);
  }

  /// Where the package of [release] must be downloaded before [downloadStagedRelease].
  Future<File> stagedPackageFile({required VelopackStagedRelease release}) async =>
      File(path.join((await _call()).feedDirectory, release.fileName));

  /// Hands the staged package to Velopack, which verifies it, and then clears
  /// the staging directory. Returns the downloaded version.
  Future<String> downloadStagedRelease() async {
    final _VelopackCall call = await _call();
    try {
      return await Isolate.run(call.downloadStagedRelease);
    } finally {
      await Directory(call.feedDirectory).delete(recursive: true);
    }
  }

  /// Starts Velopack's updater, which waits for this process to exit, then
  /// installs the downloaded package silently and, with [restart], opens it.
  Future<void> applyPendingRelease({required bool restart}) async {
    final _VelopackCall call = await _call();
    await Isolate.run(() => call.applyPendingRelease(restart: restart));
  }

  Future<_VelopackCall> _call() async {
    final Directory supportDirectory = await _applicationSupportDirectory.resolve();
    final Directory directory = await Directory(path.join(supportDirectory.path, _directoryName)).create(recursive: true);
    return _VelopackCall(libraryPath: _bundleSource.velopackLibraryPath, feedDirectory: directory.path);
  }
}

/// Plain values sent to the isolate that makes one Velopack call.
final class _VelopackCall({required final String libraryPath, required final String feedDirectory}) {
  String? readPendingVersion() => _withManager(
    use: (bindings, manager) => using((Arena arena) {
      final Pointer<Pointer<VelopackAsset>> asset = arena();
      if (!bindings.updatePendingRestart(manager, asset)) {
        return null;
      }
      try {
        return asset.value.ref.version.toDartString();
      } finally {
        bindings.freeAsset(asset.value);
      }
    }),
  );

  VelopackStagedRelease? checkStagedFeed() => _withUpdate(
    use: (bindings, manager, update) {
      final VelopackAsset target = update.ref.targetFullRelease.ref;
      return VelopackStagedRelease(fileName: target.fileName.toDartString(), version: target.version.toDartString());
    },
  );

  String downloadStagedRelease() {
    final String? version = _withUpdate(
      use: (bindings, manager, update) {
        if (!bindings.downloadUpdates(manager, update, nullptr, nullptr)) {
          throw bindings.failure(operation: "download the staged package");
        }
        return update.ref.targetFullRelease.ref.version.toDartString();
      },
    );
    if (version == null) {
      throw const VelopackException(operation: "download the staged package", message: "the feed offers no update");
    }
    return version;
  }

  void applyPendingRelease({required bool restart}) => _withManager(
    use: (bindings, manager) => using((Arena arena) {
      final Pointer<Pointer<VelopackAsset>> asset = arena();
      if (!bindings.updatePendingRestart(manager, asset)) {
        throw const VelopackException(operation: "apply the update", message: "no downloaded update is pending");
      }
      try {
        if (!bindings.waitExitThenApplyUpdates(manager, asset.value, true, restart, nullptr, 0)) {
          throw bindings.failure(operation: "start the updater");
        }
      } finally {
        bindings.freeAsset(asset.value);
      }
    }),
  );

  /// Runs [use] with Velopack's update info when the staged feed offers an update.
  T? _withUpdate<T>({
    required T Function(VelopackBindings bindings, Pointer<Void> manager, Pointer<VelopackUpdateInfo> update) use,
  }) => _withManager(
    use: (bindings, manager) => using((Arena arena) {
      final Pointer<Pointer<VelopackUpdateInfo>> update = arena();
      switch (bindings.checkForUpdates(manager, update)) {
        case VelopackBindings.updateAvailable:
          try {
            return use(bindings, manager, update.value);
          } finally {
            bindings.freeUpdateInfo(update.value);
          }
        case VelopackBindings.noUpdateAvailable || VelopackBindings.remoteIsEmpty:
          return null;
        default:
          throw bindings.failure(operation: "check the staged feed");
      }
    }),
  );

  T _withManager<T>({required T Function(VelopackBindings bindings, Pointer<Void> manager) use}) {
    final VelopackBindings bindings = VelopackBindings.open(libraryPath: libraryPath);
    return using((Arena arena) {
      final Pointer<Pointer<Void>> manager = arena();
      if (!bindings.newUpdateManager(feedDirectory.toNativeUtf8(allocator: arena), nullptr, nullptr, manager)) {
        throw bindings.failure(operation: "create the update manager");
      }
      try {
        return use(bindings, manager.value);
      } finally {
        bindings.freeUpdateManager(manager.value);
      }
    });
  }
}
