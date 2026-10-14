import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

class _RecordingRouteDispatcher({required final List<String> _calls}) implements RouteDispatcher {
  final List<RouteStack> stacks = [];

  @override
  void dismissPopups() {}

  @override
  void replaceStack({required RouteStack stack}) {
    _calls.add("navigate");
    stacks.add(stack);
  }
}

void main() {
  test("a switch returns to the Projects root, then selects the computer", () async {
    final calls = <String>[];
    final selectedComputer = _MockSelectedComputerService();
    final routes = _RecordingRouteDispatcher(calls: calls);
    when(
      () => selectedComputer.select(bridgeId: "br_b", source: ComputerSwitchSource.menu),
    ).thenAnswer((_) async => calls.add("select"));

    await ComputerSwitchDispatcher(
      selectedComputerService: selectedComputer,
      routeDispatcher: routes,
    ).switchTo(bridgeId: "br_b", source: ComputerSwitchSource.menu);

    expect(calls, ["navigate", "select"]);
    expect(routes.stacks.single.paths, [const AppRoute.projects().buildPath()]);
  });
}
