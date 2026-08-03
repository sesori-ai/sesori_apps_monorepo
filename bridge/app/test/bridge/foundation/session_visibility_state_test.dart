import "dart:async";

import "package:sesori_bridge/src/bridge/foundation/session_visibility_state.dart";
import "package:test/test.dart";

void main() {
  test("creation blocks only later same-plugin catalog writers", () async {
    final state = SessionVisibilityState();
    final creation = state.reserveSessionCreation(pluginId: "reserved");
    final entered = Completer<void>();
    final reservedWrite = state.withCatalogWrite(pluginId: "reserved", body: () async => entered.complete());
    await state.withCatalogWrite(pluginId: "unrelated", body: () async {});
    expect(entered.isCompleted, isFalse);
    state.releaseSessionCreation(reservation: creation);
    await reservedWrite;
  });

  test("creation commit drains a catalog writer that acquired first", () async {
    final state = SessionVisibilityState();
    final releaseWrite = Completer<void>();
    final catalogWrite = state.withCatalogWrite(pluginId: "plugin", body: () => releaseWrite.future);
    await Future<void>.delayed(Duration.zero);
    final creation = state.reserveSessionCreation(pluginId: "plugin");
    var committed = false;
    final commitFuture = state.withSessionCreationCommit(reservation: creation, body: () async => committed = true);
    await Future<void>.delayed(Duration.zero);
    expect(committed, isFalse);
    releaseWrite.complete();
    await catalogWrite;
    await commitFuture;
    expect(committed, isTrue);
    state.releaseSessionCreation(reservation: creation);
  });
}
