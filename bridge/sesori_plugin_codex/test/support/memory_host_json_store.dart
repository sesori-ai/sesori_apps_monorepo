import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class MemoryHostJsonStore() implements HostJsonStore {
  @override
  HostJsonStore scope({required String directoryName}) => throw UnsupportedError("Unused child store");

  final Map<String, String> files = {};

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
  Future<void> quarantine({
    required String name,
    required String quarantinedName,
  }) async {
    final contents = files.remove(name);
    if (contents != null) files[quarantinedName] = contents;
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final contents = await transform(files[name]);
    if (contents == null) {
      files.remove(name);
    } else {
      files[name] = contents;
    }
    return contents;
  }
}
