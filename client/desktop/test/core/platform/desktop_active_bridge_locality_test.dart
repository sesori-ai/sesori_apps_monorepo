import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/desktop_active_bridge_locality.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

class _BridgeStatusTracker() extends Mock implements BridgeStatusTracker;

void main() {
  test("requires live helper and exact management bridge identity", () {
    final tracker = _BridgeStatusTracker();
    final locality = DesktopActiveBridgeLocality(statusTracker: tracker);

    when(() => tracker.status).thenReturn(BridgeControlStatus.offline);
    expect(locality.isLocalBridge(bridgeId: "bridge-1"), isFalse);

    when(() => tracker.status).thenReturn(BridgeControlStatus.offline.copyWith(bridgeId: "bridge-1"));
    expect(locality.isLocalBridge(bridgeId: "bridge-1"), isFalse);

    when(
      () => tracker.status,
    ).thenReturn(BridgeControlStatus.offline.copyWith(bridgeId: "bridge-1", helperOnline: true));
    expect(locality.isLocalBridge(bridgeId: "bridge-other"), isFalse);
    expect(locality.isLocalBridge(bridgeId: "bridge-1"), isTrue);

    when(() => tracker.status).thenReturn(BridgeControlStatus.offline.copyWith(bridgeId: "bridge-1"));
    expect(locality.isLocalBridge(bridgeId: "bridge-1"), isFalse);
  });
}
