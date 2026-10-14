import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  test('forgetting credentials is a distinct server-only action', () {
    const action = McpForgetAuthenticationEntryAction(
      target: McpServerTarget(
        scope: McpSessionScope(sessionId: 'session'),
        serverKey: 'server',
      ),
    );
    expect(action.toJson()['type'], 'forgetAuthentication');
    expect(action.toJson().containsKey('action'), isFalse);
    expect(McpEntryAction.fromJson(action.toJson()), action);
    final json = action.toJson()
      ..['target'] = {
        'type': 'connectorOffer',
        'scope': {'type': 'harness'},
        'offerKey': 'server',
      };
    expect(() => McpEntryAction.fromJson(json), throwsA(isA<FormatException>()));
    expect(
      McpEntryActionResult.fromJson(const McpActionUnavailable(reason: McpActionUnavailableReason.busy).toJson()),
      const McpActionUnavailable(reason: McpActionUnavailableReason.busy),
    );
  });

  test('authentication availability and forgetting availability remain independent', () {
    for (final capability in [
      const McpAuthenticationCapabilityUnknown(),
      const McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.harness),
      const McpAuthenticationCapabilityUnavailable(reason: McpAuthenticationCapabilityUnavailableReason.notImplemented),
    ]) {
      expect(McpAuthenticationCapability.fromJson(capability.toJson()), capability);
    }
    expect(McpAuthenticationCapability.fromJson({'type': 'future'}), const McpAuthenticationCapabilityUnknown());
    expect(
      McpAuthenticationCapability.fromJson({'type': 'available', 'effectScope': 'future'}),
      const McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.unknown),
    );
    expect(
      McpAuthenticationCapability.fromJson({'type': 'unavailable', 'reason': 'future'}),
      const McpAuthenticationCapabilityUnavailable(reason: McpAuthenticationCapabilityUnavailableReason.unknown),
    );
    final server = McpInventoryEntry.fromJson({
      'type': 'server',
      'target': {
        'type': 'server',
        'scope': {'type': 'harness'},
        'serverKey': 'fixture',
      },
      'name': 'Fixture',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'unknown',
      'authentication': {'type': 'available', 'effectScope': 'harness'},
      'credentialForgetting': {'type': 'unavailable', 'reason': 'notSupported'},
      'tools': {'type': 'unavailable'},
      'actions': <String>[],
    }) as McpServerSnapshot;
    expect(server.authentication, isA<McpAuthenticationCapabilityAvailable>());
    expect(server.credentialForgetting, isA<McpAuthenticationCapabilityUnavailable>());
    expect(server.authorization, McpAuthorizationState.unknown);
    expect(McpInventoryEntry.fromJson(server.toJson()), server);
  });

  test('released v1.9.1 snapshots retain inventory with unknown new capabilities', () {
    final server = McpInventoryEntry.fromJson({
      'type': 'server',
      'target': {
        'type': 'server',
        'scope': {'type': 'session', 'sessionId': 'fixture'},
        'serverKey': 'server',
      },
      'name': 'Fixture',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'unknown',
      'tools': {'type': 'unavailable'},
      'actions': [
        {'action': 'reconnect', 'effectScope': 'session'},
      ],
    }) as McpServerSnapshot;
    expect(server.authentication, const McpAuthenticationCapabilityUnknown());
    expect(server.credentialForgetting, const McpAuthenticationCapabilityUnknown());
    expect(server.actions.single.action, McpServerAction.reconnect);
    expect(server.connection, const McpConnectionStatus(phase: McpConnectionPhase.connected));
  });

  test('server actions reject connector targets and retain authoritative read results', () {
    const request = McpEntryActionRequest(
      pluginId: 'fixture',
      action: McpServerEntryAction(
        target: McpServerTarget(
          scope: McpSessionScope(sessionId: 'session'),
          serverKey: 'server',
        ),
        action: McpServerAction.reconnect,
      ),
    );
    expect(McpEntryActionRequest.fromJson(request.toJson()), request);
    for (final type in [null, 'future', 'connectorSetup']) {
      final json = request.action.toJson()..['type'] = type;
      expect(() => McpEntryAction.fromJson(json), throwsA(isA<FormatException>()));
    }
    expect(
      () => McpEntryAction.fromJson({
        'type': 'server',
        'action': 'enable',
        'target': {
          'type': 'connectorOffer',
          'scope': {'type': 'harness'},
          'offerKey': 'offer',
          'serverKey': 'server',
        },
      }),
      throwsA(isA<FormatException>()),
    );
    const result = McpActionCompleted(
      inventory: McpInventoryUnavailable(
        scope: McpSessionScope(sessionId: 'session'),
        reason: McpInventoryUnavailableReason.readFailed,
        message: 'Unavailable',
      ),
    );
    expect(McpEntryActionResult.fromJson(result.toJson()), result);
    expect(McpEntryActionResult.fromJson({'type': 'future'}), const McpActionUnknown());
    final event = SesoriSseEvent.mcpInventoryChanged(
      pluginId: request.pluginId,
      scope: const McpSessionScope(sessionId: 'session'),
    );
    expect(SesoriSseEvent.fromJson(event.toJson()), event);
    final unknown = McpServerActionCapability.fromJson({'action': 'future', 'effectScope': 'future'});
    expect(unknown.action, McpServerAction.unknown);
    expect(unknown.effectScope, McpActionEffectScope.unknown);
  });

  test('wire targets distinguish a server from an equal-key connector offer', () {
    final server = McpEntryTarget.fromJson({
      'type': 'server',
      'serverKey': 'opaque-key',
      'scope': {'type': 'session', 'sessionId': 'session-1'},
    });
    final offer = McpEntryTarget.fromJson({
      'type': 'connectorOffer',
      'offerKey': 'opaque-key',
      'scope': {'type': 'session', 'sessionId': 'session-1'},
    });
    expect(server, isA<McpServerTarget>());
    expect(offer, isA<McpConnectorOfferTarget>());
    expect(server, isNot(offer));
    expect(server.scope, offer.scope);
    expect(server.toJson()['type'], 'server');
    expect(offer.toJson()['type'], 'connectorOffer');
  });

  test('unavailable tools remain distinct from an empty discovered catalog on the wire', () {
    final available = McpToolInventory.fromJson({'type': 'available', 'tools': <Object?>[]});
    final unavailable = McpToolInventory.fromJson({'type': 'unavailable'});
    final failed = McpToolInventory.fromJson({'type': 'failed', 'message': 'Discovery failed'});
    expect(available, const McpToolInventory.available(tools: []));
    expect(unavailable, const McpToolInventory.unavailable());
    expect(failed, const McpToolInventory.failed(message: 'Discovery failed'));
    expect(available, isNot(unavailable));
    expect(failed.toJson(), {'type': 'failed', 'message': 'Discovery failed'});
    for (final state in [available, unavailable, failed]) {
      expect(McpToolInventory.fromJson(state.toJson()), state);
    }
  });

  test('server authorization does not grant a tool permission or create configuration fields', () {
    final server = McpInventoryEntry.fromJson({
      'type': 'server',
      'actions': <String>[],
      'target': {
        'type': 'server',
        'scope': {'type': 'harness'},
        'serverKey': 'fixture',
      },
      'name': 'Fixture server',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'authenticated',
      'authentication': {'type': 'unknown'},
      'credentialForgetting': {'type': 'unknown'},
      'tools': {'type': 'available', 'tools': <Object?>[]},
    });
    expect(server, isA<McpServerSnapshot>());
    expect(server.toJson(), {
      'type': 'server',
      'actions': <String>[],
      'target': {
        'type': 'server',
        'scope': {'type': 'harness'},
        'serverKey': 'fixture',
      },
      'name': 'Fixture server',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'authenticated',
      'authentication': {'type': 'unknown'},
      'credentialForgetting': {'type': 'unknown'},
      'tools': {'type': 'available', 'tools': <Object?>[]},
    });
  });

  test('catalog unavailability leaves configured server inventory readable', () {
    final snapshot = McpInventoryResult.fromJson({
      'type': 'available',
      'scope': {'type': 'project', 'projectId': 'project-1'},
      'entries': [
        {
          'type': 'server',
          'actions': <String>[],
          'target': {
            'type': 'server',
            'scope': {'type': 'project', 'projectId': 'project-1'},
            'serverKey': 'fixture',
          },
          'name': 'Fixture server',
          'connection': {'type': 'status', 'phase': 'connected'},
          'authorization': 'unknown',
          'authentication': {'type': 'unknown'},
          'credentialForgetting': {'type': 'unknown'},
          'tools': {'type': 'unavailable'},
        },
      ],
      'servers': {'type': 'available'},
      'connectors': {'type': 'unavailable', 'message': 'Catalog requires sign-in'},
    });
    expect(snapshot, isA<McpInventorySnapshot>());
    final inventory = snapshot as McpInventorySnapshot;
    expect(inventory.servers, const McpCatalogAvailable());
    expect(inventory.scope, const McpScope.project(projectId: 'project-1'));
    expect(inventory.connectors, const McpCatalogAvailability.unavailable(message: 'Catalog requires sign-in'));
    final restored = McpInventoryResult.fromJson(snapshot.toJson()) as McpInventorySnapshot;
    expect(restored, snapshot);
    expect((restored.entries.single as McpServerSnapshot).serverTarget.serverKey, 'fixture');
  });

  test('unknown response variants and scalar states degrade without losing known inventory', () {
    expect(
      McpConnectionState.fromJson({'type': 'status', 'phase': 'reconnecting'}),
      const McpConnectionStatus(phase: McpConnectionPhase.unknown),
    );
    expect(McpConnectionState.fromJson({'type': 'future'}), const McpConnectionUnknown());
    expect(McpToolInventory.fromJson({'type': 'future'}), const McpToolsUnavailable());
    expect(McpCatalogAvailability.fromJson({'type': 'future'}), const McpCatalogUnknown());
    expect(McpInventoryEntry.fromJson({'type': 'future'}), const McpUnknownInventoryEntry());
    expect(McpInventoryResult.fromJson({'type': 'future'}), const McpInventoryUnknown());
    final unknownReason = McpInventoryResult.fromJson({
      'type': 'unavailable',
      'scope': {'type': 'harness'},
      'reason': 'future',
      'message': 'Unavailable',
    }) as McpInventoryUnavailable;
    expect(unknownReason.reason, McpInventoryUnavailableReason.unknown);
    final server = McpInventoryEntry.fromJson({
      'type': 'server',
      'actions': <String>[],
      'target': {
        'type': 'server',
        'scope': {'type': 'harness'},
        'serverKey': 'fixture',
      },
      'name': 'Fixture',
      'connection': {'type': 'future'},
      'authorization': 'future',
      'authentication': {'type': 'unknown'},
      'credentialForgetting': {'type': 'unknown'},
      'configuration': {'scope': 'future', 'mutability': 'future'},
      'tools': {'type': 'future'},
    }) as McpServerSnapshot;
    expect(server.authorization, McpAuthorizationState.unknown);
    expect(server.configuration!.scope, McpConfigurationScope.unknown);
    expect(server.configuration!.mutability, McpConfigurationMutability.unknown);
    final offer = McpInventoryEntry.fromJson({
      'type': 'connectorOffer',
      'target': {
        'type': 'connectorOffer',
        'scope': {'type': 'harness'},
        'offerKey': 'offer',
      },
      'name': 'Offer',
      'availability': 'future',
    }) as McpConnectorOfferSnapshot;
    expect(offer.availability, McpConnectorOfferAvailability.unknown);
  });

  test('server-section failure preserves readable offered connectors', () {
    final snapshot = McpInventoryResult.fromJson({
      'type': 'available',
      'scope': {'type': 'harness'},
      'entries': [
        {
          'type': 'connectorOffer',
          'target': {
            'type': 'connectorOffer',
            'scope': {'type': 'harness'},
            'offerKey': 'offer',
          },
          'name': 'Fixture offer',
          'availability': 'available',
        },
      ],
      'servers': {'type': 'unavailable', 'message': 'Server discovery failed'},
      'connectors': {'type': 'available'},
    }) as McpInventorySnapshot;
    final restored = McpInventoryResult.fromJson(snapshot.toJson()) as McpInventorySnapshot;
    expect(restored, snapshot);
    expect(restored.servers, isA<McpCatalogUnavailable>());
    expect(restored.connectors, isA<McpCatalogAvailable>());
    expect((restored.entries.single as McpConnectorOfferSnapshot).offerTarget.offerKey, 'offer');
  });
}
