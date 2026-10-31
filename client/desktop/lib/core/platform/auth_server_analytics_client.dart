import "dart:async";

import "package:flutter/foundation.dart" show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

// With the 5 second attempt deadline, retrying ends after about 50 seconds.
const _retryDelays = [Duration(seconds: 5), Duration(seconds: 30)];

/// Posts product events to the auth server, which rechecks the account's
/// preference and derives the user key from the access token.
///
/// Sending happens in the background so a dead endpoint can't stall the caller.
/// Events still in flight when the app quits, or outlasting the retries during
/// an outage, are lost by design.
@LazySingleton(as: AnalyticsClient)
class AuthServerAnalyticsClient implements AnalyticsClient {
  final ProductAnalyticsEventApi _api;
  final AuthSession _authSession;
  final Future<PackageInfo> Function() _readPackageInfo;
  late final Future<String?> _appVersion = _readAppVersion();

  new({required ProductAnalyticsEventApi api, required AuthSession authSession})
    : _api = api,
      _authSession = authSession,
      _readPackageInfo = PackageInfo.fromPlatform;

  @visibleForTesting
  new withPackageInfoReader({
    required ProductAnalyticsEventApi api,
    required AuthSession authSession,
    required Future<PackageInfo> Function() readPackageInfo,
  }) : _api = api,
       _authSession = authSession,
       _readPackageInfo = readPackageInfo;

  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {
    final params = _wireParams(event: envelope.event);
    final platform = _wirePlatform();
    if (params == null || platform == null) return;
    final authState = _authSession.currentState;
    if (authState is! AuthAuthenticated) {
      logw("Dropped a product analytics event with no signed-in account: ${envelope.event.wireName}");
      return;
    }
    unawaited(_send(userId: authState.user.id, envelope: envelope, params: params, platform: platform));
  }

  @override
  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {}

  @override
  Future<void> activateAfterInteractiveAuthentication() async {}

  Future<void> _send({
    required String userId,
    required ProductAnalyticsEnvelope envelope,
    required Map<String, String> params,
    required ProductAnalyticsEventPlatform platform,
  }) async {
    final appVersion = await _appVersion;
    if (appVersion == null) return;
    final request = ProductAnalyticsEventRequest(
      schemaVersion: ProductAnalyticsEventSchemaVersion.v1,
      platform: platform,
      appVersion: appVersion,
      name: envelope.event.wireName,
      occurredAtMicros: envelope.occurredAtUtc.microsecondsSinceEpoch,
      params: params,
    );

    var result = await _api.send(userId: userId, request: request);
    for (final delay in _retryDelays) {
      if (result is! ProductAnalyticsEventApiTransientFailure) break;
      logw(
        "Will retry a product analytics event: ${request.name} (${result.description})",
        result.cause,
        result.stackTrace,
      );
      await Future<void>.delayed(delay);
      result = await _api.send(userId: userId, request: request);
    }
    switch (result) {
      case ProductAnalyticsEventApiDelivered():
        break;
      case ProductAnalyticsEventApiPermanentFailure(:final description, :final cause):
        loge("Dropped a product analytics event without retrying: ${request.name} ($description)", cause);
      case ProductAnalyticsEventApiTransientFailure(:final description, :final cause, :final stackTrace):
        loge("Gave up sending a product analytics event: ${request.name} ($description)", cause, stackTrace);
    }
  }

  /// Read once for the process, so a failed read drops every event with one warning.
  Future<String?> _readAppVersion() async {
    try {
      final info = await _readPackageInfo();
      return info.version.split("+").first;
    } on Object catch (error, stackTrace) {
      logw("Failed to read the app version for product analytics", error, stackTrace);
      return null;
    }
  }

  /// The event's params on the wire, or null for an event the warehouse doesn't
  /// allow. Listing every event makes a new one fail to compile until someone
  /// decides whether it reaches the warehouse.
  Map<String, String>? _wireParams({required ProductAnalyticsEvent event}) => switch (event) {
    HarnessInstallFinishedEvent() ||
    TranscriptPromptsOpenedEvent() ||
    ComputerSwitchedEvent() ||
    ComputerManagedEvent() ||
    FounderCallShownEvent() ||
    FounderCallLinkOpenedEvent() ||
    FounderCallDeclinedEvent() => null,
    // The warehouse has no `finish` or `mode` column, and a server enum would
    // reject the next new mode.
    VoiceTranscriptionCompletedEvent() => const {},
    AnalyticsSchemaReadyEvent() ||
    AnalyticsActivationReadyEvent() ||
    ProjectInventoryLoadedEvent() ||
    SessionActivityViewedEvent() ||
    SessionMessageSentEvent() ||
    SessionCreatedWithMessageEvent() ||
    SessionCreationFailedEvent() ||
    SessionQuestionAnsweredEvent() ||
    SessionQuestionRejectedEvent() ||
    SessionPermissionAnsweredEvent() ||
    SessionAbortSucceededEvent() ||
    SessionDiffViewedEvent() ||
    FeedbackPromptAnsweredEvent() ||
    PrivateFeedbackSentEvent() ||
    NeedHelpMenuOpenedEvent() ||
    SupportLinkOpenedEvent() ||
    WhyBridgeOpenedEvent() ||
    InstallCommandCopiedEvent() ||
    InstallCommandSharedEvent() ||
    RunCommandCopiedEvent() ||
    RunCommandSharedEvent() ||
    ProductScreenViewedEvent() => event.parameters,
  };

  ProductAnalyticsEventPlatform? _wirePlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => ProductAnalyticsEventPlatform.macos,
    TargetPlatform.linux => ProductAnalyticsEventPlatform.linux,
    TargetPlatform.windows => ProductAnalyticsEventPlatform.windows,
    // Unreachable in the desktop shell.
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => null,
  };
}
