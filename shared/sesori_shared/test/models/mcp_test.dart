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
      'connectors': {'type': 'unavailable', 'message': 'Catalog requires sign-in'},
    });
    expect(snapshot, isA<McpInventorySnapshot>());
    final inventory = snapshot as McpInventorySnapshot;
    expect(inventory.scope, const McpScope.project(projectId: 'project-1'));
    expect(inventory.connectors, const McpCatalogAvailability.unavailable(message: 'Catalog requires sign-in'));
    final restored = McpInventoryResult.fromJson(snapshot.toJson()) as McpInventorySnapshot;
    expect(restored, snapshot);
    expect((restored.entries.single as McpServerSnapshot).serverTarget.serverKey, 'fixture');
  });
}
