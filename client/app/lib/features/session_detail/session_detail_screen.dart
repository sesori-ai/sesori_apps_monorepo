import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/session_detail_body.dart";

class const SessionDetailScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final String sessionId,
  final String? sessionTitle,
  final bool readOnly = false,
  required final String? bridgeId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = _SessionDetailProvider(
      projectId: projectId,
      projectName: projectName,
      sessionId: sessionId,
      sessionTitle: sessionTitle,
      readOnly: readOnly,
      bridgeId: null,
      initialDeviceCanvasStatus: null,
    );
    final expectedBridgeId = bridgeId;
    if (expectedBridgeId == null) return content;

    return BlocProvider(
      key: ValueKey(("device-canvas-link", expectedBridgeId)),
      create: (_) => DeviceCanvasSessionLinkCubit(
        service: getIt<DeviceCanvasService>(),
        registeredBridgesService: getIt<RegisteredBridgesService>(),
        connectionService: getIt<ConnectionService>(),
        bridgeId: expectedBridgeId,
        projectId: projectId,
        sessionId: sessionId,
      ),
      child: _DeviceCanvasSessionLinkGate(
        projectId: projectId,
        projectName: projectName,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
      ),
    );
  }
}

class const DeviceCanvasSessionDetailScreen({
  super.key,
  required final String sessionId,
  required final bool readOnly,
  required final String bridgeId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(("device-canvas-link", bridgeId, sessionId)),
      create: (_) => DeviceCanvasSessionLinkCubit(
        service: getIt<DeviceCanvasService>(),
        registeredBridgesService: getIt<RegisteredBridgesService>(),
        connectionService: getIt<ConnectionService>(),
        bridgeId: bridgeId,
        projectId: null,
        sessionId: sessionId,
      ),
      child: _DeviceCanvasSessionRouteResolver(
        sessionId: sessionId,
        readOnly: readOnly,
      ),
    );
  }
}

class const _DeviceCanvasSessionRouteResolver({
  required final String sessionId,
  required final bool readOnly,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeviceCanvasSessionLinkCubit, DeviceCanvasSessionLinkState>(
      listenWhen: (_, current) => current is DeviceCanvasSessionLinkVerified,
      listener: (context, state) {
        if (state is! DeviceCanvasSessionLinkVerified) return;
        final projectId = state.status.projectId;
        if (projectId == null) return;
        final detailRoute = AppRoute.sessionDetail(
          projectId: projectId,
          projectName: null,
          sessionId: sessionId,
          sessionTitle: null,
          readOnly: readOnly,
          bridgeId: state.status.bridgeId,
        );
        getIt<RouteDispatcher>().replaceStack(
          stack: RouteStack(
            paths: [
              const AppRoute.projects().buildPath(),
              AppRoute.sessions(projectId: projectId, projectName: null).buildPath(),
              detailRoute.buildPath(),
            ],
          ),
        );
      },
      builder: (context, state) => switch (state) {
        DeviceCanvasSessionLinkUnavailable() => _DeviceCanvasLinkScaffold(
          sessionTitle: null,
          child: _DeviceCanvasLinkUnavailable(
            onRetry: context.read<DeviceCanvasSessionLinkCubit>().verify,
          ),
        ),
        DeviceCanvasSessionLinkWaiting() || DeviceCanvasSessionLinkVerified() => _DeviceCanvasLinkScaffold(
          sessionTitle: null,
          child: PregoLaunchStatus(
            semanticsLabel: context.loc.deviceCanvasLinkWaiting,
            messages: [context.loc.deviceCanvasLinkWaiting],
          ),
        ),
      },
    );
  }
}

class const _SessionDetailProvider({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final String? bridgeId,
  required final DeviceCanvasSessionStatusResponse? initialDeviceCanvasStatus,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionDetailCubit(
        getIt<ConnectionService>(),
        loadService: getIt<SessionDetailLoadService>(),
        promptDispatcher: getIt<SessionRepository>(),
        permissionRepository: getIt<PermissionRepository>(),
        sessionViewingService: getIt<SessionViewingService>(),
        projectViewingService: getIt<ProjectViewingService>(),
        lifecycleSource: getIt<LifecycleSource>(),
        composerDraftRepository: getIt<ComposerDraftRepository>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        sessionId: sessionId,
        projectId: projectId,
        notificationCanceller: getIt<NotificationCanceller>(),
        failureReporter: getIt<FailureReporter>(),
        deviceCanvasService: getIt<DeviceCanvasService>(),
        initialDeviceCanvasStatus: initialDeviceCanvasStatus,
      ),
      child: _SessionActivityAnalyticsOwner(
        child: SessionDetailBody(
          projectId: projectId,
          projectName: projectName,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
          bridgeId: bridgeId,
        ),
      ),
    );
  }
}

class const _DeviceCanvasSessionLinkGate({
  required final String projectId,
  required final String? projectName,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceCanvasSessionLinkCubit>().state;
    return switch (state) {
      DeviceCanvasSessionLinkWaiting() => _DeviceCanvasLinkScaffold(
        sessionTitle: sessionTitle,
        child: PregoLaunchStatus(
          semanticsLabel: context.loc.deviceCanvasLinkWaiting,
          messages: [context.loc.deviceCanvasLinkWaiting],
        ),
      ),
      DeviceCanvasSessionLinkUnavailable() => _DeviceCanvasLinkScaffold(
        sessionTitle: sessionTitle,
        child: _DeviceCanvasLinkUnavailable(
          onRetry: context.read<DeviceCanvasSessionLinkCubit>().verify,
        ),
      ),
      DeviceCanvasSessionLinkVerified(:final status) => _SessionDetailProvider(
        key: ValueKey((status.bridgeId, status.sessionId, status.projectId)),
        projectId: projectId,
        projectName: projectName,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        bridgeId: status.bridgeId,
        initialDeviceCanvasStatus: status,
      ),
    };
  }
}

class const _DeviceCanvasLinkScaffold({required final String? sessionTitle, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGlassScaffold(
      title: sessionTitle ?? context.loc.sessionDetailTitle,
      banner: ConnectionBanner.maybeFor(context),
      titleMode: PregoTopNavigationTitleMode.inline,
      onBack: () => context.pop(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }
}

class const _DeviceCanvasLinkUnavailable({required final Future<void> Function() onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.prego.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerRegular.link_off, size: 40, color: context.prego.colors.fgErrorPrimary),
            SizedBox(height: context.prego.spacing.md),
            Text(
              context.loc.deviceCanvasLinkUnavailable,
              textAlign: TextAlign.center,
              style: context.prego.textTheme.textLg.bold,
            ),
            SizedBox(height: context.prego.spacing.lg),
            PregoButtonsSolid(
              label: context.loc.sessionDetailRetry,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.md,
              onPressed: () => unawaited(onRetry()),
            ),
          ],
        ),
      ),
    );
  }
}

class const _SessionActivityAnalyticsOwner({required final Widget child}) extends StatefulWidget {
  @override
  State<_SessionActivityAnalyticsOwner> createState() => _SessionActivityAnalyticsOwnerState();
}

class _SessionActivityAnalyticsOwnerState() extends State<_SessionActivityAnalyticsOwner> {
  SessionActivityAnalyticsListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRouteVisible = ModalRoute.of(context)?.isCurrent ?? false;
    final listener = _listener;
    if (listener == null) {
      _listener = SessionActivityAnalyticsListener(
        sessionDetailCubit: context.read<SessionDetailCubit>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        initialRouteVisible: isRouteVisible,
      );
    } else {
      listener.setRouteVisible(isVisible: isRouteVisible);
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) unawaited(listener.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
