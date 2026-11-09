import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _Repository repository;
  late StreamController<DesktopAppMenuCommand> menu;
  late DesktopTextSizeCubit cubit;

  setUpAll(() => registerFallbackValue(DesktopTextSize.standard));
  setUp(() {
    repository = _Repository();
    menu = StreamController<DesktopAppMenuCommand>.broadcast();
    when(() => repository.writeTextSize(size: any(named: "size"))).thenAnswer((_) async {});
  });
  tearDown(() async {
    await cubit.close();
    await menu.close();
  });

  DesktopTextSizeCubit create({DesktopTextSize initialSize = DesktopTextSize.standard}) =>
      cubit = DesktopTextSizeCubit(repository: repository, appMenu: _Menu(menu.stream), initialSize: initialSize);

  test("starts at the restored size without writing it back", () async {
    create(initialSize: DesktopTextSize.large);
    await pumpEventQueue();
    expect(cubit.state, DesktopTextSize.large);
    verifyNever(() => repository.writeTextSize(size: any(named: "size")));
  });

  test("a pick persists, and picking the current size again does not", () async {
    create();
    await cubit.select(size: DesktopTextSize.small);
    await cubit.select(size: DesktopTextSize.small);
    expect(cubit.state, DesktopTextSize.small);
    verify(() => repository.writeTextSize(size: DesktopTextSize.small)).called(1);
  });

  test("steps up through every size and stops at the largest", () async {
    create(initialSize: DesktopTextSize.small);
    final sizes = <DesktopTextSize>[];
    for (var press = 0; press < 4; press++) {
      await cubit.increase();
      sizes.add(cubit.state);
    }
    expect(sizes, [DesktopTextSize.standard, DesktopTextSize.large, DesktopTextSize.larger, DesktopTextSize.larger]);
    verify(() => repository.writeTextSize(size: any(named: "size"))).called(3);
  });

  test("steps down through every size and stops at the smallest", () async {
    create(initialSize: DesktopTextSize.larger);
    final sizes = <DesktopTextSize>[];
    for (var press = 0; press < 4; press++) {
      await cubit.decrease();
      sizes.add(cubit.state);
    }
    expect(sizes, [DesktopTextSize.large, DesktopTextSize.standard, DesktopTextSize.small, DesktopTextSize.small]);
  });

  test("reset returns to the default size", () async {
    create(initialSize: DesktopTextSize.larger);
    await cubit.reset();
    expect(cubit.state, DesktopTextSize.standard);
    verify(() => repository.writeTextSize(size: DesktopTextSize.standard)).called(1);
  });

  test("app menu commands step the same setting", () async {
    create();
    menu.add(DesktopAppMenuCommand.increaseTextSize);
    await pumpEventQueue();
    expect(cubit.state, DesktopTextSize.large);
    menu.add(DesktopAppMenuCommand.resetTextSize);
    await pumpEventQueue();
    expect(cubit.state, DesktopTextSize.standard);
    menu.add(DesktopAppMenuCommand.decreaseTextSize);
    await pumpEventQueue();
    expect(cubit.state, DesktopTextSize.small);
    verify(() => repository.writeTextSize(size: any(named: "size"))).called(3);
  });

  test("quick steps are stored in order, so the last pick is the one kept", () async {
    final first = Completer<void>();
    when(() => repository.writeTextSize(size: DesktopTextSize.large)).thenAnswer((_) => first.future);
    create();
    final stored = <DesktopTextSize>[];
    when(
      () => repository.writeTextSize(size: DesktopTextSize.larger),
    ).thenAnswer((_) async => stored.add(DesktopTextSize.larger));
    unawaited(cubit.increase());
    final second = cubit.increase();
    await pumpEventQueue();
    expect(stored, isEmpty);
    first.complete();
    await second;
    expect(stored, [DesktopTextSize.larger]);
  });

  test("a failed write keeps the size on screen", () async {
    when(() => repository.writeTextSize(size: any(named: "size"))).thenThrow(StateError("disk full"));
    create();
    await cubit.increase();
    expect(cubit.state, DesktopTextSize.large);
  });
}

class _Repository() extends Mock implements DesktopInstanceRepository;

class _Menu(@override final Stream<DesktopAppMenuCommand> commands) implements DesktopAppMenu;
