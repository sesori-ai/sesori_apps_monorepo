import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// Width/height ratio of a preview tile, matching the appearance tiles above.
const double _previewAspectRatio = 96 / 69;

/// Corner radius of a preview tile, and of the selection ring around it.
const double _previewRadius = PregoRadius.xl;
const double _selectionRingWidth = 2.0;
const double _selectionRadius = _previewRadius + _selectionRingWidth;

/// Horizontal gap between the two tiles.
const double _optionGap = PregoSpacing.x3l;

/// Gap between a tile and its label.
const double _labelGap = PregoSpacing.sm;

/// The "Chat input" section: two composer previews (voice first, text first)
/// that switch which input the session composer leads with.
///
/// Reads and writes the app-wide [ChatInputModeCubit] the composer resolves
/// its resting layout from, so a tap re-shapes every composer immediately.
class ChatInputModePicker extends StatelessWidget {
  const ChatInputModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<ChatInputModeCubit>();
    final labels = <ChatInputMode, String>{
      ChatInputMode.voiceFirst: loc.settingsChatInputVoiceFirst,
      ChatInputMode.textFirst: loc.settingsChatInputTextFirst,
    };

    return Padding(
      // The tiles sit inset from the section header, matching the card
      // padding the neighbouring grouped-row sections have.
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: Row(
        spacing: _optionGap,
        children: [
          for (final MapEntry(key: mode, value: label) in labels.entries)
            Expanded(
              child: _ChatInputModeOption(
                mode: mode,
                label: label,
                isSelected: cubit.state == mode,
                onTap: () => cubit.select(mode: mode),
              ),
            ),
        ],
      ),
    );
  }
}

/// One input-mode choice: a preview tile in a selection ring, with its label
/// below.
class _ChatInputModeOption extends StatelessWidget {
  const _ChatInputModeOption({
    required this.mode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final ChatInputMode mode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return MergeSemantics(
      child: Semantics(
        // The two tiles are one choice, not two independent buttons — the
        // same semantics a [Radio] carries, so assistive technology announces
        // the selection as mutually exclusive.
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                // A Container (rather than a DecoratedBox) so the ring insets
                // the preview instead of being painted underneath it. The ring
                // stays transparent when unselected, so selecting one tile
                // never resizes the row.
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_selectionRadius),
                  border: Border.all(
                    color: isSelected ? prego.colors.borderBrand : Colors.transparent,
                    width: _selectionRingWidth,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_previewRadius),
                  child: AspectRatio(
                    aspectRatio: _previewAspectRatio,
                    child: _ComposerPreview(mode: mode),
                  ),
                ),
              ),
              const SizedBox(height: _labelGap),
              Text(
                label,
                style: prego.textTheme.textSm.regular.copyWith(
                  color: isSelected ? prego.colors.textPrimary : prego.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stylised mini composer pill: a waveform for the voice-first mode, a text
/// line with the microphone alongside for the text-first mode.
///
/// Drawn from the ambient theme — unlike the appearance previews, these tiles
/// illustrate a layout rather than a palette.
class _ComposerPreview extends StatelessWidget {
  const _ComposerPreview({required this.mode});

  final ChatInputMode mode;

  /// Fractions of the tile, mirroring the appearance previews' scale.
  static const double _pillBleed = 0.10;
  static const double _pillTop = 0.30;
  static const double _pillWidth = 1.2;
  static const double _pillHeight = 0.40;

  /// Relative heights of the mock waveform bars, echoing the recording state.
  static const List<double> _waveformBars = [0.3, 0.55, 0.9, 0.65, 1.0, 0.5, 0.3];

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final canvas = prego.colors.brightness == Brightness.light ? prego.colors.bgSurface3 : prego.colors.bgSurface1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return DecoratedBox(
          decoration: BoxDecoration(color: canvas),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -width * _pillBleed,
                top: height * _pillTop,
                width: width * _pillWidth,
                height: height * _pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: prego.colors.bgSurface3,
                    border: Border.all(color: prego.colors.borderSecondary),
                    borderRadius: BorderRadius.circular(PregoRadius.full),
                  ),
                  child: switch (mode) {
                    ChatInputMode.voiceFirst => _VoiceFirstPillContent(barHeight: height * _pillHeight * 0.55),
                    ChatInputMode.textFirst => _TextFirstPillContent(width: width),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Centered mock waveform bars — the hold-to-talk pill mid-recording.
class _VoiceFirstPillContent extends StatelessWidget {
  const _VoiceFirstPillContent({required this.barHeight});

  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 2.5,
      children: [
        for (final factor in _ComposerPreview._waveformBars)
          Container(
            width: 2.5,
            height: (barHeight * factor).clamp(2.5, barHeight),
            decoration: BoxDecoration(
              color: prego.colors.textPrimary,
              borderRadius: BorderRadius.circular(PregoRadius.full),
            ),
          ),
      ],
    );
  }
}

/// A text line with the trailing microphone — the tap-to-type pill.
class _TextFirstPillContent extends StatelessWidget {
  const _TextFirstPillContent({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.10),
      child: Row(
        children: [
          Expanded(
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.55,
              heightFactor: 0.28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: prego.colors.textSecondary,
                  borderRadius: BorderRadius.circular(PregoRadius.full),
                ),
              ),
            ),
          ),
          Icon(
            TablerRegular.microphone,
            size: width * 0.14,
            color: prego.colors.textPrimary,
          ),
        ],
      ),
    );
  }
}
