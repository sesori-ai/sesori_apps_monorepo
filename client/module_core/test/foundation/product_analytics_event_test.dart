import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  group("ProductAnalyticsEvent wire contract", () {
    final cases = <(ProductAnalyticsEvent, String, Map<String, String>)>[
      (
        const ProductAnalyticsEvent.analyticsSchemaReady(),
        "analytics_schema_ready",
        const {},
      ),
      (
        const ProductAnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
        "onboarding_need_help_opened",
        const {"surface": "connect_setup"},
      ),
      (
        const ProductAnalyticsEvent.supportLinkOpened(
          channel: SupportChannel.discord,
          surface: OnboardingSurface.connectedEmpty,
        ),
        "onboarding_support_link_opened",
        const {"channel": "discord", "surface": "connected_empty"},
      ),
      (
        const ProductAnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.bridgeOffline),
        "onboarding_why_bridge_opened",
        const {"surface": "bridge_offline"},
      ),
      (
        const ProductAnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: OnboardingSurface.connectSetup,
        ),
        "bridge_install_command_copied",
        const {"method": "powershell", "os": "windows", "surface": "connect_setup"},
      ),
      (
        const ProductAnalyticsEvent.installCommandShared(
          method: BridgeInstallMethod.bun,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.bridgeOffline,
        ),
        "bridge_install_command_shared",
        const {"method": "bun", "os": "unix", "surface": "bridge_offline"},
      ),
      (
        const ProductAnalyticsEvent.runCommandCopied(surface: OnboardingSurface.connectSetup),
        "bridge_run_command_copied",
        const {"surface": "connect_setup"},
      ),
      (
        const ProductAnalyticsEvent.runCommandShared(surface: OnboardingSurface.bridgeOffline),
        "bridge_run_command_shared",
        const {"surface": "bridge_offline"},
      ),
      (
        const ProductAnalyticsEvent.screenViewed(screen: AnalyticsScreen.sessionDetail),
        "product_screen_viewed",
        const {"screen": "session_detail"},
      ),
    ];

    for (final (event, expectedName, expectedParameters) in cases) {
      test(expectedName, () {
        expect(event.wireName, expectedName);
        expect(event.parameters, expectedParameters);
        expect(event.wireName.length, lessThanOrEqualTo(40));
      });
    }
  });

  test("installation events stay account-less and use only bounded parameters", () {
    const started = InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github);
    const completed = InstallationAnalyticsEvent.loginAttemptCompleted(provider: AnalyticsLoginProvider.apple);
    const failed = InstallationAnalyticsEvent.loginAttemptFailed(
      provider: AnalyticsLoginProvider.email,
      failureKind: AnalyticsLoginFailureKind.timeout,
    );

    expect(started.wireName, "login_attempt_started");
    expect(started.parameters, {"provider": "github"});
    expect(completed.wireName, "login_attempt_completed");
    expect(completed.parameters, {"provider": "apple"});
    expect(failed.wireName, "login_attempt_failed");
    expect(failed.parameters, {"provider": "email", "failure_kind": "timeout"});
    for (final event in [started, completed, failed]) {
      expect(event.parameters, isNot(contains("user_key")));
      expect(event.parameters, isNot(contains("attempt_id")));
    }
  });

  test("envelope normalizes occurrence time to UTC without changing the instant", () {
    final local = DateTime.parse("2026-07-29T12:30:00+03:00");

    final envelope = ProductAnalyticsEnvelope(
      event: const ProductAnalyticsEvent.analyticsSchemaReady(),
      occurredAtUtc: local,
    );

    expect(envelope.occurredAtUtc.isUtc, isTrue);
    expect(envelope.occurredAtUtc.microsecondsSinceEpoch, local.microsecondsSinceEpoch);
  });
}
