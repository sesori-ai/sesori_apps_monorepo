import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

class _Permission() extends Mock implements FileAccessPermission;
class _Window() extends Mock implements WindowHost;

void main() {
  late _Permission permission;
  late _Window window;
  late StreamController<WindowHostState> focus;
  late FileAccessCubit cubit;
  var status = FileAccessStatus.denied;

  setUp(() {
    permission = _Permission();
    window = _Window();
    focus = StreamController<WindowHostState>.broadcast(sync: true);
    status = FileAccessStatus.denied;
    when(permission.check).thenAnswer((_) async => status);
    when(permission.openSystemSettings).thenAnswer((_) async {});
    when(() => window.states).thenAnswer((_) => focus.stream);
    cubit = FileAccessCubit(permission: permission, windowHost: window);
  });
  tearDown(() async {
    await cubit.close();
    await focus.close();
  });

  test("denied prompt is optional and stays dismissed across focus refreshes", () async {
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.showPrompt, isTrue);
    cubit.dismiss();
    await cubit.openSystemSettings();
    focus.add(WindowHostState.unfocused);
    focus.add(WindowHostState.focused);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, FileAccessStatus.denied);
    expect(cubit.state.showPrompt, isFalse);
    verify(permission.check).called(2);
    verify(permission.openSystemSettings).called(1);
  });

  for (final next in [FileAccessStatus.granted, FileAccessStatus.unknown, FileAccessStatus.unsupported]) {
    test("focus refresh to $next hides the prompt", () async {
      await Future<void>.delayed(Duration.zero);
      status = next;
      focus.add(WindowHostState.focused);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, next);
      expect(cubit.state.showPrompt, isFalse);
    });
  }

  test("late older probe cannot replace a newer permission result", () async {
    await Future<void>.delayed(Duration.zero);
    final older = Completer<FileAccessStatus>();
    when(permission.check).thenAnswer((_) => older.future);
    final pending = cubit.refresh();
    when(permission.check).thenAnswer((_) async => FileAccessStatus.granted);
    await cubit.refresh();
    older.complete(FileAccessStatus.denied);
    await pending;
    expect(cubit.state.status, FileAccessStatus.granted);
  });

  test("closed owner unsubscribes and ignores in-flight completion", () async {
    await Future<void>.delayed(Duration.zero);
    final pending = Completer<FileAccessStatus>();
    when(permission.check).thenAnswer((_) => pending.future);
    final refresh = cubit.refresh();
    await cubit.close();
    pending.complete(FileAccessStatus.granted);
    await refresh;
    expect(focus.hasListener, isFalse);
    expect(cubit.state.status, FileAccessStatus.denied);
  });

  test("probe failure remains unknown; settings failure leaves the prompt usable", () async {
    when(permission.check).thenThrow(StateError("probe"));
    await cubit.refresh();
    expect(cubit.state.status, FileAccessStatus.unknown);
    when(permission.openSystemSettings).thenThrow(StateError("launcher"));
    await cubit.openSystemSettings();
    expect(cubit.state.dismissed, isFalse);
  });
}
