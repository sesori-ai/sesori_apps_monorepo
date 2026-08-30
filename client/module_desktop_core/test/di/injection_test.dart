import "package:get_it/get_it.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  test("configureDesktopCoreDependencies registers supervision primitives on a fresh container", () {
    final GetIt getIt = GetIt.asNewInstance();

    expect(() => configureDesktopCoreDependencies(getIt), returnsNormally);
    expect(getIt.isRegistered<BridgeIdStorage>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessApi>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessRepository>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessLogStorage>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessLogTracker>(), isTrue);
    expect(getIt.isRegistered<BridgeProcessService>(), isTrue);
    expect(getIt.isRegistered<ControlChannelApi>(), isTrue);
    expect(getIt.isRegistered<ControlCommandRepository>(), isTrue);
    expect(getIt.isRegistered<ControlCommandService>(), isTrue);
    expect(getIt.isRegistered<DesktopInstanceApi>(), isTrue);
    expect(getIt.isRegistered<DesktopInstanceStorage>(), isTrue);
    expect(getIt.isRegistered<DesktopInstanceRepository>(), isTrue);
    expect(getIt.isRegistered<DesktopInstanceService>(), isTrue);
    expect(getIt.isRegistered<DesktopStartupOrchestrator>(), isTrue);
    expect(getIt.isRegistered<DesktopLogoutOrchestrator>(), isTrue);
  });
}
