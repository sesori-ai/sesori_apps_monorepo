import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "device_canvas_video_viewport.dart";

class const DeviceCanvasStatusBanner({
  super.key,
  required final DeviceCanvasSessionState state,
  required final bool readOnly,
  final bool videoPreviewEnabled = deviceCanvasLanVideoPreviewEnabled,
})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (state is DeviceCanvasSessionHidden) return const SizedBox.shrink();
    final readyStatus = switch (state) {
      DeviceCanvasSessionReady(:final status) => status,
      DeviceCanvasSessionHidden() ||
      DeviceCanvasSessionLoading() ||
      DeviceCanvasSessionDisconnected() ||
      DeviceCanvasSessionFailure() => null,
    };
    final available = readyStatus?.devices.where((device) => device.descriptor != null).length ?? 0;
    final assigned = switch (readyStatus) {
      final status? => status.devices.where((device) => device.claim?.sessionId == status.sessionId).length,
      null => 0,
    };
    final connected = readyStatus?.connection == DeviceCanvasClientConnectionStatus.connected;
    final subtitle = switch (state) {
      DeviceCanvasSessionLoading() => context.loc.deviceCanvasLoading,
      DeviceCanvasSessionDisconnected() => context.loc.deviceCanvasDisconnected,
      DeviceCanvasSessionFailure() => context.loc.deviceCanvasUnavailable,
      DeviceCanvasSessionReady() when !connected => context.loc.deviceCanvasDisconnected,
      DeviceCanvasSessionReady() => context.loc.deviceCanvasSummary(available, assigned),
      DeviceCanvasSessionHidden() => "",
    };
    final onTap = switch (state) {
      DeviceCanvasSessionReady() => () => _showDeviceCanvasSheet(
        context: context,
        readOnly: readOnly,
        videoPreviewEnabled: videoPreviewEnabled,
      ),
      DeviceCanvasSessionFailure() => () => unawaited(context.read<SessionDetailCubit>().refreshDeviceCanvas()),
      DeviceCanvasSessionHidden() || DeviceCanvasSessionLoading() || DeviceCanvasSessionDisconnected() => null,
    };
    final hint = switch (state) {
      DeviceCanvasSessionReady() => context.loc.deviceCanvasOpenDetailsHint,
      DeviceCanvasSessionFailure() => context.loc.deviceCanvasRetryHint,
      DeviceCanvasSessionHidden() || DeviceCanvasSessionLoading() || DeviceCanvasSessionDisconnected() => null,
    };

    return Semantics(
      container: true,
      button: onTap != null,
      label: context.loc.deviceCanvasBannerLabel(subtitle),
      hint: hint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: context.prego.colors.bgSecondary,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    connected ? TablerRegular.devices : TablerRegular.devices_off,
                    size: 20,
                    color: connected ? context.prego.colors.fgSuccessPrimary : context.prego.colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.loc.deviceCanvasTitle, style: context.prego.textTheme.textSm.bold),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.prego.textTheme.textXs.regular.copyWith(
                            color: context.prego.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state is DeviceCanvasSessionLoading)
                    SizedBox.square(
                      dimension: 18,
                      child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
                    )
                  else if (state is DeviceCanvasSessionFailure)
                    Tooltip(
                      message: context.loc.sessionDetailRetry,
                      child: Icon(TablerRegular.refresh, size: 20, color: context.prego.colors.textSecondary),
                    )
                  else if (readyStatus != null)
                    Icon(TablerRegular.chevron_right, size: 20, color: context.prego.colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showDeviceCanvasSheet({
  required BuildContext context,
  required bool readOnly,
  required bool videoPreviewEnabled,
}) {
  final cubit = context.read<SessionDetailCubit>();
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DeviceCanvasSheet(readOnly: readOnly, videoPreviewEnabled: videoPreviewEnabled),
    ),
  );
}

class const _DeviceCanvasSheet({
  required final bool readOnly,
  required final bool videoPreviewEnabled,
}) extends StatefulWidget {
  @override
  State<_DeviceCanvasSheet> createState() => _DeviceCanvasSheetState();
}

class _DeviceCanvasSheetState() extends State<_DeviceCanvasSheet> {
  _DeviceCanvasVideoSelection? _videoSelection;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionDetailCubit, SessionDetailState>(
      buildWhen: (previous, current) => switch ((previous, current)) {
        (SessionDetailLoaded(deviceCanvas: final previous), SessionDetailLoaded(deviceCanvas: final current)) =>
          previous != current,
        (
          SessionDetailLoading() || SessionDetailFailed(),
          SessionDetailLoading() || SessionDetailLoaded() || SessionDetailFailed(),
        ) ||
        (
          SessionDetailLoaded(),
          SessionDetailLoading() || SessionDetailFailed(),
        ) => true,
      },
      builder: (context, state) {
        final deviceCanvas = switch (state) {
          SessionDetailLoaded(:final deviceCanvas) => deviceCanvas,
          SessionDetailLoading() || SessionDetailFailed() => const DeviceCanvasSessionHidden(),
        };
        final selection = _videoSelection;
        if (selection != null) {
          return DeviceCanvasVideoViewportOwner(
            initialStatus: selection.status,
            initialDevice: selection.device,
            authorizationState: deviceCanvas,
            deviceName: selection.deviceName,
            onClose: () {
              if (!mounted) return;
              setState(() => _videoSelection = null);
            },
          );
        }
        return switch (deviceCanvas) {
          DeviceCanvasSessionReady(:final status, :final mutation) => _DeviceCanvasInventory(
            status: status,
            mutation: mutation,
            readOnly: widget.readOnly,
            onWatch: widget.videoPreviewEnabled
                ? ({required device, required deviceName}) {
                    setState(
                      () => _videoSelection = _DeviceCanvasVideoSelection(
                        status: status,
                        device: device,
                        deviceName: deviceName,
                      ),
                    );
                  }
                : null,
          ),
          DeviceCanvasSessionLoading() => Center(
            child: Semantics(
              label: context.loc.deviceCanvasLoading,
              child: ExcludeSemantics(
                child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
              ),
            ),
          ),
          DeviceCanvasSessionDisconnected() => _DeviceCanvasMessage(message: context.loc.deviceCanvasDisconnected),
          DeviceCanvasSessionFailure() ||
          DeviceCanvasSessionHidden() => _DeviceCanvasMessage(message: context.loc.deviceCanvasUnavailable),
        };
      },
    );
  }
}

class const _DeviceCanvasInventory({
  required final DeviceCanvasSessionStatusResponse status,
  required final DeviceCanvasSessionMutationState mutation,
  required final bool readOnly,
  required final void Function({required DeviceCanvasDeviceStatus device, required String deviceName})? onWatch,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          Semantics(
            header: true,
            child: Text(context.loc.deviceCanvasTitle, style: context.prego.textTheme.displayXs.bold),
          ),
          if (readOnly) ...[
            const SizedBox(height: 4),
            Text(
              context.loc.deviceCanvasReadOnly,
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          if (mutation case DeviceCanvasSessionMutationFailed(:final reason)) ...[
            _DeviceCanvasMutationNotice(reason: reason),
            const SizedBox(height: 8),
          ],
          if (status.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.loc.deviceCanvasNoDevices,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
              ),
            )
          else
            for (final device in status.devices)
              _DeviceCanvasDeviceRow(
                device: device,
                status: status,
                mutation: mutation,
                readOnly: readOnly,
                onWatch: onWatch,
              ),
          if (status.inventoryTruncated) ...[
            const SizedBox(height: 8),
            Text(
              context.loc.deviceCanvasInventoryTruncated,
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class const _DeviceCanvasDeviceRow({
  required final DeviceCanvasDeviceStatus device,
  required final DeviceCanvasSessionStatusResponse status,
  required final DeviceCanvasSessionMutationState mutation,
  required final bool readOnly,
  required final void Function({required DeviceCanvasDeviceStatus device, required String deviceName})? onWatch,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final descriptor = device.descriptor;
    final claim = device.claim;
    final claimedHere = claim?.sessionId == status.sessionId;
    final displayName = descriptor?.displayName;
    final title = displayName == null || displayName.isEmpty ? context.loc.deviceCanvasUnknownDevice : displayName;
    final presence = descriptor == null ? context.loc.deviceCanvasDeviceMissing : context.loc.deviceCanvasDevicePresent;
    final claimTitle = claim?.displayTitle;
    final assignment = claim == null
        ? context.loc.deviceCanvasDeviceUnclaimed
        : claimedHere
        ? context.loc.deviceCanvasDeviceClaimedHere
        : context.loc.deviceCanvasDeviceClaimedElsewhere(
            claimTitle == null || claimTitle.isEmpty ? context.loc.deviceCanvasUnknownSession : claimTitle,
          );
    final mutatingThisDevice = switch (mutation) {
      DeviceCanvasSessionMutationInProgress(:final deviceKey) => deviceKey == device.deviceKey,
      DeviceCanvasSessionMutationIdle() || DeviceCanvasSessionMutationFailed() => false,
    };
    final _DeviceCanvasAction? action;
    if (readOnly) {
      action = null;
    } else if (claimedHere) {
      action = _DeviceCanvasAction.release;
    } else if (descriptor == null) {
      action = null;
    } else if (claim == null) {
      action = _DeviceCanvasAction.claim;
    } else if (status.supportsReassignment) {
      action = _DeviceCanvasAction.reassign;
    } else {
      action = null;
    }
    VoidCallback? onAction;
    if (action != null && mutation is! DeviceCanvasSessionMutationInProgress) {
      final selectedAction = action;
      onAction = () => _performAction(context: context, action: selectedAction, deviceTitle: title);
    }
    final actionLabel = switch (action) {
      _DeviceCanvasAction.claim => context.loc.deviceCanvasClaimDevice(title),
      _DeviceCanvasAction.reassign => context.loc.deviceCanvasReassignDevice(title),
      _DeviceCanvasAction.release => context.loc.deviceCanvasReleaseDevice(title),
      null => null,
    };
    VoidCallback? watch;
    final watchCallback = onWatch;
    if (!readOnly &&
        watchCallback != null &&
        status.connection == DeviceCanvasClientConnectionStatus.connected &&
        descriptor?.platform == DeviceCanvasClientPlatform.android &&
        (descriptor?.capabilities.remoteVideo ?? false) &&
        claimedHere &&
        (claim?.revision ?? 0) > 0 &&
        mutation is! DeviceCanvasSessionMutationInProgress) {
      watch = () => watchCallback(device: device, deviceName: title);
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.prego.colors.borderSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(TablerRegular.device_mobile, color: context.prego.colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.prego.textTheme.textSm.bold),
                Text(
                  "$presence, $assignment",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (mutatingThisDevice)
            Semantics(
              label: context.loc.deviceCanvasUpdatingDevice(title),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox.square(
                    dimension: 18,
                    child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
                  ),
                ),
              ),
            )
          else if (watch != null || action != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (watch != null)
                  Semantics(
                    container: true,
                    button: true,
                    label: context.loc.deviceCanvasVideoOpenDevice(title),
                    onTap: watch,
                    child: ExcludeSemantics(
                      child: TextButton(onPressed: watch, child: Text(context.loc.deviceCanvasVideoOpen)),
                    ),
                  ),
                if (action != null)
                  Semantics(
                    container: true,
                    button: true,
                    enabled: onAction != null,
                    label: actionLabel,
                    onTap: onAction,
                    child: ExcludeSemantics(
                      child: TextButton(
                        onPressed: onAction,
                        child: Text(
                          switch (action) {
                            _DeviceCanvasAction.claim => context.loc.deviceCanvasClaim,
                            _DeviceCanvasAction.reassign => context.loc.deviceCanvasReassign,
                            _DeviceCanvasAction.release => context.loc.deviceCanvasRelease,
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _performAction({
    required BuildContext context,
    required _DeviceCanvasAction action,
    required String deviceTitle,
  }) async {
    final cubit = context.read<SessionDetailCubit>();
    switch (action) {
      case _DeviceCanvasAction.claim:
        await cubit.claimDeviceCanvasDevice(deviceKey: device.deviceKey, reassign: false);
        return;
      case _DeviceCanvasAction.release:
        await cubit.releaseDeviceCanvasDevice(deviceKey: device.deviceKey);
        return;
      case _DeviceCanvasAction.reassign:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.loc.deviceCanvasReassignTitle(deviceTitle)),
            content: Text(context.loc.deviceCanvasReassignMessage(deviceTitle)),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(false),
                child: Text(context.loc.deviceCanvasCancel),
              ),
              TextButton(
                onPressed: () => dialogContext.pop(true),
                child: Text(context.loc.deviceCanvasReassign),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await cubit.claimDeviceCanvasDevice(deviceKey: device.deviceKey, reassign: true);
        }
    }
  }
}

class const _DeviceCanvasMutationNotice({required final DeviceCanvasSessionMutationFailure reason})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      DeviceCanvasSessionMutationFailure.requestFailed => context.loc.deviceCanvasMutationFailed,
      DeviceCanvasSessionMutationFailure.conflict => context.loc.deviceCanvasMutationConflict,
      DeviceCanvasSessionMutationFailure.deviceUnavailable ||
      DeviceCanvasSessionMutationFailure.sessionUnavailable => context.loc.deviceCanvasMutationUnavailable,
      DeviceCanvasSessionMutationFailure.uncertain => context.loc.deviceCanvasMutationUncertain,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.prego.colors.bgSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(TablerRegular.alert_triangle, size: 18, color: context.prego.colors.fgErrorPrimary),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: context.prego.textTheme.textXs.regular)),
          ],
        ),
      ),
    );
  }
}

class const _DeviceCanvasMessage({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

enum _DeviceCanvasAction() { claim, reassign, release }

final class const _DeviceCanvasVideoSelection({
  required final DeviceCanvasSessionStatusResponse status,
  required final DeviceCanvasDeviceStatus device,
  required final String deviceName,
});
