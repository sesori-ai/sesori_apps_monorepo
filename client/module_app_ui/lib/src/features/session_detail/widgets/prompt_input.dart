import "dart:async";
import "dart:math";

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
import "../../../widgets/composer_or_notice.dart";
import "../composer_presentation_scope.dart";
import "command_picker.dart";
import "composer_live_words.dart";
import "composer_options_accordion.dart";
import "composer_surface_style.dart";
import "image_attachment_viewer.dart";
import "prompt_editor_sheet.dart";
import "sent_bubble_landing.dart";
import "transcript_motion.dart";

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

/// Whether Send is held until in-flight inserts stage.
sealed class const _SendHold();

final class const _SendNotHeld() extends _SendHold;

/// Completing [cancelled] abandons the held send because the composer moved
/// to another draft.
final class const _SendHeld({required final Completer<void> cancelled}) extends _SendHold;

// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _PasteResult { unhandled, handled, stale }

final class _ComposerPasteAction({
  required final Future<void> Function({
    required TextEditingValue initialValue,
    required FutureOr<void> Function() onTextPaste,
    required VoidCallback? onAttachmentPasted,
  })
  _pasteClipboard,
  required final TextEditingController _controller,
}) extends Action<PasteTextIntent> {
  @override
  Object? invoke(PasteTextIntent intent) {
    // callingAction is available only during this synchronous override call,
    // so retain Flutter's normal text-paste action before reading the clipboard.
    final textPasteAction = callingAction;
    final initialValue = _controller.value;
    unawaited(
      _pasteClipboard(
        initialValue: initialValue,
        onTextPaste: () {
          textPasteAction?.invoke(intent);
        },
        onAttachmentPasted: null,
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

  /// Whether the bridge saves files that are not inline images. Null keeps
  /// already staged files while current bridge capability is being resolved.
  required final bool? fileUploadsSupported,

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
  /// Finds the composer's Send button, enabled or not, in widget and
  /// integration tests. The session and new-session composers share it.
  static const sendButtonKey = ValueKey("promptInput.sendButton");

  /// Finds the composer's text field in widget and integration tests.
  static const textFieldKey = ValueKey("promptInput.textField");

  /// Finds the resting text-first pill's field area, which a tap opens into
  /// the text field, in widget and integration tests.
  static const startTypingKey = ValueKey("promptInput.startTyping");

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState() extends State<PromptInput> {
  static const _draftCalculator = ComposerDraftCalculator();
  static const _minimumRecordingDuration = Duration(milliseconds: 200);
  static const _successFeedbackPulseDelay = Duration(milliseconds: 100);

  /// A notice that something wasn't added often comes as a picker closes or a
  /// drop lands, while the eyes are still on their way back, and it names the
  /// reason as well as what was left out, so it stays up longer.
  static const _rejectedAttachmentNoticeDuration = Duration(seconds: 5);
  final _controller = TextEditingController();
  late final _wordsBox = ComposerWordsBox(controller: _controller);
  final _textScrollController = ScrollController();
  final _focusNode = FocusNode();

  /// Holds keyboard focus for the whole composer while a click-started
  /// recording runs outside the text field, so Escape can cancel it.
  final _composerFocusNode = FocusNode(debugLabel: "PromptInput composer", skipTraversal: true);
  late final Action<PasteTextIntent> _pasteAction;
  int _pasteGeneration = 0;

  /// The last answer each capability gave, kept while it reads null. A
  /// dropped connection resets both to null until the bridge answers again,
  /// which is a blip rather than a new answer: the plus, pastes and drops
  /// keep offering and routing by these, and only a change between two
  /// answers discards what is in flight. Send and the stranded sweep read
  /// the widget's values, so Send waits for the real answer and a later
  /// `false` still clears what it strands.
  bool? _knownAttachmentsSupported;
  bool? _knownFileUploadsSupported;
  late ComposerDraft _draft;
  late TextEditingValue _previousEditingValue;
  bool _isApplyingDraft = false;
  bool _isSubmitting = false;

  /// What [PromptInput.onBusyChanged] last heard, and the work behind it.
  bool _reportedBusy = false;
  bool _voiceBusy = false;
  int _pendingInserts = 0;

  /// Picks, pastes and drops in flight for the current paste generation; the
  /// only ones Send waits for, since older ones are discarded when they land.
  int _generationInserts = 0;

  /// Settles once every pick, paste and drop started in the current paste
  /// generation has settled.
  Future<void> _insertsSettled = Future<void>.value();

  _SendHold _sendHold = const _SendNotHeld();
  _VoiceGesturePresentation _voiceInteraction = const _VoiceIdle();
  VoiceInputState _renderedVoiceState = const VoiceInputState.idle();
  StreamSubscription<VoiceInputState>? _voiceStateSub;
  Stream<List<String>>? _droppedPaths;
  StreamSubscription<List<String>>? _droppedPathsSub;
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
  bool _optionsOpen = false;

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

  /// Whether a send has just left the keyboard down. Lasts while the layout the
  /// send left fades, see [_layoutComposerBody].
  bool _sendLeftKeyboardDown = false;

  /// Whether the composer closes with the send's row rising in the transcript. A
  /// tap back into typing during that fade ends it, as the box then opens again.
  bool get _closesWithSend => _sendLeftKeyboardDown && _layout != ComposerSurfaceLayout.typing;

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

  ComposerCapabilityProvider<FileClipboard>? get _fileClipboard =>
      ComposerPresentationScope.read(context).fileClipboard;

  @override
  void initState() {
    super.initState();
    _pasteAction = _ComposerPasteAction(
      pasteClipboard: _pasteClipboard,
      controller: _controller,
    );
    _applyDraft(draft: widget.initialDraft, notify: false);
    if (widget.initialSelection case (:final base, :final extent)) {
      _controller.selection = TextSelection(baseOffset: base, extentOffset: extent);
      _previousEditingValue = _controller.value;
    }
    _restoreInitialAttachments();
    _knownAttachmentsSupported = widget.attachmentsSupported;
    _knownFileUploadsSupported = widget.fileUploadsSupported;
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
    final droppedPaths = capabilities.droppedPaths;
    if (droppedPaths != _droppedPaths) {
      unawaited(_droppedPathsSub?.cancel());
      _droppedPaths = droppedPaths;
      _droppedPathsSub = droppedPaths?.listen(_handleDroppedPaths);
    }
    _syncSurfaceStyle();
    _releaseHintHeight = _measureReleaseHintHeight();
    // A notice in the composer's place hides the mic and every way to release
    // or cancel it, so a recording would run on unseen. Dropping it leaves the
    // draft and attachments as they were.
    if (ComposerSetAside.of(context) && _isListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isListening) unawaited(_cancelVoiceInteraction());
      });
    }
  }

  @override
  void dispose() {
    _cancelHeldSend();
    _voiceStateSub?.cancel();
    _droppedPathsSub?.cancel();
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
      if (exceededBudget) {
        _showComposerNotice(
          context.loc.sessionDetailAttachmentBudgetExceeded,
          duration: _rejectedAttachmentNoticeDuration,
        );
      }
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
    // Under a pointer the composer is always its full two rows, with the pickers
    // inside it, so it reads as one block and never resizes as typing starts.
    showsTypingLayout: _showsTypingLayout || _pointerShell,
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
    return widget.canSend && hasContent && _canDeliverAttachments;
  }

  bool get _canDeliverAttachments => canDeliverComposerAttachments(
    attachments: _attachments,
    inlineImages: widget.attachmentsSupported,
    fileUploads: widget.fileUploadsSupported,
  );

  /// Whether the plus, a paste or a drop can stage anything: an image for a
  /// harness that takes them, or a file for a bridge that saves uploads. Read
  /// from the last answers, so a reconnect doesn't switch them off.
  bool get _takesAttachments => (_knownAttachmentsSupported ?? false) || (_knownFileUploadsSupported ?? false);

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
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
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
    _isSubmitting = true;
    try {
      return await _submitHeldComposer(fromDictation: fromDictation);
    } finally {
      _isSubmitting = false;
      _reportBusy();
    }
  }

  /// Holds Send, with a spinner in its place, until every pick, paste and
  /// drop in flight has staged, so an image still being prepared goes out
  /// with the prompt. One that fails shows its own notice and the prompt goes
  /// without it. Returns false when the composer moved to another draft or
  /// went away meanwhile, so nothing is sent into the wrong session.
  Future<bool> _awaitPendingInserts() async {
    final cancelled = Completer<void>();
    setState(() => _sendHold = _SendHeld(cancelled: cancelled));
    try {
      while (_generationInserts > 0 && !cancelled.isCompleted) {
        await Future.any([_insertsSettled, cancelled.future]);
      }
      return mounted && !cancelled.isCompleted;
    } finally {
      if (mounted) {
        setState(() => _sendHold = const _SendNotHeld());
      } else {
        _sendHold = const _SendNotHeld();
      }
    }
  }

  /// Makes every pick, paste and drop in flight stale. Their results are
  /// discarded, so later inserts and Send no longer wait for them.
  void _startPasteGeneration() {
    _pasteGeneration++;
    _generationInserts = 0;
    _insertsSettled = Future<void>.value();
  }

  /// Whether a capability gave an answer other than its last one. Losing an
  /// answer (null) is no change, and neither is a first answer: anything
  /// routed before it treated the capability as absent, so it never stages
  /// more than the answer allows.
  static bool _capabilityAnswerChanged({required bool? known, required bool? current}) =>
      known != null && current != null && known != current;

  void _cancelHeldSend() {
    if (_sendHold case _SendHeld(:final cancelled) when !cancelled.isCompleted) cancelled.complete();
  }

  /// [_submitComposer]'s body, run while it holds [_isSubmitting], so a second
  /// press while Send waits does nothing.
  Future<bool> _submitHeldComposer({required bool fromDictation}) async {
    // Checked without awaiting when nothing is in flight, so a plain send
    // still goes out in the same turn.
    if (_generationInserts > 0 && !await _awaitPendingInserts()) return false;
    if (!mounted || !widget.canSend) return false;

    final wasFocused = _focusNode.hasFocus;
    final stagedCommand = widget.stagedCommand;
    final attachments = List<ComposerAttachment>.unmodifiable(_attachments);
    if (!_canDeliverAttachments) return false;
    if (stagedCommand != null && attachments.isNotEmpty) {
      // The bridge's command paths read only the text part, so attachments
      // sent with a command would silently vanish. Refuse the combination and
      // keep both staged for the user to untangle.
      _showComposerNotice(context.loc.sessionDetailAttachmentsNotWithCommands);
      return false;
    }

    final submission = _draftCalculator.trim(draft: _draft);
    if (stagedCommand == null && submission.text.isEmpty && attachments.isEmpty) return false;

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

    _startPasteGeneration();
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
    } else {
      setState(() => _sendLeftKeyboardDown = true);
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant PromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draftChanged = oldWidget.draftIdentity != widget.draftIdentity;
    final restorationRequested = widget.restorationKey != null && oldWidget.restorationKey != widget.restorationKey;
    final stagedCommandChanged = oldWidget.stagedCommand?.name != widget.stagedCommand?.name;
    // A pick, paste or drop in flight was routed by the answers when it
    // started, so only a different answer makes it stale. A null between two
    // equal answers is a connection blip: a Files pick that outlives Android
    // closing the backgrounded app's socket still lands.
    if (_capabilityAnswerChanged(known: _knownAttachmentsSupported, current: widget.attachmentsSupported) ||
        _capabilityAnswerChanged(known: _knownFileUploadsSupported, current: widget.fileUploadsSupported)) {
      _startPasteGeneration();
    }
    if (draftChanged) {
      // Another composer's answers say nothing about this one's.
      _knownAttachmentsSupported = widget.attachmentsSupported;
      _knownFileUploadsSupported = widget.fileUploadsSupported;
    } else {
      _knownAttachmentsSupported = widget.attachmentsSupported ?? _knownAttachmentsSupported;
      _knownFileUploadsSupported = widget.fileUploadsSupported ?? _knownFileUploadsSupported;
    }
    if (draftChanged || restorationRequested) {
      // A draft identity change means this state moved to another composer. A
      // restoration key change means a fast failed send reused this composer.
      // Both replace authored content exactly once, and abandon a send still
      // waiting for the old draft's images.
      _startPasteGeneration();
      _cancelHeldSend();
      _attachments.clear();
      _applyDraft(draft: widget.initialDraft, notify: false);
      _restoreInitialAttachments();
    }
    // Switching the new-session harness to one that drops image parts strands
    // the images staged for the previous pick, and a bridge that turns out not
    // to save uploads strands the files, so each goes with its capability.
    bool stranded(ComposerAttachment attachment) => isComposerAttachmentStranded(
      attachment: attachment,
      inlineImages: widget.attachmentsSupported,
      fileUploads: widget.fileUploadsSupported,
    );
    if (_attachments.any(stranded)) {
      setState(() => _attachments.removeWhere(stranded));
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

  /// Whether a screen reader's tap on the hold surface or the mic does anything:
  /// [_toggleRecording] has nothing to toggle while words are on their way or a
  /// failed recording waits for its retry.
  bool get _takesRecordingToggle =>
      _isListening || (_voiceInteraction is _VoiceIdle && _renderedVoiceState is VoiceInputIdle);

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
      case (VoiceDictationOutcome.limitReached, VoiceDictationMode.live || VoiceDictationMode.onDeviceLive):
        _showComposerNotice(context.loc.voiceDictationLimitReached);
      case (VoiceDictationOutcome.limitReached, VoiceDictationMode.afterRecording || VoiceDictationMode.onDeviceHidden):
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
        VoiceDictationMode.onDeviceLive || VoiceDictationMode.onDeviceHidden => AnalyticsVoiceMode.onDevice,
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
    Duration duration = PregoPopupAlertPresenter.defaultDuration,
  }) {
    PregoPopupAlertPresenter.of(context).show(
      title: message,
      variant: variant,
      duration: duration,
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

  /// A pointer shell's empty input says Transcribing itself, in the placeholder's
  /// place; with a draft in the way the caption says it instead.
  bool get _transcribesInField =>
      _pointerShell &&
      _layout == ComposerSurfaceLayout.typing &&
      _voicePresentation == _VoicePresentation.transcribing &&
      _controller.text.isEmpty;

  String _hintText(BuildContext context) {
    final command = widget.stagedCommand;
    if (command != null) {
      for (final hint in command.hints ?? <String>[]) {
        final trimmed = hint.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return context.loc.sessionDetailCommandArgumentsHint;
    }
    if (_pointerShell && _voicePresentation == _VoicePresentation.recording) return context.loc.voiceListening;
    return widget.hasMessages ? context.loc.sessionDetailFollowUpHint : context.loc.sessionDetailPromptHint;
  }

  /// House transition timing for the composer's state morphs.
  static const Duration _morphDuration = Duration(milliseconds: 220);
  static const Curve _morphCurve = Curves.easeOutCubic;

  /// Even through its stretch: the house ease squeezed into these 88 ms would show
  /// half of what returns in a single 60 Hz frame.
  static const Interval _trailingReturnCurve = Interval(0.6, 1);
  static const Curve _heldLeaveCurve = FlippedCurve(_morphCurve);

  /// The latest fade in of what covers the resting words, a hold's and then its
  /// transcribing's, which the caption's transition reports.
  Animation<double>? _coverFade;

  /// The hint and the waveform dissolve in on a press, then leave on the house
  /// curve so what rests beneath them can come back into a clear space. An
  /// [AnimatedSwitcher] entry keeps the curves of the build that made it, and one
  /// turned back mid-fade retraces its way in, so a quick tap never jumps.
  Curve get _heldOutCurve => _voicePresentation == _VoicePresentation.recording ? _heldLeaveCurve : Curves.linear;

  /// Under a pointer, starting a dictation clears the row before filling it: the
  /// options are gone by 40% of the morph and the waveform arrives from there, so
  /// its line never runs through their labels.
  bool get _pointerRowAtRest => _pointerShell && _voicePresentation == _VoicePresentation.idle;
  bool get _pointerRowListening => _pointerShell && _voicePresentation == _VoicePresentation.recording;
  static const Interval _clearsRowCurve = Interval(0.6, 1);
  static const Interval _intoClearRowCurve = Interval(0.4, 1, curve: Curves.easeOut);

  /// How what rests beneath a hold or a transcribing comes back: after what
  /// covered it has mostly gone, unless that was turned back mid-fade, when waiting
  /// would blink empty. Read once per build: with a trailing control the top slot
  /// builds in layout, after the caption has reported the fade this build started.
  Curve _restingInCurve = Curves.linear;

  /// [AnimatedSwitcher.defaultTransitionBuilder] keys a fade by its child's key,
  /// and the switcher drops an outgoing fade sharing the incoming one's key, so a
  /// child coming back mid-fade after a quick tap restarts from nothing. Pressing
  /// again before it finishes leaves two outgoing fades with one key, which the
  /// framework refuses. Unkeyed, every entry finishes its own fade.
  static AnimatedSwitcherTransitionBuilder get _fadeEachEntry =>
      (child, animation) => FadeTransition(opacity: animation, child: child);

  /// What a hold shows a screen reader ends with the hold, not with its fade, whose
  /// instructions and pencil no longer apply. A switcher reaches an outgoing entry
  /// only through a transition builder that differs from the last build's, so pass
  /// a closure rather than a method's tear-off.
  Widget _holdOnlyForScreenReaders({required Widget child}) =>
      ExcludeSemantics(excluding: _voicePresentation != _VoicePresentation.recording, child: child);

  /// Eases [child]'s size changes. Reduced motion resizes at once: a
  /// zero-duration [AnimatedSize] would re-dirty itself mid-layout.
  Widget _morphSize({
    required AlignmentGeometry alignment,
    required Duration duration,
    required Curve curve,
    required Clip clipBehavior,
    required Widget child,
  }) => prefersReducedMotion(context)
      ? child
      : AnimatedSize(duration: duration, curve: curve, alignment: alignment, clipBehavior: clipBehavior, child: child);

  /// Stacks the composer's layouts on its bottom edge. A layout fading out holds
  /// the box open until it has gone, unless a send left it: then it gives up its
  /// height at once and the box closes in the frame the send's row starts to rise.
  ///
  /// The same [Align] carries a layout from current to outgoing, so that it keeps
  /// its state when it starts to fade.
  Widget _layoutComposerBody({required Widget? currentChild, required List<Widget> previousChildren}) {
    if (_sendLeftKeyboardDown && previousChildren.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sendLeftKeyboardDown = false);
      });
    }
    Widget place({required Widget child, required double heightFactor, required bool outgoing}) => Align(
      key: child.key,
      alignment: Alignment.bottomCenter,
      widthFactor: 1,
      heightFactor: heightFactor,
      child: _ComposerLayoutSlot(outgoing: outgoing, child: child),
    );
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        for (final child in previousChildren)
          place(child: child, heightFactor: _closesWithSend ? 0 : 1, outgoing: true),
        if (currentChild != null) place(child: currentChild, heightFactor: 1, outgoing: false),
      ],
    );
  }

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
    _pauseDropsWhileVoiceBusy();
    // A press is never a return: words landing in the box can swap the layout, and
    // its caption with them, leaving the last report settled and never turned back.
    final coverSettled = _voicePresentation != _VoicePresentation.recording && (_coverFade?.isCompleted ?? false);
    _restingInCurve = coverSettled ? _trailingReturnCurve : Curves.linear;

    // Escape cancels a running recording from anywhere in the composer. The
    // binding exists only while listening (for a pointer shell, until its words
    // arrive, as its X does), so an idle Escape still reaches the shell's own
    // handling (leaving the text field, closing popups). A pointer shell's Enter
    // and Shift+Enter finish the dictation the same way; they are handled here,
    // so neither reaches the field as a newline. Focus outside the composer
    // never gets here.
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
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
      child: Focus(
        focusNode: _composerFocusNode,
        child: _buildComposerColumn(context, capabilities: capabilities),
      ),
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
                      Expanded(
                        child: _buildComposerTopSlot(context: context, hintWidth: constraints.maxWidth),
                      ),
                      _buildComposerTrailing(trailing: trailing),
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
                // Only a layout a send left stands above the closing box: it is cut
                // along the top of the surface it is fading from.
                child: ClipRRect(
                  clipBehavior: _closesWithSend ? Clip.antiAlias : Clip.none,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(PregoRadius.x3l)),
                  child: _morphSize(
                    alignment: Alignment.bottomCenter,
                    duration: _closesWithSend ? transcriptMotionDuration : _morphDuration,
                    curve: _closesWithSend ? transcriptMotionCurve : _morphCurve,
                    clipBehavior: Clip.hardEdge,
                    child: AnimatedSwitcher(
                      key: _composerBodyKey,
                      duration: _morphDuration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) =>
                          _layoutComposerBody(currentChild: currentChild, previousChildren: previousChildren),
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
                            extraTrailingWidth: widget.isBusy ? _stopRoom : 0,
                            trailing: _buildRestingActions(context),
                          ),
                        },
                      ),
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
  Widget _buildComposerTrailing({required Widget trailing}) {
    final visible = _voicePresentation != _VoicePresentation.recording;
    return _fadeInPlace(
      visible: visible,
      child: _inertUntilShowing(
        visible: visible,
        waitsOnArrival: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
          child: PregoPageHalo(radius: PregoRadius.full, reachesLayerBottom: false, child: trailing),
        ),
      ),
    );
  }

  /// Fades [child] where it stands, inert from the moment it starts to go.
  Widget _fadeInPlace({required bool visible, required Widget child}) {
    final opacity = visible ? 1.0 : 0.0;
    // Leaves on the house curve and comes back once what is over its place (the
    // release hint, the waveform's end, the keyboard button) has mostly gone: each
    // fade holds one curve, as an implicit animation given a new curve restarts from
    // the wrong value when a quick tap turns it back.
    return AnimatedOpacity(
      duration: _morphDuration,
      curve: _morphCurve,
      opacity: opacity,
      child: AnimatedOpacity(
        duration: _morphDuration,
        curve: _trailingReturnCurve,
        opacity: opacity,
        child: ExcludeFocus(
          excluding: !visible,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    );
  }

  /// Keeps [child] inert for the first stretch of its return, while [_fadeInPlace]
  /// still shows nothing: a tap on that empty spot must not send the draft a hold
  /// left in the box, or stop the running work. With [waitsOnArrival] it also waits
  /// as its layout cross-fades in: a send that collapses the box brings the resting
  /// stop under the finger.
  Widget _inertUntilShowing({required bool visible, required bool waitsOnArrival, required Widget child}) {
    final target = visible ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: waitsOnArrival ? 0 : target, end: target),
      duration: _morphDuration,
      builder: (context, progress, _) {
        final inert = progress < _trailingReturnCurve.begin;
        return ExcludeFocus(
          excluding: inert,
          child: IgnorePointer(ignoring: inert, child: child),
        );
      },
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
    } else if (_voicePresentation == _VoicePresentation.recording && !_pointerShell) {
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
        null => _pointerShell ? null : widget.composerHeader,
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
        child:
            headerChild ??
            (_pointerShell
                ? const SizedBox(width: double.infinity)
                : SizedBox(width: double.infinity, height: _actionButtonSize)),
      );
    }

    return _morphSize(
      duration: _morphDuration,
      curve: _morphCurve,
      alignment: Alignment.bottomCenter,
      // Growing for large text must not cut off a hint reaching past this slot.
      clipBehavior: hintWidth == null ? Clip.hardEdge : Clip.none,
      child: AnimatedSwitcher(
        duration: _morphDuration,
        // A failed transcribing's Retry and Discard take taps as they arrive, so they
        // show at once rather than waiting behind the shimmer's exit.
        switchInCurve: _renderedVoiceState is VoiceInputRetryPending ? Curves.linear : _restingInCurve,
        switchOutCurve: _heldOutCurve,
        transitionBuilder: (transitionChild, animation) {
          // Only the staged chip bears glass. Picker/voice/retry content keeps
          // its ordinary fade, including while the outgoing chip dematerializes.
          // Under reduced motion the materialize is itself a plain fade, with no
          // scale or blur, and the one fade that glass honours.
          if (transitionChild.key == const ValueKey("staged-command")) {
            return GlassMaterializeTransition(animation: animation, child: transitionChild);
          }
          final fade = _fadeEachEntry(transitionChild, animation);
          return transitionChild.key == const ValueKey("release-hint") ? _holdOnlyForScreenReaders(child: fade) : fade;
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

    if (_pointerShell) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.sm),
        child: DecoratedBox(
          decoration: pregoComposerSurfaceDecoration(
            prego: prego,
            style: PregoComposerSurfaceStyle.subtle,
            borderRadius: BorderRadius.circular(PregoRadius.x2l),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              PregoSpacing.lg,
              PregoSpacing.md,
              PregoSpacing.md,
              PregoSpacing.md,
            ),
            child: Row(
              spacing: PregoSpacing.md,
              children: [
                Icon(TablerRegular.alert_circle, size: PregoIconSize.sm, color: prego.colors.fgWarningPrimary),
                Expanded(
                  child: Text(
                    loc.voiceSavedNotice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
                  ),
                ),
                PregoButtonsSolid(
                  key: const Key("voice_saved_discard"),
                  label: loc.voiceDiscard,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: _discardSavedRecording,
                ),
                PregoButtonsSolid(
                  key: const Key("voice_saved_retry"),
                  label: loc.voiceRetry,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: _retrySavedRecording,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
      hintHeight: _pointerShell ? 0 : _releaseHintHeight,
      box: _wordsBox,
      boxStyle: _fieldStyle(context),
      isBusy: widget.isBusy,
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
                      _VoiceDragArm.none => loc.voiceReleaseToSend,
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
  /// [restingActions] sit in a layer over the row at the row's resting inset.
  /// Their room in the row closes during recording: with only the row gap left,
  /// the end inset eases down so the waveform ends the spec's 12pt from the edge.
  /// Neither that nor the room reopening beneath them ever moves them.
  Widget _buildVoicePillSurface(
    BuildContext context, {
    required PregoComposerSurfaceStyle surfaceStyle,
    required Widget child,
    required Widget? overlay,
    required Widget? restingActions,
  }) {
    final prego = context.prego;
    final radius = BorderRadius.circular(_pointerShell ? PregoRadius.x2l : PregoRadius.full);
    final tightenEnd = restingActions != null && _voicePresentation == _VoicePresentation.recording;

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
            duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
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
          if (restingActions != null)
            PositionedDirectional(
              top: PregoSpacing.sm,
              bottom: PregoSpacing.sm,
              end: PregoSpacing.sm,
              child: restingActions,
            ),
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
            borderRadius: BorderRadius.circular(_pointerShell ? PregoRadius.x2l : PregoRadius.full),
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
    final trailingVisible = _voicePresentation != _VoicePresentation.recording;

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.subtle,
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
          // Open, the options reach past the room the words keep from the row's
          // actions. On both sides, so that words with room to spare stay put.
          extraSideWidth: _optionsOpen && _voicePresentation == _VoicePresentation.idle
              ? ComposerOptionsAccordion.openWidth(showAttachImage: _offersAttachImage, pointer: _pointerShell) -
                    _actionButtonSize
              : 0,
        ),
      ),
      restingActions: _fadeInPlace(
        visible: trailingVisible,
        child: _inertUntilShowing(visible: trailingVisible, waitsOnArrival: false, child: trailing),
      ),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildLeadingSlot(context),
          Expanded(
            child: _buildHoldSurface(
              context,
              hint: hint,
              child: _buildVoiceAwareSlot(height: _actionButtonSize, idle: const SizedBox()),
            ),
          ),
          // The room held for the actions in the layer above. It closes while the
          // waveform needs it, and the row's child list never changes: gesture
          // owners elsewhere in the row must keep their elements.
          _morphSize(
            alignment: AlignmentDirectional.centerStart,
            duration: _morphDuration,
            curve: _morphCurve,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: trailingVisible ? _actionButtonSize + extraTrailingWidth : 0),
          ),
        ],
      ),
    );
  }

  /// The composer's centred words, in a layer over its row: the slot beneath
  /// widens as the room for voice-first's trailing actions closes, which would
  /// carry them sideways as they fade. The insets match the row's at rest, so they sit centred between
  /// its actions. [extraTrailingWidth] is how much wider the trailing actions
  /// rest than the leading ones, [extraSideWidth] more room to keep on each side.
  Widget _buildVoiceCaption(
    BuildContext context, {
    required Widget idle,
    required double extraTrailingWidth,
    required double extraSideWidth,
  }) {
    final Widget child = switch (_voicePresentation) {
      _VoicePresentation.idle => KeyedSubtree(key: const ValueKey("voice-caption-idle"), child: idle),
      _VoicePresentation.recording => const SizedBox.shrink(key: ValueKey("voice-caption-recording")),
      _VoicePresentation.transcribing when _transcribesInField => const SizedBox.shrink(
        key: ValueKey("voice-caption-transcribing-in-field"),
      ),
      _VoicePresentation.transcribing => KeyedSubtree(
        key: const ValueKey("voice-caption-transcribing"),
        child: _buildTranscribingShimmer(context),
      ),
    };

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: PregoSpacing.sm + _actionButtonSize + PregoSpacing.md),
        child: AnimatedPadding(
          duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
          curve: _morphCurve,
          padding: EdgeInsetsDirectional.only(start: extraSideWidth, end: extraSideWidth + extraTrailingWidth),
          child: Center(
            child: AnimatedSwitcher(
              duration: _morphDuration,
              switchInCurve: _restingInCurve,
              // Only the shimmer shows on the way out: the words at rest dissolve
              // into a press, and the transcribing words clear for them to return.
              switchOutCurve: _voicePresentation == _VoicePresentation.idle ? Curves.linear : _heldLeaveCurve,
              transitionBuilder: (transitionChild, animation) {
                if (transitionChild.key != const ValueKey("voice-caption-idle")) _coverFade = animation;
                return _fadeEachEntry(transitionChild, animation);
              },
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Voice-first's resting actions: the keyboard button and, while work runs, the
  /// stop button at the row's end. Stop never travels: it fades where it rests, in
  /// the spot the keyboard button leaves, and stays mounted so that it still is a
  /// stop button as it goes. The keyboard button glides past on top, in step with
  /// the room behind it and the words beside it.
  Widget _buildRestingActions(BuildContext context) {
    final busy = widget.isBusy;
    return SizedBox(
      width: _actionButtonSize + _stopRoom,
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          _fadeInPlace(
            visible: busy,
            child: _inertUntilShowing(
              visible: busy,
              waitsOnArrival: true,
              child: _buildStopButton(
                context,
                onPressed: () {
                  // A press can outlast the work: lifting after it ended stops nothing.
                  if (widget.isBusy) widget.onAbort();
                },
              ),
            ),
          ),
          AnimatedPositionedDirectional(
            duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
            curve: _morphCurve,
            end: busy ? _stopRoom : 0,
            child: _buildLabelledIconButton(
              label: context.loc.sessionDetailTypeMessage,
              icon: TablerRegular.keyboard,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              onPressed: _enterTypingMode,
            ),
          ),
        ],
      ),
    );
  }

  /// The text-first layouts' caption, showing the shimmer and [idle] at rest. A
  /// pointer shell's voice targets and wide Send are equally wide; a touch shell
  /// has the mic beyond the send.
  Widget _buildTextFirstCaption(BuildContext context, {required Widget idle}) {
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    final pointer = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;
    return _buildVoiceCaption(
      context,
      idle: idle,
      extraTrailingWidth: pointer ? 0 : _actionButtonSize + PregoSpacing.sm,
      extraSideWidth: 0,
    );
  }

  /// The compact pill's hint in the caption, for a pointer shell, whose voice
  /// targets are wider than its options and would carry it sideways in the slot.
  /// The insets narrow the caption to that slot as it rests, so the words sit and
  /// clip as they would inside it. The tap target in the slot speaks for them.
  Widget _buildPointerCaptionHint(BuildContext context, {required Widget hint}) {
    final optionsWidth = ComposerOptionsAccordion.openWidth(
      showAttachImage: _offersAttachImage,
      pointer: _pointerShell,
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: _actionButtonSize,
        child: AnimatedPadding(
          // Follows the options when the harness' attachment support resolves.
          duration: prefersReducedMotion(context) ? Duration.zero : _morphDuration,
          curve: _morphCurve,
          padding: EdgeInsetsDirectional.only(
            start: optionsWidth - _actionButtonSize + PregoSpacing.xs,
            end: _pointerVoiceGroupWidth - _actionButtonSize,
          ),
          child: Align(alignment: AlignmentDirectional.centerStart, child: hint),
        ),
      ),
    );
  }

  /// Resting state for text-first mode: a compact pill whose field area
  /// invites typing, with mic and send/stop alongside.
  Widget _buildCompactComposer(BuildContext context) {
    final prego = context.prego;
    final hintInCaption =
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
        _voiceSupport.isSupported && ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;
    final hint = Text(
      _hintText(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
    );

    return _buildVoicePillSurface(
      context,
      surfaceStyle: PregoComposerSurfaceStyle.emphasized,
      overlay: _buildTextFirstCaption(
        context,
        idle: hintInCaption ? _buildPointerCaptionHint(context, hint: hint) : const SizedBox.shrink(),
      ),
      restingActions: null,
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
                  key: PromptInput.startTypingKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _enterTypingMode,
                  child: hintInCaption
                      ? Semantics(label: _hintText(context), child: const SizedBox.expand())
                      : Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                            child: hint,
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
    final decoration = pregoComposerSurfaceDecoration(
      prego: context.prego,
      style: PregoComposerSurfaceStyle.emphasized,
      borderRadius: borderRadius,
    );

    // Not a Container, which adds its border to its padding: the controls below
    // would rest 1 pt inside where the resting pills put theirs, and shift as the
    // layouts cross-fade. Only the words keep clear of the border.
    return DecoratedBox(
      decoration: decoration,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          // A tap on the padding around the words focuses them, as a tap on the
          // words does. This layer lies beneath the content, so it only gets taps
          // that land on nothing there: the tiles keep their open and remove taps,
          // and the strip keeps the space between them as its own.
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: _focusNode.requestFocus,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PregoSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.md,
              children: [
                Padding(padding: decoration.padding, child: _buildTypingField(context)),
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
          ),
        ],
      ),
    );
  }

  /// The typing container's staged images and multiline field, with the
  /// fullscreen-editor button in the field's corner.
  Widget _buildTypingField(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final sendKeyPolicy = ComposerPresentationScope.of(context).sendKeyPolicy;
    // A pointer shell grows the box for long prompts instead of offering the
    // full-screen editor sheet.
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    final growsInPlace = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PregoSpacing.md,
      children: [
        if (_attachments.isNotEmpty) _buildAttachmentStrip(context),
        Stack(
          children: [
            Padding(
              // Clear the expand button on the trailing edge so text never
              // runs underneath it.
              // Under a pointer the words start on the + glyph's edge below them.
              padding: EdgeInsetsDirectional.fromSTEB(
                // Optically on the + glyph's edge.
                _pointerShell ? PregoSpacing.md + 2 : PregoSpacing.xs,
                0,
                growsInPlace ? PregoSpacing.xs : 36,
                0,
              ),
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
                      key: PromptInput.textFieldKey,
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
                        hint: _transcribesInField ? _buildTranscribingShimmer(context) : null,
                        hintText: _transcribesInField ? null : _hintText(context),
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
                child: PregoButtonSemantics(
                  label: loc.sessionDetailExpandEditor,
                  enabled: _voicePresentation == _VoicePresentation.idle,
                  showsTooltip: true,
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
      ],
    );
  }

  Widget _buildComposerContextMenu({required EditableTextState editableTextState}) {
    final buttonItems = [...editableTextState.contextMenuButtonItems];
    if (!kIsWeb && (_takesAttachments || _fileClipboard != null)) {
      final pasteIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.paste);
      final existingPaste = pasteIndex < 0 ? null : buttonItems[pasteIndex];
      final existingPasteCallback = existingPaste?.onPressed;
      final pasteItem = ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        label: existingPaste?.label,
        onPressed: () {
          // Preserve the selection from the paste intent; the file and image probes may
          // outlive the menu, so a later caret move must not redirect the text
          // fallback.
          final initialValue = editableTextState.textEditingValue;
          unawaited(
            _pasteClipboard(
              initialValue: initialValue,
              onTextPaste: existingPasteCallback ?? () => editableTextState.pasteText(SelectionChangedCause.toolbar),
              onAttachmentPasted: editableTextState.hideToolbar,
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
          switch (_attachments[index]) {
            final ComposerFileAttachment file => PregoFileAttachmentPreview(
              key: ObjectKey(file),
              fileName: file.filename,
              removeLabel: loc.sessionDetailRemoveAttachment,
              onRemove: () => _removeAttachment(index: index),
            ),
            final ComposerImageAttachment image => PregoImageAttachmentPreview(
              key: ObjectKey(image),
              imageLabel: image.filename ?? loc.sessionDetailAttachedImage,
              onOpen: () => _openAttachment(attachment: image),
              removeLabel: loc.sessionDetailRemoveAttachment,
              onRemove: () => _removeAttachment(index: index),
              image: Hero(
                tag: ObjectKey(image),
                child: Image.memory(
                  image.bytes,
                  // Decode at thumbnail scale rather than retaining full-resolution
                  // rasters for every staged image. Original bytes still get sent.
                  cacheWidth: (PregoImageAttachmentPreview.size * MediaQuery.devicePixelRatioOf(context)).round(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          },
      ],
    );
  }

  void _removeAttachment({required int index}) {
    setState(() => _attachments.removeAt(index));
    _reportAttachments();
  }

  void _openAttachment({required ComposerImageAttachment attachment}) {
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
              child: _buildVoiceAwareSlot(
                height: _actionButtonSize,
                idle: switch (widget.composerHeader) {
                  final pickers? when _pointerShell => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: pickers,
                  ),
                  _ => const SizedBox(),
                },
              ),
            ),
            _buildMicAndPrimaryActions(context),
          ],
        ),
        Positioned.fill(
          left: -PregoSpacing.sm,
          top: -PregoSpacing.sm,
          right: -PregoSpacing.sm,
          bottom: -PregoSpacing.sm,
          child: _buildTextFirstCaption(context, idle: const SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildMicAndPrimaryActions(BuildContext context) {
    if (_voiceSupport.isSupported &&
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
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
          duration: _morphDuration,
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
    final keepsStop = _showsStop;
    final sendEnd = keepsStop ? _stopRoom : 0.0;
    // The Send covers the mic and primary action, and widens the group only when
    // its label, translated or at a larger text size, would not fit over them.
    final sendWidth = max(
      _pointerVoiceGroupWidth,
      PregoVoiceSendButton.widthFor(context: context, label: loc.sessionDetailSend),
    );
    final groupWidth = merged ? sendWidth + sendEnd : _pointerVoiceGroupWidth;
    final motion = prefersReducedMotion(context) ? Duration.zero : _morphDuration;

    return AnimatedContainer(
      duration: motion,
      curve: _morphCurve,
      width: groupWidth,
      height: _actionButtonSize,
      child: Stack(
        // The buttons' focus rings paint past this box.
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: PregoSpacing.sm,
              children: [
                _fadesWithMerge(merged: merged, child: _buildMicButton(context)),
                if (merged && keepsStop)
                  _buildPrimaryActionButton(context)
                else
                  _fadesWithMerge(merged: merged, child: _buildPrimaryActionButton(context)),
              ],
            ),
          ),
          AnimatedPositionedDirectional(
            start: merged ? 0 : groupWidth - sendEnd - _actionButtonSize,
            end: sendEnd,
            top: 0,
            bottom: 0,
            duration: motion,
            curve: _morphCurve,
            child: IgnorePointer(
              ignoring: !merged,
              child: AnimatedOpacity(
                opacity: merged ? 1 : 0,
                duration: _morphDuration,
                curve: merged ? _intoClearRowCurve : Curves.linear,
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

  Widget _fadesWithMerge({required bool merged, required Widget child}) => ExcludeFocus(
    excluding: merged,
    child: IgnorePointer(
      ignoring: merged,
      child: AnimatedOpacity(
        opacity: merged ? 0 : 1,
        duration: _morphDuration,
        curve: merged ? const Interval(0, 0.4) : Curves.linear,
        child: child,
      ),
    ),
  );

  /// A pointer shell's X and pencil. They keep their places into transcribing:
  /// the pencil fades out, leaving nothing under a cursor that just clicked it,
  /// and the X stays on the row's edge, still stopping the work.
  Widget _buildPointerVoiceTargets(BuildContext context) {
    final loc = context.loc;
    final listening = _voicePresentation == _VoicePresentation.recording;
    final cancelLabel = listening ? loc.voiceCancelRecording : loc.voiceCancelTranscription;

    return SizedBox(
      width: _pointerVoiceGroupWidth,
      child: Row(
        spacing: PregoSpacing.sm,
        children: [
          _buildLabelledIconButton(
            label: cancelLabel,
            icon: TablerRegular.x,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            onPressed: _cancelVoiceInteractionWithFeedback,
          ),
          IgnorePointer(
            ignoring: !listening,
            child: AnimatedOpacity(
              opacity: listening ? 1 : 0,
              duration: _morphDuration,
              child: _buildLabelledIconButton(
                label: loc.voiceEditBeforeSending,
                icon: TablerRegular.pencil,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                onPressed: _handleEditTargetTap,
              ),
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
  // Read without depending: this can be asked before the first build, and a shell's
  // mode never changes.
  bool get _pointerShell =>
      // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
      context.getInheritedWidgetOfExactType<PregoInteractionScope>()?.mode == PregoInteractionMode.pointer;

  double get _actionButtonSize => _pointerShell ? 32 : 44;

  PregoButtonsSolidSize get _actionSize => _pointerShell ? PregoButtonsSolidSize.md : PregoButtonsSolidSize.lg;

  /// What the stop button adds to voice-first's resting actions.
  double get _stopRoom => _actionButtonSize + PregoSpacing.sm;

  /// A pointer shell's two 44pt controls and the gap between them, as the mic
  /// and send sit at rest.
  double get _pointerVoiceGroupWidth => _actionButtonSize * 2 + PregoSpacing.sm;

  /// Nearly every harness takes images, and new bridges save files, so the
  /// action holds its place while support is unknown instead of growing in
  /// once it is known. It leaves only when neither can take anything.
  bool get _offersAttachImage => (_knownAttachmentsSupported ?? true) || (_knownFileUploadsSupported ?? true);

  /// Where the plus picks from. Desktop's file dialog covers everything. On
  /// mobile, Photos applies whenever an image can be staged, inline or saved
  /// as a file, and Files only where the bridge saves uploads.
  List<ComposerPickSource> _attachSources({required ComposerAttachKind attachKind}) {
    if (!_takesAttachments) return const [];
    return switch (attachKind) {
      ComposerAttachKind.files => const [ComposerPickSource.files],
      ComposerAttachKind.photosAndFiles => [
        ComposerPickSource.photos,
        if (_knownFileUploadsSupported ?? false) ComposerPickSource.files,
      ],
    };
  }

  Widget _buildOptionsAccordion() {
    final attachKind = ComposerPresentationScope.of(context).attachKind;
    final attachSources = _attachSources(attachKind: attachKind);
    return PregoPickerPopover(
      pointerWidth: 360,
      onClosed: () {
        if (mounted) _updateComposerState(update: () => _typingPinnedByPicker = false);
      },
      triggerBuilder: (context, toggle) => ComposerOptionsAccordion(
        actionsEnabled: _voicePresentation == _VoicePresentation.idle,
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
        alwaysOpen: ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer,
        // A pointer shell has the room, so typing never folds the actions away.
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
        isTyping: _hasText && ComposerPresentationScope.of(context).presentation != ComposerPresentation.pointer,
        showAttachImage: _offersAttachImage,
        attachTooltip: switch (attachKind) {
          ComposerAttachKind.files => context.loc.sessionDetailAttachFiles,
          ComposerAttachKind.photosAndFiles when attachSources.length > 1 =>
            context.loc.sessionDetailAttachPhotosOrFiles,
          ComposerAttachKind.photosAndFiles => context.loc.sessionDetailAttachImage,
        },
        onSlashCommandsTap: () {
          _typingPinnedByPicker = _layout == ComposerSurfaceLayout.typing;
          toggle();
        },
        attachSources: attachSources,
        onAttach: (source) => unawaited(_handleAttach(source: source)),
        onOpenChanged: (isOpen) {
          if (isOpen != _optionsOpen) setState(() => _optionsOpen = isOpen);
        },
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

  /// Opens the shell's picker for [source]. Adding an attachment switches the
  /// composer to the typing layout (via [_showsTypingLayout]) so the preview
  /// strip is visible, without raising the keyboard.
  Future<void> _handleAttach({required ComposerPickSource source}) => _attach(
    outcome: (stagedAttachmentBytes) => _attachmentDispatcher.pick(
      source: source,
      attachmentsSupported: _knownAttachmentsSupported,
      fileUploadsSupported: _knownFileUploadsSupported,
      stagedAttachmentBytes: stagedAttachmentBytes,
    ),
  );

  /// Recording and transcription own the field, so the composer pauses its
  /// drops meanwhile: the pane then shows no drop hint and answers a drop with
  /// a notice instead of handing it over.
  void _pauseDropsWhileVoiceBusy() {
    final subscription = _droppedPathsSub;
    if (subscription == null) return;
    final busy = _voicePresentation != _VoicePresentation.idle;
    if (busy == subscription.isPaused) return;
    if (busy) {
      subscription.pause();
    } else {
      subscription.resume();
    }
  }

  void _handleDroppedPaths(List<String> paths) {
    // A drop delivered just before recording paused the subscription still
    // waits out recording and transcription, like the attach action.
    if (_voicePresentation != _VoicePresentation.idle) {
      _showComposerNotice(context.loc.sessionDetailFinishRecordingBeforeAddingFiles);
      return;
    }
    unawaited(
      _attach(
        outcome: (stagedAttachmentBytes) => _attachmentDispatcher.routeHostPaths(
          paths: paths,
          source: ComposerAttachmentSource.drop,
          attachmentsSupported: _knownAttachmentsSupported,
          fileUploadsSupported: _knownFileUploadsSupported,
          stagedAttachmentBytes: stagedAttachmentBytes,
        ),
      ),
    );
  }

  /// Applies what a pick or a drop adds, in a turn of its own.
  Future<void> _attach({required Future<ComposerAttachOutcome?> Function(int stagedAttachmentBytes) outcome}) async {
    final turn = _startInsert();
    try {
      await _insertOutcome(turn: turn, pastedOver: null, outcome: outcome);
    } finally {
      _settleInsert(turn: turn);
    }
  }

  /// Applies what a pick, a drop or pasted files add within [turn]: staged
  /// images, paths at the caret, and one notice for whatever could not be
  /// added. Reports [_PasteResult.unhandled] when [outcome] has nothing to add.
  ///
  /// [pastedOver] is the field as it was when paste was pressed, so pasted
  /// paths replace that selection; it is `null` for picks and drops.
  Future<_PasteResult> _insertOutcome({
    required _InsertTurn turn,
    required TextEditingValue? pastedOver,
    required Future<ComposerAttachOutcome?> Function(int stagedAttachmentBytes) outcome,
  }) async {
    // The result can settle after this state was reused for another session
    // (didUpdateWidget cleared the strip), after a send, or after the harness
    // changed whether it takes attachments. A late result must not leak into
    // the composer that replaced the one where it started.
    final draftIdentity = widget.draftIdentity;
    bool isStale() => draftIdentity != widget.draftIdentity || turn.pasteGeneration != _pasteGeneration;
    try {
      // Routed only once earlier inserts have staged, so each file is judged
      // against the budget that is really left.
      await turn.earlierSettled;
      // The composer may have moved on while this waited; don't open a picker
      // or read files for it.
      if (!mounted || isStale()) return _PasteResult.stale;
      final result = await outcome(_stagedAttachmentBytes);
      if (!mounted || isStale()) return _PasteResult.stale;
      if (result == null) return _PasteResult.unhandled;
      for (final attachment in result.attachments) {
        _stageAttachment(attachment: attachment);
      }
      if (result.insertedText case final text?) {
        if (pastedOver != null) _restorePasteSelection(initialValue: pastedOver);
        _insertAtCaret(text: text);
      }
      if (result.rejections.isNotEmpty) _showRejectionNotice(rejections: result.rejections);
    } on UnsupportedAttachmentImageError {
      if (!mounted || isStale()) return _PasteResult.stale;
      _showComposerNotice(context.loc.sessionDetailAttachmentUnsupported, duration: _rejectedAttachmentNoticeDuration);
    } catch (error) {
      loge("Failed to attach", error);
      if (!mounted || isStale()) return _PasteResult.stale;
      _showComposerNotice(context.loc.sessionDetailAttachmentPickFailed, duration: _rejectedAttachmentNoticeDuration);
    }
    return _PasteResult.handled;
  }

  /// One notice for whatever could not be added.
  void _showRejectionNotice({required Map<ComposerAttachRejectionReason, int> rejections}) {
    _showComposerNotice(_rejectionNotice(rejections: rejections), duration: _rejectedAttachmentNoticeDuration);
  }

  /// One line per reason, each with its own count, so a drop turned away for
  /// several reasons gets one notice that covers them all.
  String _rejectionNotice({required Map<ComposerAttachRejectionReason, int> rejections}) {
    final loc = context.loc;
    return [
      for (final reason in ComposerAttachRejectionReason.values)
        if (rejections[reason] case final count?)
          switch (reason) {
            ComposerAttachRejectionReason.notTransferable => loc.sessionDetailFilesNotTransferable(count),
            ComposerAttachRejectionReason.folderNotTransferable => loc.sessionDetailFoldersNotTransferable(count),
            ComposerAttachRejectionReason.unreadable => loc.sessionDetailFilesUnreadable(count),
            ComposerAttachRejectionReason.attachmentsUnsupported => loc.sessionDetailImagesNotAccepted(count),
            ComposerAttachRejectionReason.overBudget => loc.sessionDetailAttachmentsOverBudget(count),
          },
    ].join("\n");
  }

  /// Types [text] over the selection, or at the end when the field has none,
  /// keeping a space on each side so it never runs into the words around it.
  void _insertAtCaret({required String text}) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final leading = before.isEmpty || before.trimRight() != before ? "" : " ";
    final trailing = after.trimLeft() != after ? "" : " ";
    final inserted = "$leading$text$trailing";
    // Goes through the typed-edit path, like a text paste.
    _controller.value = TextEditingValue(
      text: "$before$inserted$after",
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
  }

  /// An image pick, paste or drop, whose result lands after an await. Its
  /// turn stages only after the ones started before it have settled, so images
  /// stage in the order they were added even when an earlier one takes longer
  /// to downscale.
  _InsertTurn _startInsert() {
    final turn = _InsertTurn(earlierSettled: _insertsSettled, pasteGeneration: _pasteGeneration);
    _insertsSettled = turn.settled;
    _pendingInserts++;
    _generationInserts++;
    _reportBusy();
    return turn;
  }

  void _settleInsert({required _InsertTurn turn}) {
    turn.settle();
    _pendingInserts--;
    if (turn.pasteGeneration == _pasteGeneration) _generationInserts--;
    _reportBusy();
  }

  /// Reads an image before allowing Flutter's normal text paste to run. An
  /// image wins when the clipboard exposes both binary and text formats. It is
  /// staged as an image when the harness takes images, and as a file when only
  /// the bridge saves uploads.
  ///
  /// The image is routed right away, so a slow downscale doesn't hold up a
  /// later paste; it stages only once earlier inserts have, and is checked
  /// then against the budget they left.
  Future<_PasteResult> _handlePasteImage({required Future<void> earlierInsertsSettled}) async {
    if (!_takesAttachments) return _PasteResult.unhandled;
    final draftIdentity = widget.draftIdentity;
    final pasteGeneration = _pasteGeneration;
    final Uint8List? bytes;
    try {
      bytes = await _imageClipboard.readImage();
    } catch (error, stackTrace) {
      loge("Failed to read a pasted image", error, stackTrace);
      return _isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)
          ? _PasteResult.stale
          : _PasteResult.unhandled;
    }

    // Never let an asynchronous paste land in a composer that replaced the
    // one where the action started.
    if (_isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)) {
      return _PasteResult.stale;
    }
    if (!mounted) return _PasteResult.stale;
    if (bytes == null) return _PasteResult.unhandled;

    // Downscaling an oversized image awaits too, so every outcome checks
    // staleness again before it touches the composer.
    try {
      final outcome = await _attachmentDispatcher.routeImageBytes(
        bytes: bytes,
        filename: null,
        source: ComposerAttachmentSource.paste,
        attachmentsSupported: _knownAttachmentsSupported,
        fileUploadsSupported: _knownFileUploadsSupported,
        stagedAttachmentBytes: _stagedAttachmentBytes,
      );
      await earlierInsertsSettled;
      if (_isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)) {
        return _PasteResult.stale;
      }
      if (outcome.attachments case [final attachment] when _stageAttachment(attachment: attachment)) {
        return _PasteResult.handled;
      }
      // Nothing was staged, so fall back and keep the clipboard's text from
      // being swallowed.
      if (outcome.rejections.isNotEmpty) _showRejectionNotice(rejections: outcome.rejections);
      return _PasteResult.unhandled;
    } on UnsupportedAttachmentImageError {
      if (!mounted || _isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)) {
        return _PasteResult.stale;
      }
      _showComposerNotice(context.loc.sessionDetailAttachmentUnsupported, duration: _rejectedAttachmentNoticeDuration);
      return _PasteResult.unhandled;
    } catch (error, stackTrace) {
      loge("Failed to attach a pasted image", error, stackTrace);
      if (!mounted || _isPasteStale(draftIdentity: draftIdentity, pasteGeneration: pasteGeneration)) {
        return _PasteResult.stale;
      }
      _showComposerNotice(context.loc.sessionDetailAttachmentPickFailed, duration: _rejectedAttachmentNoticeDuration);
      return _PasteResult.unhandled;
    }
  }

  /// Adds the files copied in the file manager like a drop, where the shell
  /// pastes files. It is not gated on image support: copied files are routed
  /// like dropped ones, whatever the backend takes.
  ///
  /// The copied files are read right away, so a copy made while an earlier
  /// image is still preparing doesn't replace them; only routing waits for it.
  Future<_PasteResult> _handlePasteFiles({
    required _InsertTurn turn,
    required TextEditingValue initialValue,
  }) async {
    final fileClipboard = _fileClipboard;
    if (fileClipboard == null) return _PasteResult.unhandled;
    final draftIdentity = widget.draftIdentity;
    // A failed read still goes through the staleness check below, so it never
    // falls back into a composer that replaced this one.
    final paths = await fileClipboard().readPaths().catchError((Object error, StackTrace stackTrace) {
      loge("Failed to read pasted files", error, stackTrace);
      return const <String>[];
    });
    if (!mounted || draftIdentity != widget.draftIdentity || turn.pasteGeneration != _pasteGeneration) {
      return _PasteResult.stale;
    }
    if (paths.isEmpty) return _PasteResult.unhandled;
    final dispatcher = _attachmentDispatcher;
    return await _insertOutcome(
      turn: turn,
      pastedOver: initialValue,
      outcome: (stagedAttachmentBytes) => dispatcher.routeClipboardPaths(
        paths: paths,
        attachmentsSupported: _knownAttachmentsSupported,
        fileUploadsSupported: _knownFileUploadsSupported,
        stagedAttachmentBytes: stagedAttachmentBytes,
      ),
    );
  }

  /// Pastes copied files first, then an image, then text. On macOS a copied
  /// Finder file also reads as an image (its icon) and as text (its name), so
  /// the files must win.
  Future<void> _pasteClipboard({
    required TextEditingValue initialValue,
    required FutureOr<void> Function() onTextPaste,
    required VoidCallback? onAttachmentPasted,
  }) async {
    // The text fallback reads the clipboard too, so the paste is busy until
    // whichever lands has landed.
    final turn = _startInsert();
    try {
      var result = await _handlePasteFiles(turn: turn, initialValue: initialValue);
      if (result == _PasteResult.unhandled) {
        result = await _handlePasteImage(earlierInsertsSettled: turn.earlierSettled);
      }
      switch (result) {
        case _PasteResult.unhandled:
          _restorePasteSelection(initialValue: initialValue);
          await onTextPaste();
          return;
        case _PasteResult.handled:
          if (mounted) onAttachmentPasted?.call();
          return;
        case _PasteResult.stale:
          return;
      }
    } catch (error, stackTrace) {
      loge("Failed to handle composer paste", error, stackTrace);
    } finally {
      _settleInsert(turn: turn);
    }
  }

  /// Restores the selection captured when paste was pressed, so what lands
  /// late replaces the same selection, unless the user typed meanwhile.
  void _restorePasteSelection({required TextEditingValue initialValue}) {
    if (_controller.text == initialValue.text && initialValue.selection.isValid) {
      _controller.selection = initialValue.selection;
    }
  }

  /// A paste only starts while the composer takes attachments, and a changed
  /// answer starts a new paste generation, so a capability that reads null
  /// meanwhile (a connection blip) does not discard the image.
  bool _isPasteStale({required String draftIdentity, required int pasteGeneration}) {
    return !mounted || draftIdentity != widget.draftIdentity || pasteGeneration != _pasteGeneration;
  }

  /// Stages an attachment and reports whether it fit the aggregate budget.
  bool _stageAttachment({required ComposerAttachment attachment}) {
    if (_attachmentsDecodedSizeWith(attachment: attachment) > maxComposerPromptAttachmentBytes) {
      _showComposerNotice(
        context.loc.sessionDetailAttachmentBudgetExceeded,
        duration: _rejectedAttachmentNoticeDuration,
      );
      return false;
    }
    setState(() => _attachments.add(attachment));
    _reportAttachments();
    return true;
  }

  /// Total decoded bytes the staged strip would carry with [attachment]
  /// added. The outbound budget is aggregate, so multiple images cannot each
  /// consume the full transport allowance.
  int _attachmentsDecodedSizeWith({required ComposerAttachment attachment}) =>
      attachment.bytes.length + _stagedAttachmentBytes;

  int get _stagedAttachmentBytes => _attachments.fold(0, (total, staged) => total + staged.bytes.length);

  /// The leading slot: the options accordion at rest, the pencil to slide onto
  /// while recording, and a plain cancel button while transcribing. A pointer
  /// shell keeps its pencil and X through both.
  Widget _buildLeadingSlot(BuildContext context) {
    final loc = context.loc;
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    final pointer = ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer;
    // The accordion leaves the tree for these and comes back closed.
    if (_voicePresentation != _VoicePresentation.idle) _optionsOpen = false;

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
        child: _buildLabelledIconButton(
          label: loc.voiceCancelTranscription,
          icon: TablerRegular.x,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          onPressed: _cancelVoiceInteractionWithFeedback,
        ),
      ),
    };

    // The pointer accordion and the targets differ in width; glide the change
    // so the waveform beside them does not snap at the fade's end.
    return _morphSize(
      duration: _morphDuration,
      curve: _morphCurve,
      alignment: AlignmentDirectional.centerStart,
      // The accordion's focus ring and glass may paint past its box at rest.
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: _morphDuration,
        switchInCurve: _pointerRowListening ? _intoClearRowCurve : Curves.linear,
        switchOutCurve: _pointerRowAtRest ? _clearsRowCurve : Curves.linear,
        transitionBuilder: (transitionChild, animation) {
          final fade = _fadeEachEntry(transitionChild, animation);
          return transitionChild.key == const ValueKey("edit-target") ? _holdOnlyForScreenReaders(child: fade) : fade;
        },
        // Pinned to the leading edge: centred, the narrower child would jump
        // sideways when the wider one leaves at the fade's end.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previousChildren, ?currentChild],
        ),
        child: child,
      ),
    );
  }

  /// Wraps a resting pill's centre in the press-and-hold recording gesture.
  ///
  /// The listener wraps the voice-aware slot (not the other way around) so it
  /// stays mounted when the waveform swaps in and still receives the release
  /// that ends the hold. Semantic taps toggle recording and a semantic dismiss
  /// cancels it — assistive technologies cannot express the press-and-hold
  /// gesture or the slide out of it.
  Widget _buildHoldSurface(BuildContext context, {required String hint, required Widget child}) {
    return Semantics(
      // A node of its own, which nothing else in the composer merges into.
      container: true,
      button: true,
      enabled: _takesRecordingToggle,
      // The surface speaks for the pill, whose words it excludes.
      label: _voicePresentation == _VoicePresentation.transcribing ? _transcribingLabel(context) : hint,
      excludeSemantics: true,
      onTap: _takesRecordingToggle ? _toggleRecording : null,
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
      child: AnimatedSwitcher(
        duration: _morphDuration,
        switchInCurve: _pointerRowListening ? _intoClearRowCurve : _restingInCurve,
        switchOutCurve: _pointerRowAtRest ? _clearsRowCurve : _heldOutCurve,
        transitionBuilder: _fadeEachEntry,
        child: child,
      ),
    );
  }

  Widget _buildWaveform(BuildContext context) {
    final prego = context.prego;

    if (_pointerShell) {
      return PregoVoiceWaveform(
        amplitudeStream: _voiceCubit.amplitudeStream,
        barColor: prego.colors.textSecondary,
        dotColor: prego.colors.fgQuaternary,
        height: 20,
        barWidth: 2,
        slotPitch: 4,
        restingHeight: 2,
        fadesOlderBars: true,
      );
    }
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
      highlightColor: _pointerShell ? prego.colors.textPrimary : prego.colors.textPlaceholderSubtle,
      semanticLabel: label,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _pointerShell
            ? prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)
            : prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
      ),
    );
  }

  /// Hold-to-record microphone for text-first mode. Stays mounted (and in its
  /// enabled look) through every voice state: it owns the hold gesture while
  /// recording, and recording is guarded against re-entry while transcribing.
  Widget _buildMicButton(BuildContext context) {
    final loc = context.loc;

    // A pointer shell clicks to start; the wide Send takes it from there.
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: variant
    if (ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer) {
      return _buildLabelledIconButton(
        label: loc.voiceRecord,
        icon: TablerRegular.microphone,
        hierarchy: PregoButtonsSolidHierarchy.tertiary,
        onPressed: _handleMicClick,
      );
    }

    // No Tooltip here: its long-press trigger would race the recording hold.
    // The button keeps its enabled look and swallows plain taps via
    // [_ignoreTap]; the surrounding raw pointer listener drives recording.
    // Semantic taps toggle recording and a semantic dismiss cancels it, because
    // assistive technologies cannot express the hold or the slide out of it.
    return PregoButtonSemantics(
      label: loc.voiceRecord,
      enabled: _takesRecordingToggle,
      showsTooltip: false,
      child: Semantics(
        excludeSemantics: true,
        onTap: _takesRecordingToggle ? _toggleRecording : null,
        onDismiss: _isListening ? _cancelVoiceInteractionWithFeedback : null,
        child: Listener(
          onPointerDown: _handleRecordPointerDown,
          onPointerMove: _handleRecordPointerMove,
          onPointerUp: _handleRecordPointerEnd,
          onPointerCancel: _handleRecordPointerEnd,
          child: const PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.microphone,
            semanticLabel: null,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _ignoreTap,
          ),
        ),
      ),
    );
  }

  /// Keeps a button rendering in its enabled look when a plain tap deliberately
  /// does nothing: the mic records on press-and-hold, and send may be fading out.
  static void _ignoreTap() {}

  /// Which button rests in the primary action's spot.
  bool get _showsStop => widget.isBusy && !_hasSendableContent;

  /// Send as it last looked while it was the current button. It keeps that look
  /// under an arriving stop: emptying the box would otherwise grey it on the first
  /// frame, under a stop that has barely started to show.
  Widget? _sendAsLastShown;

  /// How much of the current button shows when it starts taking input, whichever
  /// way the swap went: 132 ms into a settled fade, the wait [_inertUntilShowing]
  /// gives. Nobody reacts to a button sooner, so a tap before this was aimed at what
  /// was there before, such as the second tap of a double tap on send landing on the
  /// stop that the send brought.
  static final double _primaryActionShownEnough = _morphCurve.transform(_trailingReturnCurve.begin);

  /// The dark action button: sends when there is content to send, otherwise
  /// stops the agent's in-flight work while it is busy.
  ///
  /// The two dissolve in one spot. Stop fades over a send that stays opaque until
  /// it is covered, so the spot never goes faint, and one value carries the fade so
  /// that a swap turned back midway retraces it with no restart and no third layer.
  Widget _buildPrimaryActionButton(BuildContext context) {
    final showStop = _showsStop;
    if (!showStop) _sendAsLastShown = _buildSendButton(context);
    final send = _sendAsLastShown;
    final stop = _buildStopButton(
      context,
      // A press can outlast the button: lifting after it left stops nothing.
      onPressed: () {
        if (_showsStop) widget.onAbort();
      },
    );
    final stopTarget = showStop ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: stopTarget, end: stopTarget),
      duration: _morphDuration,
      curve: _morphCurve,
      builder: (context, stopShown, _) => Stack(
        children: [
          if (send != null && (!showStop || stopShown < 1))
            _buildPrimaryActionLayer(name: "send", current: !showStop, shown: 1 - stopShown, child: send),
          if (showStop || stopShown > 0)
            _buildPrimaryActionLayer(
              name: "stop",
              current: showStop,
              shown: stopShown,
              child: Opacity(opacity: stopShown, alwaysIncludeSemantics: true, child: stop),
            ),
        ],
      ),
    );
  }

  /// One button of the primary action's spot. Only the current one is there for a
  /// screen reader, and it takes input once it shows; the other is inert from the
  /// frame of the swap.
  Widget _buildPrimaryActionLayer({
    required String name,
    required bool current,
    required double shown,
    required Widget child,
  }) {
    final inert = !current || shown < _primaryActionShownEnough;
    return ExcludeSemantics(
      key: ValueKey(name),
      excluding: !current,
      child: ExcludeFocus(
        excluding: inert,
        child: IgnorePointer(ignoring: inert, child: child),
      ),
    );
  }

  /// Send's enabled look fades over its opaque disabled look, so the spot never goes
  /// faint, and one value carries the fade, so a change turned back midway retraces
  /// it. It takes a tap from the first frame of enabling. Fading out it keeps the
  /// enabled look, so that a press carries on where it was, but sends nothing.
  Widget _buildSendButton(BuildContext context) {
    // An empty composer has nothing to send: show the action as genuinely
    // unavailable instead of accepting a tap that does nothing.
    final enabled = _hasSendableContent && !_isAwaitingDictatedWords;
    final enabledTarget = enabled ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: enabledTarget, end: enabledTarget),
      duration: _morphDuration,
      curve: _morphCurve,
      builder: (context, enabledShown, _) {
        final settled = enabledShown == enabledTarget;
        return Stack(
          children: [
            if (!settled)
              _buildPrimaryActionLayer(
                name: "disabled send",
                current: false,
                shown: 0,
                child: _buildSendLook(onPressed: null),
              ),
            Opacity(
              key: PromptInput.sendButtonKey,
              opacity: settled ? 1 : enabledShown,
              alwaysIncludeSemantics: true,
              child: IgnorePointer(
                // Only the fade out: a disabled send at rest still shows its tooltip.
                ignoring: !enabled && !settled,
                child: PregoButtonSemantics(
                  label: context.loc.sessionDetailSend,
                  enabled: enabled,
                  showsTooltip: true,
                  child: _buildSendLook(
                    onPressed: enabled
                        ? _handleSend
                        : settled
                        ? null
                        : _ignoreTap,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Send's look for [onPressed], with no screen reader node of its own.
  Widget _buildSendLook({required VoidCallback? onPressed}) {
    return PregoButtonsSolid.iconOnly(
      leadingIcon: TablerRegular.arrow_up,
      semanticLabel: null,
      hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
      size: _actionSize,
      pointerRadius: composerActionRadius,
      // A send held for an image still being prepared.
      isLoading: _sendHold is _SendHeld,
      onPressed: onPressed,
    );
  }

  Widget _buildStopButton(BuildContext context, {required VoidCallback onPressed}) {
    return _buildLabelledIconButton(
      label: context.loc.sessionDetailAbort,
      icon: TablerSolid.player_stop,
      // Quieter than Send under a pointer: work in progress is not a call to act.
      hierarchy: _pointerShell ? PregoButtonsSolidHierarchy.secondary : PregoButtonsSolidHierarchy.primaryAlt,
      onPressed: onPressed,
    );
  }

  /// A composer icon button with its name on one screen reader node and in a
  /// tooltip.
  Widget _buildLabelledIconButton({
    required String label,
    required IconData icon,
    required PregoButtonsSolidHierarchy hierarchy,
    required VoidCallback? onPressed,
  }) {
    return PregoButtonsSolid.iconOnly(
      leadingIcon: icon,
      semanticLabel: label,
      showsTooltip: true,
      pointerRadius: composerActionRadius,
      hierarchy: hierarchy,
      size: _actionSize,
      onPressed: onPressed,
    );
  }
}

/// One pick, paste or drop in flight.
final class _InsertTurn({required final Future<void> earlierSettled, required final int pasteGeneration}) {
  final _settled = Completer<void>();

  Future<void> get settled => _settled.future;

  /// Completes only once every earlier turn has settled too, so the latest
  /// turn's [settled] covers everything started before it.
  void settle() => _settled.complete(earlierSettled);
}

/// Holds one composer layout in the cross-fade stack. A layout fading out counts
/// as offstage for test finders and the inspector, so the keys every layout
/// builds (such as [PromptInput.sendButtonKey]) match only the current one.
/// It changes nothing at run time: no element is remounted and no state lost.
class const _ComposerLayoutSlot({required final bool outgoing, required super.child}) extends ProxyWidget {
  @override
  Element createElement() => _ComposerLayoutSlotElement(this);
}

class _ComposerLayoutSlotElement(_ComposerLayoutSlot super.widget) extends ProxyElement {
  @override
  void notifyClients(_ComposerLayoutSlot oldWidget) {}

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (widget case _ComposerLayoutSlot(outgoing: true)) return;
    super.debugVisitOnstageChildren(visitor);
  }
}
