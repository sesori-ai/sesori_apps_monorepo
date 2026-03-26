import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:sesori_dart_core/logging.dart";

import "../../../capabilities/voice/voice_transcription_service.dart";
import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";

enum _VoiceState { idle, recording, transcribing }

class PromptInput extends StatefulWidget {
  final bool isBusy;
  final ValueChanged<String> onSend;
  final VoidCallback onAbort;

  /// Optional widget rendered inside the prompt container, above the text field
  /// but below the separator line.
  final Widget? header;

  const PromptInput({
    super.key,
    required this.isBusy,
    required this.onSend,
    required this.onAbort,
    this.header,
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
    _maxDurationSub = _voiceService.onMaxDurationReached.listen((_) {
      if (_voiceState == _VoiceState.recording && mounted) {
        _showRecordingLimitReached();
        _stopAndTranscribe();
      }
    });
  }

  @override
  void dispose() {
    _maxDurationSub?.cancel();
    // Fire-and-forget cancel if the widget is disposed mid-recording or mid-transcription.
    if (_voiceState != _VoiceState.idle) {
      _voiceService.cancelRecording();
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRecordingLimitReached() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.loc.voiceRecordingLimitReached)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          if (widget.header != null) widget.header!,
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: widget.header != null ? 4 : 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              crossAxisAlignment: .end,
              children: [
                Expanded(
                  child: switch (_voiceState) {
                    _VoiceState.recording => _RecordingIndicator(amplitudeStream: _voiceService.amplitudeStream),
                    _VoiceState.transcribing => const _TranscribingIndicator(),
                    _VoiceState.idle => TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: loc.sessionDetailPromptHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  },
                ),
                const SizedBox(width: 8),
                _MicButton(
                  voiceState: _voiceState,
                  onTap: _handleMicTap,
                ),
                if (_voiceState == _VoiceState.idle) ...[
                  IconButton(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send),
                    color: theme.colorScheme.primary,
                    tooltip: loc.sessionDetailSend,
                  ),
                  if (widget.isBusy)
                    IconButton(
                      onPressed: widget.onAbort,
                      icon: const Icon(Icons.stop_circle),
                      color: theme.colorScheme.error,
                      tooltip: loc.sessionDetailAbort,
                    ),
                ],
              ],
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
    final theme = Theme.of(context);
    final loc = context.loc;

    return switch (voiceState) {
      _VoiceState.idle => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.mic_none),
        color: theme.colorScheme.onSurfaceVariant,
        tooltip: loc.voiceRecord,
      ),
      _VoiceState.recording => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.stop_circle_outlined),
        color: theme.colorScheme.error,
        tooltip: loc.voiceStopRecording,
      ),
      _VoiceState.transcribing => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.close),
        color: theme.colorScheme.error,
        tooltip: loc.voiceCancelTranscription,
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
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.error;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
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
    final theme = Theme.of(context);
    final loc = context.loc;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            loc.voiceTranscribing,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
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
