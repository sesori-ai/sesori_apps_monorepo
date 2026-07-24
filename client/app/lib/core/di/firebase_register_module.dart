import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:injectable/injectable.dart";

import "../platform/firebase/firebase_messaging_static_adapter.dart";
import "../platform/firebase/no_op_firebase_analytics_adapter.dart";
import "../platform/firebase/no_op_firebase_app_adapter.dart";
import "../platform/firebase/no_op_firebase_crashlytics_adapter.dart";
import "../platform/firebase/no_op_firebase_messaging_adapter.dart";

const String firebaseEnabledEnvironmentName = "firebaseEnabled";
const String firebaseDisabledEnvironmentName = "firebaseDisabled";
const firebaseEnabledEnvironment = Environment(firebaseEnabledEnvironmentName);
const firebaseDisabledEnvironment = Environment(firebaseDisabledEnvironmentName);

/// Selects real FlutterFire objects or type-compatible no-ops as one DI unit.
@module
abstract class FirebaseRegisterModule {
  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseApp get enabledFirebaseApp => Firebase.app();

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseApp get disabledFirebaseApp => const NoOpFirebaseAppAdapter();

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseMessaging get enabledFirebaseMessaging => FirebaseMessaging.instance;

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseMessaging disabledFirebaseMessaging(FirebaseApp app) => NoOpFirebaseMessagingAdapter(app: app);

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseAnalytics get enabledFirebaseAnalytics => FirebaseAnalytics.instance;

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseAnalytics disabledFirebaseAnalytics(FirebaseApp app) => NoOpFirebaseAnalyticsAdapter(app: app);

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseCrashlytics get enabledFirebaseCrashlytics => FirebaseCrashlytics.instance;

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseCrashlytics disabledFirebaseCrashlytics(FirebaseApp app) => NoOpFirebaseCrashlyticsAdapter(app: app);

  @firebaseEnabledEnvironment
  @lazySingleton
  FirebaseMessagingStaticAdapter get enabledFirebaseMessagingStaticAdapter => FirebaseMessagingStaticAdapter.enabled();

  @firebaseDisabledEnvironment
  @lazySingleton
  FirebaseMessagingStaticAdapter get disabledFirebaseMessagingStaticAdapter =>
      const FirebaseMessagingStaticAdapter.disabled();
}
