import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/cubits/sse_toast/sse_toast_cubit.dart";
import "package:sesori_dart_core/src/cubits/sse_toast/sse_toast_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("SseToastCubit", () {
    late MockConnectionService connectionService;
    late StreamController<SseEvent> events;

    setUp(() {
      connectionService = MockConnectionService();
      events = StreamController<SseEvent>.broadcast();
      when(() => connectionService.events).thenAnswer((_) => events.stream);
    });

    tearDown(() async {
      await events.close();
    });

    SseToastCubit buildCubit() => SseToastCubit(connectionService);

    blocTest<SseToastCubit, SseToastState>(
      "shows a toast with parsed variant and monotonic sequence for repeated equal guidance",
      build: buildCubit,
      act: (cubit) {
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(title: "Pi login required", message: "Run /login", variant: "warning"),
          ),
        );
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(title: "Pi login required", message: "Run /login", variant: "warning"),
          ),
        );
      },
      expect: () => const [
        SseToastState.show(
          sequence: 1,
          title: "Pi login required",
          message: "Run /login",
          variant: SseToastVariant.warning,
        ),
        SseToastState.show(
          sequence: 2,
          title: "Pi login required",
          message: "Run /login",
          variant: SseToastVariant.warning,
        ),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "falls back to the title as message and info variant for unknown variants",
      build: buildCubit,
      act: (cubit) => events.add(
        SseEvent(data: const SesoriSseEvent.tuiToastShow(title: "Notice", message: "  ", variant: "sparkle")),
      ),
      expect: () => const [
        SseToastState.show(sequence: 1, title: null, message: "Notice", variant: SseToastVariant.info),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "normalizes a whitespace-only title to null when the message carries the text",
      build: buildCubit,
      act: (cubit) => events.add(
        SseEvent(data: const SesoriSseEvent.tuiToastShow(title: "  ", message: "Run /login", variant: "warning")),
      ),
      expect: () => const [
        SseToastState.show(sequence: 1, title: null, message: "Run /login", variant: SseToastVariant.warning),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "drops toasts with no renderable text and non-toast events",
      build: buildCubit,
      act: (cubit) {
        events.add(SseEvent(data: const SesoriSseEvent.tuiToastShow(title: null, message: null, variant: "error")));
        events.add(SseEvent(data: const SesoriSseEvent.tuiToastShow(title: " ", message: "", variant: null)));
        events.add(SseEvent(data: const SesoriSseEvent.projectUpdated(projectID: null, updatedAt: null)));
      },
      expect: () => const <SseToastState>[],
    );
  });
}
