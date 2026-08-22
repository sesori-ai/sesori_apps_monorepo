import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// A [HostJsonStore] kept entirely in memory, so a test can exercise the
/// supervisor's start-intent side file without touching the filesystem.
///
/// [files] is public on purpose: tests assert on the exact bytes written, and
/// observe the intent file's presence from inside a spawn seam.
class InMemoryHostJsonStore() implements HostJsonStore {
  final Map<String, String> files = <String, String>{};

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) async {
    final contents = files.remove(name);
    if (contents != null) {
      files[quarantinedName] = contents;
    }
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }
}
