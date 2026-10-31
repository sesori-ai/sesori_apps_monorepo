import "dart:async";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/gestures.dart" show kPrimaryButton;
import "package:flutter/rendering.dart" show OverflowBoxFit;
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../composer_presentation_scope.dart";
import "command_picker.dart";
import "composer_live_words.dart";
import "composer_options_accordion.dart";
import "composer_surface_style.dart";
import "image_attachment_viewer.dart";
import "prompt_editor_sheet.dart";
import "sent_bubble_landing.dart";

// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _VoicePresentation { idle, recording, transcribing }

/// What a finished dictation does with its words, decided when the gesture
/// ends: goes out as a message, or waits in the box.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _VoiceFinish { send, edit }

/// What releasing the hold would do at the finger's current position.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _VoiceDragArm { none, edit, cancel }

/// [origin] is where the hold began, [position] where the finger is now.
typedef _RecordingPointer = ({int id, Offset origin, Offset position});

/// Pointer/layout presentation only. [VoiceInputCubit] owns the authoritative
/// recording, transcription, cancellation, and disposal lifecycle.
sealed class const _VoiceGesturePresentation();

final class const _VoiceIdle() extends _VoiceGesturePresentation;

final class const _VoiceStarting({
  required final int id,
  required final ComposerSurfaceLayout pinnedLayout,
  required final bool releaseRequested,
  required final _RecordingPointer? pointer,
}) extends _VoiceGesturePresentation;

final class const _VoiceRecording({
  required final int id,
  required final ComposerSurfaceLayout pinnedLayout,
  required final bool minimumDurationReached,
  required final _RecordingPointer? pointer,
}) extends _VoiceGesturePresentation;

final class const _VoiceTranscribing({
  required final int id,
  required final ComposerSurfaceLayout? pinnedLayout,
  required final _VoiceFinish finish,
}) extends _VoiceGesturePresentation;

final class const _VoiceCancelling() extends _VoiceGesturePresentation;

// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _PasteImageResult { noImage, handled, stale }

final class _ComposerPasteAction({
  required final Future<void> Function({
    required TextEditingValue initialValue,
    required FutureOr<void> Function() onTextPaste,
    required VoidCallback? onImagePasted,
  })
  _pasteImageOrText,
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

final class _ComposerSendShortcutActivator({
  required final TextEditingController controller,
  required final SingleActivator activator,
}) extends ShortcutActivator {
  final TextEditingController _controller = controller;
  final SingleActivator _activator = activator;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => _activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    final composing = _controller.value.composing;
    return (!composing.isValid || composing.isCollapsed) && _activator.accepts(event, state);
  }

  @override
  String debugDescribeKeys() => _activator.debugDescribeKeys();
}

typedef PromptSubmitCallback = void Function({
  required ComposerDraft draft,
  required String? command,
  required List<ComposerAttachment> attachments,
});

typedef VoiceTranscriptionFinishedCallback = void Function({
  required AnalyticsVoiceFinish finish,
  required AnalyticsVoiceMode mode,
});

class const PromptInput({
  super.key,
  required final bool isBusy,

  /// Whether the session already has (or has queued) messages. Drives the
  /// resting hint copy ("Ask anything..." vs "Follow up...") and, in
  /// text-first mode, which prompt the compact pill invites.
  required final bool hasMessages,

  /// Whether a send may go out now. Typing stays open either way; while this
  /// is false the draft simply waits in the field.
  required final bool canSend,
  required final PromptSubmitCallback onSend,

  /// Told what became of a dictation's words, once that is decided.
  required final VoiceTranscriptionFinishedCallback? onVoiceTranscriptionFinished,
  required final ValueChanged<ComposerDraft> onDraftChanged,
  required final VoidCallback onDraftCleared,
  required final VoidCallback onAbort,
  required final ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController,
  required final Widget? composerHeader,

  /// Kept at the trailing edge of the strip above the input in every state,
  /// while a staged command or the voice controls take [composerHeader]'s place.
  required final Widget? composerTrailing,
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

  /// Where the caret or selection starts in [initialDraft]; null puts the
  /// caret at its end.
  required final ({int base, int extent})? initialSelection,
  required final List<ComposerAttachment> initialAttachments,
  required final VoidCallback onInitialAttachmentsConsumed,

  /// Told the staged images whenever they change, for an owner that hands them
  /// on; null when nobody needs them outside this composer.
  required final ValueChanged<List<ComposerAttachment>>? onAttachmentsChanged,

  /// Told where the caret or selection moves, for an owner that hands the
  /// composer on; null when nobody needs it outside this composer.
  required final ValueChanged<({int base, int extent})>? onSelectionChanged,

  /// Told when work starts or settles whose result lands in this composer
  /// later — a voice recording or transcription, an image pick or paste, or a
  /// word the keyboard is still composing — so an owner about to replace the
  /// composer can wait for it; null when nobody replaces it.
  required final ValueChanged<bool>? onBusyChanged,

  /// Takes keyboard focus on the first frame, for a composer that continues
  /// one which had it.
  required final bool autofocus,

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
  late final _wordsBox = ComposerWordsBox(controller: _controller);
  final _textScrollController = ScrollController();
  final _focusNode = FocusNode();

  /// Holds keyboard focus for the whole composer while a click-started
  /// recording runs outside the text field, so Escape can cancel it.
  final _composerFocusNode = FocusNode(debugLabel: "PromptInput composer", skipTraversal: true);
  late final Action<PasteTextIntent> _pasteAction;
  int _pasteGeneration = 0;
  late ComposerDraft _draft;
  late TextEditingValue _previousEditingValue;
  bool _isApplyingDraft = false;
  bool _isSubmitting = false;

  /// What [PromptInput.onBusyChanged] last heard, and the work behind it.
  bool _reportedBusy = false;
  bool _voiceBusy = false;
  int _pendingInserts = 0;
  _VoiceGesturePresentation _voiceInteraction = const _VoiceIdle();
  VoiceInputState _renderedVoiceState = const VoiceInputState.idle();
  StreamSubscription<VoiceInputState>? _voiceStateSub;
  Timer? _minimumRecordingDurationTimer;
  late final ComposerVoiceSupport _voiceSupport;
  bool _capabilitiesInitialized = false;

  /// Keeps the typing layout mounted after the keyboard affordance was tapped
  /// while the field wasn't in the tree yet (hold-to-talk / compact layouts),
  /// until the post-frame focus request lands. Cleared when focus leaves.
  bool _typingRequested = false;

  /// Keeps the typing layout while the slash-command picker is open over it:
  /// the picker's search takes focus, and a layout swap would drop the
  /// picker's anchor.
  bool _typingPinnedByPicker = false;

  /// Whether the field holds sendable text. Mirrored into state so the
  /// composer only rebuilds when emptiness flips (layout + send/stop swap),
  /// not on every keystroke.
  bool _hasText = false;

  /// Active interaction ids live in the sealed variants. The latest id remains
  /// available after completion so delayed success feedback can be suppressed
  /// when a newer recording starts.
  int _latestVoiceInteractionId = 0;

  /// How far the recording hold has slid up out of the pill: 0 at or below its
  /// top edge, 1 once releasing would discard the recording. A notifier rather
  /// than state: the drag scrubs at pointer-move rate and feeds the waveform,
  /// the red wash, and the hint directly, without rebuilding the composer.
  ///
  /// Both drag notifiers keep their last value until the next hold starts, so
  /// whatever is fading out after a release holds still instead of snapping.
  final ValueNotifier<double> _cancelDragProgress = ValueNotifier<double>(0);

  /// How far the hold has slid toward the pencil, likewise: 0 at the hold
  /// point, 1 once releasing would put the words in the box.
  final ValueNotifier<double> _editDragProgress = ValueNotifier<double>(0);

  /// Locates the pencil, which both drag measurements are taken from.
  GlobalKey _editTargetKey = GlobalKey();

  /// Carries the composer's layouts, and the input's focus, across the
  /// [AnimatedSize] that [_morphSize] adds or drops as reduced motion toggles.
  final GlobalKey _composerBodyKey = GlobalKey();

  /// Images staged for the next submission. Not part of the persisted
  /// draft — they live and die with this composer.
  final List<ComposerAttachment> _attachments = [];

  VoiceInputCubit get _voiceCubit {
    if (!_voiceSupport.isSupported) {
      throw StateError("VoiceInputCubit is unavailable when composer voice support is disabled");
    }
    return context.read<VoiceInputCubit>();
  }

  ComposerAttachmentDispatcher get _attachmentDispatcher =>
      ComposerPresentationScope.read(context).attachmentDispatcher();

  ImageClipboard get _imageClipboard => ComposerPresentationScope.read(context).imageClipboard();

  @override
  void initState() {
    super.initState();
    _pasteAction = _ComposerPasteAction(
      pasteImageOrText: _pasteImageOrText,
      controller: _controller,
    );
    _applyDraft(draft: widget.initialDraft, notify: false);
    if (widget.initialSelection case (:final base, :final extent)) {
      _controller.selection = TextSelection(baseOffset: base, extentOffset: extent);
      _previousEditingValue = _controller.value;
    }
    _restoreInitialAttachments();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    if (widget.autofocus) {
      _typingRequested = true;
      _focusComposerField();
    }
  }

  void _reportAttachments() => widget.onAttachmentsChanged?.call(List.unmodifiable(_attachments));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final capabilities = ComposerPresentationScope.of(context);
    if (!_capabilitiesInitialized) {
      _voiceSupport = capabilities.voiceSupport;
      _capabilitiesInitialized = true;
      if (_voiceSupport.isSupported) {
        _voiceStateSub = _voiceCubit.stream.listen(_handleVoiceStateChanged);
      }
    }
    _syncSurfaceStyle();
    _releaseHintHeight = _measureReleaseHintHeight();
  }

  @override
  void dispose() {
    _voiceStateSub?.cancel();
    _minimumRecordingDurationTimer?.cancel();
    _cancelDragProgress.dispose();
    _editDragProgress.dispose();
    _controller.dispose();
    _textScrollController.dispose();
    _focusNode.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  /// Stages the restored attachments in order under the same aggregate budget
  /// as a paste, stopping at the first that does not fit: a restoration can
  /// merge several prompts' attachments into one. Runs before a build, so it
  /// stages without `setState` and shows the notice after the frame.
  void _restoreInitialAttachments() {
    var exceededBudget = false;
    for (final attachment in widget.initialAttachments) {
      if (_attachmentsDecodedSizeWith(attachment: attachment) > maxComposerPromptAttachmentBytes) {
        exceededBudget = true;
        break;
      }
      _attachments.add(attachment);
    }
    _reportAttachments();
    final onConsumed = widget.onInitialAttachmentsConsumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (exceededBudget) _showComposerNotice(context.loc.sessionDetailAttachmentBudgetExceeded);
      onConsumed();
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
    final selection = currentValue.selection;
    if (selection.isValid && selection != _previousEditingValue.selection) {
      widget.onSelectionChanged?.call((base: selection.baseOffset, extent: selection.extentOffset));
    }
    _previousEditingValue = currentValue;
    final hasText = currentValue.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      _updateComposerState(update: () => _hasText = hasText);
    }
    _reportBusy();
  }

  /// Tells [PromptInput.onBusyChanged] when the composer starts or settles
  /// work whose result lands in it later. A pick or paste that settles after
  /// this composer is gone stays silent, as its owner may be gone too. A send
  /// reports only once it has cleared the sent draft, so an outcome released
  /// by that clear (a composed word committed by Send) cannot be wiped by it.
  void _reportBusy() {
    if (!mounted || _isSubmitting) return;
    final composing = _controller.value.composing;
    final busy = _voiceBusy || _pendingInserts > 0 || (composing.isValid && !composing.isCollapsed);
    if (busy == _reportedBusy) return;
    _reportedBusy = busy;
    widget.onBusyChanged?.call(busy);
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
  bool get _isVoiceFirst =>
      _voiceSupport.isSupported && ComposerPresentationScope.read(context).inputMode == ChatInputMode.voiceFirst;

  /// Whether the expanded typing container is showing (vs. the resting
  /// hold-to-talk / compact pills).
  bool get _showsTypingLayout =>
      _typingRequested ||
      _typingPinnedByPicker ||
      _focusNode.hasFocus ||
      _hasText ||
      widget.stagedCommand != null ||
      _attachments.isNotEmpty;

  /// The layout the composer would rest in right now, ignoring any pinned
  /// voice interaction.
  ComposerSurfaceLayout get _restingLayout => resolveComposerSurfaceLayout(
    inputMode: _isVoiceFirst ? ChatInputMode.voiceFirst : ChatInputMode.textFirst,
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
    if (widget.surfaceStyleController.value == surfaceStyle) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncSurfaceStyle();
      });
      return;
    }
    widget.surfaceStyleController.value = surfaceStyle;
  }

  bool get _releaseRequestedWhileStarting => switch (_voiceInteraction) {
    _VoiceStarting(releaseRequested: true) => true,
    _VoiceIdle() || _VoiceStarting() || _VoiceRecording() || _VoiceTranscribing() || _VoiceCancelling() => false,
  };

  /// Acknowledges the hold immediately while the recorder starts without
  /// claiming that the underlying recording lifecycle has advanced yet.
  _VoicePresentation get _voicePresentation => switch (_renderedVoiceState) {
    VoiceInputStarting() when _releaseRequestedWhileStarting => _VoicePresentation.idle,
    VoiceInputStarting() || VoiceInputRecording() || VoiceInputLiveRecording() => _VoicePresentation.recording,
    VoiceInputTranscribing() || VoiceInputLiveFinishing() || VoiceInputRetrying() => _VoicePresentation.transcribing,
    VoiceInputIdle() ||
    VoiceInputRetryPending() ||
    VoiceInputRetryCancelling() ||
    VoiceInputDiscarding() ||
    VoiceInputCompleted() ||
    VoiceInputStartFailed() ||
    VoiceInputTranscriptionFailed() ||
    VoiceInputCancelling() => _VoicePresentation.idle,
  };

  bool get _hasSendableContent {
    final hasContent = _hasText || widget.stagedCommand != null || _attachments.isNotEmpty;
    return widget.canSend && hasContent && (_attachments.isEmpty || (widget.attachmentsSupported ?? false));
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
          // Asking for the keyboard means the words are wanted in the box.
          _voiceInteraction = _VoiceTranscribing(id: id, pinnedLayout: null, finish: _VoiceFinish.edit);
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

  /// Words are on their way into the box, so it must not go out ahead of them.
  /// A retried recording is no dictation: sending abandons it.
  bool get _isAwaitingDictatedWords =>
      _voiceInteraction is _VoiceTranscribing && _voiceCubit.state is! VoiceInputRetrying;

  /// Enter and the send button. While a pointer shell listens, Enter finishes
  /// the dictation.
  void _handleSend() {
    if (_isAwaitingDictatedWords) return;
    if (_isListening && ComposerPresentationScope.read(context).presentation == ComposerPresentation.pointer) {
      unawaited(_endRecording(finish: _VoiceFinish.send));
      return;
    }
    unawaited(_submitComposer(fromDictation: false));
  }

  /// Sends the composer's content and reports whether it went out; a refusal
  /// leaves everything where it is.
  Future<bool> _submitComposer({required bool fromDictation}) async {
    if (_isSubmitting || !widget.canSend) return false;

    final wasFocused = _focusNode.hasFocus;
    final stagedCommand = widget.stagedCommand;
    final attachments = List<ComposerAttachment>.unmodifiable(_attachments);
    if (attachments.isNotEmpty && widget.attachmentsSupported != true) return false;
    if (stagedCommand != null && attachments.isNotEmpty) {
      // The bridge's command paths read only the text part, so images sent
      // with a command would silently vanish. Refuse the combination and
      // keep both staged for the user to untangle.
      _showComposerNotice(context.loc.sessionDetailAttachmentsNotWithCommands);
      return false;
    }

    final submission = _draftCalculator.trim(draft: _draft);
    if (stagedCommand == null && submission.text.isEmpty && attachments.isEmpty) return false;

    _isSubmitting = true;
    try {
      if (_voiceSupport.isSupported) {
        final voiceState = _voiceCubit.state;
        if (voiceState is VoiceInputRetryPending || voiceState is VoiceInputRetrying) {
          await _voiceCubit.discard();
          if (!mounted) return false;
        }
      }

      // Here rather than before this method: a refusal above leaves the words
      // for the box, with no bubble expected.
      if (fromDictation) SentBubbleLanding.of(context: context).expect();
      widget.onSend(
        draft: submission,
        command: stagedCommand?.name,
        attachments: attachments,
      );
      if (stagedCommand != null) widget.onCommandCleared();

      _pasteGeneration++;
      if (_attachments.isNotEmpty) {
        setState(_attachments.clear);
        _reportAttachments();
      }
      _controller.clear();
      widget.onDraftCleared();
      // Keep the keyboard up across a send only where it was already part of
      // the flow: when the field was focused, and after a typed send in
      // text-first. A dictation that sent itself never raises it — the composer
      // collapses back to its resting pill and the chat keeps its height.
      if (wasFocused || (!_isVoiceFirst && !fromDictation)) {
        _focusNode.requestFocus();
      }
      return true;
    } finally {
      _isSubmitting = false;
      _reportBusy();
    }
  }

  @override
  void didUpdateWidget(covariant PromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draftChanged = oldWidget.draftIdentity != widget.draftIdentity;
    final restorationRequested = widget.restorationKey != null && oldWidget.restorationKey != widget.restorationKey;
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
      _reportAttachments();
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
    if (_voiceInteraction is! _VoiceIdle || _voiceCubit.state is! VoiceInputIdle) return;
    // Fire before recorder startup or rebuilding so touch-down feels immediate.
    unawaited(_playHapticFeedback(play: HapticFeedback.lightImpact));
    final interactionId = ++_latestVoiceInteractionId;
    _minimumRecordingDurationTimer?.cancel();
    _minimumRecordingDurationTimer = null;
    _cancelDragProgress.value = 0;
    _editDragProgress.value = 0;
    // This hold's pencil gets its own key: the last hold's may still be fading out.
    _editTargetKey = GlobalKey();
    _updateComposerState(
      update: () => _voiceInteraction = _VoiceStarting(
        id: interactionId,
        pinnedLayout: _restingLayout,
        releaseRequested: false,
        pointer: pointer,
      ),
    );

    final started = await _startRecording();
    if (!mounted) return;

    final interaction = _voiceInteraction;
    if (interaction is! _VoiceStarting || interaction.id != interactionId) {
      if (started) unawaited(_voiceCubit.cancel());
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
      ),
    );
    // Startup can finish after the user has already dragged. Reapply the latest
    // position once the newly mounted target has layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeInteraction = _voiceInteraction;
      if (activeInteraction case _VoiceRecording(:final id, pointer: final pointer?) when id == interactionId) {
        _handleRecordDragUpdate(pointer: pointer);
      }
    });
    _minimumRecordingDurationTimer = Timer(_minimumRecordingDuration, () {
      final activeInteraction = _voiceInteraction;
      if (activeInteraction
          case _VoiceRecording(
            :final id,
            :final pinnedLayout,
            :final pointer,
          )
          when id == interactionId) {
        _voiceInteraction = _VoiceRecording(
          id: id,
          pinnedLayout: pinnedLayout,
          minimumDurationReached: true,
          pointer: pointer,
        );
      }
    });
  }

  void _handleRecordPointerDown(PointerDownEvent event) {
    if (_voiceInteraction is! _VoiceIdle || (event.buttons & kPrimaryButton) == 0) return;
    unawaited(
      _handleRecordStart(pointer: (id: event.pointer, origin: event.position, position: event.position)),
    );
  }

  void _handleRecordPointerMove(PointerMoveEvent event) {
    final interaction = _voiceInteraction;
    final _RecordingPointer moved;
    switch (interaction) {
      case _VoiceStarting(:final id, :final pinnedLayout, :final releaseRequested, pointer: final pointer?)
          when pointer.id == event.pointer:
        moved = (id: pointer.id, origin: pointer.origin, position: event.position);
        _voiceInteraction = _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: releaseRequested,
          pointer: moved,
        );
      case _VoiceRecording(:final id, :final pinnedLayout, :final minimumDurationReached, pointer: final pointer?)
          when pointer.id == event.pointer:
        moved = (id: pointer.id, origin: pointer.origin, position: event.position);
        _voiceInteraction = _VoiceRecording(
          id: id,
          pinnedLayout: pinnedLayout,
          minimumDurationReached: minimumDurationReached,
          pointer: moved,
        );
      case _VoiceStarting() || _VoiceRecording() || _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling():
        return;
    }
    _handleRecordDragUpdate(pointer: moved);
  }

  void _handleRecordPointerEnd(PointerEvent event) {
    final pointer = switch (_voiceInteraction) {
      _VoiceStarting(pointer: final pointer?) => pointer,
      _VoiceRecording(pointer: final pointer?) => pointer,
      _VoiceStarting() || _VoiceRecording() || _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => null,
    };
    if (pointer == null || pointer.id != event.pointer) return;
    // The system took a cancelled pointer away (a call, a system gesture): its
    // position says nothing about the finger, and nobody chose to send.
    final systemCancelled = event is PointerCancelEvent;
    if (!systemCancelled) {
      _handleRecordDragUpdate(pointer: (id: pointer.id, origin: pointer.origin, position: event.position));
    }
    final interaction = _voiceInteraction;
    _voiceInteraction = switch (interaction) {
      _VoiceStarting(:final id, :final pinnedLayout, :final releaseRequested) => _VoiceStarting(
        id: id,
        pinnedLayout: pinnedLayout,
        releaseRequested: releaseRequested,
        pointer: null,
      ),
      _VoiceRecording(:final id, :final pinnedLayout, :final minimumDurationReached) => _VoiceRecording(
        id: id,
        pinnedLayout: pinnedLayout,
        minimumDurationReached: minimumDurationReached,
        pointer: null,
      ),
      _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => interaction,
    };
    unawaited(_endRecording(finish: systemCancelled ? _VoiceFinish.edit : _finishOnRelease));
  }

  /// Slide-up cancel arms this far above the pill's top edge.
  static const double _cancelArmDistance = 64;

  /// The pencil arms at this fraction of the way from the hold point to it.
  static const double _editArmFraction = 0.9;

  /// A small retreat keeps an armed target armed, so finger tremor cannot
  /// chatter across the threshold.
  static const double _disarmTolerance = 12;

  /// The fade of the red wash once the finger has lifted.
  static const Duration _washFadeOutDuration = Duration(milliseconds: 240);

  /// Reads what the two drag notifiers say. Only meaningful during a hold.
  _VoiceDragArm get _dragArm {
    if (_cancelDragProgress.value >= 1) return _VoiceDragArm.cancel;
    if (_editDragProgress.value >= 1) return _VoiceDragArm.edit;
    return _VoiceDragArm.none;
  }

  /// A release sends, unless the finger is on the pencil.
  _VoiceFinish get _finishOnRelease => switch (_dragArm) {
    _VoiceDragArm.edit => _VoiceFinish.edit,
    _VoiceDragArm.none || _VoiceDragArm.cancel => _VoiceFinish.send,
  };

  /// Tracks the hold as it moves, scrubbing the slide-out cancel and the pencil.
  /// A cancel in progress wins over the pencil.
  void _handleRecordDragUpdate({required _RecordingPointer pointer}) {
    final tracksDrag = switch (_voiceInteraction) {
      _VoiceStarting(:final releaseRequested) => !releaseRequested,
      _VoiceRecording() => true,
      _VoiceIdle() || _VoiceTranscribing() || _VoiceCancelling() => false,
    };
    if (!tracksDrag) return;
    final target = _editTargetKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize || !target.attached) return;

    // The pencil sits the pill's padding below the pill's top edge in every
    // layout, and its centre is the far end of the slide toward it.
    final pillTop = target.localToGlobal(Offset.zero).dy - PregoSpacing.sm;
    final pencilCenterX = target.localToGlobal(target.size.center(Offset.zero)).dx;
    final cancelProgress = _cancelProgressFor(pillTop: pillTop, pointer: pointer);
    final editProgress = cancelProgress > 0 ? 0.0 : _editProgressFor(pencilCenterX: pencilCenterX, pointer: pointer);

    final previousArm = _dragArm;
    _cancelDragProgress.value = cancelProgress;
    _editDragProgress.value = editProgress;
    if (_dragArm != previousArm) unawaited(_playHapticFeedback(play: HapticFeedback.selectionClick));
  }

  double _cancelProgressFor({required double pillTop, required _RecordingPointer pointer}) {
    final tolerance = _cancelDragProgress.value >= 1 ? _disarmTolerance : 0.0;
    return ((pillTop - pointer.position.dy + tolerance) / _cancelArmDistance).clamp(0.0, 1.0);
  }

  double _editProgressFor({required double pencilCenterX, required _RecordingPointer pointer}) {
    final span = pencilCenterX - pointer.origin.dx;
    if (span.abs() < 1) return 0;
    final tolerance = _editDragProgress.value >= 1 ? _disarmTolerance / span.abs() : 0.0;
    final fraction = (pointer.position.dx - pointer.origin.dx) / span;
    return ((fraction + tolerance) / _editArmFraction).clamp(0.0, 1.0);
  }

  Future<void> _handleRecordEnd() => _endRecording(finish: _finishOnRelease);

  Future<void> _endRecording({required _VoiceFinish finish}) async {
    final interaction = _voiceInteraction;
    if (interaction case _VoiceStarting(:final id, :final pinnedLayout, :final pointer)) {
      _updateComposerState(
        update: () => _voiceInteraction = _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: true,
          pointer: pointer,
        ),
      );
      return;
    }
    if (interaction is! _VoiceRecording) return;
    if (_dragArm == _VoiceDragArm.cancel || !interaction.minimumDurationReached) {
      await _cancelVoiceInteraction();
      return;
    }
    await _stopAndTranscribe(finish: finish);
  }

  /// A tap on the pencil: a pointer shell's click, a second finger, or assistive
  /// technology, which has no drag to express it with.
  void _handleEditTargetTap() {
    unawaited(_playHapticFeedback(play: HapticFeedback.selectionClick));
    unawaited(_endRecording(finish: _VoiceFinish.edit));
  }

  /// Toggles recording for a pointer shell's mic click and for
  /// assistive-technology activation, which cannot express the press-and-hold
  /// gesture. An activation while the recorder is still starting up counts as
  /// the stop half of the toggle, not another start.
  Future<void> _toggleRecording() async {
    if (_voiceInteraction is _VoiceStarting || _voiceInteraction is _VoiceRecording) {
      await _handleRecordEnd();
    } else if (_voiceInteraction is _VoiceIdle) {
      await _handleRecordStart(pointer: null);
    }
  }

  /// A pointer shell's mic click. Starting keeps keyboard focus inside the
  /// composer so Escape reaches its cancel binding, and lifts it off the mic,
  /// which the wide Send is about to hide.
  void _handleMicClick() {
    if (_voiceInteraction is _VoiceIdle && !_focusNode.hasFocus) _composerFocusNode.requestFocus();
    unawaited(_toggleRecording());
  }

  bool get _isListening => _voiceInteraction is _VoiceStarting || _voiceInteraction is _VoiceRecording;

  Future<bool> _startRecording() async {
    await _voiceCubit.startRecording();
    final state = _voiceCubit.state;
    return state is VoiceInputRecording || state is VoiceInputLiveRecording;
  }

  Future<void> _stopAndTranscribe({required _VoiceFinish finish}) async {
    if (_voiceInteraction is! _VoiceRecording) return;
    _showTranscribingPresentation(limitReached: false, finish: finish);
    await _voiceCubit.stopAndTranscribe(limitReached: false);
  }

  void _handleVoiceStateChanged(VoiceInputState state) {
    if (!mounted) return;
    // Busy until the voice input is idle again: a failed transcription keeps
    // its recording until Retry or Discard, and a completed one until its
    // words are in the draft.
    _voiceBusy = state is! VoiceInputIdle;
    _reportBusy();

    switch (state) {
      case VoiceInputIdle():
        if (_voiceInteraction is _VoiceCancelling) _resetVoicePresentation();
      case VoiceInputStarting() ||
          VoiceInputRecording() ||
          VoiceInputLiveRecording() ||
          VoiceInputRetrying() ||
          VoiceInputRetryCancelling() ||
          VoiceInputDiscarding() ||
          VoiceInputCancelling():
        return;
      case VoiceInputTranscribing(:final limitReached):
        // Reached only when the cubit stopped by itself, with no release to
        // say otherwise.
        _showTranscribingPresentation(limitReached: limitReached, finish: _VoiceFinish.edit);
      case VoiceInputLiveFinishing():
        // The same, and its limit notice comes with the words.
        _showTranscribingPresentation(limitReached: false, finish: _VoiceFinish.edit);
      case VoiceInputRetryPending():
        _resetVoicePresentation();
      case VoiceInputCompleted(:final transcript, :final outcome, :final mode):
        _handleCompletedTranscription(transcript: transcript, outcome: outcome, mode: mode);
        _voiceCubit.acknowledgeOutcome();
      case VoiceInputStartFailed(:final error):
        _handleVoiceStartFailure(error: error);
        _voiceCubit.acknowledgeOutcome();
      case VoiceInputTranscriptionFailed(:final error):
        _handleVoiceTranscriptionFailure(error: error);
        _voiceCubit.acknowledgeOutcome();
    }
  }

  void _showTranscribingPresentation({required bool limitReached, required _VoiceFinish finish}) {
    final recording = _voiceInteraction;
    if (recording is! _VoiceRecording) return;

    _minimumRecordingDurationTimer?.cancel();
    _minimumRecordingDurationTimer = null;
    if (limitReached) _showComposerNotice(context.loc.voiceRecordingLimitReached);
    _updateComposerState(
      update: () => _voiceInteraction = _VoiceTranscribing(
        id: recording.id,
        pinnedLayout: recording.pinnedLayout,
        finish: finish,
      ),
    );
  }

  void _handleCompletedTranscription({
    required String transcript,
    required VoiceDictationOutcome outcome,
    required VoiceDictationMode mode,
  }) {
    final int interactionId;
    final _VoiceFinish finish;
    switch (_voiceInteraction) {
      case _VoiceTranscribing(:final id, finish: final chosenFinish):
        interactionId = id;
        finish = chosenFinish;
      // A dictation can end with the finger still down. Nothing was released,
      // so nothing is sent; the later pointer-up finds the presentation idle.
      case _VoiceRecording(:final id):
        interactionId = id;
        finish = _VoiceFinish.edit;
      case _VoiceIdle() || _VoiceStarting() || _VoiceCancelling():
        return;
    }

    _showDictationOutcomeNotice(outcome: outcome, mode: mode);
    if (transcript.trim().isNotEmpty) {
      final nextDraft = _draftCalculator.appendVoiceTranscript(
        draft: _draft,
        transcript: transcript,
      );
      _applyDraft(draft: nextDraft, notify: true);
      unawaited(_playSuccessFeedback(interactionId: interactionId));
      unawaited(_settleDictation(finish: finish, outcome: outcome, mode: mode));
    }
    _resetVoicePresentation();
  }

  /// After recording, the limit's notice came when the recording stopped.
  void _showDictationOutcomeNotice({required VoiceDictationOutcome outcome, required VoiceDictationMode mode}) {
    switch ((outcome, mode)) {
      case (VoiceDictationOutcome.interrupted, _):
        _showComposerNotice(context.loc.voiceDictationCutOff);
      case (VoiceDictationOutcome.limitReached, VoiceDictationMode.live):
        _showComposerNotice(context.loc.voiceDictationLimitReached);
      case (VoiceDictationOutcome.limitReached, VoiceDictationMode.afterRecording):
      case (VoiceDictationOutcome.finished, _):
        break;
    }
  }

  /// Sends the words now in the draft when the gesture and the outcome both
  /// allow it. A send runs before the next frame, so the box never shows them.
  Future<void> _settleDictation({
    required _VoiceFinish finish,
    required VoiceDictationOutcome outcome,
    required VoiceDictationMode mode,
  }) async {
    final report = widget.onVoiceTranscriptionFinished;
    final sendRequested = finish == _VoiceFinish.send && outcome == VoiceDictationOutcome.finished;
    final sent = sendRequested && await _submitComposer(fromDictation: true);
    report?.call(
      finish: switch (outcome) {
        VoiceDictationOutcome.limitReached || VoiceDictationOutcome.interrupted => AnalyticsVoiceFinish.cutOff,
        VoiceDictationOutcome.finished => sent ? AnalyticsVoiceFinish.sent : AnalyticsVoiceFinish.edited,
      },
      mode: switch (mode) {
        VoiceDictationMode.live => AnalyticsVoiceMode.live,
        VoiceDictationMode.afterRecording => AnalyticsVoiceMode.afterRecording,
      },
    );
    if (sent || !mounted) return;
    _scrollToDraftEndAfterLayout();
    if (!_isVoiceFirst) _focusComposerField();
  }

  void _handleVoiceStartFailure({required VoiceTranscriptionError error}) {
    if (error is MicrophonePermissionDeniedError) {
      _showComposerNotice(context.loc.voiceErrorPermission);
    } else {
      _showComposerNotice(
        context.loc.voiceErrorRecording,
        variant: PregoPopupAlertsNotificationsVariant.error,
      );
    }
    _resetVoicePresentation();
  }

  void _handleVoiceTranscriptionFailure({required VoiceTranscriptionError error}) {
    final message = switch (error) {
      NotAuthenticatedVoiceError() => context.loc.voiceErrorNotAuthenticated,
      MissingRecordingArtifactError() => context.loc.voiceErrorSavedRecordingMissing,
      // Only live reaches here with these: after recording they keep the recording
      // for Retry instead, and live has no recording to mention.
      NetworkVoiceError() ||
      RetryableServerVoiceError() ||
      MicrophonePermissionDeniedError() ||
      RecordingFailedError() ||
      NotRecordingError() ||
      ServerVoiceError() ||
      EmptyTranscriptError() ||
      TranscriptionCancelledError() => context.loc.voiceErrorTranscription,
    };
    _showComposerNotice(message, variant: PregoPopupAlertsNotificationsVariant.error);
    _resetVoicePresentation();
  }

  Future<void> _retrySavedRecording() async {
    if (_voiceCubit.state is! VoiceInputRetryPending) return;
    final interactionId = ++_latestVoiceInteractionId;
    _updateComposerState(
      update: () => _voiceInteraction = _VoiceTranscribing(
        id: interactionId,
        pinnedLayout: _restingLayout,
        // The attempt failed and the user has moved on: a late send would
        // surprise them.
        finish: _VoiceFinish.edit,
      ),
    );
    await _voiceCubit.retry();
  }

  Future<void> _discardSavedRecording() async {
    if (_voiceCubit.state is! VoiceInputRetryPending) return;
    _playDismissFeedback();
    await _voiceCubit.discard();
    _resetVoicePresentation();
  }

  void _resetVoicePresentation() {
    if (!mounted || _voiceInteraction is _VoiceIdle) return;
    _updateComposerState(update: () => _voiceInteraction = const _VoiceIdle());
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

  /// Discards the running voice interaction: a tap on the pointer shell's X
  /// mid-recording, Escape, or a tap on the X while transcribing.
  Future<void> _cancelVoiceInteractionWithFeedback() async {
    _playDismissFeedback();
    await _cancelVoiceInteraction();
  }

  Future<void> _cancelVoiceInteraction() async {
    final interaction = _voiceInteraction;
    if (interaction case _VoiceStarting(:final id, :final pinnedLayout, :final pointer)) {
      // Native startup must settle before it can be safely cancelled.
      _updateComposerState(
        update: () => _voiceInteraction = _VoiceStarting(
          id: id,
          pinnedLayout: pinnedLayout,
          releaseRequested: true,
          pointer: pointer,
        ),
      );
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
    await _voiceCubit.cancel();
    if (mounted && _voiceInteraction is _VoiceCancelling) {
      _updateComposerState(
        update: () => _voiceInteraction = const _VoiceIdle(),
      );
    }
  }

  void _playDismissFeedback() {
    // Arming the cancel already ticked.
    if (_isListening && _dragArm == _VoiceDragArm.cancel) return;
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
  static const Curve _trailingReturnCurve = Interval(0.6, 1, curve: _morphCurve);

  /// [AnimatedSwitcher.defaultTransitionBuilder] keys a fade by its child's key,
  /// and the switcher drops an outgoing fade sharing the incoming one's key, so a
  /// child coming back mid-fade after a quick tap restarts from nothing. Pressing
  /// again before it finishes leaves two outgoing fades with one key, which the
  /// framework refuses. Unkeyed, every entry finishes its own fade.
  static AnimatedSwitcherTransitionBuilder get _fadeEachEntry =>
      (child, animation) => FadeTransition(opacity: animation, child: child);

  /// Eases [child]'s size changes in the house timing. Reduced motion resizes
  /// at once: a zero-duration [AnimatedSize] would re-dirty itself mid-layout.
  Widget _morphSize({required AlignmentGeometry alignment, required Widget child}) => prefersReducedMotion(context)
      ? child
      : AnimatedSize(duration: _morphDuration, curve: _morphCurve, alignment: alignment, child: child);

  /// The composer only cares which state it is in. Live words change many times
  /// a second and show in their own layer, so they must not rebuild it.
  static VoiceInputState _withoutLiveWords({required VoiceInputState state}) {
    if (state is VoiceInputLiveRecording) return state.copyWith(words: LiveWords.none);
    if (state is VoiceInputLiveFinishing) return state.copyWith(words: LiveWords.none);
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ComposerPresentationScope.of(context);
    _renderedVoiceState = capabilities.voiceSupport.isSupported
        ? context.select<VoiceInputCubit, VoiceInputState>((cubit) => _withoutLiveWords(state: cubit.state))
        : const VoiceInputState.idle();

    // Escape cancels a running recording from anywhere in the composer. The
    // binding exists only while listening (for a pointer shell, until its words
    // arrive, as its X does), so an idle Escape still reaches the shell's own
    // handling (leaving the text field, closing popups). A pointer shell's Enter
    // and Shift+Enter finish the dictation the same way; they are handled here,
    // so neither reaches the field as a newline. Focus outside the composer
    // never gets here.
    final pointer = capabilities.presentation == ComposerPresentation.pointer;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (_isListening || (pointer && _voiceInteraction is _VoiceTranscribing))
          const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(_cancelVoiceInteractionWithFeedback()),
        if (pointer && (_isListening || _isAwaitingDictatedWords)) ...{
          _ComposerSendShortcutActivator(
            controller: _controller,
            activator: const SingleActivator(LogicalKeyboardKey.enter),
          ): _handleSend,
          _ComposerSendShortcutActivator(
            controller: _controller,
            activator: const SingleActivator(LogicalKeyboardKey.enter, shift: true),
          ): () =>
              unawaited(_endRecording(finish: _VoiceFinish.edit)),
        },
      },
      child: Focus(focusNode: _composerFocusNode, child: _buildComposerColumn(context, capabilities: capabilities)),
    );
  }

  Widget _buildComposerColumn(BuildContext context, {required ComposerPresentationScope capabilities}) {
    // Floating composer: no bar surface, no separator line. Each control's
    // [PregoPageHalo] fades the content passing under it.
    return Column(
      mainAxisSize: .min,
      children: [
        ?widget.header,
        // A focused composer consumes the first route pop so Android back
        // dismisses the keyboard before a later back leaves the screen.
        Builder(
          builder: (context) {
            final shouldDismissKeyboardBeforePop =
                Theme.of(context).platform == TargetPlatform.android &&
                _focusNode.hasFocus &&
                capabilities.isKeyboardVisible;
            return PopScope(
              canPop: !shouldDismissKeyboardBeforePop,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && shouldDismissKeyboardBeforePop) _focusNode.unfocus();
              },
              child: switch (widget.composerTrailing) {
                null => _buildComposerTopSlot(context: context, hintWidth: null),
                final trailing => LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Expanded(child: _buildComposerTopSlot(context: context, hintWidth: constraints.maxWidth)),
                      _buildComposerTrailing(context: context, trailing: trailing),
                    ],
                  ),
                ),
              },
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
            // One gap whatever the header shows, so a header easing in or out
            // never shifts the input under the pills in a frame.
            padding: EdgeInsetsDirectional.only(top: 8, bottom: MediaQuery.paddingOf(context).bottom + 8),
            // The composer's halo runs on to the bottom edge, so nothing
            // shows below it. It follows the animated size rather than one
            // layout's surface, so it stays put while layouts cross-fade.
            child: _withLiveWords(
              context: context,
              body: PregoPageHalo(
                radius: PregoRadius.x3l,
                reachesLayerBottom: true,
                child: _morphSize(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSwitcher(
                    key: _composerBodyKey,
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
                          // The stop button beside the keyboard one.
                          extraTrailingWidth: widget.isBusy ? _actionButtonSize + PregoSpacing.sm : 0,
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
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header slot
  // ---------------------------------------------------------------------------

  /// Fades where it stands while the release hint shows over its place. It stays
  /// mounted and keeps its room, so nothing in the row moves.
  Widget _buildComposerTrailing({required BuildContext context, required Widget trailing}) {
    final visible = _voicePresentation != _VoicePresentation.recording;
    final duration = prefersReducedMotion(context) ? Duration.zero : _morphDuration;
    final opacity = visible ? 1.0 : 0.0;
    // Leaves on the house curve and comes back once the hint over its place has
    // mostly gone: each fade holds one curve, as an implicit animation given a
    // new curve restarts from the wrong value when a quick tap turns it back.
    return AnimatedOpacity(
      duration: duration,
      curve: _morphCurve,
      opacity: opacity,
      child: AnimatedOpacity(
        duration: duration,
        curve: _trailingReturnCurve,
        opacity: opacity,
        child: ExcludeFocus(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
              child: PregoPageHalo(radius: PregoRadius.full, reachesLayerBottom: false, child: trailing),
            ),
          ),
        ),
      ),
    );
  }

  /// The strip above the input container: the composer header (agent/model
  /// pills) or the staged-command chip normally, replaced by the floating
  /// recording helper or persistent saved-recording actions.
  ///
  /// [hintWidth] is the composer's whole width when a trailing control shares the
  /// row. The helper still centres over all of it, reaching past this slot.
  Widget _buildComposerTopSlot({required BuildContext context, required double? hintWidth}) {
    final Widget child;
    if (_renderedVoiceState is VoiceInputRetryPending) {
      child = KeyedSubtree(
        key: const ValueKey("saved-recording-actions"),
        child: _buildSavedRecordingActions(context),
      );
    } else if (_voicePresentation == _VoicePresentation.recording) {
      final hint = _buildReleaseHint(context);
      child = KeyedSubtree(
        key: const ValueKey("release-hint"),
        child: switch (hintWidth) {
          null => hint,
          final width => OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minWidth: width,
            maxWidth: width,
            alignment: AlignmentDirectional.centerStart,
            child: hint,
          ),
        },
      );
    } else {
      final headerChild = switch (widget.stagedCommand) {
        null => widget.composerHeader,
        final commandInfo => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 2),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PregoPageHalo(
              radius: PregoRadius.full,
              reachesLayerBottom: false,
              child: GlassChip(
                label: "/${commandInfo.name}",
                onDeleted: widget.onCommandCleared,
                deleteIcon: const Icon(TablerRegular.x, size: PregoIconSize.md),
              ),
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

    if (prefersReducedMotion(context)) return child;
    return AnimatedSize(
      duration: _morphDuration,
      curve: _morphCurve,
      alignment: Alignment.bottomCenter,
      // Growing for large text must not cut off a hint reaching past this slot.
      clipBehavior: hintWidth == null ? Clip.hardEdge : Clip.none,
      child: AnimatedSwitcher(
        duration: _morphDuration,
        transitionBuilder: (transitionChild, animation) {
          // Only the staged chip bears glass. Picker/voice/retry content keeps
          // its ordinary fade, including while the outgoing chip dematerializes.
          if (transitionChild.key == const ValueKey("staged-command")) {
            return GlassMaterializeTransition(animation: animation, child: transitionChild);
          }
          return _fadeEachEntry(transitionChild, animation);
        },
        // Sat on the pill: centred, a taller hint at large text would lift the
        // fading header off it by half the difference in one frame.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previousChildren, ?currentChild],
        ),
        child: child,
      ),
    );
  }

  Widget _buildSavedRecordingActions(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 2),
      child: PregoPageHalo(
        radius: PregoRadius.full,
        reachesLayerBottom: false,
        child: Row(
          spacing: PregoSpacing.sm,
          children: [
            Expanded(
              child: Text(
                loc.voiceRecordingSaved,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ),
            PregoButtonsSolid(
              key: const Key("voice_saved_discard"),
              label: loc.voiceDiscard,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.sm,
              onPressed: _discardSavedRecording,
            ),
            PregoButtonsSolid(
              key: const Key("voice_saved_retry"),
              label: loc.voiceRetry,
              leadingIcon: TablerRegular.refresh,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.sm,
              onPressed: _retrySavedRecording,
            ),
          ],
        ),
      ),
    );
  }

  /// Hangs the live words' layer on the composer's body, where a composer with
  /// no voice has no cubit to take them from.
  Widget _withLiveWords({required BuildContext context, required Widget body}) {
    if (!ComposerPresentationScope.of(context).voiceSupport.isSupported) return body;
    return ComposerLiveWords(
      cancelProgress: _cancelDragProgress,
      hintHeight: _releaseHintHeight,
      box: _wordsBox,
      boxStyle: _fieldStyle(context),
      child: body,
    );
  }

  TextStyle _fieldStyle(BuildContext context) {
    final prego = context.prego;
    return prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary);
  }

  /// The design floats the helper spacing-3xl above the pill, less the padding
  /// the tap-region below already contributes.
  static const _releaseHintPadding = EdgeInsetsDirectional.only(top: PregoSpacing.xs, bottom: PregoSpacing.xl);

  /// The height of [_buildReleaseHint], which stays one line whatever it says.
  double _releaseHintHeight = 0;

  double _measureReleaseHintHeight() {
    final line = TextPainter(
      text: TextSpan(style: context.prego.textTheme.textMd.regular),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final height = line.preferredLineHeight;
    line.dispose();
    return _releaseHintPadding.vertical + height;
  }

  /// The floating helper above the recording pill. Follows the drag: what a
  /// release does now, in destructive colour once it would cancel.
  Widget _buildReleaseHint(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    // A pointer shell records on click, so there is no hold to release.
    final restingHint = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer
        ? loc.voiceEnterToSend
        : loc.voiceReleaseToSend;

    return Padding(
      padding: _releaseHintPadding,
      child: Center(
        // The halo hugs the label, not the full-width strip.
        child: PregoPageHalo(
          radius: PregoRadius.full,
          reachesLayerBottom: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([_cancelDragProgress, _editDragProgress]),
            builder: (context, _) {
              final arm = _dragArm;
              return Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: _fadeEachEntry,
                  child: Text(
                    switch (arm) {
                      _VoiceDragArm.none => restingHint,
                      _VoiceDragArm.edit => loc.voiceReleaseToEdit,
                      _VoiceDragArm.cancel => loc.voiceReleaseToCancel,
                    },
                    key: ValueKey(arm),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: prego.textTheme.textMd.regular.copyWith(
                      color: arm == _VoiceDragArm.cancel ? prego.colors.textErrorPrimary : prego.colors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Composer layouts
  // ---------------------------------------------------------------------------

  /// A resting pill surface with the slide-out cancel's red wash sandwiched
  /// between its background and [child]. The wash layer is always mounted (invisible at zero progress) so entering the recording
  /// state never restructures the tree around an in-flight hold.
  ///
  /// [tightensTrailingWhileRecording] is set by the pills whose trailing
  /// actions fully collapse during recording: with only the row gap left, the
  /// end inset eases down so the waveform ends the spec's 12pt from the edge.
  Widget _buildVoicePillSurface(
    BuildContext context, {
    required PregoComposerSurfaceStyle surfaceStyle,
    required Widget child,
    required Widget? overlay,
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
          Positioned.fill(child: _buildCancelWash(context)),
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
          if (overlay != null) Positioned.fill(child: overlay),
        ],
      ),
    );
  }

  /// The red wash over the full pill as the hold slides out of it. Follows the
  /// finger exactly while it is down, and fades away once it lifts.
  Widget _buildCancelWash(BuildContext context) {
    final listening = _voicePresentation == _VoicePresentation.recording;

    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: _cancelDragProgress,
        builder: (context, progress, child) => AnimatedOpacity(
          opacity: listening ? progress : 0,
          duration: listening ? Duration.zero : _washFadeOutDuration,
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(PregoRadius.full)),
            color: context.prego.colors.bgDestructivePressedAlt,
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePill(
    BuildContext context, {
    required String hint,
    required double extraTrailingWidth,
    required Widget trailing,
  }) {
    final prego = context.prego;

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.subtle,
      tightensTrailingWhileRecording: true,
      // The hold surface beneath takes the touches and speaks for the pill.
      overlay: ExcludeSemantics(
        child: _buildVoiceCaption(
          context,
          idle: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
          ),
          extraTrailingWidth: extraTrailingWidth,
        ),
      ),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildLeadingSlot(context),
          Expanded(
            child: _buildHoldSurface(
              context,
              child: _buildVoiceAwareSlot(height: _actionButtonSize, idle: const SizedBox()),
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

  /// The composer's centred words, in a layer over its row: the slot beneath
  /// widens as voice-first's trailing actions collapse, which would carry them
  /// sideways as they fade. The insets match the row's at rest, so they sit centred between
  /// its actions. [extraTrailingWidth] is how much wider the trailing actions
  /// rest than the leading ones.
  Widget _buildVoiceCaption(BuildContext context, {required Widget idle, required double extraTrailingWidth}) {
    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("voice-caption-idle"), child: idle),
      _VoicePresentation.recording => const SizedBox.shrink(key: ValueKey("voice-caption-recording")),
      _VoicePresentation.transcribing => KeyedSubtree(
        key: const ValueKey("voice-caption-transcribing"),
        child: _buildTranscribingShimmer(context),
      ),
    };

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm + _actionButtonSize + PregoSpacing.md),
        child: AnimatedPadding(
          duration: _morphDuration,
          curve: _morphCurve,
          padding: EdgeInsetsDirectional.only(end: extraTrailingWidth),
          child: Center(
            child: AnimatedSwitcher(duration: _morphDuration, transitionBuilder: _fadeEachEntry, child: child),
          ),
        ),
      ),
    );
  }

  /// The text-first layouts' caption. Their hint stays in the slot, where it can
  /// be tapped, so only the shimmer shows here. A pointer shell's voice targets
  /// and wide Send are equally wide; a touch shell has the mic beyond the send.
  Widget _buildTextFirstCaption(BuildContext context) {
    final pointer = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;
    return _buildVoiceCaption(
      context,
      idle: const SizedBox.shrink(),
      extraTrailingWidth: pointer ? 0 : _actionButtonSize + PregoSpacing.sm,
    );
  }

  /// Resting state for text-first mode: a compact pill whose field area
  /// invites typing, with mic and send/stop alongside.
  Widget _buildCompactComposer(BuildContext context) {
    final prego = context.prego;

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.emphasized,
      overlay: _buildTextFirstCaption(context),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildLeadingSlot(context),
          Expanded(
            child: _buildVoiceAwareSlot(
              height: _actionButtonSize,
              idle: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: GestureDetector(
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
    final sendKeyPolicy = ComposerPresentationScope.of(context).sendKeyPolicy;
    // A pointer shell grows the box for long prompts instead of offering the
    // full-screen editor sheet.
    final growsInPlace = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;

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
                padding: EdgeInsetsDirectional.fromSTEB(PregoSpacing.xs, 0, growsInPlace ? PregoSpacing.xs : 36, 0),
                child: Actions(
                  // Browser paste must remain synchronous with its DOM event;
                  // deferring Flutter's text action behind an async Clipboard
                  // API read can lose browser user activation.
                  actions: kIsWeb ? const {} : {PasteTextIntent: _pasteAction},
                  child: CallbackShortcuts(
                    // Mobile retains Cmd/Ctrl+Enter with plain Enter as a
                    // newline. Desktop additionally binds unmodified Enter;
                    // Shift+Enter does not match it and reaches the multiline
                    // field as a newline.
                    bindings: <ShortcutActivator, VoidCallback>{
                      _ComposerSendShortcutActivator(
                        controller: _controller,
                        activator: const SingleActivator(LogicalKeyboardKey.enter, meta: true),
                      ): _handleSend,
                      _ComposerSendShortcutActivator(
                        controller: _controller,
                        activator: const SingleActivator(LogicalKeyboardKey.enter, control: true),
                      ): _handleSend,
                      if (sendKeyPolicy == ComposerSendKeyPolicy.enterSends)
                        _ComposerSendShortcutActivator(
                          controller: _controller,
                          activator: const SingleActivator(LogicalKeyboardKey.enter),
                        ): _handleSend,
                    },
                    child: ComposerWordsBoxSlot(
                      box: _wordsBox,
                      child: TextField(
                        controller: _controller,
                        scrollController: _textScrollController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: growsInPlace ? 16 : 6,
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
                        style: _fieldStyle(context),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          // Growing in place stops at a third of the window and
                          // then scrolls, so a short window keeps the selectors
                          // above the draft on screen.
                          constraints: growsInPlace
                              ? BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 3)
                              : null,
                          contentPadding: ComposerWordsBox.contentPadding,
                          // Command-aware placeholder: the staged command's hint,
                          // else the follow-up/default prompt hint.
                          hintText: _hintText(context),
                          hintStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!growsInPlace)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: Tooltip(
                    message: loc.sessionDetailExpandEditor,
                    child: PregoTappable(
                      onTap: _voicePresentation == _VoicePresentation.idle ? _openEditorSheet : null,
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                      containerBuilder: (Widget child) => SizedBox.square(dimension: 32, child: child),
                      child: Icon(TablerRegular.maximize, size: PregoIconSize.md, color: prego.colors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          if (voiceFirst)
            _buildVoicePill(
              context,
              hint: _hasText ? loc.sessionDetailHoldToTalkMore : loc.sessionDetailHoldToTalk,
              extraTrailingWidth: 0,
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
              onTextPaste: existingPasteCallback ?? () => editableTextState.pasteText(SelectionChangedCause.toolbar),
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

  Widget _buildAttachmentStrip(BuildContext context) {
    final loc = context.loc;
    return PregoImageAttachmentStrip(
      children: [
        for (var index = 0; index < _attachments.length; index++)
          PregoImageAttachmentPreview(
            key: ObjectKey(_attachments[index]),
            imageLabel: _attachments[index].filename ?? loc.sessionDetailAttachedImage,
            onOpen: () => _openAttachment(attachment: _attachments[index]),
            removeLabel: loc.sessionDetailRemoveAttachment,
            onRemove: () {
              setState(() => _attachments.removeAt(index));
              _reportAttachments();
            },
            image: Hero(
              tag: ObjectKey(_attachments[index]),
              child: Image.memory(
                _attachments[index].bytes,
                // Decode at thumbnail scale rather than retaining full-resolution
                // rasters for every staged image. Original bytes still get sent.
                cacheWidth: (PregoImageAttachmentPreview.size * MediaQuery.devicePixelRatioOf(context)).round(),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
      ],
    );
  }

  void _openAttachment({required ComposerAttachment attachment}) {
    unawaited(
      showImageAttachmentViewer(
        context: context,
        image: ViewOnlyMessageImage(
          // The chat thumbnails' viewer cap; staged originals can be camera-sized.
          provider: ResizeImage(
            MemoryImage(attachment.bytes),
            width: 2048,
            height: 2048,
            policy: ResizeImagePolicy.fit,
          ),
          originalUri: null,
        ),
        heroPresentation: ImageAttachmentHeroPresentation.cropped,
        filename: attachment.filename,
        heroTag: ObjectKey(attachment),
      ),
    );
  }

  /// The text-first typing container's bottom strip: accordion, a voice-aware
  /// gap, then mic and send/stop. It has no surface of its own, so the red wash
  /// and the caption reach out over the container's padding to read as the same
  /// pill the other layouts have.
  Widget _buildTypingActionRow(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -PregoSpacing.sm,
          top: -PregoSpacing.sm,
          right: -PregoSpacing.sm,
          bottom: -PregoSpacing.sm,
          child: _buildCancelWash(context),
        ),
        Row(
          spacing: PregoSpacing.md,
          children: [
            _buildLeadingSlot(context),
            Expanded(
              child: _buildVoiceAwareSlot(height: _actionButtonSize, idle: const SizedBox()),
            ),
            _buildMicAndPrimaryActions(context),
          ],
        ),
        Positioned.fill(
          left: -PregoSpacing.sm,
          top: -PregoSpacing.sm,
          right: -PregoSpacing.sm,
          bottom: -PregoSpacing.sm,
          child: _buildTextFirstCaption(context),
        ),
      ],
    );
  }

  Widget _buildMicAndPrimaryActions(BuildContext context) {
    if (_voiceSupport.isSupported &&
        ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer) {
      return _buildPointerVoiceActions(context);
    }
    final visible = _voicePresentation != _VoicePresentation.recording;
    return Row(
      spacing: PregoSpacing.sm,
      children: [
        if (_voiceSupport.isSupported) _buildMicButton(context),
        // The finger is on the mic, so the primary action fades where it stands
        // and keeps its room: nothing moves under the hold.
        AnimatedOpacity(
          duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
          curve: _morphCurve,
          opacity: visible ? 1 : 0,
          child: ExcludeFocus(
            excluding: !visible,
            child: IgnorePointer(ignoring: !visible, child: _buildPrimaryActionButton(context)),
          ),
        ),
      ],
    );
  }

  /// A pointer shell's mic and primary action, which merge into one wide Send
  /// while a dictation runs, so the cursor that clicked the mic is already on it.
  /// The Send grows over them rather than replacing them: nothing around it
  /// moves, and they wait mounted beneath it to fade back. It stays through
  /// transcribing, dimmed and inert, so a second click lands on nothing. A
  /// retried recording leaves the send button free, as sending abandons it.
  Widget _buildPointerVoiceActions(BuildContext context) {
    final merged =
        _voicePresentation == _VoicePresentation.recording ||
        _renderedVoiceState is VoiceInputTranscribing ||
        _renderedVoiceState is VoiceInputLiveFinishing;
    final loc = context.loc;

    return SizedBox(
      width: _pointerVoiceGroupWidth,
      height: _actionButtonSize,
      child: Stack(
        // The buttons' focus rings paint past this box.
        clipBehavior: Clip.none,
        children: [
          ExcludeFocus(
            excluding: merged,
            child: IgnorePointer(
              ignoring: merged,
              child: AnimatedOpacity(
                opacity: merged ? 0 : 1,
                duration: _morphDuration,
                child: Row(
                  spacing: PregoSpacing.sm,
                  children: [_buildMicButton(context), _buildPrimaryActionButton(context)],
                ),
              ),
            ),
          ),
          AnimatedPositionedDirectional(
            start: merged ? 0 : _actionButtonSize + PregoSpacing.sm,
            end: 0,
            top: 0,
            bottom: 0,
            duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
            curve: _morphCurve,
            child: IgnorePointer(
              ignoring: !merged,
              child: AnimatedOpacity(
                opacity: merged ? 1 : 0,
                duration: _morphDuration,
                child: Tooltip(
                  message: loc.sessionDetailSend,
                  excludeFromSemantics: true,
                  child: PregoVoiceSendButton(
                    label: loc.sessionDetailSend,
                    enabled: _voicePresentation == _VoicePresentation.recording,
                    onPressed: () => unawaited(_handleRecordEnd()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A pointer shell's pencil and X. They keep their places into transcribing:
  /// the pencil fades out, leaving nothing under a cursor that just clicked it,
  /// and the X stays where it was, still stopping the work.
  Widget _buildPointerVoiceTargets(BuildContext context) {
    final loc = context.loc;
    final listening = _voicePresentation == _VoicePresentation.recording;
    final cancelLabel = listening ? loc.voiceCancelRecording : loc.voiceCancelTranscription;

    return SizedBox(
      width: _pointerVoiceGroupWidth,
      child: Row(
        spacing: PregoSpacing.sm,
        children: [
          IgnorePointer(
            ignoring: !listening,
            child: AnimatedOpacity(
              opacity: listening ? 1 : 0,
              duration: _morphDuration,
              child: Tooltip(
                message: loc.voiceEditBeforeSending,
                excludeFromSemantics: true,
                child: PregoVoiceTarget(
                  icon: TablerRegular.pencil,
                  tone: PregoVoiceTargetTone.primary,
                  semanticLabel: loc.voiceEditBeforeSending,
                  progress: _editDragProgress,
                  onTap: _handleEditTargetTap,
                ),
              ),
            ),
          ),
          Tooltip(
            message: cancelLabel,
            excludeFromSemantics: true,
            child: PregoVoiceTarget(
              icon: TablerRegular.x,
              tone: PregoVoiceTargetTone.destructive,
              semanticLabel: cancelLabel,
              progress: _cancelDragProgress,
              onTap: _cancelVoiceInteractionWithFeedback,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  /// The mic / send buttons and the accordion's closed pill are all 44pt.
  static const double _actionButtonSize = 44;

  /// A pointer shell's two 44pt controls and the gap between them, as the mic
  /// and send sit at rest.
  static const double _pointerVoiceGroupWidth = _actionButtonSize * 2 + PregoSpacing.sm;

  Widget _buildOptionsAccordion() {
    return PregoPickerPopover(
      pointerWidth: 360,
      onClosed: () {
        if (mounted) _updateComposerState(update: () => _typingPinnedByPicker = false);
      },
      triggerBuilder: (context, toggle) => ComposerOptionsAccordion(
        actionsEnabled: _voicePresentation == _VoicePresentation.idle,
        alwaysOpen: ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer,
        isTyping: _hasText,
        // Nearly every harness takes images, so the action holds its place
        // while support is unknown instead of growing in once it is known.
        showAttachImage: widget.attachmentsSupported ?? true,
        onSlashCommandsTap: () {
          _typingPinnedByPicker = _layout == ComposerSurfaceLayout.typing;
          toggle();
        },
        onAttachImageTap: (widget.attachmentsSupported ?? false) ? _handleAttachImage : null,
      ),
      contentBuilder: (context, close) => CommandPicker(
        commands: widget.availableCommands,
        onCommandSelected: (command) {
          close();
          // App shortcuts can change the session under the open picker.
          if (!mounted) return;
          widget.onCommandSelected(command);
          _focusComposerField();
        },
        onClose: close,
      ),
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
    _startInsert();
    try {
      final attachment = await _attachmentDispatcher.pickImage();
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
    } finally {
      _settleInsert();
    }
  }

  /// An image pick or a paste, whose result lands after an await.
  void _startInsert() {
    _pendingInserts++;
    _reportBusy();
  }

  void _settleInsert() {
    _pendingInserts--;
    _reportBusy();
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
      final attachment = _attachmentDispatcher.attachmentFromBytes(bytes: bytes, filename: null);
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
    // The text fallback reads the clipboard too, so the paste is busy until
    // whichever lands has landed.
    _startInsert();
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
    } finally {
      _settleInsert();
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
    _reportAttachments();
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

  /// The leading slot: the options accordion at rest, the pencil to slide onto
  /// while recording, and a plain cancel button while transcribing. A pointer
  /// shell keeps its pencil and X through both.
  Widget _buildLeadingSlot(BuildContext context) {
    final loc = context.loc;
    final pointer = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;

    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("accordion"), child: _buildOptionsAccordion()),
      _VoicePresentation.recording || _VoicePresentation.transcribing when pointer => KeyedSubtree(
        key: const ValueKey("pointer-voice-targets"),
        child: _buildPointerVoiceTargets(context),
      ),
      _VoicePresentation.recording => KeyedSubtree(
        key: const ValueKey("edit-target"),
        child: PregoVoiceTarget(
          key: _editTargetKey,
          icon: TablerRegular.pencil,
          tone: PregoVoiceTargetTone.primary,
          semanticLabel: loc.voicePutWordsInBox,
          progress: _editDragProgress,
          onTap: _handleEditTargetTap,
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

    final switcher = AnimatedSwitcher(
      duration: _morphDuration,
      transitionBuilder: _fadeEachEntry,
      // Pinned to the leading edge: centred, the narrower child would jump
      // sideways when the wider one leaves at the fade's end.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: child,
    );
    if (prefersReducedMotion(context)) return switcher;
    // The pointer accordion and the targets differ in width; glide the change
    // so the waveform beside them does not snap at the fade's end.
    return AnimatedSize(
      duration: _morphDuration,
      curve: _morphCurve,
      alignment: AlignmentDirectional.centerStart,
      // The accordion's focus ring and glass may paint past its box at rest.
      clipBehavior: Clip.none,
      child: switcher,
    );
  }

  /// Wraps a resting pill's centre in the press-and-hold recording gesture.
  ///
  /// The listener wraps the voice-aware slot (not the other way around) so it
  /// stays mounted when the waveform swaps in and still receives the release
  /// that ends the hold. Semantic taps toggle recording and a semantic dismiss
  /// cancels it — assistive technologies cannot express the press-and-hold
  /// gesture or the slide out of it.
  Widget _buildHoldSurface(BuildContext context, {required Widget child}) {
    final loc = context.loc;

    return Semantics(
      button: true,
      // The surface speaks for the pill, whose words it excludes.
      label: _voicePresentation == _VoicePresentation.transcribing
          ? _transcribingLabel(context)
          : loc.sessionDetailHoldToTalk,
      excludeSemantics: true,
      onTap: _toggleRecording,
      onDismiss: _isListening ? _cancelVoiceInteractionWithFeedback : null,
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
      child: _morphSize(
        alignment: AlignmentDirectional.centerStart,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }

  /// Shows [idle] normally, the recording waveform in its place while recording,
  /// and nothing while transcribing, when the caption above shows the shimmer.
  /// [height] pins the slot to the resting pills' 44pt row.
  Widget _buildVoiceAwareSlot({required double height, required Widget idle}) {
    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("voice-slot-idle"), child: idle),
      _VoicePresentation.recording => KeyedSubtree(
        key: const ValueKey("voice-slot-recording"),
        child: Center(child: _buildWaveform(context)),
      ),
      _VoicePresentation.transcribing => const SizedBox(key: ValueKey("voice-slot-transcribing")),
    };

    return SizedBox(
      height: height,
      child: AnimatedSwitcher(duration: _morphDuration, transitionBuilder: _fadeEachEntry, child: child),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    final prego = context.prego;

    return PregoVoiceWaveform(
      amplitudeStream: _voiceCubit.amplitudeStream,
      // White-on-dark in the dark theme per the design; the light theme flips
      // to its own primary so the bars stay visible on the light pill.
      barColor: prego.colors.textPrimary,
      dotColor: prego.colors.fgQuaternary,
      flattenProgress: _cancelDragProgress,
    );
  }

  /// The design's `Transcribing...` treatment: primary-coloured text swept by
  /// a placeholder-dark band.
  String _transcribingLabel(BuildContext context) =>
      _renderedVoiceState is VoiceInputLiveFinishing ? context.loc.voiceFinishing : context.loc.voiceTranscribing;

  Widget _buildTranscribingShimmer(BuildContext context) {
    final prego = context.prego;
    final label = _transcribingLabel(context);

    return PregoShimmer(
      appearDelay: Duration.zero,
      highlightColor: prego.colors.textPlaceholderSubtle,
      semanticLabel: label,
      child: Text(
        label,
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

    // A pointer shell clicks to start; the wide Send takes it from there.
    if (ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer) {
      return Semantics(
        button: true,
        child: Tooltip(
          message: loc.voiceRecord,
          child: PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.microphone,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _handleMicClick,
          ),
        ),
      );
    }

    // No Tooltip here: its long-press trigger would race the recording hold.
    // The button keeps its enabled look and swallows plain taps via
    // [_ignoreTap]; the surrounding raw pointer listener drives recording.
    // Semantic taps toggle recording and a semantic dismiss cancels it, because
    // assistive technologies cannot express the hold or the slide out of it.
    return Semantics(
      button: true,
      label: loc.voiceRecord,
      excludeSemantics: true,
      onTap: _toggleRecording,
      onDismiss: _isListening ? _cancelVoiceInteractionWithFeedback : null,
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
        onPressed: _hasSendableContent && !_isAwaitingDictatedWords ? _handleSend : null,
      ),
    );
  }
}
