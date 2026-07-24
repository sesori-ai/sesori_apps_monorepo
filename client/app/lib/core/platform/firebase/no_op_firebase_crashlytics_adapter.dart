import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";

/// Type-compatible Crashlytics implementation for Firebase-disabled builds.
class NoOpFirebaseCrashlyticsAdapter implements FirebaseCrashlytics {
  NoOpFirebaseCrashlyticsAdapter({required FirebaseApp app}) : _app = app;

  FirebaseApp _app;

  @override
  FirebaseApp get app => _app;

  @override
  set app(FirebaseApp value) => _app = value;

  @override
  Map<dynamic, dynamic> get pluginConstants => const {};

  @override
  bool get isCrashlyticsCollectionEnabled => false;

  @override
  Future<bool> checkForUnsentReports() async => false;

  @override
  void crash() {}

  @override
  Future<void> deleteUnsentReports() async {}

  @override
  Future<bool> didCrashOnPreviousExecution() async => false;

  @override
  Future<void> recordError(
    Object? exception,
    StackTrace? stack, {
    Object? reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails flutterErrorDetails, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails flutterErrorDetails) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> sendUnsentReports() async {}

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserIdentifier(String identifier) async {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}
