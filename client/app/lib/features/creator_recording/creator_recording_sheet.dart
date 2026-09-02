import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

Future<void> showCreatorRecordingSheet({
  required BuildContext context,
  required CreatorRecordingCubit cubit,
}) async {
  await showPregoBottomSheet<void>(
    context: context,
    title: context.loc.creatorRecordingSheetTitle,
    builder: (_) => BlocProvider<CreatorRecordingCubit>.value(
      value: cubit,
      child: const CreatorRecordingSheet(),
    ),
  );

  var capture = cubit.state.capture;
  if (capture is CreatorRecordingPreparing) {
    capture = await cubit.stream
        .map((state) => state.capture)
        .firstWhere(
          (state) => state is! CreatorRecordingPreparing,
        );
  }
  if (capture is CreatorRecordingPreviewReady || capture is CreatorRecordingStartFailed) {
    await cubit.dismissPreview();
  }
}

@visibleForTesting
class const CreatorRecordingSheet({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreatorRecordingCubit>().state;
    final prego = context.prego;
    final loc = context.loc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.creatorRecordingDescription,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.md),
        Text(
          loc.creatorRecordingLocalOnly,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.lg),
        PregoInlineAlertsNotifications(
          title: loc.creatorRecordingPortraitOnly,
          type: PregoInlineAlertsNotificationsType.info,
        ),
        const SizedBox(height: PregoSpacing.xl),
        _CaptureControls(capture: state.capture),
        const SizedBox(height: PregoSpacing.x3l),
        Text(
          loc.creatorRecordingSavedSection,
          style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.lg),
        _RecordingLibrary(library: state.library, export: state.export),
      ],
    );
  }
}

class const _CaptureControls({required final CreatorRecordingCaptureState capture}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreatorRecordingCubit>();
    final loc = context.loc;
    final capture = this.capture;

    return switch (capture) {
      CreatorRecordingUnsupported() => PregoInlineAlertsNotifications(
        title: loc.creatorRecordingUnavailable,
        type: PregoInlineAlertsNotificationsType.warning,
      ),
      CreatorRecordingIdle() || CreatorRecordingCaptureCompleted() => PregoButtonsSolid(
        label: loc.creatorRecordingPrepare,
        hierarchy: PregoButtonsSolidHierarchy.primary,
        size: PregoButtonsSolidSize.lg,
        leadingIcon: TablerRegular.camera_selfie,
        fullWidth: true,
        onPressed: () => unawaited(cubit.preparePreview()),
      ),
      CreatorRecordingPreparing() => PregoButtonsSolid(
        label: loc.creatorRecordingPreparing,
        hierarchy: PregoButtonsSolidHierarchy.primary,
        size: PregoButtonsSolidSize.lg,
        isLoading: true,
        fullWidth: true,
        onPressed: null,
      ),
      CreatorRecordingPreviewReady() => PregoButtonsSolid(
        label: loc.creatorRecordingStart,
        hierarchy: PregoButtonsSolidHierarchy.primary,
        size: PregoButtonsSolidSize.lg,
        leadingIcon: TablerRegular.player_record,
        fullWidth: true,
        onPressed: () => _startAndDismiss(context: context, cubit: cubit),
      ),
      CreatorRecordingStarting() => PregoButtonsSolid(
        label: loc.creatorRecordingStarting,
        hierarchy: PregoButtonsSolidHierarchy.primary,
        size: PregoButtonsSolidSize.lg,
        isLoading: true,
        fullWidth: true,
        onPressed: null,
      ),
      CreatorRecordingActive() => PregoInlineAlertsNotifications(
        title: loc.creatorRecordingActive,
        type: PregoInlineAlertsNotificationsType.success,
      ),
      CreatorRecordingSavingCapture() => PregoInlineAlertsNotifications(
        title: loc.creatorRecordingSaving,
        type: PregoInlineAlertsNotificationsType.info,
      ),
      CreatorRecordingPrepareFailed(:final failure) => _FailureControls(
        failure: failure,
        retry: cubit.preparePreview,
      ),
      CreatorRecordingStartFailed(:final failure) => _FailureControls(
        failure: failure,
        retry: cubit.start,
      ),
      CreatorRecordingCaptureFailed(:final failure) => _FailureControls(
        failure: failure,
        retry: cubit.preparePreview,
      ),
    };
  }

  Future<void> _startAndDismiss({
    required BuildContext context,
    required CreatorRecordingCubit cubit,
  }) async {
    final started = await cubit.start();
    if (context.mounted && started) context.pop();
  }
}

class const _FailureControls({
  required final CreatorRecordingFailure failure,
  required final Future<Object?> Function() retry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PregoInlineAlertsNotifications(
          title: _failureMessage(context: context, failure: failure),
          type: PregoInlineAlertsNotificationsType.error,
        ),
        const SizedBox(height: PregoSpacing.lg),
        PregoButtonsSolid(
          label: context.loc.creatorRecordingRetry,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.md,
          fullWidth: true,
          onPressed: () => unawaited(retry()),
        ),
      ],
    );
  }
}

class const _RecordingLibrary({
  required final CreatorRecordingLibraryState library,
  required final CreatorRecordingExportState export,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final library = this.library;
    return switch (library) {
      CreatorRecordingLibraryLoading() => Center(
        child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
      ),
      CreatorRecordingLibraryFailed(:final failure) => PregoInlineAlertsNotifications(
        title: _failureMessage(context: context, failure: failure),
        type: PregoInlineAlertsNotificationsType.error,
      ),
      CreatorRecordingLibraryLoaded(:final recordings) when recordings.isEmpty => Text(
        context.loc.creatorRecordingEmpty,
        style: context.prego.textTheme.textSm.regular.copyWith(
          color: context.prego.colors.textSecondary,
        ),
      ),
      CreatorRecordingLibraryLoaded(:final recordings) => Column(
        children: [
          for (var index = 0; index < recordings.length; index++) ...[
            if (index > 0) const SizedBox(height: PregoSpacing.lg),
            _RecordingCard(artifact: recordings[index], export: export),
          ],
        ],
      ),
    };
  }
}

class const _RecordingCard({
  required final CreatorRecordingArtifact artifact,
  required final CreatorRecordingExportState export,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final sharingKind = switch (export) {
      CreatorRecordingSharing(:final artifact, :final kind) when artifact.id == this.artifact.id => kind,
      CreatorRecordingExportIdle() || CreatorRecordingSharing() || CreatorRecordingShareFailed() => null,
    };
    final sharingInProgress = export is CreatorRecordingSharing;

    return Container(
      padding: const EdgeInsets.all(PregoSpacing.xl),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface3,
        borderRadius: BorderRadius.circular(PregoRadius.x5l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _recordingTitle(context: context, artifact: artifact),
            style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
          ),
          const SizedBox(height: PregoSpacing.lg),
          Wrap(
            spacing: PregoSpacing.md,
            runSpacing: PregoSpacing.md,
            children: [
              PregoButtonsSolid(
                label: context.loc.creatorRecordingExportVideo,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                leadingIcon: TablerRegular.video,
                isLoading: sharingKind == CreatorRecordingExportKind.composedVideo,
                onPressed: sharingInProgress
                    ? null
                    : () => unawaited(
                        context.read<CreatorRecordingCubit>().shareRecording(
                          artifact: artifact,
                          kind: CreatorRecordingExportKind.composedVideo,
                        ),
                      ),
              ),
              PregoButtonsSolid(
                label: context.loc.creatorRecordingExportLayers,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                leadingIcon: TablerRegular.layers_intersect,
                isLoading: sharingKind == CreatorRecordingExportKind.sourceLayers,
                onPressed: sharingInProgress
                    ? null
                    : () => unawaited(
                        context.read<CreatorRecordingCubit>().shareRecording(
                          artifact: artifact,
                          kind: CreatorRecordingExportKind.sourceLayers,
                        ),
                      ),
              ),
              PregoButtonsSolid(
                label: context.loc.creatorRecordingDelete,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.sm,
                type: PregoButtonsSolidType.destructive,
                leadingIcon: TablerRegular.trash,
                onPressed: sharingInProgress ? null : () => _confirmDelete(context: context),
              ),
            ],
          ),
          if (export case CreatorRecordingShareFailed(:final artifact, :final failure)
              when artifact.id == this.artifact.id) ...[
            const SizedBox(height: PregoSpacing.lg),
            PregoInlineAlertsNotifications(
              title: context.loc.creatorRecordingShareFailed,
              supportingText: _failureMessage(context: context, failure: failure),
              type: PregoInlineAlertsNotificationsType.error,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete({required BuildContext context}) async {
    final shouldDelete = await showPregoBottomSheet<bool>(
      context: context,
      title: context.loc.creatorRecordingDeleteTitle,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.creatorRecordingDeleteDescription,
            style: context.prego.textTheme.textMd.regular.copyWith(
              color: context.prego.colors.textPrimary,
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
          PregoSheetActions(
            primary: PregoButtonsSolid(
              label: context.loc.creatorRecordingDelete,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              size: PregoButtonsSolidSize.lg,
              type: PregoButtonsSolidType.destructive,
              onPressed: () => sheetContext.pop(true),
            ),
            secondary: PregoButtonsSolid(
              label: context.loc.creatorRecordingCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              onPressed: () => sheetContext.pop(false),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete ?? false) {
      if (!context.mounted) return;
      await context.read<CreatorRecordingCubit>().deleteRecording(artifact: artifact);
    }
  }
}

String _recordingTitle({required BuildContext context, required CreatorRecordingArtifact artifact}) {
  final local = artifact.createdAt.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = TimeOfDay.fromDateTime(local).format(context);
  final minutes = artifact.duration.inMinutes;
  final seconds = artifact.duration.inSeconds.remainder(60).toString().padLeft(2, "0");
  return "$date · $time · $minutes:$seconds";
}

String _failureMessage({required BuildContext context, required CreatorRecordingFailure failure}) {
  final loc = context.loc;
  return switch (failure.reason) {
    CreatorRecordingFailureReason.cameraPermissionDenied => loc.creatorRecordingCameraPermissionDenied,
    CreatorRecordingFailureReason.microphonePermissionDenied => loc.creatorRecordingMicrophonePermissionDenied,
    CreatorRecordingFailureReason.portraitRequired => loc.creatorRecordingPortraitRequired,
    CreatorRecordingFailureReason.unsupported ||
    CreatorRecordingFailureReason.screenCaptureUnavailable ||
    CreatorRecordingFailureReason.recordingAlreadyInProgress => loc.creatorRecordingUnavailable,
    CreatorRecordingFailureReason.recordingNotInProgress ||
    CreatorRecordingFailureReason.storage ||
    CreatorRecordingFailureReason.capture ||
    CreatorRecordingFailureReason.export ||
    CreatorRecordingFailureReason.unexpected => loc.creatorRecordingFailed,
  };
}
