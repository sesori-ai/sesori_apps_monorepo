import "package:flutter/semantics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/device_canvas_status_banner.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("shows connection and assignment summary", (tester) async {
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "session-1"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    expect(find.text("Device Canvas"), findsOneWidget);
    expect(find.text("1 available, 1 assigned here"), findsOneWidget);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel("Device Canvas. 1 available, 1 assigned here"),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets("confirms reassignment before invoking the cubit", (tester) async {
    final semantics = tester.ensureSemantics();
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "other-session"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Assigned to Other session"), findsOneWidget);
    expect(find.bySemanticsLabel("Reassign iPhone"), findsOneWidget);
    await tester.tap(find.text("Reassign"));
    await tester.pumpAndSettle();
    expect(find.text("Reassign iPhone?"), findsOneWidget);
    await tester.tap(find.text("Reassign").last);
    await tester.pumpAndSettle();

    expect(cubit.claims, [(deviceKey: "device-1", reassign: true)]);
    semantics.dispose();
  });

  testWidgets("read-only sessions do not expose assignment actions", (tester) async {
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "session-1"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas, readOnly: true));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Assign"), findsNothing);
    expect(find.text("Reassign"), findsNothing);
    expect(find.text("Release"), findsNothing);
    expect(find.text("Assignments are read-only in this session."), findsOneWidget);
  });

  testWidgets("does not expose raw identifiers when display metadata is missing", (tester) async {
    final status = _status(claimSessionId: "sensitive-session").copyWith(
      devices: const [
        DeviceCanvasDeviceStatus(
          deviceKey: "sensitive-device-key",
          descriptor: null,
          claim: DeviceCanvasClaimStatus(
            projectId: "project-2",
            sessionId: "sensitive-session",
            revision: 1,
            claimedAt: 1,
            displayTitle: null,
          ),
        ),
      ],
    );
    final deviceCanvas = DeviceCanvasSessionReady(
      status: status,
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Unnamed device"), findsOneWidget);
    expect(find.textContaining("Assigned to another session"), findsOneWidget);
    expect(find.textContaining("sensitive-device-key"), findsNothing);
    expect(find.textContaining("sensitive-session"), findsNothing);
  });

  testWidgets("failed status can be retried", (tester) async {
    final deviceCanvas = DeviceCanvasSessionFailure(error: ApiError.generic());
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pump();

    expect(cubit.refreshes, 1);
  });
}

Widget _app({
  required _FakeSessionDetailCubit cubit,
  required DeviceCanvasSessionState deviceCanvas,
  bool readOnly = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (_, _) => Scaffold(
          body: DeviceCanvasStatusBanner(state: deviceCanvas, readOnly: readOnly),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return BlocProvider<SessionDetailCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _FakeSessionDetailCubit(DeviceCanvasSessionState initialDeviceCanvas)
    extends Cubit<SessionDetailState>
    implements SessionDetailCubit {
  final List<({String deviceKey, bool reassign})> claims = [];
  final List<String> releases = [];
  int refreshes = 0;

  this : super(_loaded(initialDeviceCanvas));

  @override
  Future<void> claimDeviceCanvasDevice({required String deviceKey, required bool reassign}) async {
    claims.add((deviceKey: deviceKey, reassign: reassign));
  }

  @override
  Future<void> releaseDeviceCanvasDevice({required String deviceKey}) async {
    releases.add(deviceKey);
  }

  @override
  Future<void> refreshDeviceCanvas() async {
    refreshes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SessionDetailState _loaded(DeviceCanvasSessionState deviceCanvas) => SessionDetailState.loaded(
  messages: const [],
  olderMessagesCursor: null,
  streamingText: const {},
  sessionStatus: const SessionStatus.idle(),
  pendingQuestions: const [],
  pendingPermissions: const [],
  sessionTitle: "Session",
  pluginId: "opencode",
  supportsPromptAttachments: false,
  agent: null,
  assistantAgentModel: null,
  children: const [],
  childStatuses: const {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: const [],
  sendingSubmission: null,
  availableAgents: const [],
  availableProviders: const [],
  availableCommands: const [],
  selectedAgent: "build",
  selectedAgentModel: null,
  stagedCommand: null,
  isRefreshing: false,
  retryErrorMessage: null,
  deviceCanvas: deviceCanvas,
);

DeviceCanvasSessionStatusResponse _status({required String? claimSessionId}) {
  return DeviceCanvasSessionStatusResponse(
    bridgeId: "bridge-1",
    sessionId: "session-1",
    sessionAvailable: true,
    projectId: "project-1",
    connection: DeviceCanvasClientConnectionStatus.connected,
    devices: [
      DeviceCanvasDeviceStatus(
        deviceKey: "device-1",
        descriptor: const DeviceCanvasClientDescriptor(
          platform: DeviceCanvasClientPlatform.ios,
          displayName: "iPhone",
          runtimeDescription: "iOS 26",
          modelDescription: "iPhone",
          dimensions: DeviceCanvasClientDimensions(width: 1179, height: 2556),
          orientation: DeviceCanvasClientOrientation.portrait,
          capabilities: DeviceCanvasClientCapabilities(localView: true),
        ),
        claim: claimSessionId == null
            ? null
            : DeviceCanvasClaimStatus(
                projectId: "project-2",
                sessionId: claimSessionId,
                revision: 1,
                claimedAt: 1,
                displayTitle: "Other session",
              ),
      ),
    ],
    supportsReassignment: true,
  );
}
