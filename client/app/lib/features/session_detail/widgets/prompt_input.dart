import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
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

enum _VoiceState { idle, recording, transcribing }

/// The composer's three visual states: the fresh-session hold-to-talk pill,
/// the compact follow-up pill, and the expanded typing container.
enum _ComposerLayout { holdToTalk, compact, typing }

typedef PromptSubmitCallback =
    void Function({required String text, required String? command, required AnalyticsInputMode inputMode});

class PromptInput extends StatefulWidget {
  final bool isBusy;

  /// Whether the session already has (or has queued) messages. A fresh
  /// session opens with the hold-to-talk pill; once messages exist the
  /// composer rests as a compact "Follow up" field instead.
  final bool hasMessages;
  final PromptSubmitCallback onSend;
  final VoidCallback onVoiceTranscriptionCompleted;
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
    required this.onVoiceTranscriptionCompleted,
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
  AnalyticsInputMode _inputMode = AnalyticsInputMode.typed;
  TextEditingValue _previousEditingValue = TextEditingValue.empty;

  /// Layout pinned for the duration of a voice interaction. Swapping the
  /// field slot for the recording/transcribing indicators must not relayout
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

  VoiceTranscriptionService get _voiceService => getIt<VoiceTranscriptionService>();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _hasText = _controller.text.trim().isNotEmpty;
    _previousEditingValue = _controller.value;
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
      _inputMode = AnalyticsInputMode.typed;
      return;
    }
    final draft = store.read(key: key);
    _controller.text = draft?.text ?? "";
    _inputMode = draft?.inputMode ?? AnalyticsInputMode.typed;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  void _saveDraft() => _saveDraftFor(widget.draftKey);

  void _saveDraftFor(String? key) {
    final store = _draftStore;
    if (key == null || store == null) return;
    store.write(
      key: key,
      draft: ComposerDraft(text: _controller.text, inputMode: _inputMode),
    );
  }

  void _clearDraft() {
    final key = widget.draftKey;
    final store = _draftStore;
    if (key == null || store == null) return;
    store.clear(key: key);
  }

  void _handleTextChanged() {
    final currentValue = _controller.value;
    final previousValue = _previousEditingValue;
    final hasText = currentValue.text.trim().isNotEmpty;
    final replacedEntireText = previousValue.text.isNotEmpty &&
        previousValue.selection.start == 0 &&
        previousValue.selection.end == previousValue.text.length &&
        !currentValue.text.startsWith(previousValue.text);
    if (!hasText || replacedEntireText) _inputMode = AnalyticsInputMode.typed;
    _previousEditingValue = currentValue;
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

  /// Whether the expanded typing container is showing (vs. the resting
  /// hold-to-talk / compact pills).
  bool get _showsTypingLayout => _typingRequested || _focusNode.hasFocus || _hasText || widget.stagedCommand != null;

  /// The layout the composer would rest in right now, ignoring any pinned
  /// voice interaction.
  _ComposerLayout get _restingLayout {
    if (_showsTypingLayout) return _ComposerLayout.typing;
    // A busy session is past its fresh state even while the first message
    // hasn't landed in the list yet (e.g. it was sent from another device) —
    // resting compact keeps the stop control reachable.
    if (widget.hasMessages || widget.isBusy) return _ComposerLayout.compact;
    return _ComposerLayout.holdToTalk;
  }

  _ComposerLayout get _layout => _pinnedVoiceLayout ?? _restingLayout;

  bool get _hasSendableContent => _hasText || widget.stagedCommand != null;

  /// Switches to the typing layout and raises the keyboard. Focus is
  /// requested post-frame because the field only mounts with the typing
  /// layout.
  void _enterTypingMode() {
    if (_voiceState != _VoiceState.idle) return;
    setState(() => _typingRequested = true);
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
    final stagedCommand = widget.stagedCommand;
    if (stagedCommand != null) {
      widget.onSend(
        text: _controller.text,
        command: stagedCommand.name,
        inputMode: AnalyticsInputMode.typed,
      );
      widget.onCommandCleared();
    } else {
      final text = _controller.text.trim();
      if (text.isEmpty) return;
      widget.onSend(text: text, command: null, inputMode: _inputMode);
    }

    _controller.clear();
    _clearDraft();
    _focusNode.requestFocus();
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
    if (_voiceState != _VoiceState.idle || _isRecordStartInFlight) return;
    _isRecordStartInFlight = true;
    _releaseRequestedDuringStart = false;
    _pinnedVoiceLayout = _restingLayout;
    await _startRecording();
    _isRecordStartInFlight = false;
    if (!mounted) return;
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

  Future<void> _handleRecordEnd() async {
    if (_voiceState == _VoiceState.idle) {
      // The release raced a recorder that is still starting up (or was a
      // stray pointer event); [_handleRecordStart] consumes this after the
      // start completes.
      _releaseRequestedDuringStart = true;
      return;
    }
    if (_voiceState != _VoiceState.recording) return;
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
    setState(() => _voiceState = _VoiceState.transcribing);

    try {
      final transcript = await _voiceService.stopAndTranscribe();
      if (!mounted) return;
      if (transcript.trim().isEmpty) return;

      // Append transcript to the text field, preserving any existing text.
      _inputMode = AnalyticsInputMode.voiceAssisted;
      final currentText = _controller.text;
      if (currentText.isNotEmpty && !currentText.endsWith(" ")) {
        _controller.text = "$currentText $transcript";
      } else {
        _controller.text = "$currentText$transcript";
      }
      // Move cursor to end.
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      widget.onVoiceTranscriptionCompleted();
      // The transcript lands in the typing layout, whose field may only mount
      // with this rebuild — focus once it exists.
      _focusComposerField();
    } on TranscriptionCancelledError {
      // User cancelled — nothing to do, finally resets state.
    } on NotAuthenticatedVoiceError {
      if (!mounted) return;
      _showVoiceError(context.loc.voiceErrorNotAuthenticated);
    } on NetworkVoiceError {
      if (!mounted) return;
      _showVoiceError(context.loc.voiceErrorNetwork);
    } on VoiceTranscriptionError catch (error) {
      loge("Transcription failed", error);
      if (!mounted) return;
      _showVoiceError(context.loc.voiceErrorTranscription);
    } finally {
      if (mounted) {
        setState(() {
          _voiceState = _VoiceState.idle;
          _pinnedVoiceLayout = null;
        });
      }
    }
  }

  Future<void> _cancelTranscription() async {
    try {
      await _voiceService.cancelRecording();
    } catch (error) {
      loge("Failed to cancel transcription", error);
    }
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.idle;
      _pinnedVoiceLayout = null;
    });
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
          ?switch (widget.stagedCommand) {
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
          },

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
              child: switch (_layout) {
                _ComposerLayout.typing => _buildTypingComposer(context),
                _ComposerLayout.compact => _buildCompactComposer(context),
                _ComposerLayout.holdToTalk => _buildHoldToTalkComposer(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Composer layouts
  // ---------------------------------------------------------------------------

  BoxDecoration _containerDecoration(
    PregoDesignSystem prego, {
    required Color borderColor,
    required double radius,
  }) {
    return BoxDecoration(
      color: prego.colors.bgSurface2,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(color: prego.colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2),
      ],
    );
  }

  /// Fresh-session resting state: one pill whose whole centre is a
  /// press-and-hold voice target, with a keyboard button to switch to typing.
  Widget _buildHoldToTalkComposer(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Container(
      padding: const EdgeInsets.all(PregoSpacing.sm),
      decoration: _containerDecoration(
        prego,
        borderColor: prego.colors.borderSecondary,
        radius: PregoRadius.full,
      ),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildOptionsAccordion(),
          Expanded(
            // The detector wraps the voice-aware slot (not the other way
            // around) so it stays mounted when the recording indicator swaps
            // in and still receives the release that ends the hold. Semantic
            // taps toggle recording — assistive technologies cannot express
            // the press-and-hold gesture.
            child: Semantics(
              button: true,
              label: loc.sessionDetailHoldToTalk,
              excludeSemantics: true,
              onTap: _handleSemanticRecordToggle,
              child: Listener(
                // A pointer cancel mid-hold (incoming call, system gesture)
                // resets the accepted long-press silently — no onLongPressEnd
                // — so the raw pointer stream is the only place to keep the
                // recording bounded by the gesture.
                onPointerCancel: (_) => _handleRecordEnd(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (_) => _handleRecordStart(),
                  onLongPressEnd: (_) => _handleRecordEnd(),
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
            ),
          ),
          Tooltip(
            message: loc.sessionDetailTypeMessage,
            child: PregoButtonsSolid.iconOnly(
              leadingIcon: TablerRegular.keyboard,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              onPressed: _enterTypingMode,
            ),
          ),
        ],
      ),
    );
  }

  /// Resting state once the session has messages: a compact pill whose field
  /// area invites a follow-up, with mic and send/stop alongside.
  Widget _buildCompactComposer(BuildContext context) {
    final prego = context.prego;

    return Container(
      padding: const EdgeInsets.all(PregoSpacing.sm),
      decoration: _containerDecoration(
        prego,
        borderColor: prego.colors.borderPrimary,
        radius: PregoRadius.full,
      ),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          _buildOptionsAccordion(),
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
              _buildMicButton(context),
              _buildPrimaryActionButton(context),
            ],
          ),
        ],
      ),
    );
  }

  /// The expanded typing container: multiline field with the fullscreen-editor
  /// button in its top-right corner, and the action row below.
  Widget _buildTypingComposer(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Container(
      padding: const EdgeInsets.all(PregoSpacing.sm),
      decoration: _containerDecoration(
        prego,
        borderColor: prego.colors.borderPrimary,
        radius: PregoRadius.x3l,
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
                child: _buildVoiceAwareSlot(
                  height: null,
                  idle: CallbackShortcuts(
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
          Row(
            children: [
              _buildOptionsAccordion(),
              const Spacer(),
              _buildMicButton(context),
              const SizedBox(width: PregoSpacing.sm),
              _buildPrimaryActionButton(context),
            ],
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

  Widget _buildOptionsAccordion() {
    return ComposerOptionsAccordion(
      actionsEnabled: _voiceState == _VoiceState.idle,
      onSlashCommandsTap: _openCommandPicker,
    );
  }

  /// Shows [idle] normally, or the recording / transcribing feedback in its
  /// place while a voice interaction is running. [height] constrains the
  /// indicators inside the 44pt-tall resting pills; the typing layout passes
  /// null and keeps their intrinsic height.
  Widget _buildVoiceAwareSlot({required double? height, required Widget idle}) {
    final indicator = switch (_voiceState) {
      _VoiceState.recording => _RecordingIndicator(amplitudeStream: _voiceService.amplitudeStream),
      _VoiceState.transcribing => const _TranscribingIndicator(),
      _VoiceState.idle => null,
    };
    if (indicator == null) {
      return height == null ? idle : SizedBox(height: height, child: idle);
    }
    return height == null ? indicator : SizedBox(height: height, child: indicator);
  }

  /// Hold-to-record microphone. While transcribing it becomes the cancel
  /// affordance, mirroring the old tap-to-cancel behaviour.
  Widget _buildMicButton(BuildContext context) {
    final loc = context.loc;

    if (_voiceState == _VoiceState.transcribing) {
      return Tooltip(
        message: loc.voiceCancelTranscription,
        child: PregoButtonsSolid.iconOnly(
          leadingIcon: TablerRegular.x,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.lg,
          onPressed: _cancelTranscription,
        ),
      );
    }

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

// -----------------------------------------------------------------------------
// Recording indicator with live amplitude waveform
// -----------------------------------------------------------------------------

/// Number of bars in the waveform visualizer.
const _barCount = 28;

/// Minimum bar height (silence).
const _barMinHeight = 3.0;

/// Maximum bar height (full amplitude).
const _barMaxHeight = 28.0;

class _RecordingIndicator extends StatefulWidget {
  final Stream<double> amplitudeStream;

  const _RecordingIndicator({required this.amplitudeStream});

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator> {
  double _amplitude = 0.0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _amplitude = amp);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final barColor = prego.colors.fgErrorPrimary;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: prego.colors.bgErrorPrimary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.mic, color: barColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _AmplitudeBars(amplitude: _amplitude, color: barColor),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Transcribing indicator (replaces text field while waiting for server response)
// -----------------------------------------------------------------------------

class _TranscribingIndicator extends StatelessWidget {
  const _TranscribingIndicator();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: prego.colors.bgBrandPrimary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: PregoActivityIndicator(
              color: prego.colors.bgBrandSolid,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            loc.voiceTranscribing,
            style: prego.textTheme.textSm.regular.copyWith(
              color: prego.colors.bgBrandSolid,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Amplitude bars — individual animated bars forming the waveform
// -----------------------------------------------------------------------------

class _AmplitudeBars extends StatelessWidget {
  final double amplitude;
  final Color color;

  const _AmplitudeBars({required this.amplitude, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      crossAxisAlignment: .center,
      children: List.generate(_barCount, (i) {
        // Bell curve: center bars are tallest, edges are shortest.
        const center = (_barCount - 1) / 2;
        final distanceFromCenter = (i - center).abs() / center;
        final bellMultiplier = 1.0 - (distanceFromCenter * distanceFromCenter * 0.7);

        // Per-bar variation using a deterministic pattern so bars don't all
        // look identical, giving the waveform an organic feel.
        final variation = 0.7 + 0.3 * math.sin(i * 1.3 + i * i * 0.1);

        final targetHeight = _barMinHeight + (amplitude * bellMultiplier * variation * (_barMaxHeight - _barMinHeight));
        final clampedHeight = targetHeight.clamp(_barMinHeight, _barMaxHeight);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          width: 3,
          height: clampedHeight,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6 + 0.4 * bellMultiplier),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
