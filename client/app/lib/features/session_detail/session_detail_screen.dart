import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/routing/imperative_pane_route.dart";
import "widgets/device_canvas_status_banner.dart";
import "widgets/session_detail_composer_controls.dart";

class const SessionDetailScreen({
  super.key,
  required final String projectId,
  required final bool auditView,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
  required final String? projectName,
  required final String sessionId,
  final String? sessionTitle,
  final bool readOnly = false,
  required final String? bridgeId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = _SessionDetailProvider(
      auditView: auditView,
      onBack: onBack,
      onClose: onClose,
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
        auditView: auditView,
        onBack: onBack,
        onClose: onClose,
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
  required final bool auditView,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => createSessionDetailCubit(
            claimProjectView: !auditView,
            locator: getIt,
            sessionId: sessionId,
            projectId: projectId,
            initialDeviceCanvasStatus: initialDeviceCanvasStatus,
          ),
        ),
      ],
      child: SessionDetailActivityOwner(
        routeSource: getIt<RouteSource>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        expectedDetailRoute: auditView ? AppRouteDef.archivedSessionDetail : AppRouteDef.sessionDetail,
        child: _MobileSessionDetailBody(
          auditView: auditView,
          onBack: onBack,
          onClose: onClose,
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
  required final bool auditView,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
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
        auditView: auditView,
        onBack: onBack,
        onClose: onClose,
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

class const _MobileSessionDetailBody({
  required final String? bridgeId,
  required final String projectId,
  required final bool auditView,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
  required final String? projectName,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isSplit = SessionSplitScope.maybeOf(context)?.isSplit ?? false;
    final isImperative = isImperativePaneRoute(context);
    final showLeading = !isSplit || isImperative;
    return SessionDetailPresentationScope(
      messageImageRepository: getIt.get<MessageImageRepository>,
      imageSaver: getIt.get<ImageSaver>,
      imageClipboard: getIt.get<ImageClipboard>,
      imageSharer: getIt.get<ImageSharer>,
      canShareImages: kIsWeb || defaultTargetPlatform != TargetPlatform.linux,
      openExternalLink: openExternalLink,
      openHarnessSettings: () => context.pushRoute(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
      ),
      openSession:
          ({
            required projectId,
            required sessionId,
            required sessionTitle,
            required readOnly,
          }) => context.pushRoute(
            auditView
                ? AppRoute.archivedSessionDetail(
                    projectId: projectId,
                    projectName: projectName,
                    sessionId: sessionId,
                    sessionTitle: sessionTitle,
                  )
                : AppRoute.sessionDetail(
                    bridgeId: bridgeId,
                    projectId: projectId,
                    projectName: projectName,
                    sessionId: sessionId,
                    readOnly: readOnly,
                    sessionTitle: sessionTitle,
                  ),
          ),
      child: SessionDetailBody(
        onClose: onClose,
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?ConnectionBanner.maybeFor(context),
            if (context.watch<SessionDetailCubit>().state case SessionDetailLoaded(:final deviceCanvas))
              DeviceCanvasStatusBanner(state: deviceCanvas, readOnly: readOnly || auditView),
          ],
        ),
        onBack:
            onBack ??
            (showLeading
                ? () => isImperative
                      ? context.pop()
                      : context.goRoute(
                          AppRoute.sessions(
                            projectId: projectId,
                            projectName: projectName,
                          ),
                        )
                : null),
        onShowDiffs: auditView
            ? null
            : () => context.pushRoute(
                AppRoute.sessionDiffs(
                  bridgeId: bridgeId,
                  projectId: projectId,
                  projectName: projectName,
                  sessionId: sessionId,
                ),
              ),
        bottomControlsBuilder: ({required context, required projectId, required sessionId, required state}) =>
            MobileSessionDetailComposerControls(
              projectId: projectId,
              sessionId: sessionId,
              state: state,
            ),
      ),
    );
  }
}
