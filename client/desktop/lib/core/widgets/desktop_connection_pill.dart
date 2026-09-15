import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

/// Desktop presentation of the shared connection state; owns no reconnect timer.
class const DesktopConnectionPill({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final overlay = context.watch<ConnectionOverlayCubit>();
    final wanted = context.select((BridgeControlCubit cubit) => cubit.state.desiredState);
    final state = overlay.state;
    final title = switch (state) {
      ConnectionOverlayHidden() => null,
      ConnectionOverlayBridgeOffline() when wanted == BridgeProcessDesiredState.off => null,
      ConnectionOverlayBridgeOffline() => context.loc.bridgeDisconnectedTitle,
      ConnectionOverlayReconnecting() => context.loc.connectionReconnectingTitle,
      ConnectionOverlayConnectionLost() => context.loc.connectionLostTitle,
    };
    final colors = context.prego.colors;
    final failed = state is ConnectionOverlayConnectionLost;
    final foreground = failed ? colors.textErrorPrimary : colors.textWarningPrimary;
    return AnimatedSwitcher(
      duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 180),
      // Retained fade-out content must neither intercept clicks nor re-announce.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child)),
          ?current,
        ],
      ),
      child: title == null
          ? const SizedBox.shrink()
          : Semantics(
              key: ValueKey(state.runtimeType),
              container: true,
              liveRegion: true,
              child: Material(
                key: const Key("desktop-connection-pill"),
                color: colors.bgSecondary,
                shape: StadiumBorder(side: BorderSide(color: colors.borderSecondary)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state is ConnectionOverlayBridgeOffline ? TablerRegular.broadcast_off : TablerRegular.cloud_off,
                        size: 18,
                        color: foreground,
                      ),
                      const SizedBox(width: PregoSpacing.sm),
                      Flexible(
                        child: Text(title, style: context.prego.textTheme.textSm.medium.copyWith(color: foreground)),
                      ),
                      if (failed) ...[
                        const SizedBox(width: PregoSpacing.sm),
                        TextButton(onPressed: overlay.reconnect, child: Text(context.loc.connectionLostReconnect)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
