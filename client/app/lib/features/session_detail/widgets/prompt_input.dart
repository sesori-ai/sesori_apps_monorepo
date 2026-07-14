import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../capabilities/voice/voice_transcription_service.dart";
import "../../../core/constants.dart";
import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/command_picker_sheet.dart";

enum _VoiceState { idle, recording, transcribing }

class PromptInput extends StatefulWidget {
  final bool isBusy;
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

  VoiceTranscriptionService get _voiceService => getIt<VoiceTranscriptionService>();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
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

  void _handleSend() {
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
      _focusNode.requestFocus();
    }
  }

  Future<void> _handleMicTap() async {
    switch (_voiceState) {
      case _VoiceState.idle:
        await _startRecording();
      case _VoiceState.recording:
        await _stopAndTranscribe();
      case _VoiceState.transcribing:
        await _cancelTranscription();
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
    } on VoiceTranscriptionError catch (error) {
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

      // Append transcript to the text field, preserving any existing text.
      final currentText = _controller.text;
      if (currentText.isNotEmpty && !currentText.endsWith(" ")) {
        _controller.text = "$currentText $transcript";
      } else {
        _controller.text = "$currentText$transcript";
      }
      // Move cursor to end.
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      _focusNode.requestFocus();
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
        setState(() => _voiceState = _VoiceState.idle);
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
    setState(() => _voiceState = _VoiceState.idle);
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
    _focusNode.requestFocus();
  }

  String _commandHintText(BuildContext context) {
    final command = widget.stagedCommand;
    if (command == null) return context.loc.sessionDetailPromptHint;
    for (final hint in command.hints ?? <String>[]) {
      final trimmed = hint.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return context.loc.sessionDetailCommandArgumentsHint;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return DecoratedBox(
      // Floating composer: no bar surface, no separator line. The scaffold
      // background fades up behind the floating controls so chat content
      // dissolves as it scrolls past — the same scrim the glass top navigation
      // bar uses (PregoGlassScaffold), mirrored to the bottom edge: opaque
      // where the controls sit, transparent where content emerges above. The
      // controls keep their own glass.
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

          // Group only the input row with the text field via a
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
              child: Row(
                spacing: 8,
                crossAxisAlignment: .end,
                children: [
                  PregoButtonsIconGlass(
                    onPressed: _voiceState == _VoiceState.idle ? _openCommandPicker : null,
                    icon: TablerRegular.slash,
                    semanticLabel: loc.sessionDetailCommandPickerTitle,
                  ),
                  Expanded(
                    child: switch (_voiceState) {
                      _VoiceState.recording => _RecordingIndicator(amplitudeStream: _voiceService.amplitudeStream),
                      _VoiceState.transcribing => const _TranscribingIndicator(),
                      _VoiceState.idle => CallbackShortcuts(
                        // Cmd/Ctrl+Enter sends (handy with a hardware keyboard);
                        // plain Enter stays a newline via textInputAction below.
                        bindings: <ShortcutActivator, VoidCallback>{
                          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _handleSend,
                          const SingleActivator(LogicalKeyboardKey.enter, control: true): _handleSend,
                        },
                        child: GlassTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          // Command-aware placeholder: the staged command's hint,
                          // else the default prompt hint. The glass field supplies
                          // its own surface/fill/border, so only the hint text
                          // carries over from the old InputDecoration.
                          placeholder: _commandHintText(context),
                        ),
                      ),
                    },
                  ),
                  _MicButton(
                    voiceState: _voiceState,
                    onTap: _handleMicTap,
                  ),
                  if (_voiceState == _VoiceState.idle) ...[
                    // GlassIconButton has no tooltip/semanticLabel, so wrap it in
                    // a Tooltip to restore the long-press/hover label and the
                    // screen-reader name the old IconButton carried.
                    Tooltip(
                      message: loc.sessionDetailSend,
                      child: GlassIconButton(
                        onPressed: _handleSend,
                        icon: const Icon(Icons.send),
                        glowColor: prego.colors.bgBrandSolid,
                      ),
                    ),
                    if (widget.isBusy)
                      Tooltip(
                        message: loc.sessionDetailAbort,
                        child: GlassIconButton(
                          onPressed: widget.onAbort,
                          icon: const Icon(Icons.stop_circle),
                          glowColor: prego.colors.fgErrorPrimary,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mic button
// -----------------------------------------------------------------------------

class _MicButton extends StatelessWidget {
  final _VoiceState voiceState;
  final VoidCallback onTap;

  const _MicButton({required this.voiceState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    // GlassIconButton exposes no tooltip/semanticLabel, so wrap each state's
    // button in a Tooltip to keep the long-press/hover label and screen-reader
    // name the old IconButton provided.
    return switch (voiceState) {
      _VoiceState.idle => Tooltip(
        message: loc.voiceRecord,
        child: GlassIconButton(
          onPressed: onTap,
          icon: const Icon(Icons.mic_none),
          glowColor: prego.colors.textSecondary,
        ),
      ),
      _VoiceState.recording => Tooltip(
        message: loc.voiceStopRecording,
        child: GlassIconButton(
          onPressed: onTap,
          icon: const Icon(Icons.stop_circle_outlined),
          glowColor: prego.colors.fgErrorPrimary,
        ),
      ),
      _VoiceState.transcribing => Tooltip(
        message: loc.voiceCancelTranscription,
        child: GlassIconButton(
          onPressed: onTap,
          icon: const Icon(Icons.close),
          glowColor: prego.colors.fgErrorPrimary,
        ),
      ),
    };
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
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
