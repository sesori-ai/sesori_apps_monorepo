import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostJsonStore;

import "../api/runtime_file_api.dart";

class BridgeHostJsonStore implements HostJsonStore {
  BridgeHostJsonStore({
    required RuntimeFileApi fileApi,
  }) : _fileApi = fileApi;

  final RuntimeFileApi _fileApi;

  @override
  Future<String?> read({required String name}) {
    _validateName(name);
    return _fileApi.readFile(name: name);
  }

  @override
  Future<void> write({required String name, required String contents}) {
    _validateName(name);
    return _fileApi.writeFile(name: name, contents: contents);
  }

  @override
  Future<void> delete({required String name}) {
    _validateName(name);
    return _fileApi.deleteFile(name: name);
  }

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) {
    _validateName(name);
    _validateName(quarantinedName);
    return _fileApi.renameFile(fromName: name, toName: quarantinedName);
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) {
    _validateName(name);
    return _fileApi.updateFile(name: name, transform: transform);
  }

  /// A bad name is plugin code reaching outside its store, not user input —
  /// hence [ArgumentError], not a recoverable exception.
  static void _validateName(String name) {
    if (name.isEmpty || name == "." || name == "..") {
      throw ArgumentError.value(name, "name", "must be a plain file name");
    }
    if (name.contains("/") || name.contains(r"\")) {
      throw ArgumentError.value(name, "name", "must not contain path separators");
    }
    if (name.startsWith("bridge-startup")) {
      throw ArgumentError.value(name, "name", "the 'bridge-startup.*' prefix is reserved for the bridge");
    }
    if (name.endsWith(".tmp") || name.endsWith(RuntimeFileApi.updateLockSuffix)) {
      throw ArgumentError.value(name, "name", "the '.tmp' and '${RuntimeFileApi.updateLockSuffix}' suffixes are reserved for the store's own machinery");
    }
  }
}
