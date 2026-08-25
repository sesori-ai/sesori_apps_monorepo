import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:injectable/injectable.dart";

import "../platform/firebase/firebase_messaging_static_adapter.dart";

const String firebaseEnabledEnvironmentName = "firebaseEnabled";
const String firebaseDisabledEnvironmentName = "firebaseDisabled";
const firebaseEnabledEnvironment = Environment(firebaseEnabledEnvironmentName);
const firebaseDisabledEnvironment = Environment(firebaseDisabledEnvironmentName);

/// Registers the real FlutterFire objects for builds that ship the SDK.
///
/// There is no disabled-environment counterpart: a build without Firebase binds
/// the small `module_core` interfaces (`AnalyticsClient`, `FailureReporter`,
/// `PushMessagingSource`) to no-ops directly, instead of standing up fake SDK
/// objects for the wrappers to talk to.
@module
abstract class FirebaseRegisterModule() {
  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseApp get enabledFirebaseApp => Firebase.app();

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseMessaging get enabledFirebaseMessaging => FirebaseMessaging.instance;

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseAnalytics get enabledFirebaseAnalytics => FirebaseAnalytics.instance;

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseCrashlytics get enabledFirebaseCrashlytics => FirebaseCrashlytics.instance;

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseMessagingStaticAdapter get enabledFirebaseMessagingStaticAdapter => FirebaseMessagingStaticAdapter.enabled();

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseMessagingStaticAdapter get disabledFirebaseMessagingStaticAdapter =>
      const FirebaseMessagingStaticAdapter.disabled();
}
