import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../capabilities/voice/voice_transcription_service.dart";
import "../../../core/constants.dart";
import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/command_picker_sheet.dart";

enum _VoiceState { idle, recording, transcribing }

enum _AttachmentAction { gallery, camera, clipboard }

class PromptInput extends StatefulWidget {
  final bool isBusy;
  final void Function(String text, String? command, List<PickedMedia> attachments) onSend;
  final VoidCallback onAbort;
  final Widget? composerHeader;
  final List<CommandInfo> availableCommands;
  final CommandInfo? stagedCommand;
  final ValueChanged<CommandInfo> onCommandSelected;
  final VoidCallback onCommandCleared;

  /// Optional widget rendered inside the prompt container, above the text field
  /// but below the separator line.
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
  final List<PickedMedia> _attachments = [];

  /// Guards against overlapping clipboard reads (e.g. a rapid second Cmd+V
  /// firing before the first read resolves) staging the same image twice.
  bool _pasteInFlight = false;

  VoiceTranscriptionService get _voiceService => getIt<VoiceTranscriptionService>();

  ClipboardImageReader get _clipboardReader => getIt<ClipboardImageReader>();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    // Intercept Cmd/Ctrl+V (hardware keyboards) to attach a pasted image without
    // consuming the event, so any plain-text content still pastes normally.
    _focusNode.onKeyEvent = (_, event) => _handlePasteShortcut(event);
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
    final attachments = List<PickedMedia>.of(_attachments);
    if (stagedCommand != null) {
      widget.onSend(_controller.text, stagedCommand.name, attachments);
      widget.onCommandCleared();
    } else {
      final text = _controller.text.trim();
      if (text.isEmpty && attachments.isEmpty) return;
      widget.onSend(text, null, attachments);
    }

    _controller.clear();
    if (_attachments.isNotEmpty) {
      setState(_attachments.clear);
    }
    _clearDraft();
    _focusNode.requestFocus();
  }

  Future<void> _showAttachmentSheet() async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheetContext.loc.attachFromGallery),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheetContext.loc.attachFromCamera),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_outlined),
              title: Text(sheetContext.loc.attachFromClipboard),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.clipboard),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case null:
        return;
      case _AttachmentAction.gallery:
        await _addImage(() => getIt<MediaPicker>().pickImageFromGallery());
      case _AttachmentAction.camera:
        await _addImage(() => getIt<MediaPicker>().pickImageFromCamera());
      case _AttachmentAction.clipboard:
        await _pasteFromClipboard(announceEmpty: true);
    }
  }

  Future<void> _addImage(Future<PickedMedia?> Function() pick) async {
    try {
      final media = await pick();
      if (media == null || !mounted) return;
      setState(() => _attachments.add(media));
    } on MediaPickerException catch (error) {
      loge("Failed to attach image", error);
      if (!mounted) return;
      _showError(context.loc.attachError);
    }
  }

  /// Reads an image from the clipboard and stages it as an attachment.
  ///
  /// When [announceEmpty] is true (an explicit "Paste" action), shows a message
  /// if the clipboard holds no image. When false (a Cmd/Ctrl+V keystroke that may
  /// also be pasting text), stays silent on an empty result.
  Future<void> _pasteFromClipboard({required bool announceEmpty}) async {
    if (_pasteInFlight) return;
    _pasteInFlight = true;
    try {
      final media = await _clipboardReader.readImage();
      if (!mounted) return;
      if (media == null) {
        if (announceEmpty) _showError(context.loc.attachClipboardEmpty);
        return;
      }
      setState(() => _attachments.add(media));
    } on MediaPickerException catch (error) {
      loge("Failed to paste image", error);
      // Stay silent on the keystroke path (announceEmpty == false): the user may
      // only be pasting text, so a clipboard error shouldn't surface a toast.
      if (mounted && announceEmpty) _showError(context.loc.attachError);
    } finally {
      _pasteInFlight = false;
    }
  }

  /// Handles Cmd/Ctrl+V from a hardware keyboard. Always lets the event continue
  /// (returns [KeyEventResult.ignored]) so the field's default text paste still
  /// runs; in parallel it attaches a clipboard image when one is present.
  KeyEventResult _handlePasteShortcut(KeyEvent event) {
    final isPaste = event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed);
    if (isPaste) {
      unawaited(_pasteFromClipboard(announceEmpty: false));
    }
    return KeyEventResult.ignored;
  }

  /// Replaces the selection toolbar's "Paste" so it attaches a clipboard image
  /// when present, falling back to the default text paste otherwise. This covers
  /// the case where a copied image also carries text (e.g. an image + its URL).
  Widget _buildContextMenu(EditableTextState editableState) {
    final items = editableState.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.paste) return item;
      final defaultPaste = item.onPressed;
      return item.copyWith(
        onPressed: () {
          editableState.hideToolbar();
          unawaited(_pasteImageOrFallback(defaultPaste));
        },
      );
    }).toList();
    return AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: items,
      anchors: editableState.contextMenuAnchors,
    );
  }

  Future<void> _pasteImageOrFallback(VoidCallback? defaultPaste) async {
    if (_pasteInFlight) {
      defaultPaste?.call();
      return;
    }
    _pasteInFlight = true;
    try {
      final media = await _clipboardReader.readImage();
      if (mounted && media != null) {
        setState(() => _attachments.add(media));
        return;
      }
    } on MediaPickerException catch (error) {
      loge("Failed to paste image", error);
    } finally {
      _pasteInFlight = false;
    }
    defaultPaste?.call();
  }

  /// Attaches an image inserted via the system keyboard (e.g. Gboard image insert).
  void _handleContentInserted(KeyboardInsertedContent content) {
    final data = content.data;
    if (data == null || data.isEmpty || !mounted) return;
    final name = content.uri.split("/").last;
    setState(() {
      _attachments.add(PickedMedia(
        bytes: data,
        mimeType: content.mimeType,
        filename: name.isEmpty ? null : name,
      ));
    });
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    setState(() => _attachments.removeAt(index));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: kSnackBarDuration,
        ),
      );
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
    final zyra = context.zyra;
    final loc = context.loc;

    return Container(
      decoration: BoxDecoration(
        color: zyra.colors.bgPrimary,
        border: Border(
          top: BorderSide(color: zyra.colors.borderSecondary),
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
                child: InputChip(
                  label: Text("/${commandInfo.name}"),
                  avatar: CircleAvatar(
                    backgroundColor: zyra.colors.bgBrandPrimary,
                    child: Text(
                      "/",
                      style: zyra.textTheme.textMd.bold.copyWith(
                        color: zyra.colors.textBrandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onDeleted: widget.onCommandCleared,
                  deleteIcon: const Icon(Icons.close, size: 18),
                ),
              ),
            ),
          },

          if (_attachments.isNotEmpty)
            _AttachmentsPreview(
              attachments: _attachments,
              onRemove: _removeAttachment,
            ),

          Padding(
            padding: EdgeInsetsDirectional.only(
              start: 12,
              end: 8,
              top: widget.header != null ? 4 : 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              crossAxisAlignment: .end,
              children: [
                _SlashButton(
                  enabled: _voiceState == _VoiceState.idle,
                  onTap: _openCommandPicker,
                ),
                const SizedBox(width: 8),
                if (widget.stagedCommand == null) ...[
                  _AttachButton(
                    enabled: _voiceState == _VoiceState.idle,
                    onTap: _showAttachmentSheet,
                  ),
                  const SizedBox(width: 8),
                ],
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
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        contextMenuBuilder: (_, editableState) => _buildContextMenu(editableState),
                        contentInsertionConfiguration: ContentInsertionConfiguration(
                          onContentInserted: _handleContentInserted,
                        ),
                        decoration: InputDecoration(
                          hintText: _commandHintText(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: zyra.colors.bgQuaternary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
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
                    color: zyra.colors.bgBrandSolid,
                    tooltip: loc.sessionDetailSend,
                  ),
                  if (widget.isBusy)
                    IconButton(
                      onPressed: widget.onAbort,
                      icon: const Icon(Icons.stop_circle),
                    color: zyra.colors.fgErrorPrimary,
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
// Slash button
// -----------------------------------------------------------------------------

class _SlashButton extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onTap;

  const _SlashButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Material(
      color: enabled
          ? zyra.colors.bgQuaternary
          : zyra.colors.bgQuaternary.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(
              "/",
              style: zyra.textTheme.textMd.bold.copyWith(
                color: enabled ? zyra.colors.textSecondary : zyra.colors.borderPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Attach button
// -----------------------------------------------------------------------------

class _AttachButton extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onTap;

  const _AttachButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Material(
      color: enabled ? zyra.colors.bgQuaternary : zyra.colors.bgQuaternary.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 22,
            color: enabled ? zyra.colors.textSecondary : zyra.colors.borderPrimary,
            semanticLabel: context.loc.attachImage,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Attachments preview strip
// -----------------------------------------------------------------------------

class _AttachmentsPreview extends StatelessWidget {
  final List<PickedMedia> attachments;
  final void Function(int index) onRemove;

  const _AttachmentsPreview({required this.attachments, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final loc = context.loc;

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final media = attachments[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  media.bytes,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: zyra.colors.bgPrimary.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: zyra.colors.textPrimary,
                      semanticLabel: loc.attachRemove,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final zyra = context.zyra;
    final loc = context.loc;

    return switch (voiceState) {
      _VoiceState.idle => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.mic_none),
        color: zyra.colors.textSecondary,
        tooltip: loc.voiceRecord,
      ),
      _VoiceState.recording => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.stop_circle_outlined),
        color: zyra.colors.fgErrorPrimary,
        tooltip: loc.voiceStopRecording,
      ),
      _VoiceState.transcribing => IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.close),
        color: zyra.colors.fgErrorPrimary,
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
    final zyra = context.zyra;
    final barColor = zyra.colors.fgErrorPrimary;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: zyra.colors.bgErrorPrimary.withValues(alpha: 0.3),
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
    final zyra = context.zyra;
    final loc = context.loc;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: zyra.colors.bgBrandPrimary.withValues(alpha: 0.3),
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
              color: zyra.colors.bgBrandSolid,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            loc.voiceTranscribing,
            style: zyra.textTheme.textSm.regular.copyWith(
              color: zyra.colors.bgBrandSolid,
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
