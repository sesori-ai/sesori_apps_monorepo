import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/platform/desktop_app_info_source.dart";

// With the 5 second attempt deadline, retrying ends after about 50 seconds.
const _retryDelays = [Duration(seconds: 5), Duration(seconds: 30)];

/// Posts product events to the auth server, which rechecks the account's
/// preference and derives the user key from the access token.
///
/// Sending happens in the background so a dead endpoint can't stall the caller.
/// Events still in flight when the app quits, or outlasting the retries during
/// an outage, are lost by design.
@LazySingleton(as: AnalyticsClient)
class AuthServerAnalyticsClient({
  required final ProductAnalyticsEventClient _eventClient,
  required final AuthSession _authSession,
  required final DesktopAppInfoSource _appInfoSource,
}) implements AnalyticsClient {
  late final Future<String?> _appVersion = _readAppVersion();

  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {
    final params = _wireParams(event: envelope.event);
    final platform = _appInfoSource.platform;
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
    if (appVersion == null) {
      logw("Dropped a product analytics event with no app version: ${envelope.event.wireName}");
      return;
    }
    final request = ProductAnalyticsEventRequest(
      schemaVersion: ProductAnalyticsEventSchemaVersion.v1,
      platform: platform,
      appVersion: appVersion,
      name: envelope.event.wireName,
      occurredAtMicros: envelope.occurredAtUtc.microsecondsSinceEpoch,
      params: params,
    );

    var result = await _eventClient.send(userId: userId, request: request);
    for (final delay in _retryDelays) {
      if (result is! ProductAnalyticsEventClientTransientFailure) break;
      logw(
        "A product analytics attempt failed: ${request.name} (${result.description})",
        result.cause,
        result.stackTrace,
      );
      await Future<void>.delayed(delay);
      if (!_isSignedIn(userId: userId)) break;
      result = await _eventClient.send(userId: userId, request: request);
    }
    switch (result) {
      case ProductAnalyticsEventClientDelivered():
        break;
      case ProductAnalyticsEventClientPermanentFailure(:final description, :final cause):
        loge("Dropped a product analytics event without retrying: ${request.name} ($description)", cause);
      case ProductAnalyticsEventClientTransientFailure(:final description, :final cause, :final stackTrace):
        if (_isSignedIn(userId: userId)) {
          loge("Gave up sending a product analytics event: ${request.name} ($description)", cause, stackTrace);
        } else {
          logi("Stopped sending a product analytics event after a sign-out: ${request.name}");
        }
    }
  }

  bool _isSignedIn({required String userId}) {
    final authState = _authSession.currentState;
    return authState is AuthAuthenticated && authState.user.id == userId;
  }

  /// Read once for the process, so a failed read drops every event.
  Future<String?> _readAppVersion() async {
    try {
      final version = await _appInfoSource.readVersion();
      return version.split("+").first;
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
}
