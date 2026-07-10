import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/analytics/analytics_event.dart";
import "package:sesori_mobile/core/analytics/firebase_analytics_reporter.dart";

import "../../helpers/test_helpers.dart";

/// One expected GA4 wire shape for a union case: the event [name] Firebase
/// must receive and the exact [parameters] map sent alongside it.
typedef _WirePin = ({AnalyticsEvent event, String name, Map<String, Object> parameters});

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late FirebaseAnalyticsReporter reporter;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    reporter = FirebaseAnalyticsReporter(analytics: mockAnalytics);

    when(
      () => mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
    ).thenAnswer((_) async {});
  });

  group("FirebaseAnalyticsReporter", () {
    // Pins the GA4 wire name and parameter map of every union case, so
    // renaming a case, field, or enum identifier cannot silently change what
    // reaches analytics. One entry per case keeps the list exhaustive.
    const wirePins = <_WirePin>[
      (
        event: AnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
        name: "onboarding_need_help_opened",
        parameters: {"surface": "connect_setup"},
      ),
      (
        event: AnalyticsEvent.supportLinkOpened(
          channel: SupportChannel.email,
          surface: OnboardingSurface.connectedEmpty,
        ),
        name: "onboarding_support_link_opened",
        parameters: {"channel": "email", "surface": "connected_empty"},
      ),
      (
        event: AnalyticsEvent.whyBridgeOpened(surface: OnboardingSurface.connectedEmpty),
        name: "onboarding_why_bridge_opened",
        parameters: {"surface": "connected_empty"},
      ),
      (
        event: AnalyticsEvent.installCommandCopied(
          method: BridgeInstallMethod.powershell,
          os: BridgeInstallOs.windows,
          surface: OnboardingSurface.bridgeOffline,
        ),
        name: "bridge_install_command_copied",
        parameters: {"method": "powershell", "os": "windows", "surface": "bridge_offline"},
      ),
      (
        event: AnalyticsEvent.installCommandShared(
          method: BridgeInstallMethod.curl,
          os: BridgeInstallOs.unix,
          surface: OnboardingSurface.connectSetup,
        ),
        name: "bridge_install_command_shared",
        parameters: {"method": "curl", "os": "unix", "surface": "connect_setup"},
      ),
      (
        event: AnalyticsEvent.runCommandCopied(surface: OnboardingSurface.bridgeOffline),
        name: "bridge_run_command_copied",
        parameters: {"surface": "bridge_offline"},
      ),
      (
        event: AnalyticsEvent.runCommandShared(surface: OnboardingSurface.connectSetup),
        name: "bridge_run_command_shared",
        parameters: {"surface": "connect_setup"},
      ),
    ];

    for (final pin in wirePins) {
      test("sends ${pin.name} with its pinned parameter map", () async {
        await reporter.logEvent(event: pin.event);

        verify(
          () => mockAnalytics.logEvent(name: pin.name, parameters: pin.parameters),
        ).called(1);
      });
    }

    test("swallows analytics errors without crashing", () async {
      when(
        () =>
            mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
      ).thenThrow(Exception("analytics crashed"));

      // Test passes if no exception propagates out of the reporter.
      await reporter.logEvent(
        event: const AnalyticsEvent.needHelpMenuOpened(surface: OnboardingSurface.connectSetup),
      );

      verify(
        () => mockAnalytics.logEvent(
          name: "onboarding_need_help_opened",
          parameters: {"surface": "connect_setup"},
        ),
      ).called(1);
    });
  });
}
