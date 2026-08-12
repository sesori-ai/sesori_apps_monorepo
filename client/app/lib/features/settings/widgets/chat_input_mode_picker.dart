import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

const double _optionHeight = 100.0;
const double _previewHeight = 69.0;
const double _labelGap = PregoSpacing.sm;
const double _selectionRingWidth = 2.0;
const double _composerHeight = 54.0;
const double _composerWidth = 370.0;
const double _composerInset = PregoSpacing.md;

/// The two default composer input choices shown on the dedicated settings page.
class ChatInputModePicker extends StatelessWidget {
  const ChatInputModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<ChatInputModeCubit>();
    final labels = <ChatInputMode, String>{
      ChatInputMode.voiceFirst: loc.settingsDefaultInputVoice,
      ChatInputMode.textFirst: loc.settingsDefaultInputText,
    };

    return Row(
      spacing: PregoSpacing.lg,
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
    );
  }
}

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
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _optionHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: _previewHeight,
                  decoration: BoxDecoration(
                    color: prego.colors.bgSurface3,
                    borderRadius: BorderRadius.circular(PregoRadius.lg),
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PregoRadius.lg),
                    border: Border.all(
                      color: isSelected ? prego.colors.borderBrand : Colors.transparent,
                      width: _selectionRingWidth,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ExcludeSemantics(
                    child: _ComposerPreview(mode: mode, isSelected: isSelected),
                  ),
                ),
                const SizedBox(height: _labelGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: PregoSpacing.sm,
                  children: [
                    Icon(
                      switch (mode) {
                        ChatInputMode.voiceFirst => TablerRegular.microphone,
                        ChatInputMode.textFirst => TablerRegular.keyboard,
                      },
                      size: 14,
                      color: isSelected ? prego.colors.textPrimary : prego.colors.textSecondary,
                    ),
                    Text(
                      label,
                      style: prego.textTheme.textSm.regular.copyWith(
                        color: isSelected ? prego.colors.textPrimary : prego.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerPreview extends StatelessWidget {
  const _ComposerPreview({required this.mode, required this.isSelected});

  final ChatInputMode mode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _composerInset,
          top: (_previewHeight - _composerHeight) / 2,
          width: _composerWidth,
          height: _composerHeight,
          child: _ComposerPill(mode: mode, isSelected: isSelected),
        ),
        PositionedDirectional(
          end: 0,
          top: 0,
          width: 46,
          height: _previewHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    context.prego.colors.bgSurface3.withValues(alpha: 0),
                    context.prego.colors.bgSurface3,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComposerPill extends StatelessWidget {
  const _ComposerPill({required this.mode, required this.isSelected});

  final ChatInputMode mode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        border: Border.all(
          color: mode == ChatInputMode.textFirst ? prego.colors.borderPrimary : prego.colors.borderSecondary,
        ),
        borderRadius: BorderRadius.circular(PregoRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.sm),
        child: Row(
          spacing: PregoSpacing.md,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: prego.colors.bgSurface4,
                border: Border.all(color: prego.colors.borderPrimary),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                switch (mode) {
                  ChatInputMode.voiceFirst => TablerRegular.microphone,
                  ChatInputMode.textFirst => TablerRegular.arrow_up,
                },
                size: mode == ChatInputMode.voiceFirst ? 14 : 18,
                color: isSelected ? prego.colors.textPrimary : prego.colors.textTertiary,
              ),
            ),
            switch (mode) {
              ChatInputMode.voiceFirst => _Waveform(isSelected: isSelected),
              ChatInputMode.textFirst => _TextPreview(isSelected: isSelected),
            },
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.isSelected});

  final bool isSelected;

  static const _barHeights = <double>[
    6,
    6,
    6,
    8,
    12,
    18,
    15,
    21,
    18,
    24,
    18,
    24,
    18,
    24,
    24,
    20,
    22,
    8,
    14,
    11,
    6,
    6,
  ];

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Row(
      spacing: 3.7,
      children: [
        for (var index = 0; index < _barHeights.length; index++)
          Container(
            width: 4.9,
            height: _barHeights[index],
            decoration: BoxDecoration(
              color: index < 2
                  ? prego.colors.fgQuaternary
                  : isSelected
                  ? prego.colors.textSecondaryOnBrand
                  : prego.colors.textSecondary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(PregoRadius.xxs),
            ),
          ),
      ],
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 20,
          color: isSelected ? prego.colors.borderBrand : prego.colors.textTertiary,
        ),
        Text(
          context.loc.settingsDefaultInputTextPreview,
          textScaler: TextScaler.noScaling,
          style: prego.textTheme.textMd.regular.copyWith(
            color: isSelected ? prego.colors.textSecondary : prego.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
