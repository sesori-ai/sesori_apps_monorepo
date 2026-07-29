import "package:meta/meta.dart";

enum SupportChannel {
  email(wireValue: "email"),
  discord(wireValue: "discord"),
  x(wireValue: "x");

  final String wireValue;
  const SupportChannel({required this.wireValue});
}

enum OnboardingSurface {
  connectSetup(wireValue: "connect_setup"),
  connectedEmpty(wireValue: "connected_empty"),
  bridgeOffline(wireValue: "bridge_offline");

  final String wireValue;
  const OnboardingSurface({required this.wireValue});
}

enum BridgeInstallMethod {
  curl(wireValue: "curl"),
  powershell(wireValue: "powershell"),
  npm(wireValue: "npm"),
  bun(wireValue: "bun");

  final String wireValue;
  const BridgeInstallMethod({required this.wireValue});
}

enum BridgeInstallOs {
  unix(wireValue: "unix"),
  windows(wireValue: "windows");

  final String wireValue;
  const BridgeInstallOs({required this.wireValue});
}

enum AnalyticsScreen {
  login(wireValue: "login"),
  projects(wireValue: "projects"),
  settings(wireValue: "settings"),
  settingsNotifications(wireValue: "settings_notifications"),
  settingsProfile(wireValue: "settings_profile"),
  sessions(wireValue: "sessions"),
  newSession(wireValue: "new_session"),
  sessionDetail(wireValue: "session_detail"),
  sessionDiffs(wireValue: "session_diffs");

  final String wireValue;
  const AnalyticsScreen({required this.wireValue});
}

enum AnalyticsInputMode {
  typed(wireValue: "typed"),
  voiceAssisted(wireValue: "voice_assisted");

  final String wireValue;
  const AnalyticsInputMode({required this.wireValue});
}

@immutable
sealed class ProductAnalyticsEvent {
  const ProductAnalyticsEvent();

  const factory ProductAnalyticsEvent.analyticsSchemaReady() = AnalyticsSchemaReadyEvent;
  const factory ProductAnalyticsEvent.needHelpMenuOpened({required OnboardingSurface surface}) =
      NeedHelpMenuOpenedEvent;
  const factory ProductAnalyticsEvent.supportLinkOpened({
    required SupportChannel channel,
    required OnboardingSurface surface,
  }) = SupportLinkOpenedEvent;
  const factory ProductAnalyticsEvent.whyBridgeOpened({required OnboardingSurface surface}) = WhyBridgeOpenedEvent;
  const factory ProductAnalyticsEvent.installCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandCopiedEvent;
  const factory ProductAnalyticsEvent.installCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) = InstallCommandSharedEvent;
  const factory ProductAnalyticsEvent.runCommandCopied({required OnboardingSurface surface}) = RunCommandCopiedEvent;
  const factory ProductAnalyticsEvent.runCommandShared({required OnboardingSurface surface}) = RunCommandSharedEvent;
  const factory ProductAnalyticsEvent.screenViewed({required AnalyticsScreen screen}) = ProductScreenViewedEvent;

  String get wireName;
  Map<String, String> get parameters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAnalyticsEvent &&
          wireName == other.wireName &&
          parameters.length == other.parameters.length &&
          parameters.entries.every((entry) => other.parameters[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    wireName,
    Object.hashAllUnordered(parameters.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

final class AnalyticsSchemaReadyEvent extends ProductAnalyticsEvent {
  const AnalyticsSchemaReadyEvent();

  @override
  String get wireName => "analytics_schema_ready";

  @override
  Map<String, String> get parameters => const {};
}

final class NeedHelpMenuOpenedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const NeedHelpMenuOpenedEvent({required this.surface});

  @override
  String get wireName => "onboarding_need_help_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class SupportLinkOpenedEvent extends ProductAnalyticsEvent {
  final SupportChannel channel;
  final OnboardingSurface surface;
  const SupportLinkOpenedEvent({required this.channel, required this.surface});

  @override
  String get wireName => "onboarding_support_link_opened";

  @override
  Map<String, String> get parameters => {"channel": channel.wireValue, "surface": surface.wireValue};
}

final class WhyBridgeOpenedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const WhyBridgeOpenedEvent({required this.surface});

  @override
  String get wireName => "onboarding_why_bridge_opened";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class InstallCommandCopiedEvent extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;
  const InstallCommandCopiedEvent({required this.method, required this.os, required this.surface});

  @override
  String get wireName => "bridge_install_command_copied";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class InstallCommandSharedEvent extends ProductAnalyticsEvent {
  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;
  const InstallCommandSharedEvent({required this.method, required this.os, required this.surface});

  @override
  String get wireName => "bridge_install_command_shared";

  @override
  Map<String, String> get parameters => {
    "method": method.wireValue,
    "os": os.wireValue,
    "surface": surface.wireValue,
  };
}

final class RunCommandCopiedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const RunCommandCopiedEvent({required this.surface});

  @override
  String get wireName => "bridge_run_command_copied";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class RunCommandSharedEvent extends ProductAnalyticsEvent {
  final OnboardingSurface surface;
  const RunCommandSharedEvent({required this.surface});

  @override
  String get wireName => "bridge_run_command_shared";

  @override
  Map<String, String> get parameters => {"surface": surface.wireValue};
}

final class ProductScreenViewedEvent extends ProductAnalyticsEvent {
  final AnalyticsScreen screen;
  const ProductScreenViewedEvent({required this.screen});

  @override
  String get wireName => "product_screen_viewed";

  @override
  Map<String, String> get parameters => {"screen": screen.wireValue};
}

final class ProductAnalyticsEnvelope {
  final ProductAnalyticsEvent event;
  final DateTime occurredAtUtc;

  ProductAnalyticsEnvelope({required this.event, required DateTime occurredAtUtc})
    : occurredAtUtc = occurredAtUtc.toUtc();
}
