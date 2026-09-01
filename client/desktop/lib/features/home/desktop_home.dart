import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// First desktop supervision surface: account, bridge state, lifecycle
/// controls, diagnostics, and device-local sign-out.
class const DesktopHome({required final AuthUser? user, super.key}) extends StatelessWidget {
  static const String _appName = "Sesori";
  static const String _bridgeSupervision = "Bridge supervision";
  static const String _openLogs = "Open Logs";
  static const String _takeOver = "Take Over";
  static const String _recentBridgeOutput = "Recent bridge output";
  static const String _signedIn = "Signed in";
  static const String _signOut = "Sign out";

  @override
  Widget build(BuildContext context) {
    final BridgeControlState state = context.watch<BridgeControlCubit>().state;
    final BridgeControlCubit controls = context.read<BridgeControlCubit>();
    final ConnectionOverlayState relayConnection = context.watch<ConnectionOverlayCubit>().state;
    final List<BridgeProcessLogEntry> crashLogs = switch (state.processState) {
      BridgeProcessCrashGiveUp(:final recentLogs) => recentLogs,
      BridgeProcessStopped() ||
      BridgeProcessLoginRequired() ||
      BridgeProcessStarting() ||
      BridgeProcessRunning() ||
      BridgeProcessStopping() ||
      BridgeProcessContention() ||
      BridgeProcessCrashRetryScheduled() => const <BridgeProcessLogEntry>[],
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.prego.spacing.x2l),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AccountHeader(user: user),
                  SizedBox(height: context.prego.spacing.x2l),
                  _SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(_bridgeSupervision, style: context.prego.textTheme.textLg.bold),
                        SizedBox(height: context.prego.spacing.md),
                        Text(state.statusLabel, style: context.prego.textTheme.textXl.medium),
                        SizedBox(height: context.prego.spacing.xl),
                        _StatusRow(label: "Desired state", value: _desiredStateLabel(state.desiredState)),
                        _StatusRow(
                          label: "Control channel",
                          value: state.controlStatus.helperOnline ? "Online" : "Offline",
                        ),
                        _StatusRow(
                          label: "Registration",
                          value: state.controlStatus.bridgeId == null ? "Not registered" : "Registered",
                        ),
                        _StatusRow(label: "Supervised relay", value: _relayLabel(state.controlStatus.relay)),
                        _StatusRow(label: "Desktop relay client", value: _connectionLabel(relayConnection)),
                        _StatusRow(label: "Plugin health", value: _pluginLabel(state.controlStatus.plugin)),
                        _StatusRow(
                          label: "Active sessions",
                          value: state.controlStatus.activeSessionCount.toString(),
                        ),
                        _StatusRow(
                          label: "Launch at login",
                          value: state.launchAtLoginEnabled ? "On" : "Off",
                        ),
                        SizedBox(height: context.prego.spacing.xl),
                        Wrap(
                          spacing: context.prego.spacing.md,
                          runSpacing: context.prego.spacing.md,
                          children: <Widget>[
                            if (state.canTakeOver)
                              OutlinedButton(
                                onPressed: state.activity.locksCommands ? null : () => unawaited(controls.takeOver()),
                                child: const Text(_takeOver),
                              ),
                            FilledButton(
                              onPressed: state.activity.locksCommands ? null : () => unawaited(controls.toggleBridge()),
                              child: Text(
                                state.toggleTarget == BridgeProcessDesiredState.off
                                    ? "Turn Bridge Off"
                                    : "Turn Bridge On",
                              ),
                            ),
                            OutlinedButton(
                              onPressed: state.activity.locksCommands
                                  ? null
                                  : () => unawaited(controls.toggleLaunchAtLogin()),
                              child: Text(
                                state.launchAtLoginEnabled ? "Disable Launch at Login" : "Enable Launch at Login",
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => unawaited(controls.openLogs()),
                              child: const Text(_openLogs),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (crashLogs.isNotEmpty) ...<Widget>[
                    SizedBox(height: context.prego.spacing.xl),
                    _CrashLogs(entries: crashLogs),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _desiredStateLabel(BridgeProcessDesiredState state) => switch (state) {
    BridgeProcessDesiredState.off => "Off",
    BridgeProcessDesiredState.on => "On",
  };

  static String _relayLabel(ControlRelayConnectionState state) => switch (state) {
    ControlRelayConnectionState.connected => "Connected",
    ControlRelayConnectionState.connecting => "Connecting",
    ControlRelayConnectionState.disconnected => "Disconnected",
    ControlRelayConnectionState.takenOver => "Taken over",
    ControlRelayConnectionState.unknown => "Unknown",
  };

  static String _connectionLabel(ConnectionOverlayState state) => switch (state) {
    ConnectionOverlayHidden(:final connected) => connected ? "Connected" : "Disconnected",
    ConnectionOverlayReconnecting() => "Reconnecting",
    ConnectionOverlayConnectionLost() => "Connection lost",
    ConnectionOverlayBridgeOffline() => "Bridge offline",
  };

  static String _pluginLabel(ControlPluginHealthState state) => switch (state) {
    ControlPluginHealthState.healthy => "Healthy",
    ControlPluginHealthState.degraded => "Degraded",
    ControlPluginHealthState.unknown => "Unknown",
  };
}

class const _AccountHeader({required final AuthUser? user}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(DesktopHome._appName, style: context.prego.textTheme.displayXs.bold),
              SizedBox(height: context.prego.spacing.xs),
              Text(_accountLabel(), style: context.prego.textTheme.textSm.regular),
            ],
          ),
        ),
        TextButton(
          onPressed: () => unawaited(context.read<AuthGateCubit>().signOut()),
          child: const Text(DesktopHome._signOut),
        ),
      ],
    );
  }

  String _accountLabel() {
    final AuthUser? user = this.user;
    if (user == null) {
      return DesktopHome._signedIn;
    }
    final String? username = user.providerUsername?.trim();
    final String account = (username == null || username.isEmpty) ? user.providerUserId : username;
    return "Signed in as $account (${user.provider.label})";
  }
}

class const _SurfaceCard({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.prego.colors.bgSurface2,
        border: Border.all(color: context.prego.colors.borderSecondary),
        borderRadius: BorderRadius.circular(context.prego.radius.lg),
        boxShadow: context.prego.shadows.sm,
      ),
      child: Padding(
        padding: EdgeInsets.all(context.prego.spacing.xl),
        child: child,
      ),
    );
  }
}

class const _StatusRow({required final String label, required final String value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.prego.spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ),
          Text(value, style: context.prego.textTheme.textSm.medium),
        ],
      ),
    );
  }
}

class const _CrashLogs({required final List<BridgeProcessLogEntry> entries}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Iterable<BridgeProcessLogEntry> visibleEntries = entries.skip(entries.length > 8 ? entries.length - 8 : 0);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(DesktopHome._recentBridgeOutput, style: context.prego.textTheme.textMd.bold),
          SizedBox(height: context.prego.spacing.md),
          SelectableText(
            visibleEntries.map((entry) => "[${entry.source.name}] ${entry.message}").join("\n"),
            style: context.prego.textTheme.textXs.regular,
          ),
        ],
      ),
    );
  }
}
