import "dart:async";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/gestures.dart" show kPrimaryButton;
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../capabilities/media/composer_image_picker.dart";
import "../../../capabilities/voice/voice_transcription_service.dart";
import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/command_picker_sheet.dart";
import "../../../core/widgets/composer_surface_style.dart";
import "composer_options_accordion.dart";
import "prompt_editor_sheet.dart";
import "voice_cancel_button.dart";

enum _VoicePresentation() { idle, recording, transcribing }

typedef _RecordingPointer = ({int id, Offset position});

sealed class const _VoiceInteraction();

final class const _VoiceIdle() extends _VoiceInteraction;

final class const _VoiceStarting({
    required final int id,
    required final ComposerSurfaceLayout pinnedLayout,
    required final bool releaseRequested,
    required final _RecordingPointer? pointer,
    required final bool cancelTargetEngaged,
  }) extends _VoiceInteraction;

final class const _VoiceRecording({
    required final int id,
    required final ComposerSurfaceLayout pinnedLayout,
    required final bool minimumDurationReached,
    required final _RecordingPointer? pointer,
    required final bool cancelTargetEngaged,
  }) extends _VoiceInteraction;

final class const _VoiceTranscribing({
    required final int id,
    required final ComposerSurfaceLayout? pinnedLayout,
  }) extends _VoiceInteraction;

final class const _VoiceCancelling() extends _VoiceInteraction;

enum _PasteImageResult() { noImage, handled, stale }

final class _ComposerPasteAction({
    required final Future<void> Function({
      required TextEditingValue initialValue,
      required FutureOr<void> Function() onTextPaste,
      required VoidCallback? onImagePasted,
    }) _pasteImageOrText,
    required final TextEditingController _controller,
  }) extends Action<PasteTextIntent> {

  @override
  Object? invoke(PasteTextIntent intent) {
    // callingAction is available only during this synchronous override call,
    // so retain Flutter's normal text-paste action before reading the image.
    final textPasteAction = callingAction;
    final initialValue = _controller.value;
    unawaited(
      _pasteImageOrText(
        initialValue: initialValue,
        onTextPaste: () {
          textPasteAction?.invoke(intent);
        },
        onImagePasted: null,
      ),
    );
    return null;
  }

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;

  @override
  bool consumesKey(PasteTextIntent intent) => callingAction?.consumesKey(intent) ?? false;
}

typedef PromptSubmitCallback = void Function({
  required ComposerDraft draft,
  required String? command,
  required List<ComposerAttachment> attachments,
});

class const PromptInput({
    super.key,
    required final bool isBusy,
    /// Whether the session already has (or has queued) messages. Drives the
  /// resting hint copy ("Ask anything..." vs "Follow up...") and, in
  /// text-first mode, which prompt the compact pill invites.
  required final bool hasMessages,
    required final PromptSubmitCallback onSend,
    required final VoidCallback onVoiceTranscriptionCompleted,
    required final ValueChanged<ComposerDraft> onDraftChanged,
    required final VoidCallback onDraftCleared,
    required final VoidCallback onAbort,
    required final ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController,
    required final Widget? composerHeader,
    required final List<CommandInfo> availableCommands,
    required final CommandInfo? stagedCommand,
    required final ValueChanged<CommandInfo> onCommandSelected,
    required final VoidCallback onCommandCleared,
    /// Whether this composer offers image attachments. Null keeps already staged
  /// images while current bridge capability is being resolved.
  required final bool? attachmentsSupported,
    /// Stable identity used only to detect when this widget state is reused for
  /// another composer. Persistence remains owned by the parent Cubit.
    required final String draftIdentity,
    /// One-shot identity for restoring a failed submission when sending and
  /// failure are coalesced before this composer can unmount.
    required final Key? restorationKey,
    required final ComposerDraft initialDraft,
    required final List<ComposerAttachment> initialAttachments,
    required final VoidCallback onInitialAttachmentsConsumed,
    /// Optional widget rendered inside the composer, above the text-field row.
  final Widget? header,
  }) extends StatefulWidget {
  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState() extends State<PromptInput> {
  static const _draftCalculator = ComposerDraftCalculator();
  static const _minimumRecordingDuration = Duration(milliseconds: 200);
  static const _successFeedbackPulseDelay = Duration(milliseconds: 100);
  final _controller = TextEditingController();
  final _textScrollController = ScrollController();
  final _focusNode = FocusNode();
  late final Action<PasteTextIntent> _pasteAction;
  int _pasteGeneration = 0;
  late ComposerDraft _draft;
  late TextEditingValue _previousEditingValue;
  bool _isApplyingDraft = false;
  _VoiceInteraction _voiceInteraction = const _VoiceIdle();
  StreamSubscription<void>? _maxDurationSub;
  StreamSubscription<ChatInputMode>? _chatInputModeSub;
  Timer? _minimumRecordingDurationTimer;

  /// Keeps the typing layout mounted after the keyboard affordance was tapped
  /// while the field wasn't in the tree yet (hold-to-talk / compact layouts),
  /// until the post-frame focus request lands. Cleared when focus leaves.
  bool _typingRequested = false;

  /// Whether the field holds sendable text. Mirrored into state so the
  /// composer only rebuilds when emptiness flips (layout + send/stop swap),
  /// not on every keystroke.
  bool _hasText = false;
  late ChatInputMode _chatInputMode;

  /// Active interaction ids live in the sealed variants. The latest id remains
  /// available after completion so delayed success feedback can be suppressed
  /// when a newer recording starts.
  int _latestVoiceInteractionId = 0;

  /// How far the recording hold has dragged toward the cancel target:
  /// 0 at rest, 1 with the finger on the target — releasing there discards
  /// the recording. A notifier rather than state: the drag scrubs at
  /// pointer-move rate and feeds the cancel button, the waveform, and the
  /// destructive gradient directly, without rebuilding the composer.
  final ValueNotifier<double> _cancelDragProgress = ValueNotifier<double>(0);

  /// Locates the cancel target so the drag can measure its distance to it.
  final GlobalKey _cancelTargetKey = GlobalKey();

  /// Images staged for the next submission. Not part of the persisted
  /// draft — they live and die with this composer.
  final List<ComposerAttachment> _attachments = [];

  VoiceTranscriptionService get _voiceService => getIt<VoiceTranscriptionService>();

  ComposerImagePicker get _imagePicker => getIt<ComposerImagePicker>();

  ImageClipboard get _imageClipboard => getIt<ImageClipboard>();

  @override
  void initState() {
    super.initState();
    _pasteAction = _ComposerPasteAction(
      pasteImageOrText: _pasteImageOrText,
      controller: _controller,
    );
    final chatInputModeCubit = context.read<ChatInputModeCubit>();
    _chatInputMode = chatInputModeCubit.state;
    _chatInputModeSub = chatInputModeCubit.stream.listen((inputMode) {
      if (!mounted || _chatInputMode == inputMode) return;
      _updateComposerState(update: () => _chatInputMode = inputMode);
    });
    _applyDraft(draft: widget.initialDraft, notify: false);
    _restoreInitialAttachments();
    _syncSurfaceStyle();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    unawaited(_voiceService.prewarmRecording());
    _maxDurationSub = _voiceService.onMaxDurationReached.listen((_) {
      if (_voiceInteraction is _VoiceRecording && mounted) {
        _showComposerNotice(context.loc.voiceRecordingLimitReached);
        _stopAndTranscribe();
      }
    });
  }

  @override
  void dispose() {
    _maxDurationSub?.cancel();
    _chatInputModeSub?.cancel();
    _minimumRecordingDurationTimer?.cancel();
    // Starting cancels after its platform future settles; cancelling already
    // owns cleanup. Only stable active service states need disposal cleanup.
    if (_voiceInteraction is _VoiceRecording || _voiceInteraction is _VoiceTranscribing) {
      _voiceService.cancelRecording();
    }
    _cancelDragProgress.dispose();
    _controller.dispose();
    _textScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _restoreInitialAttachments() {
    _attachments.addAll(widget.initialAttachments);
    final onConsumed = widget.onInitialAttachmentsConsumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onConsumed();
    });
  }

  void _handleTextChanged() {
    final currentValue = _controller.value;
    if (!_isApplyingDraft && currentValue.text != _previousEditingValue.text) {
      final previousSelection = _previousEditingValue.selection;
      final nextDraft = _draftCalculator.applyTypedEdit(
        draft: _draft,
        newText: currentValue.text,
        previousSelection: previousSelection.isValid
            ? (start: previousSelection.start, end: previousSelection.end)
            : null,
        currentSelection: currentValue.selection.isValid
            ? (start: currentValue.selection.start, end: currentValue.selection.end)
            : null,
      );
      if (nextDraft != _draft) {
        _draft = nextDraft;
        widget.onDraftChanged(nextDraft);
      }
    }
    _previousEditingValue = currentValue;
    final hasText = currentValue.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      _updateComposerState(update: () => _hasText = hasText);
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    // Rebuild on both edges: gaining focus keeps the typing layout up via the
    // focus check; losing it (with nothing to show) collapses back to the
    // resting pill.
    _updateComposerState(
      update: () {
        if (!_focusNode.hasFocus) _typingRequested = false;
      },
    );
  }

  /// Whether the session composer leads with hold-to-talk voice input (the
  /// default) or with the tap-to-type field. Chosen in settings; the cubit
  /// lives above the router, so flipping it re-shapes this composer live.
  bool get _isVoiceFirst => _chatInputMode == ChatInputMode.voiceFirst;

  /// Whether the expanded typing container is showing (vs. the resting
  /// hold-to-talk / compact pills).
  bool get _showsTypingLayout =>
      _typingRequested || _focusNode.hasFocus || _hasText || widget.stagedCommand != null || _attachments.isNotEmpty;

  /// The layout the composer would rest in right now, ignoring any pinned
  /// voice interaction.
  ComposerSurfaceLayout get _restingLayout => resolveComposerSurfaceLayout(
    inputMode: _chatInputMode,
    showsTypingLayout: _showsTypingLayout,
  );

  ComposerSurfaceLayout get _layout => switch (_voiceInteraction) {
    _VoiceStarting(:final pinnedLayout) || _VoiceRecording(:final pinnedLayout) => pinnedLayout,
    _VoiceTranscribing(:final pinnedLayout) => pinnedLayout ?? _restingLayout,
    _VoiceIdle() || _VoiceCancelling() => _restingLayout,
  };

  PregoComposerSurfaceStyle get _surfaceStyle => _layout.surfaceStyle;

  void _updateComposerState({required VoidCallback update}) {
    setState(update);
    _syncSurfaceStyle();
  }

  void _syncSurfaceStyle() {
    final surfaceStyle = _surfaceStyle;
    if (widget.surfaceStyleController.value != surfaceStyle) {
      widget.surfaceStyleController.value = surfaceStyle;
    }
  }

  /// Acknowledges the hold immediately while the recorder starts without
  /// claiming that the underlying recording lifecycle has advanced yet.
  _VoicePresentation get _voicePresentation => switch (_voiceInteraction) {
    _VoiceStarting(releaseRequested: false) || _VoiceRecording() => _VoicePresentation.recording,
    _VoiceTranscribing() => _VoicePresentation.transcribing,
    _VoiceIdle() || _VoiceStarting() || _VoiceCancelling() => _VoicePresentation.idle,
  };

  bool get _hasSendableContent {
    final hasContent = _hasText || widget.stagedCommand != null || _attachments.isNotEmpty;
    return hasContent && (_attachments.isEmpty || (widget.attachmentsSupported ?? false));
  }

  /// Switches to the typing layout and raises the keyboard. Focus is
  /// requested post-frame because the field only mounts with the typing
  /// layout. Blocked while recording and while a record start is in flight —
  /// unpinning in that window would reparent the hold-owning subtree and the
  /// release would never be delivered. A running transcription keeps going
  /// and lands its transcript in the now-focused field.
  void _enterTypingMode() {
    if (_voiceInteraction is _VoiceStarting || _voiceInteraction is _VoiceRecording) return;
    _updateComposerState(
      update: () {
        _typingRequested = true;
        // Safe to unpin while transcribing: no gesture is in flight once the
        // hold has been released.
        if (_voiceInteraction case _VoiceTranscribing(:final id)) {
          _voiceInteraction = _VoiceTranscribing(id: id, pinnedLayout: null);
        }
      },
    );
    _focusComposerField();
  }

  /// Requests focus after the current frame, so it also works right after a
  /// rebuild that (re)mounts the typing layout's field.
  void _focusComposerField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _handleSend() {
    final wasFocused = _focusNode.hasFocus;
    final stagedCommand = widget.stagedCommand;
    final attachments = List<ComposerAttachment>.unmodifiable(_attachments);
    if (attachments.isNotEmpty && widget.attachmentsSupported != true) return;
    if (stagedCommand != null) {
      if (attachments.isNotEmpty) {
        // The bridge's command paths read only the text part, so images sent
        // with a command would silently vanish. Refuse the combination and
        // keep both staged for the user to untangle.
        _showComposerNotice(context.loc.sessionDetailAttachmentsNotWithCommands);
        return;
      }
      widget.onSend(
        draft: _draftCalculator.trim(draft: _draft),
        command: stagedCommand.name,
        attachments: attachments,
      );
      widget.onCommandCleared();
    } else {
      final submission = _draftCalculator.trim(draft: _draft);
      if (submission.text.isEmpty && attachments.isEmpty) return;
      widget.onSend(
        draft: submission,
        command: null,
        attachments: attachments,
      );
    }

    _pasteGeneration++;
    if (_attachments.isNotEmpty) {
      setState(_attachments.clear);
    }
    _controller.clear();
    widget.onDraftCleared();
    // Keep the keyboard up across a send only where it was already part of
    // the flow: always in text-first, and in voice-first when the field was
    // focused. Sending a reviewed voice transcript stays keyboard-free — the
    // composer collapses back to its hold-to-talk pill.
    if (!_isVoiceFirst || wasFocused) {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant PromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draftChanged = oldWidget.draftIdentity != widget.draftIdentity;
    final restorationRequested =
        widget.restorationKey != null && oldWidget.restorationKey != widget.restorationKey;
    final stagedCommandChanged = oldWidget.stagedCommand?.name != widget.stagedCommand?.name;
    if (oldWidget.attachmentsSupported != widget.attachmentsSupported) {
      _pasteGeneration++;
    }
    if (draftChanged || restorationRequested) {
      // A draft identity change means this state moved to another composer. A
      // restoration key change means a fast failed send reused this composer.
      // Both replace authored content exactly once.
      _pasteGeneration++;
      _attachments.clear();
      _applyDraft(draft: widget.initialDraft, notify: false);
      _restoreInitialAttachments();
    }
    // Switching the new-session harness to one that drops image parts strands
    // whatever was staged for the previous pick, so drop it with the action.
    if (widget.attachmentsSupported == false && _attachments.isNotEmpty) {
      setState(_attachments.clear);
    }
    if (oldWidget.surfaceStyleController != widget.surfaceStyleController ||
        draftChanged ||
        restorationRequested ||
        stagedCommandChanged) {
      _syncSurfaceStyle();
    }
    if (stagedCommandChanged && widget.stagedCommand != null) {
      _focusComposerField();
    }
  }

  Future<void> _handleRecordStart({required _RecordingPointer? pointer}) async {
    if (_voiceInteraction is! _VoiceIdle) return;
    // Fire before recorder startup or rebuilding so touch-down feels immediate.
    unawaited(_playHapticFeedback(play: HapticFeedback.lightImpact));
    final interactionId = ++_latestVoiceInteractionId;
    _minimumRecordingDurationTimer?.cancel();
    _minimumRecordingDurationTimer = null;
    _cancelDragProgress.value = 0;
    _updateComposerState(
      update: () => _voiceInteraction = _VoiceStarting(
        id: interactionId,
        pinnedLayout: _restingLayout,
        releaseRequested: false,
        pointer: pointer,
        cancelTargetEngaged: false,
      ),
    );

    final started = await _startRecording();
    if (!mounted) {
      if (started) unawaited(_voiceService.cancelRecording());
      return;
    }

    final interaction = _voiceInteraction;
    if (interaction is! _VoiceStarting || interaction.id != interactionId) {
      if (started) unawaited(_voiceService.cancelRecording());
      return;
    }
    final starting = interaction;
    if (!started) {
      _updateComposerState(update: () => _voiceInteraction = const _VoiceIdle());
      return;
    }
    if (starting.releaseRequested) {
      // The hold ended while the recorder was still starting up, leaving no
      // meaningful captured duration to transcribe.
      await _cancelSettledVoiceInteraction();
      return;
    }

    _updateComposerState(
      update: () => _voiceInteraction = _VoiceRecording(
        id: starting.id,
        pinnedLayout: starting.pinnedLayout,
        minimumDurationReached: false,
        pointer: starting.pointer,
        cancelTargetEngaged: starting.cancelTargetEngaged,
      ),
    );
    // Startup can finish after the user has already dragged toward cancel.
    // Reapply the latest position once the newly mounted target has layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeInteraction = _voiceInteraction;
      if (activeInteraction case _VoiceRecording(:final id, pointer: final pointer?)
          when id == interactionId) {
        _handleRecordDragUpdate(globalPosition: pointer.position);
      }
    });
    _minimumRecordingDurationTimer = Timer(_minimumRecordingDuration, () {
      final activeInteraction = _voiceInteraction;
      if (activeInteraction case _VoiceRecording(
        :final id,
        :final pinnedLayout,
        :final pointer,
        :final cancelTargetEngaged,
      ) when id == interactionId) {
        _voiceInteraction = _VoiceRecording(
          id: id,
          pinnedLayout: pinnedLayout,
          minimumDurationReached: true,
          pointer: pointer,
          cancelTargetEngaged: cancelTargetEngaged,
        );
      }
    });
  }

  void _handleRecordPointerDown(PointerDownEvent event) {
    if (_voiceInteraction is! _VoiceIdle || (event.buttons & kPrimaryButton) == 0) return;
    unawaited(
      _handleRecordStart(pointer: (id: event.pointer, position: event.position)),
    );
  }

  void _handleRecordPointerMove(PointerMoveEvent event) {
    final interaction = _voiceInteraction;
    _voiceInteraction = switch (interaction) {
      _VoiceStarting(
        :final id,
        :final pinnedLayout,
        :final releaseRequested,
        pointer: final pointer?,
        :final cancelTargetEngaged,
      ) when pointer.id == event.pointer => _VoiceStarting(
        id: id,
        pinnedLayout: pinnedLayout,
        releaseRequested: releaseRequested,
        pointer: (id: pointer.id, position: event.position),
        cancelTargetEngaged: cancelTargetEngaged,
      ),
      _VoiceRecording(
        :final id,
        :final pinnedLayout,
        :final minimumDurationReached,
        pointer: final pointer?,
        :final cancelTargetEngaged,
      ) when pointer.id == event.pointer => _VoiceRecording(
        id: id,
        pinnedLayout: pinnedLayout,
        minimumDurationReached: minimumDurationReached,
        pointer: (id: pointer.id, position: event.position),
        cancelTargetEngaged: cancelTargetEngaged,
      ),
      _VoiceStarting() ||
      _VoiceRecording() ||
      _VoiceIdle() ||
      _VoiceTranscribing() ||
      _VoiceCancelling() => interaction,
    };
    if (identical(interaction, _voiceInteraction)) return;
    _handleRecordDragUpdate(globalPosition: event.position);
  }

  void _handleRecordPointerEnd(PointerEvent event) {
    final pointer = switch (_voiceInteraction) {
      _VoiceStarting(pointer: final pointer?) => pointer,
      _VoiceRecording(pointer: final pointer?) => pointer,
      _VoiceStarting() ||
      _VoiceRecording() ||
      _VoiceIdle() ||
      _VoiceTranscribing() ||
      _VoiceCancelling() => null,
    };
    if (pointer?.id != event.pointer) return;
    _handleRecordDragUpdate(globalPosition: event.position);
    final interaction = _voiceInteraction;
    _voiceInteraction = switch (interaction) {
      _VoiceStarting(
        :final id,
        :final pinnedLayout,
        :final releaseRequested,
        :final cancelTargetEngaged,
      ) => _VoiceStarting(
        id: id,
        pinnedLayout: pinnedLayout,
        releaseRequested: releaseRequested,
        pointer: null,
        cancelTargetEngaged: cancelTargetEngaged,
      ),
      _VoiceRecording(
        :final id,
        :final pinnedLayout,
        :final minimumDurationReached,
        :final cancelTargetEngaged,
      ) => _VoiceRecording(
        id: id,
        pinnedLayout: pinnedLayout,
        minimumDurationReached: minimumDurationReached,
        pointer: null,
        cancelTargetEngaged: cancelTargetEngaged,
      ),
      _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => interaction,
    };
    unawaited(_handleRecordEnd());
  }

  /// Tracks the hold as it moves, scrubbing the drag-to-cancel presentation
  /// toward the cancel target.
  void _handleRecordDragUpdate({required Offset globalPosition}) {
    final interaction = _voiceInteraction;
    final bool? currentCancelTargetEngaged = switch (interaction) {
      _VoiceStarting(releaseRequested: false, :final cancelTargetEngaged) => cancelTargetEngaged,
      _VoiceRecording(:final cancelTargetEngaged) => cancelTargetEngaged,
      _VoiceStarting() || _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => null,
    };
    if (currentCancelTargetEngaged == null) return;
    final progress = _cancelProgressFor(
      globalPosition: globalPosition,
      cancelTargetEngaged: currentCancelTargetEngaged,
    );
    final nextCancelTargetEngaged = progress >= 1;
    if (nextCancelTargetEngaged != currentCancelTargetEngaged) {
      _voiceInteraction = switch (interaction) {
        _VoiceStarting(
          :final id,
          :final pinnedLayout,
          :final releaseRequested,
          :final pointer,
        ) => _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: releaseRequested,
          pointer: pointer,
          cancelTargetEngaged: nextCancelTargetEngaged,
        ),
        _VoiceRecording(
          :final id,
          :final pinnedLayout,
          :final minimumDurationReached,
          :final pointer,
        ) => _VoiceRecording(
          id: id,
          pinnedLayout: pinnedLayout,
          minimumDurationReached: minimumDurationReached,
          pointer: pointer,
          cancelTargetEngaged: nextCancelTargetEngaged,
        ),
        _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => interaction,
      };
      unawaited(_playHapticFeedback(play: HapticFeedback.selectionClick));
    }
    _cancelDragProgress.value = progress;
  }

  /// The finger starts engaging the cancel affordance within this distance of
  /// the target's centre, and is committed to cancelling within
  /// [_cancelCommitRadius] — roughly the 44pt button plus touch slop. Once
  /// committed, the wider disengage radius prevents chatter at the boundary.
  static const double _cancelReachRadius = 170;
  static const double _cancelCommitRadius = 44;
  static const double _cancelDisengageRadius = 56;

  double _cancelProgressFor({
    required Offset globalPosition,
    required bool cancelTargetEngaged,
  }) {
    final target = _cancelTargetKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize || !target.attached) return 0;
    final center = target.localToGlobal(target.size.center(Offset.zero));
    final distance = (globalPosition - center).distance;
    final thresholdRadius = cancelTargetEngaged ? _cancelDisengageRadius : _cancelCommitRadius;
    final fraction = (distance - thresholdRadius) / (_cancelReachRadius - thresholdRadius);
    return (1 - fraction).clamp(0.0, 1.0);
  }

  Future<void> _handleRecordEnd() async {
    final interaction = _voiceInteraction;
    if (interaction case _VoiceStarting(
      :final id,
      :final pinnedLayout,
      :final pointer,
      :final cancelTargetEngaged,
    )) {
      _updateComposerState(
        update: () => _voiceInteraction = _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: true,
          pointer: pointer,
          cancelTargetEngaged: cancelTargetEngaged,
        ),
      );
      _cancelDragProgress.value = 0;
      return;
    }
    if (interaction is! _VoiceRecording) return;
    if (interaction.cancelTargetEngaged) {
      // Released on the cancel target — discard instead of transcribing.
      await _cancelVoiceInteraction();
      return;
    }
    if (!interaction.minimumDurationReached) {
      await _cancelVoiceInteraction();
      return;
    }
    await _stopAndTranscribe();
  }

  /// Assistive-technology activation: a semantic tap cannot express the
  /// press-and-hold gesture, so activation toggles recording instead. An
  /// activation while the recorder is still starting up counts as the stop
  /// half of the toggle, not another start.
  Future<void> _handleSemanticRecordToggle() async {
    if (_voiceInteraction is _VoiceStarting || _voiceInteraction is _VoiceRecording) {
      await _handleRecordEnd();
    } else if (_voiceInteraction is _VoiceIdle) {
      await _handleRecordStart(pointer: null);
    }
  }

  Future<bool> _startRecording() async {
    try {
      await _voiceService.startRecording();
      return true;
    } on MicrophonePermissionDeniedError {
      if (mounted) _showComposerNotice(context.loc.voiceErrorPermission);
    } catch (error) {
      // Typed voice errors and anything else the recorder throws (platform /
      // filesystem failures) both land here: an error escaping this method
      // would leave the interaction stuck, silently killing voice input for
      // the rest of the session.
      loge("Failed to start recording", error);
      if (mounted) {
        _showComposerNotice(
          context.loc.voiceErrorRecording,
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      }
    }
    return false;
  }

  Future<void> _stopAndTranscribe() async {
    final recording = _voiceInteraction;
    if (recording is! _VoiceRecording) return;
    // The upload can outlive this interaction (a cancel settles the state
    // long before a slow upload errors out); every continuation below is a
    // no-op once a newer interaction owns the composer.
    final interactionId = recording.id;
    _minimumRecordingDurationTimer?.cancel();
    _minimumRecordingDurationTimer = null;
    _updateComposerState(
      update: () => _voiceInteraction = _VoiceTranscribing(
        id: interactionId,
        pinnedLayout: recording.pinnedLayout,
      ),
    );
    _cancelDragProgress.value = 0;

    bool stale() {
      if (!mounted) return true;
      return switch (_voiceInteraction) {
        _VoiceTranscribing(:final id) => id != interactionId,
        _VoiceIdle() || _VoiceStarting() || _VoiceRecording() || _VoiceCancelling() => true,
      };
    }

    try {
      final transcript = await _voiceService.stopAndTranscribe();
      if (stale()) return;
      if (transcript.trim().isEmpty) return;

      final nextDraft = _draftCalculator.appendVoiceTranscript(
        draft: _draft,
        transcript: transcript,
      );
      _applyDraft(draft: nextDraft, notify: true);
      // Reward the completed outcome, not release that merely starts transcription.
      unawaited(_playSuccessFeedback(interactionId: interactionId));
      _scrollToDraftEndAfterLayout();
      widget.onVoiceTranscriptionCompleted();
      // Text-first raises the keyboard so the transcript can be extended
      // right away. Voice-first rests the transcript in the typing container
      // unfocused — the design's reviewed-before-send state — unless the
      // field was already focused (e.g. typing was entered mid-transcription),
      // which focus keeps on its own.
      if (!_isVoiceFirst) {
        _focusComposerField();
      }
    } on TranscriptionCancelledError {
      // User cancelled — nothing to do, finally resets state.
    } on NotAuthenticatedVoiceError {
      if (!mounted || stale()) return;
      _showComposerNotice(
        context.loc.voiceErrorNotAuthenticated,
        variant: PregoPopupAlertsNotificationsVariant.error,
      );
    } on NetworkVoiceError {
      if (!mounted || stale()) return;
      _showComposerNotice(
        context.loc.voiceErrorNetwork,
        variant: PregoPopupAlertsNotificationsVariant.error,
      );
    } on VoiceTranscriptionError catch (error) {
      loge("Transcription failed", error);
      if (!mounted || stale()) return;
      _showComposerNotice(
        context.loc.voiceErrorTranscription,
        variant: PregoPopupAlertsNotificationsVariant.error,
      );
    } finally {
      if (!stale()) {
        _updateComposerState(
          update: () => _voiceInteraction = const _VoiceIdle(),
        );
        _cancelDragProgress.value = 0;
      }
    }
  }

  void _applyDraft({required ComposerDraft draft, required bool notify}) {
    _isApplyingDraft = true;
    _draft = draft;
    final value = TextEditingValue(
      text: draft.text,
      selection: TextSelection.collapsed(offset: draft.text.length),
    );
    _controller.value = value;
    _previousEditingValue = value;
    _isApplyingDraft = false;
    _hasText = draft.text.trim().isNotEmpty;
    if (notify) widget.onDraftChanged(draft);
  }

  void _scrollToDraftEndAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_textScrollController.hasClients) return;
      _textScrollController.jumpTo(_textScrollController.position.maxScrollExtent);
    });
  }

  /// Discards the running voice interaction: a drag released on the cancel
  /// target, a tap on it mid-recording, or a tap on the X while transcribing.
  Future<void> _cancelVoiceInteractionWithFeedback() async {
    _playDismissFeedback();
    await _cancelVoiceInteraction();
  }

  Future<void> _cancelVoiceInteraction() async {
    final interaction = _voiceInteraction;
    if (interaction case _VoiceStarting(
      :final id,
      :final pinnedLayout,
      :final pointer,
      :final cancelTargetEngaged,
    )) {
      // Native startup must settle before it can be safely cancelled.
      _updateComposerState(
        update: () => _voiceInteraction = _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: true,
          pointer: pointer,
          cancelTargetEngaged: cancelTargetEngaged,
        ),
      );
      _cancelDragProgress.value = 0;
      return;
    }
    if (interaction is _VoiceRecording || interaction is _VoiceTranscribing) {
      await _cancelSettledVoiceInteraction();
    }
  }

  Future<void> _cancelSettledVoiceInteraction() async {
    _minimumRecordingDurationTimer?.cancel();
    _minimumRecordingDurationTimer = null;
    _updateComposerState(
      update: () => _voiceInteraction = const _VoiceCancelling(),
    );
    _cancelDragProgress.value = 0;
    try {
      await _voiceService.cancelRecording();
    } catch (error) {
      loge("Failed to cancel the voice interaction", error);
    } finally {
      if (mounted && _voiceInteraction is _VoiceCancelling) {
        _updateComposerState(
          update: () => _voiceInteraction = const _VoiceIdle(),
        );
      }
    }
  }

  void _playDismissFeedback() {
    final cancelTargetEngaged = switch (_voiceInteraction) {
      _VoiceStarting(:final cancelTargetEngaged) => cancelTargetEngaged,
      _VoiceRecording(:final cancelTargetEngaged) => cancelTargetEngaged,
      _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => false,
    };
    if (cancelTargetEngaged) return;
    unawaited(_playHapticFeedback(play: HapticFeedback.selectionClick));
  }

  Future<void> _playSuccessFeedback({required int interactionId}) async {
    await _playHapticFeedback(play: HapticFeedback.lightImpact);
    await Future<void>.delayed(_successFeedbackPulseDelay);
    if (!mounted || interactionId != _latestVoiceInteractionId) return;
    await _playHapticFeedback(play: HapticFeedback.heavyImpact);
  }

  static Future<void> _playHapticFeedback({required Future<void> Function() play}) async {
    try {
      await play();
    } on Object catch (error, stackTrace) {
      logw("Failed to play voice haptic feedback", error, stackTrace);
    }
  }

  void _showComposerNotice(
    String message, {
    PregoPopupAlertsNotificationsVariant variant = PregoPopupAlertsNotificationsVariant.warning,
  }) {
    PregoPopupAlertPresenter.of(context).show(
      title: message,
      variant: variant,
    );
  }

  Future<void> _openCommandPicker() async {
    final selected = await CommandPickerSheet.show(
      context,
      commands: widget.availableCommands,
    );
    if (!mounted || selected == null) return;
    widget.onCommandSelected(selected);
    _focusComposerField();
  }

  Future<void> _openEditorSheet() async {
    await PromptEditorSheet.show(
      context,
      controller: _controller,
      placeholder: _hintText(context),
      pasteAction: _pasteAction,
      contextMenuBuilder: (_, editableTextState) => _buildComposerContextMenu(editableTextState: editableTextState),
    );
    if (!mounted) return;
    // Return the keyboard to the inline field. Via [_enterTypingMode] because
    // an empty composer collapses to a pill while the sheet holds focus.
    _enterTypingMode();
  }

  String _hintText(BuildContext context) {
    final command = widget.stagedCommand;
    if (command != null) {
      for (final hint in command.hints ?? <String>[]) {
        final trimmed = hint.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return context.loc.sessionDetailCommandArgumentsHint;
    }
    return widget.hasMessages ? context.loc.sessionDetailFollowUpHint : context.loc.sessionDetailPromptHint;
  }

  /// House transition timing for the composer's state morphs.
  static const Duration _morphDuration = Duration(milliseconds: 220);
  static const Curve _morphCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return DecoratedBox(
      // Floating composer: no bar surface, no separator line. The scaffold
      // background fades up behind the floating controls so chat content
      // dissolves as it scrolls past — the same scrim the glass top navigation
      // bar uses (PregoGlassScaffold), mirrored to the bottom edge: opaque
      // where the controls sit, transparent where content emerges above. The
      // controls keep their own surfaces.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            prego.colors.bgSurface1.withValues(alpha: 0.98),
            prego.colors.bgSurface1.withValues(alpha: 0.88),
            prego.colors.bgSurface1.withValues(alpha: 0),
          ],
          stops: const [0, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          ?widget.header,
          // A focused composer consumes the first route pop so Android back
          // dismisses the keyboard before a later back leaves the screen.
          KeyboardVisibilityBuilder(
            builder: (context, isKeyboardVisible) {
              final shouldDismissKeyboardBeforePop =
                  Theme.of(context).platform == TargetPlatform.android && _focusNode.hasFocus && isKeyboardVisible;
              return PopScope(
                canPop: !shouldDismissKeyboardBeforePop,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop && shouldDismissKeyboardBeforePop) _focusNode.unfocus();
                },
                child: _buildComposerTopSlot(context),
              );
            },
          ),

          // Group only the input container with the text field via a
          // TextFieldTapRegion. The field's default `onTapOutside` unfocuses
          // (and dismisses the keyboard) on any pointer-down outside this
          // region; keeping the send button inside stops the hide/re-show
          // flicker that came from [_handleSend] re-requesting focus right
          // after. The agent/model/variant pills in [composerHeader] are
          // deliberately left outside the region, so tapping them dismisses the
          // keyboard (their menus want the screen space the keyboard occupies).
          TextFieldTapRegion(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                top: widget.header != null ? 4 : 8,
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              child: AnimatedSize(
                duration: _morphDuration,
                curve: _morphCurve,
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: _morphDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.bottomCenter,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: KeyedSubtree(
                    // Layout changes cross-fade; voice interactions pin
                    // [_layout], so a switch never happens mid-hold.
                    key: ValueKey(_layout),
                    child: switch (_layout) {
                      ComposerSurfaceLayout.typing => _buildTypingComposer(context),
                      ComposerSurfaceLayout.compact => _buildCompactComposer(context),
                      ComposerSurfaceLayout.holdToTalk => _buildVoicePill(
                        context,
                        hint: context.loc.sessionDetailHoldToTalk,
                        trailing: Row(
                          spacing: PregoSpacing.sm,
                          children: [
                            Tooltip(
                              message: context.loc.sessionDetailTypeMessage,
                              child: PregoButtonsSolid.iconOnly(
                                leadingIcon: TablerRegular.keyboard,
                                hierarchy: PregoButtonsSolidHierarchy.secondary,
                                size: PregoButtonsSolidSize.lg,
                                onPressed: _enterTypingMode,
                              ),
                            ),
                            // The resting voice pill has no send affordance,
                            // but stopping in-flight work must stay reachable.
                            if (widget.isBusy) _buildPrimaryActionButton(context),
                          ],
                        ),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header slot
  // ---------------------------------------------------------------------------

  /// The strip above the input container: the composer header (agent/model
  /// pills) or the staged-command chip normally, replaced by the floating
  /// "Release to transcribe" / "Release to cancel" helper while recording.
  Widget _buildComposerTopSlot(BuildContext context) {
    final Widget child;
    if (_voicePresentation == _VoicePresentation.recording) {
      child = KeyedSubtree(key: const ValueKey("release-hint"), child: _buildReleaseHint(context));
    } else {
      final headerChild = switch (widget.stagedCommand) {
        null => widget.composerHeader,
        final commandInfo => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 2),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: GlassChip(
              label: "/${commandInfo.name}",
              onDeleted: widget.onCommandCleared,
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          ),
        ),
      };
      child = KeyedSubtree(
        key: ValueKey(widget.stagedCommand == null ? "header" : "staged-command"),
        // Older bridges can provide no picker header. Reserve its footprint so
        // the recording helper does not grow the composer when it appears.
        child: headerChild ?? const SizedBox(width: double.infinity, height: _actionButtonSize),
      );
    }

    return AnimatedSize(
      duration: _morphDuration,
      curve: _morphCurve,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(duration: _morphDuration, child: child),
    );
  }

  /// The floating helper above the recording pill. Follows the drag: neutral
  /// "Release to transcribe" normally, destructive "Release to cancel" once
  /// the finger is on the cancel target.
  Widget _buildReleaseHint(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Padding(
      // The design floats the helper spacing-3xl above the pill, less the
      // padding the tap-region below already contributes.
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xs, bottom: PregoSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        child: ValueListenableBuilder<double>(
          valueListenable: _cancelDragProgress,
          builder: (context, progress, _) {
            final cancelling = progress >= 1;
            return Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  cancelling ? loc.voiceReleaseToCancel : loc.voiceReleaseToTranscribe,
                  key: ValueKey(cancelling),
                  textAlign: TextAlign.center,
                  style: prego.textTheme.textMd.regular.copyWith(
                    color: cancelling ? prego.colors.textErrorPrimary : prego.colors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Composer layouts
  // ---------------------------------------------------------------------------

  /// A resting pill surface with the destructive drag-to-cancel gradient
  /// sandwiched between its background and [child]. The gradient layer is
  /// always mounted (invisible at zero progress) so entering the recording
  /// state never restructures the tree around an in-flight hold.
  ///
  /// [tightensTrailingWhileRecording] is set by the pills whose trailing
  /// actions fully collapse during recording: with only the row gap left, the
  /// end inset eases down so the waveform ends the spec's 12pt from the edge.
  Widget _buildVoicePillSurface(
    BuildContext context, {
    required PregoComposerSurfaceStyle surfaceStyle,
    required Widget child,
    bool tightensTrailingWhileRecording = false,
  }) {
    final prego = context.prego;
    const radius = BorderRadius.all(Radius.circular(PregoRadius.full));
    final tightenEnd = tightensTrailingWhileRecording && _voicePresentation == _VoicePresentation.recording;

    return DecoratedBox(
      decoration: pregoComposerSurfaceDecoration(
        prego: prego,
        style: surfaceStyle,
        borderRadius: radius,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildCancelGradient(context, borderRadius: radius)),
          AnimatedPadding(
            duration: _morphDuration,
            curve: _morphCurve,
            padding: EdgeInsetsDirectional.only(
              start: PregoSpacing.sm,
              top: PregoSpacing.sm,
              bottom: PregoSpacing.sm,
              end: tightenEnd ? PregoSpacing.xs : PregoSpacing.sm,
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  /// The destructive wash that bleeds in from the cancel target as the hold
  /// drags toward it, from the design's `Deleting input container`.
  Widget _buildCancelGradient(BuildContext context, {required BorderRadius borderRadius}) {
    final prego = context.prego;

    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: _cancelDragProgress,
        builder: (context, progress, child) {
          if (progress == 0) return const SizedBox.shrink();
          return Opacity(opacity: progress, child: child);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              colors: [
                prego.colors.bgDestructivePressedAlt.withValues(alpha: 0.5),
                prego.colors.bgDestructivePressedAlt.withValues(alpha: 0),
              ],
              stops: const [0, 0.28],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePill(
    BuildContext context, {
    required String hint,
    required Widget trailing,
  }) {
    final prego = context.prego;

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.subtle,
      tightensTrailingWhileRecording: true,
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildLeadingSlot(context),
          Expanded(
            child: _buildHoldSurface(
              context,
              child: _buildVoiceAwareSlot(
                height: _actionButtonSize,
                idle: Center(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          _buildCollapsibleTrailing(
            visible: _voicePresentation != _VoicePresentation.recording,
            child: trailing,
          ),
        ],
      ),
    );
  }

  /// Resting state for text-first mode: a compact pill whose field area
  /// invites typing, with mic and send/stop alongside.
  Widget _buildCompactComposer(BuildContext context) {
    final prego = context.prego;

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.emphasized,
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildLeadingSlot(context),
          Expanded(
            child: _buildVoiceAwareSlot(
              height: _actionButtonSize,
              idle: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _enterTypingMode,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                    child: Text(
                      _hintText(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildMicAndPrimaryActions(context),
        ],
      ),
    );
  }

  /// The expanded typing container: multiline field with the fullscreen-editor
  /// button in its top-right corner, and the action row below — a voice pill
  /// of its own in voice-first mode, the mic/send row in text-first mode.
  Widget _buildTypingComposer(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final voiceFirst = _isVoiceFirst;

    // Voice-first nests the fully-rounded hold pill along the bottom, so the
    // container's bottom corners wrap it: pill radius (22) + padding (6) = 28
    // is well past x3l — the design draws them at x6l.
    final borderRadius = voiceFirst
        ? const BorderRadius.vertical(
            top: Radius.circular(PregoRadius.x3l),
            bottom: Radius.circular(PregoRadius.x6l),
          )
        : BorderRadius.circular(PregoRadius.x3l);

    return Container(
      padding: const EdgeInsets.all(PregoSpacing.sm),
      decoration: pregoComposerSurfaceDecoration(
        prego: prego,
        style: PregoComposerSurfaceStyle.emphasized,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PregoSpacing.md,
        children: [
          if (_attachments.isNotEmpty) _buildAttachmentStrip(context),
          Stack(
            children: [
              Padding(
                // Clear the expand button on the trailing edge so text never
                // runs underneath it.
                padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.xs, 0, 36, 0),
                child: Actions(
                  // Browser paste must remain synchronous with its DOM event;
                  // deferring Flutter's text action behind an async Clipboard
                  // API read can lose browser user activation.
                  actions: kIsWeb ? const {} : {PasteTextIntent: _pasteAction},
                  child: CallbackShortcuts(
                    // Cmd/Ctrl+Enter sends (handy with a hardware keyboard);
                    // plain Enter stays a newline via textInputAction below.
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _handleSend,
                      const SingleActivator(LogicalKeyboardKey.enter, control: true): _handleSend,
                    },
                    child: TextField(
                      controller: _controller,
                      scrollController: _textScrollController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      contextMenuBuilder: (_, editableTextState) =>
                          _buildComposerContextMenu(editableTextState: editableTextState),
                      // Material's default keeps focus on mobile touch taps;
                      // this composer wants outside taps (e.g. the picker
                      // pills above the region) to dismiss the keyboard — the
                      // behaviour the TextFieldTapRegion grouping was built
                      // around.
                      onTapOutside: (_) => _focusNode.unfocus(),
                      style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: PregoSpacing.md),
                        // Command-aware placeholder: the staged command's hint,
                        // else the follow-up/default prompt hint.
                        hintText: _hintText(context),
                        hintStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Tooltip(
                  message: loc.sessionDetailExpandEditor,
                  child: PregoTappable(
                    onTap: _voicePresentation == _VoicePresentation.idle ? _openEditorSheet : null,
                    borderRadius: BorderRadius.circular(PregoRadius.full),
                    containerBuilder: (Widget child) => SizedBox.square(dimension: 32, child: child),
                    child: Icon(TablerRegular.maximize, size: 18, color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          if (voiceFirst)
            _buildVoicePill(
              context,
              hint: _hasText ? loc.sessionDetailHoldToTalkMore : loc.sessionDetailHoldToTalk,
              trailing: _buildPrimaryActionButton(context),
            )
          else
            _buildTypingActionRow(context),
        ],
      ),
    );
  }

  Widget _buildComposerContextMenu({required EditableTextState editableTextState}) {
    final buttonItems = [...editableTextState.contextMenuButtonItems];
    if (!kIsWeb && (widget.attachmentsSupported ?? false)) {
      final pasteIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.paste);
      final existingPaste = pasteIndex < 0 ? null : buttonItems[pasteIndex];
      final existingPasteCallback = existingPaste?.onPressed;
      final pasteItem = ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        label: existingPaste?.label,
        onPressed: () {
          // Preserve the selection from the paste intent; the image probe may
          // outlive the menu, so a later caret move must not redirect the text
          // fallback.
          final initialValue = editableTextState.textEditingValue;
          unawaited(
            _pasteImageOrText(
              initialValue: initialValue,
              onTextPaste:
                  existingPasteCallback ?? () => editableTextState.pasteText(SelectionChangedCause.toolbar),
              onImagePasted: editableTextState.hideToolbar,
            ),
          );
        },
      );
      if (pasteIndex >= 0) {
        buttonItems[pasteIndex] = pasteItem;
      } else {
        final selectAllIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.selectAll);
        buttonItems.insert(selectAllIndex < 0 ? buttonItems.length : selectAllIndex, pasteItem);
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  /// The staged attachments' thumbnails, scrollable when they outgrow the
  /// row, each with a remove badge.
  Widget _buildAttachmentStrip(BuildContext context) {
    return SizedBox(
      height: _attachmentThumbnailSize,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xs),
        child: Row(
          spacing: PregoSpacing.sm,
          children: [
            for (var index = 0; index < _attachments.length; index++) _buildAttachmentThumbnail(context, index: index),
          ],
        ),
      ),
    );
  }

  static const double _attachmentThumbnailSize = 56;

  Widget _buildAttachmentThumbnail(BuildContext context, {required int index}) {
    final prego = context.prego;
    final loc = context.loc;
    final attachment = _attachments[index];

    return Stack(
      children: [
        Semantics(
          image: true,
          label: attachment.filename ?? loc.sessionDetailAttachedImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PregoRadius.md),
            child: Image.memory(
              attachment.bytes,
              width: _attachmentThumbnailSize,
              height: _attachmentThumbnailSize,
              // Decode at thumbnail scale — a full-resolution decode of a
              // 2048px pick would hold ~16MB of raster per thumbnail.
              cacheWidth: (_attachmentThumbnailSize * MediaQuery.devicePixelRatioOf(context)).round(),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
        PositionedDirectional(
          top: PregoSpacing.xxs,
          end: PregoSpacing.xxs,
          child: Tooltip(
            message: loc.sessionDetailRemoveAttachment,
            child: PregoTappable(
              onTap: () => setState(() => _attachments.removeAt(index)),
              borderRadius: BorderRadius.circular(PregoRadius.full),
              containerBuilder: (Widget child) => DecoratedBox(
                decoration: BoxDecoration(
                  color: prego.colors.bgSurface4,
                  shape: BoxShape.circle,
                  border: Border.all(color: prego.colors.borderPrimary),
                ),
                child: SizedBox.square(dimension: 20, child: child),
              ),
              child: Icon(TablerRegular.x, size: 12, color: prego.colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  /// The text-first typing container's bottom strip: accordion, a voice-aware
  /// gap, then mic and send/stop.
  Widget _buildTypingActionRow(BuildContext context) {
    return Row(
      spacing: PregoSpacing.md,
      children: [
        _buildLeadingSlot(context),
        Expanded(
          child: _buildVoiceAwareSlot(
            height: _actionButtonSize,
            idle: const SizedBox(),
          ),
        ),
        _buildMicAndPrimaryActions(context),
      ],
    );
  }

  Widget _buildMicAndPrimaryActions(BuildContext context) {
    return Row(
      spacing: PregoSpacing.sm,
      children: [
        // The mic owns the hold gesture, so only the primary action collapses.
        _buildMicButton(context),
        _buildCollapsibleTrailing(
          visible: _voicePresentation != _VoicePresentation.recording,
          child: _buildPrimaryActionButton(context),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  /// The mic / send buttons and the accordion's closed pill are all 44pt.
  static const double _actionButtonSize = 44;

  Widget _buildOptionsAccordion() {
    return ComposerOptionsAccordion(
      actionsEnabled: _voicePresentation == _VoicePresentation.idle,
      showAttachImage: widget.attachmentsSupported ?? false,
      onSlashCommandsTap: _openCommandPicker,
      onAttachImageTap: _handleAttachImage,
    );
  }

  /// Stages a gallery image for the next submission. Adding one switches the
  /// composer to the typing layout (via [_showsTypingLayout]) so the preview
  /// strip is visible, without raising the keyboard.
  Future<void> _handleAttachImage() async {
    // The pick can settle after this state was reused for another session
    // (didUpdateWidget cleared the strip) — a late result must not leak into
    // the new session's composer. It can equally settle after the harness
    // stopped supporting attachments, which the strip must not outlive.
    final draftIdentity = widget.draftIdentity;
    try {
      final attachment = await _imagePicker.pickImage();
      if (!mounted ||
          draftIdentity != widget.draftIdentity ||
          widget.attachmentsSupported != true ||
          attachment == null) {
        return;
      }
      _stageAttachment(attachment: attachment);
    } on AttachmentTooLargeError {
      if (!mounted || draftIdentity != widget.draftIdentity) return;
      _showComposerNotice(context.loc.sessionDetailAttachmentTooLarge);
    } on UnsupportedAttachmentImageError {
      if (!mounted || draftIdentity != widget.draftIdentity) return;
      _showComposerNotice(context.loc.sessionDetailAttachmentUnsupported);
    } catch (error) {
      loge("Failed to attach an image", error);
      if (!mounted || draftIdentity != widget.draftIdentity) return;
      _showComposerNotice(context.loc.sessionDetailAttachmentPickFailed);
    }
  }

  /// Reads an image before allowing Flutter's normal text paste to run. An
  /// image wins when the clipboard exposes both binary and text formats.
  Future<_PasteImageResult> _handlePasteImage() async {
    if (widget.attachmentsSupported != true) return _PasteImageResult.noImage;
    final draftIdentity = widget.draftIdentity;
    final pasteGeneration = _pasteGeneration;
    final Uint8List? bytes;
    try {
      bytes = await _imageClipboard.readImage();
    } catch (error, stackTrace) {
      loge("Failed to read a pasted image", error, stackTrace);
      return _isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)
          ? _PasteImageResult.stale
          : _PasteImageResult.noImage;
    }

    // Never let an asynchronous paste land in a composer that replaced the
    // one where the action started.
    if (_isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)) {
      return _PasteImageResult.stale;
    }
    if (!mounted) return _PasteImageResult.stale;
    if (bytes == null) return _PasteImageResult.noImage;

    try {
      final attachment = _imagePicker.attachmentFromBytes(bytes: bytes, filename: null);
      if (_stageAttachment(attachment: attachment)) return _PasteImageResult.handled;
      // The staged strip is already at its aggregate budget, so no image was
      // added; fall back so the clipboard's text is not swallowed.
      return _PasteImageResult.noImage;
    } on AttachmentTooLargeError {
      _showComposerNotice(context.loc.sessionDetailAttachmentTooLarge);
      return _PasteImageResult.noImage;
    } on UnsupportedAttachmentImageError {
      _showComposerNotice(context.loc.sessionDetailAttachmentUnsupported);
      return _PasteImageResult.noImage;
    } catch (error, stackTrace) {
      loge("Failed to attach a pasted image", error, stackTrace);
      _showComposerNotice(context.loc.sessionDetailAttachmentPickFailed);
      return _PasteImageResult.noImage;
    }
  }

  Future<void> _pasteImageOrText({
    required TextEditingValue initialValue,
    required FutureOr<void> Function() onTextPaste,
    required VoidCallback? onImagePasted,
  }) async {
    try {
      switch (await _handlePasteImage()) {
        case _PasteImageResult.noImage:
          // Restore the caret captured when paste was pressed so the fallback
          // replaces the same selection, unless the user typed meanwhile.
          if (_controller.text == initialValue.text && initialValue.selection.isValid) {
            _controller.selection = initialValue.selection;
          }
          await onTextPaste();
          return;
        case _PasteImageResult.handled:
          if (mounted) onImagePasted?.call();
          return;
        case _PasteImageResult.stale:
          return;
      }
    } catch (error, stackTrace) {
      loge("Failed to handle composer paste", error, stackTrace);
    }
  }

  bool _isPasteStale({required String draftIdentity, required int pasteGeneration}) {
    return !mounted ||
        draftIdentity != widget.draftIdentity ||
        pasteGeneration != _pasteGeneration ||
        widget.attachmentsSupported != true;
  }

  /// Stages an attachment and reports whether it fit the aggregate budget.
  bool _stageAttachment({required ComposerAttachment attachment}) {
    if (_attachmentsDecodedSizeWith(attachment: attachment) > maxComposerPromptAttachmentBytes) {
      _showComposerNotice(context.loc.sessionDetailAttachmentBudgetExceeded);
      return false;
    }
    setState(() => _attachments.add(attachment));
    return true;
  }

  /// Total decoded bytes the staged strip would carry with [attachment]
  /// added. The outbound budget is aggregate, so multiple images cannot each
  /// consume the full transport allowance.
  int _attachmentsDecodedSizeWith({required ComposerAttachment attachment}) {
    var total = attachment.bytes.length;
    for (final staged in _attachments) {
      total += staged.bytes.length;
    }
    return total;
  }

  /// The 44pt leading slot: the options accordion at rest, the drag-to-cancel
  /// target while recording, and a plain cancel button while transcribing.
  Widget _buildLeadingSlot(BuildContext context) {
    final loc = context.loc;

    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("accordion"), child: _buildOptionsAccordion()),
      _VoicePresentation.recording => KeyedSubtree(
        key: const ValueKey("cancel-target"),
        child: VoiceCancelButton(
          key: _cancelTargetKey,
          progress: _cancelDragProgress,
          onCancel: _cancelVoiceInteractionWithFeedback,
        ),
      ),
      _VoicePresentation.transcribing => KeyedSubtree(
        key: const ValueKey("cancel-transcription"),
        child: Tooltip(
          message: loc.voiceCancelTranscription,
          child: PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.x,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _cancelVoiceInteractionWithFeedback,
          ),
        ),
      ),
    };

    return AnimatedSwitcher(duration: _morphDuration, child: child);
  }

  /// Wraps a resting pill's centre in the press-and-hold recording gesture.
  ///
  /// The listener wraps the voice-aware slot (not the other way around) so it
  /// stays mounted when the waveform swaps in and still receives the release
  /// that ends the hold. Semantic taps toggle recording — assistive
  /// technologies cannot express the press-and-hold gesture.
  Widget _buildHoldSurface(BuildContext context, {required Widget child}) {
    final loc = context.loc;

    return Semantics(
      button: true,
      label: loc.sessionDetailHoldToTalk,
      excludeSemantics: true,
      onTap: _handleSemanticRecordToggle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handleRecordPointerDown,
        onPointerMove: _handleRecordPointerMove,
        onPointerUp: _handleRecordPointerEnd,
        onPointerCancel: _handleRecordPointerEnd,
        child: child,
      ),
    );
  }

  /// Animates trailing actions out of the pill while the waveform needs their
  /// width, without ever changing the surrounding row's child list — gesture
  /// owners elsewhere in the row must keep their elements.
  Widget _buildCollapsibleTrailing({required bool visible, required Widget child}) {
    return ClipRect(
      child: AnimatedSize(
        duration: _morphDuration,
        curve: _morphCurve,
        alignment: AlignmentDirectional.centerStart,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }

  /// Shows [idle] normally, or the recording waveform / transcribing shimmer
  /// in its place while a voice interaction is running. [height] pins the
  /// slot to the resting pills' 44pt row.
  Widget _buildVoiceAwareSlot({required double height, required Widget idle}) {
    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("voice-slot-idle"), child: idle),
      _VoicePresentation.recording => KeyedSubtree(
        key: const ValueKey("voice-slot-recording"),
        child: Center(child: _buildWaveform(context)),
      ),
      _VoicePresentation.transcribing => KeyedSubtree(
        key: const ValueKey("voice-slot-transcribing"),
        child: Center(child: _buildTranscribingShimmer(context)),
      ),
    };

    return SizedBox(
      height: height,
      child: AnimatedSwitcher(duration: _morphDuration, child: child),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    final prego = context.prego;

    return PregoVoiceWaveform(
      amplitudeStream: _voiceService.amplitudeStream,
      // White-on-dark in the dark theme per the design; the light theme flips
      // to its own primary so the bars stay visible on the light pill.
      barColor: prego.colors.textPrimary,
      dotColor: prego.colors.fgQuaternary,
      flattenProgress: _cancelDragProgress,
    );
  }

  /// The design's `Transcribing...` treatment: primary-coloured text swept by
  /// a placeholder-dark band.
  Widget _buildTranscribingShimmer(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return PregoShimmer(
      appearDelay: Duration.zero,
      highlightColor: prego.colors.textPlaceholderSubtle,
      semanticLabel: loc.voiceTranscribing,
      child: Text(
        loc.voiceTranscribing,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
      ),
    );
  }

  /// Hold-to-record microphone for text-first mode. Stays mounted (and in its
  /// enabled look) through every voice state: it owns the hold gesture while
  /// recording, and recording is guarded against re-entry while transcribing.
  Widget _buildMicButton(BuildContext context) {
    final loc = context.loc;

    // No Tooltip here: its long-press trigger would race the recording hold.
    // The button keeps its enabled look and swallows plain taps via
    // [_ignoreTap]; the surrounding raw pointer listener drives recording.
    // Semantic taps toggle recording because assistive technologies cannot
    // express the hold.
    return Semantics(
      button: true,
      label: loc.voiceRecord,
      excludeSemantics: true,
      onTap: _handleSemanticRecordToggle,
      child: Listener(
        onPointerDown: _handleRecordPointerDown,
        onPointerMove: _handleRecordPointerMove,
        onPointerUp: _handleRecordPointerEnd,
        onPointerCancel: _handleRecordPointerEnd,
        child: const PregoButtonsSolid.iconOnly(
          leadingIcon: TablerRegular.microphone,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.lg,
          onPressed: _ignoreTap,
        ),
      ),
    );
  }

  /// Keeps the mic rendering in its enabled look; recording is press-and-hold,
  /// so a plain tap deliberately does nothing.
  static void _ignoreTap() {}

  /// The dark action button: sends when there is content to send, otherwise
  /// stops the agent's in-flight work while it is busy.
  Widget _buildPrimaryActionButton(BuildContext context) {
    final loc = context.loc;
    final showStop = widget.isBusy && !_hasSendableContent;

    if (showStop) {
      return Tooltip(
        message: loc.sessionDetailAbort,
        child: PregoButtonsSolid.iconOnly(
          leadingIcon: TablerSolid.player_stop,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.lg,
          onPressed: widget.onAbort,
        ),
      );
    }

    return Tooltip(
      message: loc.sessionDetailSend,
      child: PregoButtonsSolid.iconOnly(
        leadingIcon: TablerRegular.arrow_up,
        hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
        size: PregoButtonsSolidSize.lg,
        // An empty composer has nothing to send: show the action as genuinely
        // unavailable instead of accepting a tap that does nothing.
        onPressed: _hasSendableContent ? _handleSend : null,
      ),
    );
  }
}
