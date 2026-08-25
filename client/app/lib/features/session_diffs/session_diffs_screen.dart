import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/connection_banner.dart";
import "session_diffs_body.dart";

class const SessionDiffsScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? bridgeId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = _SessionDiffsProvider(sessionId: sessionId);
    final expectedBridgeId = bridgeId;
    if (expectedBridgeId == null) return content;

    return BlocProvider(
      key: ValueKey(("device-canvas-diffs-link", expectedBridgeId, sessionId)),
      create: (_) => DeviceCanvasSessionLinkCubit(
        service: getIt<DeviceCanvasService>(),
        registeredBridgesService: getIt<RegisteredBridgesService>(),
        connectionService: getIt<ConnectionService>(),
        bridgeId: expectedBridgeId,
        projectId: projectId,
        sessionId: sessionId,
      ),
      child: _DeviceCanvasSessionDiffsGate(child: content),
    );
  }
}

class const _SessionDiffsProvider({required final String sessionId}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiffCubit(
        sessionRepository: getIt<SessionRepository>(),
        connectionService: getIt<ConnectionService>(),
        loadedStateAnalyticsReporter: LoadedStateAnalyticsReporter.sessionDiff(
          productAnalyticsService: getIt<ProductAnalyticsService>(),
        ),
        sessionId: sessionId,
        staleRetryDelay: const Duration(seconds: 5),
      ),
      // SessionDiffsBody owns the PregoGlassScaffold so its bar subtitle can
      // react to the loaded file/addition/deletion stats.
      child: const SessionDiffsBody(),
    );
  }
}

class const _DeviceCanvasSessionDiffsGate({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<DeviceCanvasSessionLinkCubit>().state;
    return switch (state) {
      DeviceCanvasSessionLinkVerified() => child,
      DeviceCanvasSessionLinkWaiting() => _DeviceCanvasDiffsLinkScaffold(
        child: PregoLaunchStatus(
          semanticsLabel: context.loc.deviceCanvasLinkWaiting,
          messages: [context.loc.deviceCanvasLinkWaiting],
        ),
      ),
      DeviceCanvasSessionLinkUnavailable() => _DeviceCanvasDiffsLinkScaffold(
        child: Center(
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
                  onPressed: () => unawaited(context.read<DeviceCanvasSessionLinkCubit>().verify()),
                ),
              ],
            ),
          ),
        ),
      ),
    };
  }
}

class const _DeviceCanvasDiffsLinkScaffold({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGlassScaffold(
      title: context.loc.diffFileChangesTitle,
      banner: ConnectionBanner.maybeFor(context),
      titleMode: PregoTopNavigationTitleMode.inline,
      onBack: () => context.pop(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }
}
