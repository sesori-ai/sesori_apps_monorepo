import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/platform/desktop_product_event_source.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";

// With the 5 second attempt deadline, retrying ends after about 50 seconds.
const _retryDelays = [Duration(seconds: 5), Duration(seconds: 30)];

/// Layer-3 owner of delivering desktop product events to the auth server, which
/// rechecks the account's preference and derives the user key from the access
/// token.
///
/// It decides which events reach the warehouse, which account and app version
/// they carry, and when a failure the repository calls transient is retried.
/// Sending happens in the background so a dead endpoint can't stall the caller.
/// Events still in flight when the app quits, or outlasting the retries during an
/// outage, are lost by design.
@lazySingleton
class DesktopProductAnalyticsDeliveryService({
  required final DesktopProductEventSource _eventSource,
  required final ProductAnalyticsEventRepository _repository,
  required final AuthSession _authSession,
  required final InstalledDesktopBundleSource _bundleSource,
}) {
  StreamSubscription<ProductAnalyticsEnvelope>? _subscription;

  void start() {
    final identity = _bundleSource.compiledIdentity;
    if (identity == null) logi("This is a source build, so it sends no product analytics events");
    // Listens even then, because events would otherwise wait in the source's buffer.
    _subscription = _eventSource.events.listen((envelope) {
      if (identity != null) _onEvent(envelope: envelope, identity: identity);
    });
  }

  @disposeMethod
  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  void _onEvent({required ProductAnalyticsEnvelope envelope, required DesktopBundleIdentity identity}) {
    final params = _wireParams(event: envelope.event);
    if (params == null) return;
    final authState = _authSession.currentState;
    if (authState is! AuthAuthenticated) {
      logw("Dropped a product analytics event with no signed-in account: ${envelope.event.wireName}");
      return;
    }
    unawaited(
      _send(
        userId: authState.user.id,
        envelope: envelope,
        params: params,
        platform: _wirePlatform(os: identity.os),
        appVersion: identity.version,
      ),
    );
  }

  Future<void> _send({
    required String userId,
    required ProductAnalyticsEnvelope envelope,
    required Map<String, String> params,
    required ProductAnalyticsEventPlatform platform,
    required String appVersion,
  }) async {
    final name = envelope.event.wireName;
    Future<ProductAnalyticsEventDeliveryResult> attempt() => _repository.send(
      userId: userId,
      platform: platform,
      appVersion: appVersion,
      envelope: envelope,
      params: params,
    );

    var result = await attempt();
    for (final delay in _retryDelays) {
      if (result is! ProductAnalyticsEventTransientFailure) break;
      logw("A product analytics attempt failed: $name (${result.description})", result.cause, result.stackTrace);
      await Future<void>.delayed(delay);
      if (!_isSignedIn(userId: userId)) break;
      result = await attempt();
    }
    switch (result) {
      case ProductAnalyticsEventDelivered():
        break;
      case ProductAnalyticsEventPermanentFailure(:final description, :final cause):
        loge("Dropped a product analytics event without retrying: $name ($description)", cause);
      case ProductAnalyticsEventTransientFailure(:final description, :final cause, :final stackTrace):
        if (_isSignedIn(userId: userId)) {
          loge("Gave up sending a product analytics event: $name ($description)", cause, stackTrace);
        } else {
          logi("Stopped sending a product analytics event after a sign-out: $name");
        }
    }
  }

  bool _isSignedIn({required String userId}) {
    final authState = _authSession.currentState;
    return authState is AuthAuthenticated && authState.user.id == userId;
  }

  ProductAnalyticsEventPlatform _wirePlatform({required DesktopBundleOs os}) => switch (os) {
    DesktopBundleOs.macos => ProductAnalyticsEventPlatform.macos,
    DesktopBundleOs.linux => ProductAnalyticsEventPlatform.linux,
    DesktopBundleOs.windows => ProductAnalyticsEventPlatform.windows,
  };

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
