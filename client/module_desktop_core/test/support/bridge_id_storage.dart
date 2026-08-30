import "dart:io";

import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// In-memory bridge-id storage for pure-Dart tracker/service tests.
class MemoryBridgeIdStorage extends BridgeIdStorage {
  // ignore: use_primary_constructors, unnecessary_type_name_in_constructor, the test double needs a fixed super argument
  MemoryBridgeIdStorage({String? initialBridgeId})
    : bridgeId = initialBridgeId,
      super(
        applicationSupportDirectory: _UnusedApplicationSupportDirectory(),
      );

  String? bridgeId;

  @override
  Future<String?> read() async => bridgeId;

  @override
  Future<void> write({required String bridgeId}) async {
    this.bridgeId = bridgeId;
  }

  @override
  Future<void> clear() async {
    bridgeId = null;
  }
}

// ignore: use_primary_constructors, this test-only implementation has no constructor state
class _UnusedApplicationSupportDirectory implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => Directory.systemTemp;
}
