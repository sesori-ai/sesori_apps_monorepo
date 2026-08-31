import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/platform/flutter_device_canvas_video_peer.dart";
import "../../../core/platform/flutter_webrtc_client.dart";

const bool deviceCanvasLanVideoPreviewEnabled = bool.fromEnvironment("DEVICE_CANVAS_LAN_VIDEO");
const bool deviceCanvasLocalTurnEnabled = bool.fromEnvironment("DEVICE_CANVAS_LOCAL_TURN");
const bool deviceCanvasExternalTurnTestEnabled = bool.fromEnvironment("DEVICE_CANVAS_EXTERNAL_TURN_TEST");
const bool deviceCanvasProductionTurnEnabled = bool.fromEnvironment("DEVICE_CANVAS_PRODUCTION_TURN");

bool resolveDeviceCanvasTurnEnabled({
  required bool local,
  required bool externalTest,
  required bool production,
}) {
  final enabledModeCount = (local ? 1 : 0) + (externalTest ? 1 : 0) + (production ? 1 : 0);
  if (enabledModeCount > 1) throw StateError("Device Canvas TURN client modes are mutually exclusive");
  return enabledModeCount == 1;
}

class const DeviceCanvasVideoViewportOwner({
  super.key,
  required final DeviceCanvasSessionStatusResponse initialStatus,
  required final DeviceCanvasDeviceStatus initialDevice,
  required final DeviceCanvasSessionState authorizationState,
  required final String deviceName,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<DeviceCanvasVideoViewportOwner> createState() => _DeviceCanvasVideoViewportOwnerState();
}

class _DeviceCanvasVideoViewportOwnerState() extends State<DeviceCanvasVideoViewportOwner> {
  late final FlutterDeviceCanvasVideoPeer _peer;
  DeviceCanvasVideoCubit? _cubit;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _peer = FlutterDeviceCanvasVideoPeer(client: getIt<FlutterWebRtcClient>());
  }

  @override
  void didUpdateWidget(DeviceCanvasVideoViewportOwner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorizationState != widget.authorizationState) {
      _cubit?.authorizationChanged(widget.authorizationState);
    }
  }

  @override
  void dispose() {
    final cubit = _cubit;
    if (cubit != null) unawaited(cubit.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeviceCanvasVideoCubit>(
      create: (_) {
        final cubit = DeviceCanvasVideoCubit(
          service: getIt<DeviceCanvasService>(),
          peer: _peer,
          lifecycleSource: getIt<LifecycleSource>(),
          connectionService: getIt<ConnectionService>(),
          initialAuthorization: DeviceCanvasSessionReady(
            status: widget.initialStatus,
            mutation: const DeviceCanvasSessionMutationIdle(),
          ),
          deviceKey: widget.initialDevice.deviceKey,
          useLocalTurn: resolveDeviceCanvasTurnEnabled(
            local: deviceCanvasLocalTurnEnabled,
            externalTest: deviceCanvasExternalTurnTestEnabled,
            production: deviceCanvasProductionTurnEnabled,
          ),
        );
        _cubit = cubit;
        cubit.authorizationChanged(widget.authorizationState);
        unawaited(cubit.start());
        return cubit;
      },
      child: BlocBuilder<DeviceCanvasVideoCubit, DeviceCanvasVideoState>(
        builder: (_, state) => DeviceCanvasVideoViewport(
          state: state,
          deviceName: widget.deviceName,
          videoSurface: DeviceCanvasVideoSurface(renderer: _peer.renderer),
          onClose: _close,
        ),
      ),
    );
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    final cubit = _cubit;
    if (cubit != null) unawaited(cubit.stop());
    widget.onClose();
  }
}

class const DeviceCanvasVideoViewport({
  super.key,
  required final DeviceCanvasVideoState state,
  required final String deviceName,
  required final Widget videoSurface,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = _statusText(context: context, state: state);
    final isLive = state is DeviceCanvasVideoLive;
    final isConnecting = state is DeviceCanvasVideoConnecting;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(TablerRegular.video, color: context.prego.colors.fgBrandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.prego.textTheme.textMd.bold,
                      ),
                      Text(
                        context.loc.deviceCanvasVideoLanPreview,
                        style: context.prego.textTheme.textXs.regular.copyWith(
                          color: context.prego.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: context.loc.deviceCanvasVideoClose,
                  onTap: onClose,
                  child: ExcludeSemantics(
                    child: IconButton(onPressed: onClose, icon: const Icon(TablerRegular.x)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: !isLive,
                label: status,
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.prego.radius.lg),
                    child: ColoredBox(
                      color: context.prego.colors.bgPrimarySolid,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          videoSurface,
                          if (isLive)
                            PositionedDirectional(
                              top: 12,
                              start: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: context.prego.colors.bgSuccessSolid,
                                  borderRadius: BorderRadius.circular(context.prego.radius.full),
                                ),
                                child: Text(
                                  context.loc.deviceCanvasVideoLive,
                                  style: context.prego.textTheme.textXs.bold.copyWith(
                                    color: context.prego.colors.textWhite,
                                  ),
                                ),
                              ),
                            )
                          else
                            ColoredBox(
                              color: context.prego.colors.alphaBlack70,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isConnecting)
                                        SizedBox.square(
                                          dimension: 28,
                                          child: PregoActivityIndicator(color: context.prego.colors.fgWhite),
                                        )
                                      else
                                        Icon(
                                          state is DeviceCanvasVideoStopped
                                              ? TablerRegular.player_stop
                                              : TablerRegular.alert_triangle,
                                          color: context.prego.colors.fgWhite,
                                          size: 28,
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        status,
                                        textAlign: TextAlign.center,
                                        style: context.prego.textTheme.textSm.bold.copyWith(
                                          color: context.prego.colors.textWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(TablerRegular.wifi, size: 18, color: context.prego.colors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.loc.deviceCanvasVideoLanHelp,
                    style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onClose, child: Text(context.loc.deviceCanvasVideoClose)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusText({required BuildContext context, required DeviceCanvasVideoState state}) {
    return switch (state) {
      DeviceCanvasVideoConnecting() => context.loc.deviceCanvasVideoConnecting,
      DeviceCanvasVideoLive() => context.loc.deviceCanvasVideoLive,
      DeviceCanvasVideoStopped() => context.loc.deviceCanvasVideoStopped,
      DeviceCanvasVideoFailed(:final reason) => switch (reason) {
        DeviceCanvasVideoFailureReason.unavailable => context.loc.deviceCanvasVideoUnavailable,
        DeviceCanvasVideoFailureReason.unauthorized => context.loc.deviceCanvasVideoUnauthorized,
        DeviceCanvasVideoFailureReason.unsupported => context.loc.deviceCanvasVideoUnsupported,
        DeviceCanvasVideoFailureReason.controllerConflict => context.loc.deviceCanvasVideoConflict,
        DeviceCanvasVideoFailureReason.connectionFailed => context.loc.deviceCanvasVideoConnectionFailed,
        DeviceCanvasVideoFailureReason.signalingFailed => context.loc.deviceCanvasVideoSignalingFailed,
        DeviceCanvasVideoFailureReason.lanOnly => context.loc.deviceCanvasVideoLanOnly,
        DeviceCanvasVideoFailureReason.expired => context.loc.deviceCanvasVideoExpired,
      },
    };
  }
}

class const DeviceCanvasVideoSurface({super.key, required final RTCVideoRenderer renderer}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      placeholderBuilder: (_) => ColoredBox(color: context.prego.colors.bgPrimarySolid),
    );
  }
}
