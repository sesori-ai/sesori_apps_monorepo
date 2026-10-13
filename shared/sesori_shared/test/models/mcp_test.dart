import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  test('wire targets distinguish a server from an equal-key connector offer', () {
    final server = McpEntryTarget.fromJson({
      'type': 'server', 'serverKey': 'opaque-key',
      'scope': {'type': 'session', 'sessionId': 'session-1'},
    });
    final offer = McpEntryTarget.fromJson({
      'type': 'connectorOffer', 'offerKey': 'opaque-key',
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
      'target': {'type': 'server', 'scope': {'type': 'harness'}, 'serverKey': 'fixture'},
      'name': 'Fixture server',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'authenticated',
      'tools': {'type': 'available', 'tools': <Object?>[]},
    });
    expect(server, isA<McpServerSnapshot>());
    expect(server.toJson(), {
      'type': 'server',
      'target': {'type': 'server', 'scope': {'type': 'harness'}, 'serverKey': 'fixture'},
      'name': 'Fixture server',
      'connection': {'type': 'status', 'phase': 'connected'},
      'authorization': 'authenticated',
      'tools': {'type': 'available', 'tools': <Object?>[]},
    });
  });

  test('catalog unavailability leaves configured server inventory readable', () {
    final snapshot = McpInventoryResult.fromJson({
      'type': 'available', 'scope': {'type': 'project', 'projectId': 'project-1'},
      'entries': [
        {
          'type': 'server',
          'target': {'type': 'server', 'scope': {'type': 'project', 'projectId': 'project-1'}, 'serverKey': 'fixture'},
          'name': 'Fixture server',
          'connection': {'type': 'status', 'phase': 'connected'},
          'authorization': 'unknown',
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
    expect(McpConnectionState.fromJson({'type': 'status', 'phase': 'reconnecting'}),
        const McpConnectionStatus(phase: McpConnectionPhase.unknown));
    expect(McpConnectionState.fromJson({'type': 'future'}), const McpConnectionUnknown());
    expect(McpToolInventory.fromJson({'type': 'future'}), const McpToolsUnavailable());
    expect(McpCatalogAvailability.fromJson({'type': 'future'}), const McpCatalogUnknown());
    expect(McpInventoryEntry.fromJson({'type': 'future'}), const McpUnknownInventoryEntry());
    expect(McpInventoryResult.fromJson({'type': 'future'}), const McpInventoryUnknown());
    final unknownReason = McpInventoryResult.fromJson({
      'type': 'unavailable', 'scope': {'type': 'harness'}, 'reason': 'future', 'message': 'Unavailable',
    }) as McpInventoryUnavailable;
    expect(unknownReason.reason, McpInventoryUnavailableReason.unknown);
    final server = McpInventoryEntry.fromJson({
      'type': 'server', 'target': {'type': 'server', 'scope': {'type': 'harness'}, 'serverKey': 'fixture'},
      'name': 'Fixture', 'connection': {'type': 'future'}, 'authorization': 'future',
      'configuration': {'scope': 'future', 'mutability': 'future'}, 'tools': {'type': 'future'},
    }) as McpServerSnapshot;
    expect(server.authorization, McpAuthorizationState.unknown);
    expect(server.configuration!.scope, McpConfigurationScope.unknown);
    expect(server.configuration!.mutability, McpConfigurationMutability.unknown);
    final offer = McpInventoryEntry.fromJson({
      'type': 'connectorOffer', 'target': {'type': 'connectorOffer', 'scope': {'type': 'harness'}, 'offerKey': 'offer'},
      'name': 'Offer', 'availability': 'future',
    }) as McpConnectorOfferSnapshot;
    expect(offer.availability, McpConnectorOfferAvailability.unknown);
  });

  test('server-section failure preserves readable offered connectors', () {
    final snapshot = McpInventoryResult.fromJson({
      'type': 'available', 'scope': {'type': 'harness'},
      'entries': [{
        'type': 'connectorOffer', 'target': {'type': 'connectorOffer', 'scope': {'type': 'harness'}, 'offerKey': 'offer'},
        'name': 'Fixture offer', 'availability': 'available',
      }],
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
