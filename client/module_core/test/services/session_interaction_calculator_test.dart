import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = SessionInteractionCalculator();
  const config = ServerConnectionConfig(relayHost: "relay.example", authToken: null);
  const health = HealthResponse(healthy: true, version: "1.8.0", filesystemAccessDegraded: false);
  const connected = ConnectionStatus.connected(config: config, health: health);

  for (final setup in PluginSetupState.values) {
    for (final runtime in PluginRuntimeState.values) {
      test("$setup / $runtime admission", () {
        final state = calculator.calculate(
          pluginId: "harness",
          managementResult: managementFixture(setup: setup, runtime: runtime),
          connectionStatus: connected,
          previous: null,
        );
        expect(state.canInteract, setup == PluginSetupState.ready && runtime.isRoutable);
        if (runtime == PluginRuntimeState.disabled) {
          expect((state as SessionInteractionBlocked).reason, SessionInteractionBlockedReason.disabled);
        } else if (setup == PluginSetupState.authenticationRequired) {
          final blocked = state as SessionInteractionBlocked;
          expect(blocked.reason, SessionInteractionBlockedReason.authenticationRequired);
          expect(blocked.displayName, "Test harness");
          expect(blocked.actionHint, "Open harness settings");
        }
      });
    }
  }

  test("an outdated PATH runtime has its own blocked reason", () {
    final state = calculator.calculate(
      pluginId: "harness",
      managementResult: managementFixture(
        setup: PluginSetupState.runtimeOutdated,
        runtime: PluginRuntimeState.blocked,
      ),
      connectionStatus: connected,
      previous: null,
    );

    expect(
      state,
      isA<SessionInteractionBlocked>().having(
        (blocked) => blocked.reason,
        "reason",
        SessionInteractionBlockedReason.runtimeOutdated,
      ),
    );
  });

  test("missing harness never falls back to another ready entry", () {
    expect(
      calculator.calculate(
        pluginId: "not-registered",
        managementResult: managementFixture(setup: PluginSetupState.ready, runtime: PluginRuntimeState.active),
        connectionStatus: connected,
        previous: null,
      ),
      isA<SessionInteractionBlocked>().having(
        (state) => state.reason,
        "reason",
        SessionInteractionBlockedReason.missingHarness,
      ),
    );
  });

  test("loading, failure and unsupported remain distinct", () {
    for (final result in <PluginManagementLoadResult?>[null, const PluginManagementLoadResult.loading()]) {
      expect(
        calculator.calculate(
          pluginId: "harness",
          managementResult: result,
          connectionStatus: connected,
          previous: null,
        ),
        isA<SessionInteractionChecking>(),
      );
    }
    final loadError = ApiError.generic();
    expect(
      calculator.calculate(
        pluginId: "harness",
        managementResult: PluginManagementLoadResult.failure(error: loadError),
        connectionStatus: connected,
        previous: null,
      ),
      isA<SessionInteractionBlocked>()
          .having(
            (state) => state.reason,
            "reason",
            SessionInteractionBlockedReason.statusCheckFailed,
          )
          .having((state) => state.refreshError, "original error", same(loadError)),
    );
    expect(
      calculator.calculate(
        pluginId: "harness",
        managementResult: const PluginManagementLoadResult.unsupported(),
        connectionStatus: connected,
        previous: null,
      ),
      isA<SessionInteractionLegacyUnverified>(),
    );
  });

  test("disconnect and reconnect preserve availability until management reports a result", () {
    final previousStates = [
      const SessionInteractionState.available(refreshError: null),
      const SessionInteractionState.legacyUnverified(),
      const SessionInteractionState.checking(),
      for (final reason in SessionInteractionBlockedReason.values)
        SessionInteractionState.blocked(
          reason: reason,
          displayName: "Test harness",
          actionHint: null,
          refreshError: null,
        ),
    ];
    for (final status in [
      const ConnectionStatus.disconnected(),
      const ConnectionStatus.connectionLost(config: config),
      const ConnectionStatus.reconnecting(config: config),
      const ConnectionStatus.bridgeOffline(config: config, health: health),
      connected,
    ]) {
      for (final result in <PluginManagementLoadResult?>[null, const PluginManagementLoadResult.loading()]) {
        for (final previous in previousStates) {
          expect(
            calculator.calculate(
              pluginId: "harness",
              managementResult: result,
              connectionStatus: status,
              previous: previous,
            ),
            previous,
            reason: "$status / $result must preserve $previous",
          );
        }
      }
    }
  });

  test("a confirmed disable after reconnect replaces previous availability", () {
    final result = calculator.calculate(
      pluginId: "harness",
      managementResult: managementFixture(setup: PluginSetupState.ready, runtime: PluginRuntimeState.disabled),
      connectionStatus: connected,
      previous: const SessionInteractionState.available(refreshError: null),
    );
    expect(
      result,
      isA<SessionInteractionBlocked>().having(
        (state) => state.reason,
        "reason",
        SessionInteractionBlockedReason.disabled,
      ),
    );
    expect(result.canInteract, isFalse);
  });

  test("retained refresh error preserves the decision and original error", () {
    final error = ApiError.generic();
    final fixture = managementFixture(
      setup: PluginSetupState.ready,
      runtime: PluginRuntimeState.degraded,
    ) as PluginManagementLoadResultSupported;
    final result = calculator.calculate(
      pluginId: "harness",
      managementResult: PluginManagementLoadResult.supported(response: fixture.response, refreshError: error),
      connectionStatus: connected,
      previous: null,
    );
    expect(result.canInteract, isTrue);
    expect((result as SessionInteractionAvailable).refreshError, same(error));
  });
}

PluginManagementLoadResult managementFixture({
  required PluginSetupState setup,
  required PluginRuntimeState runtime,
  String pluginId = "harness",
}) => PluginManagementLoadResult.supported(
  response: PluginManagementResponse(
    snapshotToken: "test",
    bridgeId: "bridge",
    defaultPluginId: pluginId,
    defaultIdleTimeoutMins: 45,
    plugins: [
      PluginManagementMetadata(
        setup: PluginSetupMetadata(
          id: pluginId,
          displayName: "Test harness",
          state: setup,
          runtimeVersion: null,
          actionHint: "Open harness settings",
        ),
        runtimeState: runtime,
        workState: PluginManagementWorkState.idle,
        idleTimeoutMins: 45,
        hasIdleTimeoutOverride: false,
        managementCapabilities: const {},
        actionHint: null,
      ),
    ],
  ),
  refreshError: null,
);
