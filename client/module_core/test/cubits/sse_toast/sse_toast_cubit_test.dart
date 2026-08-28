import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/cubits/sse_toast/sse_toast_cubit.dart";
import "package:sesori_dart_core/src/cubits/sse_toast/sse_toast_state.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("SseToastCubit", () {
    late MockConnectionService connectionService;
    late MockRouteSource routeSource;
    late StreamController<SseEvent> events;

    setUp(() {
      connectionService = MockConnectionService();
      routeSource = MockRouteSource(initialRoute: AppRouteDef.projects, currentLocation: "/projects");
      events = StreamController<SseEvent>.broadcast();
      when(() => connectionService.events).thenAnswer((_) => events.stream);
    });

    tearDown(() async {
      await events.close();
      await routeSource.dispose();
    });

    SseToastCubit buildCubit() => SseToastCubit(
      connectionService: connectionService,
      routeSource: routeSource,
    );

    blocTest<SseToastCubit, SseToastState>(
      "shows a toast with parsed variant and monotonic sequence for repeated equal guidance",
      build: buildCubit,
      act: (cubit) {
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(
              sessionID: null,
              title: "Pi login required",
              message: "Run /login",
              variant: "warning",
            ),
          ),
        );
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(
              sessionID: null,
              title: "Pi login required",
              message: "Run /login",
              variant: "warning",
            ),
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
        SseEvent(
          data: const SesoriSseEvent.tuiToastShow(
            sessionID: null,
            title: "Notice",
            message: "  ",
            variant: "sparkle",
          ),
        ),
      ),
      expect: () => const [
        SseToastState.show(sequence: 1, title: null, message: "Notice", variant: SseToastVariant.info),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "normalizes a whitespace-only title to null when the message carries the text",
      build: buildCubit,
      act: (cubit) => events.add(
        SseEvent(
          data: const SesoriSseEvent.tuiToastShow(
            sessionID: null,
            title: "  ",
            message: "Run /login",
            variant: "warning",
          ),
        ),
      ),
      expect: () => const [
        SseToastState.show(sequence: 1, title: null, message: "Run /login", variant: SseToastVariant.warning),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "shows session-attributed toasts only on the matching session route",
      build: buildCubit,
      act: (cubit) async {
        const toast = SesoriSseEvent.tuiToastShow(
          sessionID: "session-1",
          title: "Pi",
          message: "Extension finished",
          variant: "success",
        );
        events.add(SseEvent(data: toast));
        await Future<void>.delayed(Duration.zero);
        routeSource.emitRoute(AppRouteDef.sessionDetail);
        routeSource.currentLocation = "/projects/project-1/sessions/session-2";
        events.add(SseEvent(data: toast));
        await Future<void>.delayed(Duration.zero);
        routeSource.currentLocation = "/projects/project-1/sessions/session-1";
        events.add(SseEvent(data: toast));
        await Future<void>.delayed(Duration.zero);
        routeSource.emitRoute(AppRouteDef.sessionDiffs);
        routeSource.currentLocation = "/projects/project-1/sessions/session-1/diffs";
        events.add(SseEvent(data: toast));
      },
      expect: () => const [
        SseToastState.show(
          sequence: 1,
          title: "Pi",
          message: "Extension finished",
          variant: SseToastVariant.success,
        ),
        SseToastState.show(
          sequence: 2,
          title: "Pi",
          message: "Extension finished",
          variant: SseToastVariant.success,
        ),
      ],
    );

    blocTest<SseToastCubit, SseToastState>(
      "drops toasts with no renderable text and non-toast events",
      build: buildCubit,
      act: (cubit) {
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(
              sessionID: null,
              title: null,
              message: null,
              variant: "error",
            ),
          ),
        );
        events.add(
          SseEvent(
            data: const SesoriSseEvent.tuiToastShow(
              sessionID: null,
              title: " ",
              message: "",
              variant: null,
            ),
          ),
        );
        events.add(SseEvent(data: const SesoriSseEvent.projectUpdated(projectID: null, updatedAt: null)));
      },
      expect: () => const <SseToastState>[],
    );
  });
}
