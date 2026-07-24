import "package:firebase_core/firebase_core.dart";

/// Firebase app placeholder for builds where the native Firebase SDK is absent.
// ignore: avoid_implementing_value_types, FirebaseApp has no public constructor for a disabled SDK instance.
class NoOpFirebaseAppAdapter implements FirebaseApp {
  const NoOpFirebaseAppAdapter();

  static const FirebaseOptions _options = FirebaseOptions(
    apiKey: "firebase-disabled",
    appId: "firebase-disabled",
    messagingSenderId: "firebase-disabled",
    projectId: "firebase-disabled",
  );

  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => _options;

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> delete() async {}

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  void registerService<T extends FirebaseService>(
    T service, {
    Future<void> Function(T service)? dispose,
  }) {}

  @override
  T? getService<T extends FirebaseService>() => null;
}
