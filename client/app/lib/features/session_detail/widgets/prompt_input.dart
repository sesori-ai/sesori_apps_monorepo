import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../capabilities/voice/voice_transcription_service.dart";
import "../../../core/constants.dart";
import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/command_picker_sheet.dart";
import "composer_options_accordion.dart";
import "prompt_editor_sheet.dart";
import "voice_cancel_button.dart";

enum _VoiceState { idle, recording, transcribing }

/// The composer's three visual states: the hold-to-talk pill (voice-first
/// resting state), the compact tap-to-type pill (text-first resting state),
/// and the expanded typing container.
enum _ComposerLayout { holdToTalk, compact, typing }

class PromptInput extends StatefulWidget {
  final bool isBusy;

  /// Whether the session already has (or has queued) messages. Drives the
  /// resting hint copy ("Ask anything..." vs "Follow up...") and, in
  /// text-first mode, which prompt the compact pill invites.
  final bool hasMessages;
  final void Function(String text, String? command) onSend;
  final VoidCallback onAbort;
  final Widget? composerHeader;
  final List<CommandInfo> availableCommands;
  final CommandInfo? stagedCommand;
  final ValueChanged<CommandInfo> onCommandSelected;
  final VoidCallback onCommandCleared;

  /// Optional widget rendered inside the composer, above the text-field row.
  final Widget? header;

  /// Key under which the in-progress draft is persisted across navigation /
  /// backgrounding (the session id). Null disables draft persistence, e.g. on
  /// the new-session screen where there is no session id yet.
  final String? draftKey;

  const PromptInput({
    super.key,
    required this.isBusy,
    required this.hasMessages,
    required this.onSend,
    required this.onAbort,
    required this.composerHeader,
    required this.availableCommands,
    required this.stagedCommand,
    required this.onCommandSelected,
    required this.onCommandCleared,
    this.header,
    this.draftKey,
  });

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  _VoiceState _voiceState = _VoiceState.idle;
  StreamSubscription<void>? _maxDurationSub;

  /// Keeps the typing layout mounted after the keyboard affordance was tapped
  /// while the field wasn't in the tree yet (hold-to-talk / compact layouts),
  /// until the post-frame focus request lands. Cleared when focus leaves.
  bool _typingRequested = false;

  /// Whether the field holds sendable text. Mirrored into state so the
  /// composer only rebuilds when emptiness flips (layout + send/stop swap),
  /// not on every keystroke.
  bool _hasText = false;

  /// Layout pinned for the duration of a voice interaction. Swapping the
  /// composer's slots for the recording/transcribing chrome must not relayout
  /// the composer mid-hold — the gesture-owning elements would be reparented
  /// and never receive the release.
  _ComposerLayout? _pinnedVoiceLayout;

  /// Set when the hold is released while [_startRecording] is still awaiting
  /// the recorder, so the start path stops immediately once recording begins
  /// instead of letting it outlive the gesture.
  bool _releaseRequestedDuringStart = false;

  /// True while [_startRecording] is awaiting the recorder ([_voiceState] is
  /// still idle then). Guards against a second start — a concurrent hold on
  /// the other surface or a repeated assistive-tech activation — and routes
  /// those to the release path instead.
  bool _isRecordStartInFlight = false;

  /// True while [_cancelVoiceInteraction] is awaiting the platform cancel.
  /// The composer already reads idle then, but the service is still busy and
  /// would silently ignore a new start — so starts hold off until the cancel
  /// settles rather than presenting a recording that never began.
  bool _isCancelInFlight = false;

  /// Monotonic id of the current voice interaction, bumped on every start and
  /// cancel. A cancelled transcription's upload can settle long after the
  /// cancel; its continuations check this so they never insert a stale
  /// transcript into — or reset the state of — a newer interaction.
  int _voiceInteractionId = 0;

  /// How far the recording hold has dragged toward the cancel target:
  /// 0 at rest, 1 with the finger on the target — releasing there discards
  /// the recording. A notifier rather than state: the drag scrubs at
  /// pointer-move rate and feeds the cancel button, the waveform, and the
  /// destructive gradient directly, without rebuilding the composer.
  final ValueNotifier<double> _cancelDragProgress = ValueNotifier<double>(0);

  /// Locates the cancel target so the drag can measure its distance to it.
  final GlobalKey _cancelTargetKey = GlobalKey();

  VoiceTranscriptionService get _voiceService => getIt<VoiceTranscriptionService>();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    _maxDurationSub = _voiceService.onMaxDurationReached.listen((_) {
      if (_voiceState == _VoiceState.recording && mounted) {
        _showRecordingLimitReached();
        _stopAndTranscribe();
      }
    });
  }

  @override
  void dispose() {
    // Persist the in-progress draft so it survives leaving and returning to
    // the session. Sent messages clear the draft in [_handleSend], so this
    // only saves genuinely unsent text. Must run before disposing the
    // controller.
    _saveDraft();
    _maxDurationSub?.cancel();
    // Fire-and-forget cancel if the widget is disposed mid-recording or mid-transcription.
    if (_voiceState != _VoiceState.idle) {
      _voiceService.cancelRecording();
    }
    _cancelDragProgress.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The draft store, or null when it isn't registered. Guarded because
  /// [dispose] can run during teardown after the service locator has already
  /// been reset (e.g. in widget tests).
  DraftStore? get _draftStore => getIt.isRegistered<DraftStore>() ? getIt<DraftStore>() : null;

  void _restoreDraft() => _restoreDraftFor(widget.draftKey);

  /// Loads the draft for [key] into the controller. Clears the controller when
  /// there is no draft (or no [key]/store) so text never leaks across a
  /// session switch when the state is reused (see [didUpdateWidget]).
  void _restoreDraftFor(String? key) {
    final store = _draftStore;
    if (key == null || store == null) {
      _controller.clear();
      return;
    }
    final draft = store.read(key);
    _controller.text = draft;
    _controller.selection = TextSelection.collapsed(offset: draft.length);
  }

  void _saveDraft() => _saveDraftFor(widget.draftKey);

  void _saveDraftFor(String? key) {
    final store = _draftStore;
    if (key == null || store == null) return;
    store.write(key, text: _controller.text);
  }

  void _clearDraft() {
    final key = widget.draftKey;
    final store = _draftStore;
    if (key == null || store == null) return;
    store.clear(key);
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    // Rebuild on both edges: gaining focus keeps the typing layout up via the
    // focus check; losing it (with nothing to show) collapses back to the
    // resting pill.
    setState(() {
      if (!_focusNode.hasFocus) _typingRequested = false;
    });
  }

  /// Whether the session composer leads with hold-to-talk voice input (the
  /// default) or with the tap-to-type field. Chosen in settings; the cubit
  /// lives above the router, so flipping it re-shapes this composer live.
  bool get _isVoiceFirst => context.read<ChatInputModeCubit>().state == ChatInputMode.voiceFirst;

  /// Whether the expanded typing container is showing (vs. the resting
  /// hold-to-talk / compact pills).
  bool get _showsTypingLayout => _typingRequested || _focusNode.hasFocus || _hasText || widget.stagedCommand != null;

  /// The layout the composer would rest in right now, ignoring any pinned
  /// voice interaction.
  _ComposerLayout get _restingLayout {
    if (_showsTypingLayout) return _ComposerLayout.typing;
    return _isVoiceFirst ? _ComposerLayout.holdToTalk : _ComposerLayout.compact;
  }

  _ComposerLayout get _layout => _pinnedVoiceLayout ?? _restingLayout;

  bool get _hasSendableContent => _hasText || widget.stagedCommand != null;

  /// Switches to the typing layout and raises the keyboard. Focus is
  /// requested post-frame because the field only mounts with the typing
  /// layout. Blocked while recording and while a record start is in flight —
  /// unpinning in that window would reparent the hold-owning subtree and the
  /// release would never be delivered. A running transcription keeps going
  /// and lands its transcript in the now-focused field.
  void _enterTypingMode() {
    if (_voiceState == _VoiceState.recording || _isRecordStartInFlight) return;
    setState(() {
      _typingRequested = true;
      // Safe to unpin while transcribing: no gesture is in flight once the
      // hold has been released.
      _pinnedVoiceLayout = null;
    });
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
    if (stagedCommand != null) {
      widget.onSend(_controller.text, stagedCommand.name);
      widget.onCommandCleared();
    } else {
      final text = _controller.text.trim();
      if (text.isEmpty) return;
      widget.onSend(text, null);
    }

    _controller.clear();
    _clearDraft();
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
    if (oldWidget.draftKey != widget.draftKey) {
      // The state was reused for a different session (e.g. split-view swap
      // or a parent rebuild with a new session) without initState/dispose.
      // Persist the previous session's draft and load the new one so text
      // never leaks between sessions.
      _saveDraftFor(oldWidget.draftKey);
      _restoreDraftFor(widget.draftKey);
    }
    if (oldWidget.stagedCommand?.name != widget.stagedCommand?.name && widget.stagedCommand != null) {
      _focusComposerField();
    }
  }

  Future<void> _handleRecordStart() async {
    if (_voiceState != _VoiceState.idle || _isRecordStartInFlight || _isCancelInFlight) return;
    _voiceInteractionId++;
    _isRecordStartInFlight = true;
    _releaseRequestedDuringStart = false;
    _cancelDragProgress.value = 0;
    _pinnedVoiceLayout = _restingLayout;
    await _startRecording();
    _isRecordStartInFlight = false;
    if (!mounted) {
      // Disposed while the recorder was starting: [dispose] saw an idle state
      // and could not cancel, so release the orphaned recording here.
      unawaited(_voiceService.cancelRecording());
      return;
    }
    if (_voiceState == _VoiceState.idle) {
      // Recording never started (permission denied / recorder error), so no
      // later transition will release the pin.
      setState(() => _pinnedVoiceLayout = null);
    } else if (_releaseRequestedDuringStart) {
      // The hold ended while the recorder was still starting up — stop right
      // away so recording never outlives the gesture.
      await _stopAndTranscribe();
    }
  }

  /// Tracks the hold as it moves, scrubbing the drag-to-cancel presentation
  /// toward the cancel target.
  void _handleRecordDragUpdate({required Offset globalPosition}) {
    if (_voiceState != _VoiceState.recording) return;
    _cancelDragProgress.value = _cancelProgressFor(globalPosition: globalPosition);
  }

  /// The finger starts engaging the cancel affordance within this distance of
  /// the target's centre, and is committed to cancelling within
  /// [_cancelCommitRadius] — roughly the 44pt button plus touch slop.
  static const double _cancelReachRadius = 170;
  static const double _cancelCommitRadius = 44;

  double _cancelProgressFor({required Offset globalPosition}) {
    final target = _cancelTargetKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize || !target.attached) return 0;
    final center = target.localToGlobal(target.size.center(Offset.zero));
    final distance = (globalPosition - center).distance;
    final fraction = (distance - _cancelCommitRadius) / (_cancelReachRadius - _cancelCommitRadius);
    return (1 - fraction).clamp(0.0, 1.0);
  }

  Future<void> _handleRecordEnd() async {
    if (_voiceState == _VoiceState.idle) {
      // The release raced a recorder that is still starting up (or was a
      // stray pointer event); [_handleRecordStart] consumes this after the
      // start completes.
      _releaseRequestedDuringStart = true;
      return;
    }
    if (_voiceState != _VoiceState.recording) return;
    if (_cancelDragProgress.value >= 1) {
      // Released on the cancel target — discard instead of transcribing.
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
    if (_voiceState == _VoiceState.recording || _isRecordStartInFlight) {
      await _handleRecordEnd();
    } else {
      await _handleRecordStart();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _voiceService.startRecording();
      if (!mounted) return;
      setState(() => _voiceState = _VoiceState.recording);
    } on MicrophonePermissionDeniedError {
      if (!mounted) return;
      _showVoiceError(context.loc.voiceErrorPermission);
    } catch (error) {
      // Typed voice errors and anything else the recorder throws (platform /
      // filesystem failures) both land here: an error escaping this method
      // would leave the in-flight guard and pinned layout stuck, silently
      // killing voice input for the rest of the session.
      loge("Failed to start recording", error);
      if (!mounted) return;
      _showVoiceError(context.loc.voiceErrorRecording);
    }
  }

  Future<void> _stopAndTranscribe() async {
    // The upload can outlive this interaction (a cancel settles the state
    // long before a slow upload errors out); every continuation below is a
    // no-op once a newer interaction owns the composer.
    final interactionId = _voiceInteractionId;
    setState(() {
      _voiceState = _VoiceState.transcribing;
      _cancelDragProgress.value = 0;
    });

    bool stale() => !mounted || interactionId != _voiceInteractionId;

    try {
      final transcript = await _voiceService.stopAndTranscribe();
      if (stale()) return;

      // Append transcript to the text field, preserving any existing text.
      final currentText = _controller.text;
      if (currentText.isNotEmpty && !currentText.endsWith(" ")) {
        _controller.text = "$currentText $transcript";
      } else {
        _controller.text = "$currentText$transcript";
      }
      // Move cursor to end.
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
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
      _showVoiceError(context.loc.voiceErrorNotAuthenticated);
    } on NetworkVoiceError {
      if (!mounted || stale()) return;
      _showVoiceError(context.loc.voiceErrorNetwork);
    } on VoiceTranscriptionError catch (error) {
      loge("Transcription failed", error);
      if (!mounted || stale()) return;
      _showVoiceError(context.loc.voiceErrorTranscription);
    } finally {
      if (!stale()) {
        setState(() {
          _voiceState = _VoiceState.idle;
          _pinnedVoiceLayout = null;
          _cancelDragProgress.value = 0;
        });
      }
    }
  }

  /// Discards the running voice interaction: a drag released on the cancel
  /// target, a tap on it mid-recording, or a tap on the X while transcribing.
  Future<void> _cancelVoiceInteraction() async {
    // Reset synchronously: a release landing while the platform cancel is
    // still in flight must read the interaction as over, not stop-and-
    // transcribe the recording being discarded. The id bump orphans any
    // still-pending transcription continuation of this interaction.
    _voiceInteractionId++;
    setState(() {
      _voiceState = _VoiceState.idle;
      _pinnedVoiceLayout = null;
      _cancelDragProgress.value = 0;
    });
    _isCancelInFlight = true;
    try {
      await _voiceService.cancelRecording();
    } catch (error) {
      loge("Failed to cancel the voice interaction", error);
    } finally {
      _isCancelInFlight = false;
    }
  }

  void _showVoiceError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: kSnackBarDuration,
        ),
      );
  }

  void _showRecordingLimitReached() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.loc.voiceRecordingLimitReached),
          duration: kSnackBarDuration,
        ),
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
    // The resting layout follows the settings choice live.
    context.watch<ChatInputModeCubit>();
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
          begin: Alignment.center,
          end: Alignment.topCenter,
          colors: [
            prego.colors.bgSurface1.withValues(alpha: 0.9),
            prego.colors.bgSurface1.withValues(alpha: 0.7),
            prego.colors.bgSurface1.withValues(alpha: 0),
          ],
          stops: const [0, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          ?widget.header,
          _buildComposerTopSlot(context),

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
                      _ComposerLayout.typing => _buildTypingComposer(context),
                      _ComposerLayout.compact => _buildCompactComposer(context),
                      _ComposerLayout.holdToTalk => _buildHoldToTalkComposer(context),
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
    if (_voiceState == _VoiceState.recording) {
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
        child: headerChild ?? const SizedBox(width: double.infinity),
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
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.md, bottom: PregoSpacing.xl),
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

  BoxDecoration _containerDecoration(
    PregoDesignSystem prego, {
    required Color borderColor,
    required BorderRadius borderRadius,
  }) {
    return BoxDecoration(
      color: prego.colors.bgSurface2,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(color: prego.colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2),
      ],
    );
  }

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
    required Color borderColor,
    required Widget child,
    bool tightensTrailingWhileRecording = false,
  }) {
    final prego = context.prego;
    const radius = BorderRadius.all(Radius.circular(PregoRadius.full));
    final tightenEnd = tightensTrailingWhileRecording && _voiceState == _VoiceState.recording;

    return DecoratedBox(
      decoration: _containerDecoration(prego, borderColor: borderColor, borderRadius: radius),
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

  /// Voice-first resting state: one pill whose whole centre is a
  /// press-and-hold voice target, with a keyboard button to switch to typing
  /// (and the stop control alongside while the agent is busy).
  Widget _buildHoldToTalkComposer(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return _buildVoicePillSurface(
      context,
      borderColor: prego.colors.borderSecondary,
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
                    loc.sessionDetailHoldToTalk,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          _buildCollapsibleTrailing(
            visible: _voiceState != _VoiceState.recording,
            child: Row(
              spacing: PregoSpacing.sm,
              children: [
                Tooltip(
                  message: loc.sessionDetailTypeMessage,
                  child: PregoButtonsSolid.iconOnly(
                    leadingIcon: TablerRegular.keyboard,
                    hierarchy: PregoButtonsSolidHierarchy.secondary,
                    size: PregoButtonsSolidSize.lg,
                    onPressed: _enterTypingMode,
                  ),
                ),
                // The resting voice pill has no send affordance, but stopping
                // the agent's in-flight work must stay reachable.
                if (widget.isBusy) _buildPrimaryActionButton(context),
              ],
            ),
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
      borderColor: prego.colors.borderPrimary,
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
          Row(
            spacing: PregoSpacing.sm,
            children: [
              // The mic owns the hold gesture, so it must stay mounted (and
              // under the finger) for the whole recording; only the primary
              // action collapses away.
              _buildMicButton(context),
              _buildCollapsibleTrailing(
                visible: _voiceState != _VoiceState.recording,
                child: _buildPrimaryActionButton(context),
              ),
            ],
          ),
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
      decoration: _containerDecoration(
        prego,
        borderColor: prego.colors.borderPrimary,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PregoSpacing.md,
        children: [
          Stack(
            children: [
              Padding(
                // Clear the expand button on the trailing edge so text never
                // runs underneath it.
                padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.xs, 0, 36, 0),
                child: CallbackShortcuts(
                  // Cmd/Ctrl+Enter sends (handy with a hardware keyboard);
                  // plain Enter stays a newline via textInputAction below.
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.enter, meta: true): _handleSend,
                    const SingleActivator(LogicalKeyboardKey.enter, control: true): _handleSend,
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
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
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Tooltip(
                  message: loc.sessionDetailExpandEditor,
                  child: PregoTappable(
                    onTap: _voiceState == _VoiceState.idle ? _openEditorSheet : null,
                    borderRadius: BorderRadius.circular(PregoRadius.full),
                    containerBuilder: (Widget child) => SizedBox.square(dimension: 32, child: child),
                    child: Icon(TablerRegular.maximize, size: 18, color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          if (voiceFirst) _buildTypingVoicePill(context) else _buildTypingActionRow(context),
        ],
      ),
    );
  }

  /// The voice-first typing container's bottom strip: a hold-to-talk pill of
  /// its own, with the send action on its trailing edge — the design's
  /// `Typing input container`.
  Widget _buildTypingVoicePill(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return _buildVoicePillSurface(
      context,
      borderColor: prego.colors.borderSecondary,
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
                    _hasText ? loc.sessionDetailHoldToTalkMore : loc.sessionDetailHoldToTalk,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          _buildCollapsibleTrailing(
            visible: _voiceState != _VoiceState.recording,
            child: _buildPrimaryActionButton(context),
          ),
        ],
      ),
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
        Row(
          spacing: PregoSpacing.sm,
          children: [
            // Gesture owner during a recording hold — never collapsed.
            _buildMicButton(context),
            _buildCollapsibleTrailing(
              visible: _voiceState != _VoiceState.recording,
              child: _buildPrimaryActionButton(context),
            ),
          ],
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
      actionsEnabled: _voiceState == _VoiceState.idle,
      onSlashCommandsTap: _openCommandPicker,
    );
  }

  /// The 44pt leading slot: the options accordion at rest, the drag-to-cancel
  /// target while recording, and a plain cancel button while transcribing.
  Widget _buildLeadingSlot(BuildContext context) {
    final loc = context.loc;

    final Widget child = switch (_voiceState) {
      _VoiceState.idle => KeyedSubtree(key: const ValueKey("accordion"), child: _buildOptionsAccordion()),
      _VoiceState.recording => KeyedSubtree(
        key: const ValueKey("cancel-target"),
        child: VoiceCancelButton(
          key: _cancelTargetKey,
          progress: _cancelDragProgress,
          onCancel: _cancelVoiceInteraction,
        ),
      ),
      _VoiceState.transcribing => KeyedSubtree(
        key: const ValueKey("cancel-transcription"),
        child: Tooltip(
          message: loc.voiceCancelTranscription,
          child: PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.x,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _cancelVoiceInteraction,
          ),
        ),
      ),
    };

    return AnimatedSwitcher(duration: _morphDuration, child: child);
  }

  /// Wraps a resting pill's centre in the press-and-hold recording gesture.
  ///
  /// The detector wraps the voice-aware slot (not the other way around) so it
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
        // A pointer cancel mid-hold (incoming call, system gesture) resets
        // the accepted long-press silently — no onLongPressEnd — so the raw
        // pointer stream is the only place to keep the recording bounded by
        // the gesture.
        onPointerCancel: (_) => _handleRecordEnd(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => _handleRecordStart(),
          onLongPressMoveUpdate: (details) => _handleRecordDragUpdate(globalPosition: details.globalPosition),
          onLongPressEnd: (_) => _handleRecordEnd(),
          child: child,
        ),
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
    final Widget child = switch (_voiceState) {
      _VoiceState.idle => KeyedSubtree(key: const ValueKey("voice-slot-idle"), child: idle),
      _VoiceState.recording => KeyedSubtree(
        key: const ValueKey("voice-slot-recording"),
        child: Center(child: _buildWaveform(context)),
      ),
      _VoiceState.transcribing => KeyedSubtree(
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
    // [_ignoreTap]; holds outlast the tap recognizer, so the surrounding
    // detector wins the arena and drives the recording. Semantic taps toggle
    // recording — assistive technologies cannot express the hold.
    return Semantics(
      button: true,
      label: loc.voiceRecord,
      excludeSemantics: true,
      onTap: _handleSemanticRecordToggle,
      child: Listener(
        // A pointer cancel mid-hold resets the accepted long-press silently —
        // no onLongPressEnd — so the raw pointer stream is the only place to
        // keep the recording bounded by the gesture.
        onPointerCancel: (_) => _handleRecordEnd(),
        child: GestureDetector(
          onLongPressStart: (_) => _handleRecordStart(),
          onLongPressMoveUpdate: (details) => _handleRecordDragUpdate(globalPosition: details.globalPosition),
          onLongPressEnd: (_) => _handleRecordEnd(),
          child: const PregoButtonsSolid.iconOnly(
            leadingIcon: TablerRegular.microphone,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            onPressed: _ignoreTap,
          ),
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
        onPressed: _handleSend,
      ),
    );
  }
}
