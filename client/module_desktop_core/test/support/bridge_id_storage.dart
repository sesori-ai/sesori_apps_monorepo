import "dart:io";

import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// In-memory bridge-id storage for pure-Dart tracker/service tests.
class MemoryBridgeIdStorage extends BridgeIdStorage {
  // ignore: use_primary_constructors, unnecessary_type_name_in_constructor, the test double needs a fixed super argument
  MemoryBridgeIdStorage({BridgeRegistrationRecord? initialRegistration})
    : registration = initialRegistration,
      super(
        applicationSupportDirectory: _UnusedApplicationSupportDirectory(),
      );

  BridgeRegistrationRecord? registration;

  String? get bridgeId => registration?.bridgeId;

  set bridgeId(String? value) {
    registration = value == null
        ? null
        : BridgeRegistrationRecord(
            bridgeId: value,
            accountId: "account-a",
          );
  }

  @override
  Future<BridgeRegistrationRecord?> read() async => registration;

  @override
  Future<void> write({required BridgeRegistrationRecord registration}) async {
    this.registration = registration;
  }

  @override
  Future<void> clear() async {
    registration = null;
  }
}

// ignore: use_primary_constructors, this test-only implementation has no constructor state
class _UnusedApplicationSupportDirectory implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => Directory.systemTemp;
}
