import "dart:math" as math;

import "package:flutter/material.dart";

import "../utils/color_extensions.dart";

/// Controls the direction characters roll when transitioning.
enum ZyraRollingTextDirection {
  /// Each character independently determines its roll direction:
  /// higher char code -> rolls up; lower -> rolls down.
  perCharacter,

  /// All changing characters roll upward uniformly
  /// (old slides up + fades out, new enters from below).
  up,

  /// All changing characters roll downward uniformly
  /// (old slides down, new enters from above).
  down,
}

class _CharAnimConfig {
  const _CharAnimConfig({
    required this.oldChar,
    required this.newChar,
    required this.interval,
    required this.rollUp,
  });

  final String? oldChar;
  final String? newChar;
  final Interval interval;
  final bool rollUp;
}

/// Per-character rolling text animation for Zyra design language components.
class ZyraRollingText extends StatefulWidget {
  const ZyraRollingText({
    super.key,
    required this.text,
    required this.style,
    required this.direction,
    this.duration = const Duration(milliseconds: 450),
    this.staggerSlideDelay = const Duration(milliseconds: 40),
    this.curve = Curves.easeOut,
  });

  /// Text to display and animate.
  final String text;

  /// Text style applied to all characters.
  final TextStyle style;

  /// Character roll direction mode.
  final ZyraRollingTextDirection direction;

  /// Total cascade duration.
  final Duration duration;

  /// Delay between consecutive character starts.
  final Duration staggerSlideDelay;

  /// Easing curve used for character intervals.
  final Curve curve;

  @override
  State<ZyraRollingText> createState() => _ZyraRollingTextState();
}

class _ZyraRollingTextState extends State<ZyraRollingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _previousText = "";
  String _currentText = "";
  List<_CharAnimConfig> _configs = <_CharAnimConfig>[];
  double _charWidth = 0.0;
  double _charHeight = 0.0;
  Map<String, double> _charWidthCache = {};

  List<_CharAnimConfig?> _configBySlot = <_CharAnimConfig?>[];
  String _animatedTargetText = "";

  String? _lastMeasuredCurrentText;
  String? _lastMeasuredPreviousText;
  TextStyle? _lastMeasuredStyle;
  TextScaler? _lastMeasuredTextScaler;

  TextStyle get _tabularStyle => widget.style.copyWith(
    fontFeatures: [
      const FontFeature.tabularFigures(),
      ...?widget.style.fontFeatures,
    ],
  );

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  double _widthOf(String? char) => char != null ? (_charWidthCache[char] ?? _charWidth) : _charWidth;

  @override
  void initState() {
    super.initState();
    _currentText = widget.text;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _configs = <_CharAnimConfig>[];
          _configBySlot = <_CharAnimConfig?>[];
          _animatedTargetText = "";
        });
      }
    });
  }

  @override
  void didUpdateWidget(ZyraRollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    _beginAnimation(fromText: _currentText, toText: widget.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _beginAnimation({required String fromText, required String toText}) {
    _previousText = fromText;
    _currentText = toText;

    final oldLength = _previousText.length;
    final newLength = _currentText.length;
    final maxLength = math.max(oldLength, newLength);

    final oldStart = maxLength - oldLength;
    final newStart = maxLength - newLength;
    final paddedCurrent = _currentText.padLeft(maxLength, " ");

    final totalMs = math.max(1, widget.duration.inMilliseconds);
    final staggerMs = math.max(0, widget.staggerSlideDelay.inMilliseconds);
    final totalPositions = _currentText.length;
    final staggerOverhead = staggerMs * math.max(0, totalPositions - 1);
    var perCharMs = totalMs - staggerOverhead;
    if (perCharMs < 100) perCharMs = 100;
    if (perCharMs > totalMs) perCharMs = totalMs;

    final slotConfigs = List<_CharAnimConfig?>.filled(maxLength, null);
    final changedConfigs = <_CharAnimConfig>[];

    for (var slotIndex = 0; slotIndex < maxLength; slotIndex++) {
      final hasOld = slotIndex >= oldStart;
      final hasNew = slotIndex >= newStart;

      final oldChar = hasOld ? _previousText[slotIndex - oldStart] : null;
      final newChar = hasNew ? _currentText[slotIndex - newStart] : null;
      if (oldChar == newChar) continue;

      final staggerIndex = hasNew ? slotIndex - newStart : 0;
      final startMs = math.min(staggerMs * staggerIndex, math.max(0, totalMs - 1));
      var endMs = startMs + perCharMs;
      if (endMs > totalMs) endMs = totalMs;
      if (endMs <= startMs) endMs = math.min(totalMs, startMs + 1);

      final config = _CharAnimConfig(
        oldChar: oldChar,
        newChar: newChar,
        interval: Interval(
          startMs / totalMs,
          endMs / totalMs,
          curve: widget.curve,
        ),
        rollUp: _resolveRollUp(oldChar: oldChar, newChar: newChar),
      );

      slotConfigs[slotIndex] = config;
      changedConfigs.add(config);
    }

    setState(() {
      _configs = changedConfigs;
      _configBySlot = slotConfigs;
      _animatedTargetText = paddedCurrent;
    });

    _controller.duration = Duration(milliseconds: totalMs);
    if (_configs.isNotEmpty) {
      _controller.forward(from: 0.0);
    }
  }

  bool _resolveRollUp({required String? oldChar, required String? newChar}) {
    switch (widget.direction) {
      case ZyraRollingTextDirection.up:
        return true;
      case ZyraRollingTextDirection.down:
        return false;
      case ZyraRollingTextDirection.perCharacter:
        if (oldChar == null || newChar == null) return true;
        return newChar.codeUnitAt(0) >= oldChar.codeUnitAt(0);
    }
  }

  void _updateMeasurements(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    if (_lastMeasuredCurrentText == _currentText &&
        _lastMeasuredPreviousText == _previousText &&
        _lastMeasuredStyle == widget.style &&
        _lastMeasuredTextScaler == textScaler) {
      return;
    }
    _lastMeasuredCurrentText = _currentText;
    _lastMeasuredPreviousText = _previousText;
    _lastMeasuredStyle = widget.style;
    _lastMeasuredTextScaler = textScaler;

    final painter = TextPainter(
      text: TextSpan(text: "0", style: _tabularStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    _charWidth = painter.width;
    _charHeight = painter.height;
    painter.dispose();

    // Cache widths for all unique characters in current + previous text.
    final newCache = <String, double>{};
    final allChars = <String>{..._currentText.split(''), ..._previousText.split('')};
    for (final char in allChars) {
      if (_isDigit(char)) {
        newCache[char] = _charWidth;
      } else {
        final p = TextPainter(
          text: TextSpan(text: char, style: _tabularStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        newCache[char] = p.width;
        p.dispose();
      }
    }
    _charWidthCache = newCache;
  }

  @override
  Widget build(BuildContext context) {
    _updateMeasurements(context);

    if (_configs.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _currentText.length; i++) Text(_currentText[i], style: _tabularStyle),
        ],
      );
    }

    return AnimatedSize(
      duration: widget.duration,
      curve: widget.curve,
      clipBehavior: Clip.none,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildRow(),
      ),
    );
  }

  Widget _buildRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(_configBySlot.length, (slotIndex) {
        final config = _configBySlot[slotIndex];
        if (config == null) {
          return Text(_animatedTargetText[slotIndex], style: _tabularStyle);
        }
        return _buildAnimatedSlot(config: config);
      }),
    );
  }

  Widget _buildAnimatedSlot({required _CharAnimConfig config}) {
    final progress = config.interval.transform(_controller.value);
    final oldChar = config.oldChar;
    final newChar = config.newChar;
    final style = _tabularStyle;
    final fadeInStyle = style.copyWith(color: style.color?.withMultipliedOpacity(progress));
    final fadeOutStyle = style.copyWith(color: style.color?.withMultipliedOpacity(1.0 - progress));

    // ENTRY: new character appearing (width expand + vertical slide + fade in)
    if (oldChar == null && newChar != null) {
      final targetWidth = _widthOf(newChar);
      final inY = config.rollUp ? _charHeight * (1.0 - progress) : -_charHeight * (1.0 - progress);
      return ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: progress,
          heightFactor: 1.0,
          child: SizedBox(
            width: targetWidth,
            height: _charHeight,
            child: Transform.translate(
              offset: Offset(0, inY),
              child: Text(newChar, style: fadeInStyle),
            ),
          ),
        ),
      );
    }

    // EXIT: old character disappearing (width shrink + fade out)
    if (oldChar != null && newChar == null) {
      if (progress >= 1.0) return const SizedBox.shrink();
      final targetWidth = _widthOf(oldChar);
      return ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: 1.0 - progress,
          heightFactor: 1.0,
          child: SizedBox(
            width: targetWidth,
            height: _charHeight,
            child: Text(oldChar, style: fadeOutStyle),
          ),
        ),
      );
    }

    // CHANGE: vertical slide transition with correct per-char width
    final charWidth = _widthOf(newChar ?? oldChar);
    final outY = config.rollUp ? -_charHeight * progress : _charHeight * progress;
    final inY = config.rollUp ? _charHeight * (1.0 - progress) : -_charHeight * (1.0 - progress);

    return ClipRect(
      child: SizedBox(
        width: charWidth,
        height: _charHeight,
        child: Stack(
          children: [
            if (oldChar != null)
              Transform.translate(
                offset: Offset(0, outY),
                child: Text(oldChar, style: fadeOutStyle),
              ),
            if (newChar != null)
              Transform.translate(
                offset: Offset(0, inY),
                child: Text(newChar, style: fadeInStyle),
              ),
          ],
        ),
      ),
    );
  }
}
