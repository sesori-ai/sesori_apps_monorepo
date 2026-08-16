// This catalog-only developer tool intentionally presents fixed English audit labels.
// ignore_for_file: no_slop_linter/avoid_string_literals_in_widgets

import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";

import "inspector/prego_inspection_tokens.dart";
import "review_tools/presentation/prego_review_action.dart";
import "review_tools/presentation/prego_review_target.dart";

typedef PregoInspectorCopyText = Future<void> Function({required String text});

class const PregoCatalogInspector({
  required final Widget child,
  final PregoInspectorCopyText? copyText,
  super.key,
}) extends StatefulWidget {
  @override
  State<PregoCatalogInspector> createState() => _PregoCatalogInspectorState();
}

class _PregoCatalogInspectorState() extends State<PregoCatalogInspector> {
  final _rootKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _panelKey = GlobalKey();
  final _focusNode = FocusNode(debugLabel: "Prego catalog inspector");

  static const _targetResolver = PregoReviewTargetResolver();

  List<PregoReviewTarget> _hoverCandidates = const [];
  List<PregoReviewTarget> _pinnedCandidates = const [];
  int _pinnedIndex = 0;
  Offset _pointerPosition = Offset.zero;
  String? _copiedReference;
  bool _copyFailed = false;
  int _copyRequest = 0;
  bool _selectionClearScheduled = false;
  late PregoInspectionTokenResolver _inspectionTokenResolver;

  bool get _hasPinnedSelection => _pinnedCandidates.isNotEmpty;
  PregoReviewTarget? get _hovered => _hoverCandidates.firstOrNull;
  PregoReviewTarget? get _pinned => _hasPinnedSelection ? _pinnedCandidates[_pinnedIndex] : null;
  PregoReviewTarget? get _active => _pinned ?? _hovered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inspectionTokenResolver = PregoInspectionTokenResolver(context: context);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final active = _active;
    final rootObject = _rootKey.currentContext?.findRenderObject();
    final root = rootObject is RenderBox ? rootObject : null;
    final activeRect = active == null || root == null ? null : _safeRectIn(target: active, root: root);
    if (active != null) _scheduleInvalidSelectionClear();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        onHover: _onHover,
        onExit: (_) {
          if (!_hasPinnedSelection) setState(() => _hoverCandidates = const []);
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerUp: _onPointerUp,
          child: Stack(
            key: _rootKey,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: AbsorbPointer(
                  child: KeyedSubtree(key: _contentKey, child: widget.child),
                ),
              ),
              if (activeRect != null)
                Positioned.fromRect(
                  rect: activeRect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key("prego-inspector-highlight"),
                      decoration: BoxDecoration(
                        color: colors.bgBrandPrimary.withValues(alpha: 0.12),
                        border: Border.all(color: colors.borderBrand, width: 2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              if (active != null && activeRect != null)
                _buildInspectionCard(context, candidate: active, targetRect: activeRect),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionCard(
    BuildContext context, {
    required PregoReviewTarget candidate,
    required Rect targetRect,
  }) {
    final rootObject = _rootKey.currentContext?.findRenderObject();
    if (rootObject is! RenderBox) return const SizedBox.shrink();
    final root = rootObject;

    final details = _InspectionDetails.from(
      candidate: candidate,
      candidates: _hasPinnedSelection ? _pinnedCandidates : _hoverCandidates,
      root: root,
      resolver: _inspectionTokenResolver,
      textDirection: Directionality.of(context),
    );
    final panelWidth = _hasPinnedSelection ? 312.0 : 236.0;
    final panelHeight = _hasPinnedSelection ? 388.0 : 104.0;
    final position = _panelPosition(
      targetRect: targetRect,
      rootSize: root.size,
      panelSize: Size(panelWidth, panelHeight),
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      width: panelWidth,
      child: KeyedSubtree(
        key: _panelKey,
        child: _InspectorCard(
          key: const Key("prego-inspector-card"),
          details: details,
          expanded: _hasPinnedSelection,
          position: _pinnedIndex,
          candidateCount: _hasPinnedSelection ? _pinnedCandidates.length : _hoverCandidates.length,
          copiedReference: _copiedReference,
          copyFailed: _copyFailed,
          onPrevious: _hasPinnedSelection ? () => _cycle(by: -1) : null,
          onNext: _hasPinnedSelection ? () => _cycle(by: 1) : null,
          onClear: _hasPinnedSelection ? _clearPinned : null,
          onCopy: _hasPinnedSelection ? _copy : null,
        ),
      ),
    );
  }

  // Focus.onKeyEvent is a framework callback with positional parameters.
  // ignore: no_slop_linter/prefer_required_named_parameters
  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearPinned();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      _cycle(by: -1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
      _cycle(by: 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && !_hasPinnedSelection && _hoverCandidates.isNotEmpty) {
      setState(() {
        _pinnedCandidates = _hoverCandidates;
        _pinnedIndex = 0;
        _copyFailed = false;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onHover(PointerHoverEvent event) {
    final rootObject = _rootKey.currentContext?.findRenderObject();
    if (rootObject is! RenderBox) return;
    final root = rootObject;
    final candidates = _findCandidates(globalPosition: event.position);
    final localPosition = root.globalToLocal(event.position);
    if (_targetResolver.sameTargets(first: _hoverCandidates, second: candidates) && _pointerPosition == localPosition) {
      return;
    }
    setState(() {
      _hoverCandidates = candidates;
      _pointerPosition = localPosition;
      _copiedReference = null;
      _copyFailed = false;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _focusNode.requestFocus();
    final panel = _panelKey.currentContext?.findRenderObject();
    if (panel is RenderBox && _containsGlobalPosition(box: panel, globalPosition: event.position)) return;
    final candidates = _findCandidates(globalPosition: event.position);
    if (candidates.isEmpty) return;
    setState(() {
      if (_targetResolver.sameTargets(first: _pinnedCandidates, second: candidates)) {
        _pinnedIndex = (_pinnedIndex + 1) % candidates.length;
      } else {
        _pinnedCandidates = candidates;
        _pinnedIndex = 0;
      }
      _hoverCandidates = candidates;
      _copiedReference = null;
      _copyFailed = false;
    });
  }

  void _cycle({required int by}) {
    if (!_hasPinnedSelection) return;
    setState(() {
      _pinnedIndex = (_pinnedIndex + by) % _pinnedCandidates.length;
      _copiedReference = null;
      _copyFailed = false;
    });
  }

  void _clearPinned() {
    if (!_hasPinnedSelection && _hoverCandidates.isEmpty) return;
    setState(() {
      _pinnedCandidates = const [];
      _pinnedIndex = 0;
      _hoverCandidates = const [];
      _copiedReference = null;
    });
  }

  Future<void> _copy(String value) async {
    final request = ++_copyRequest;
    try {
      if (widget.copyText case final copyText?) {
        await copyText(text: value);
      } else {
        await Clipboard.setData(ClipboardData(text: value));
      }
    } on Object {
      if (!mounted || request != _copyRequest) return;
      setState(() {
        _copiedReference = null;
        _copyFailed = true;
      });
      return;
    }
    if (!mounted || request != _copyRequest) return;
    setState(() {
      _copiedReference = value;
      _copyFailed = false;
    });
  }

  List<PregoReviewTarget> _findCandidates({required Offset globalPosition}) {
    final content = _contentKey.currentContext?.findRenderObject();
    if (content == null) return const [];
    return _targetResolver.findAt(contentRoot: content, globalPosition: globalPosition);
  }

  void _scheduleInvalidSelectionClear() {
    if (_selectionClearScheduled) return;
    _selectionClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionClearScheduled = false;
      if (!mounted) return;
      final active = _active;
      final root = _rootKey.currentContext?.findRenderObject();
      if (active == null || root is! RenderBox || _safeRectIn(target: active, root: root) != null) return;
      _clearPinned();
    });
  }
}

Rect? _safeRectIn({required PregoReviewTarget target, required RenderBox root}) {
  if (!target.renderBox.attached || !root.attached || !target.renderBox.hasSize || !root.hasSize) return null;
  try {
    return target.rectIn(root: root);
  } on Object {
    return null;
  }
}

final class const _InspectionDetails({
  required final String label,
  required final Size logicalSize,
  required final Size renderedSize,
  required final BoxConstraints constraints,
  required final TextStyle? textStyle,
  required final PregoInspectionTokenMatches<TextStyle>? textTokens,
  required final Color? textColor,
  required final PregoInspectionTokenMatches<Color>? textColorTokens,
  required final Color? backgroundColor,
  required final PregoInspectionTokenMatches<Color>? backgroundColorTokens,
  required final EdgeInsets? padding,
  required final List<PregoInspectionTokenMatches<double>> paddingTokens,
  required final List<double>? radius,
  required final List<PregoInspectionTokenMatches<double>> radiusTokens,
  required final String? semanticLabel,
  required final SemanticsRole? semanticRole,
  required final bool isInteractive,
  required final double? contrastRatio,
}) {
  factory from({
    required PregoReviewTarget candidate,
    required List<PregoReviewTarget> candidates,
    required RenderBox root,
    required PregoInspectionTokenResolver resolver,
    required TextDirection textDirection,
  }) {
    final box = candidate.renderBox;
    final rect = candidate.rectIn(root: root);
    final style = box is RenderParagraph ? _firstTextStyle(box.text) : null;
    final decoration = switch (box) {
      RenderDecoratedBox(:final BoxDecoration decoration) => decoration,
      _ => null,
    };
    final padding = box is RenderPadding ? box.padding.resolve(textDirection) : null;
    final resolvedRadius = decoration?.borderRadius?.resolve(textDirection);
    final radius = resolvedRadius == null
        ? null
        : [
            resolvedRadius.topLeft.x,
            resolvedRadius.topRight.x,
            resolvedRadius.bottomRight.x,
            resolvedRadius.bottomLeft.x,
          ];
    final semantics = box is RenderSemanticsAnnotations ? box.properties : null;
    final background = decoration?.color ?? _nearestBackground(candidate: candidate, candidates: candidates);
    final textColor = style?.color;

    return _InspectionDetails(
      label: candidate.label,
      logicalSize: box.size,
      renderedSize: rect.size,
      constraints: box.constraints,
      textStyle: style,
      textTokens: style == null ? null : resolver.matchTypography(style),
      textColor: textColor,
      textColorTokens: textColor == null ? null : resolver.matchColor(textColor),
      backgroundColor: background,
      backgroundColorTokens: background == null ? null : resolver.matchColor(background),
      padding: padding,
      paddingTokens: padding == null
          ? const []
          : [
              resolver.matchDimension(
                padding.left,
                kinds: const {PregoInspectionTokenKind.spacing, PregoInspectionTokenKind.spacingPrimitive},
              ),
              resolver.matchDimension(
                padding.top,
                kinds: const {PregoInspectionTokenKind.spacing, PregoInspectionTokenKind.spacingPrimitive},
              ),
              resolver.matchDimension(
                padding.right,
                kinds: const {PregoInspectionTokenKind.spacing, PregoInspectionTokenKind.spacingPrimitive},
              ),
              resolver.matchDimension(
                padding.bottom,
                kinds: const {PregoInspectionTokenKind.spacing, PregoInspectionTokenKind.spacingPrimitive},
              ),
            ],
      radius: radius,
      radiusTokens: radius == null
          ? const []
          : [
              for (final value in radius)
                resolver.matchDimension(value, kinds: const {PregoInspectionTokenKind.radius}),
            ],
      semanticLabel: semantics?.label,
      semanticRole: semantics?.role,
      isInteractive: (semantics?.button ?? false) || semantics?.onTap != null || box is RenderSemanticsGestureHandler,
      contrastRatio: textColor == null || background == null ? null : _contrast(first: textColor, second: background),
    );
  }
}

class const _InspectorCard({
  required final _InspectionDetails details,
  required final bool expanded,
  required final int position,
  required final int candidateCount,
  required final String? copiedReference,
  required final bool copyFailed,
  required final VoidCallback? onPrevious,
  required final VoidCallback? onNext,
  required final VoidCallback? onClear,
  required final ValueChanged<String>? onCopy,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final text = context.prego.textTheme;
    final primaryText = text.textXs.medium.copyWith(color: colors.textPrimary);
    final secondaryText = text.textXs.regular.copyWith(color: colors.textSecondary);

    return Semantics(
      container: true,
      label: expanded ? "Pinned inspector details" : "Inspector hover summary",
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface1,
          border: Border.all(color: colors.borderSecondary),
          borderRadius: BorderRadius.circular(PregoRadius.lg),
          boxShadow: context.prego.shadows.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: secondaryText,
            child: expanded
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 364),
                    child: SingleChildScrollView(
                      child: _buildExpanded(
                        context,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                    ),
                  )
                : _buildSummary(primaryText: primaryText, secondaryText: secondaryText),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary({required TextStyle primaryText, required TextStyle secondaryText}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(details.label, style: primaryText),
      const SizedBox(height: 4),
      Text(_sizeLabel(details.logicalSize), style: secondaryText),
      if (details.textStyle case final style?) ...[
        const SizedBox(height: 4),
        Text(
          "${_format(style.fontSize ?? 0)} px · ${_candidateLabel(details.textTokens)}",
          style: secondaryText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      const SizedBox(height: 4),
      Text("Click to pin · [ ] cycle · Esc clear", style: secondaryText),
    ],
  );

  Widget _buildExpanded(
    BuildContext context, {
    required TextStyle primaryText,
    required TextStyle secondaryText,
  }) {
    final copyValue = _primaryReference(details);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(details.label, style: primaryText)),
            PregoReviewAction(label: "Previous target", text: "‹", onPressed: onPrevious),
            const SizedBox(width: 4),
            Text("${position + 1}/$candidateCount", key: const Key("prego-inspector-position"), style: secondaryText),
            const SizedBox(width: 4),
            PregoReviewAction(label: "Next target", text: "›", onPressed: onNext),
            const SizedBox(width: 4),
            PregoReviewAction(label: "Close inspector details", text: "×", onPressed: onClear),
          ],
        ),
        const SizedBox(height: 10),
        _Section(
          title: "Overview",
          rows: [
            ("Logical size", _sizeLabel(details.logicalSize)),
            if ((details.logicalSize.width - details.renderedSize.width).abs() > 0.1 ||
                (details.logicalSize.height - details.renderedSize.height).abs() > 0.1)
              ("Rendered size", _sizeLabel(details.renderedSize)),
            ("Constraints", _constraintsLabel(details.constraints)),
            if (details.isInteractive)
              (
                "Touch target",
                details.logicalSize.width >= 44 && details.logicalSize.height >= 44
                    ? "Pass · at least 44 × 44"
                    : "Review · below 44 × 44",
              ),
          ],
        ),
        if (details.textStyle case final style?) ...[
          const SizedBox(height: 10),
          _Section(
            title: "Typography",
            rows: [
              ("Token match", _candidateLabel(details.textTokens)),
              ("Font", style.fontFamily ?? "Inherited"),
              ("Size / weight", "${_format(style.fontSize ?? 0)} px / ${_weightLabel(style.fontWeight)}"),
              ("Line height", _lineHeight(style)),
              ("Letter spacing", "${_format(style.letterSpacing ?? 0)} px"),
              if (details.textColor case final color?)
                ("Text color", "${_colorHex(color)} · ${_candidateLabel(details.textColorTokens)}"),
              if (details.contrastRatio case final contrast?)
                ("Contrast", "${contrast.toStringAsFixed(2)}:1 · ${contrast >= 4.5 ? "AA" : "Review"}"),
            ],
          ),
        ],
        if (details.backgroundColor != null || details.radius != null) ...[
          const SizedBox(height: 10),
          _Section(
            title: "Appearance",
            rows: [
              if (details.backgroundColor case final color?)
                ("Fill", "${_colorHex(color)} · ${_candidateLabel(details.backgroundColorTokens)}"),
              if (details.radius case final radius?)
                (
                  "Radius TL/TR/BR/BL",
                  "${radius.map(_format).join(" / ")} · ${_dimensionCandidates(details.radiusTokens)}",
                ),
            ],
          ),
        ],
        if (details.padding case final padding?) ...[
          const SizedBox(height: 10),
          _Section(
            title: "Layout",
            rows: [
              (
                "Padding L/T/R/B",
                "${_format(padding.left)} / ${_format(padding.top)} / ${_format(padding.right)} / ${_format(padding.bottom)}",
              ),
              ("Token matches", _dimensionCandidates(details.paddingTokens)),
            ],
          ),
        ],
        if (details.semanticLabel != null || details.semanticRole != null || details.isInteractive) ...[
          const SizedBox(height: 10),
          _Section(
            title: "Accessibility",
            rows: [
              if (details.semanticLabel case final label? when label.isNotEmpty) ("Label", label),
              if (details.semanticRole case final role?) ("Role", role.name),
              ("Interactive", details.isInteractive ? "Yes" : "No"),
            ],
          ),
        ],
        if (copyValue != null) ...[
          const SizedBox(height: 12),
          PregoReviewAction(
            label: "Copy PREGO token reference",
            text: copiedReference == copyValue
                ? "Copied"
                : copyFailed
                ? "Copy failed"
                : "Copy ${_shortReference(copyValue)}",
            onPressed: switch (onCopy) {
              final onCopy? => () => onCopy(copyValue),
              null => null,
            },
            wide: true,
          ),
        ],
      ],
    );
  }
}

class const _Section({
  required final String title,
  required final List<(String, String)> rows,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = context.prego.textTheme;
    final colors = context.prego.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.textXs.bold.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 4),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 92, child: Text(label)),
                Expanded(child: Text(value, key: ValueKey("$title:$label"))),
              ],
            ),
          ),
      ],
    );
  }
}

bool _containsGlobalPosition({required RenderBox box, required Offset globalPosition}) {
  try {
    return (Offset.zero & box.size).contains(box.globalToLocal(globalPosition));
  } on Object {
    return false;
  }
}

TextStyle? _firstTextStyle(InlineSpan span) {
  if (span.style case final style?) return style;
  if (span case TextSpan(children: final children?)) {
    for (final child in children) {
      if (_firstTextStyle(child) case final style?) return style;
    }
  }
  return null;
}

Color? _nearestBackground({
  required PregoReviewTarget candidate,
  required List<PregoReviewTarget> candidates,
}) {
  final target = candidate.renderBox;
  for (final item in candidates) {
    final box = item.renderBox;
    if (box case RenderDecoratedBox(:final BoxDecoration decoration)
        when box.size >= target.size && decoration.color != null) {
      return decoration.color;
    }
  }
  return null;
}

double _contrast({required Color first, required Color second}) {
  final lighter = first.computeLuminance() > second.computeLuminance() ? first : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) / (darker.computeLuminance() + 0.05);
}

Offset _panelPosition({required Rect targetRect, required Size rootSize, required Size panelSize}) {
  const gap = 10.0;
  final rightFits = targetRect.right + gap + panelSize.width <= rootSize.width - gap;
  final left = rightFits
      ? targetRect.right + gap
      : (targetRect.left - gap - panelSize.width).clamp(gap, rootSize.width - panelSize.width - gap);
  final top = targetRect.top.clamp(gap, rootSize.height - panelSize.height - gap);
  return Offset(left, top);
}

String _candidateLabel<T>(PregoInspectionTokenMatches<T>? matches) {
  if (matches == null || matches.candidates.isEmpty) return "Custom / unmapped";
  final semantic = matches.candidates.where((token) => token.kind != PregoInspectionTokenKind.primitiveColor).toList();
  final candidates = semantic.isEmpty ? matches.candidates : semantic;
  final shown = candidates.take(2).map((token) => "${token.name} (${token.kind.label})").join(", ");
  final remaining = candidates.length - 2;
  return remaining > 0 ? "$shown +$remaining value matches" : shown;
}

String _dimensionCandidates(List<PregoInspectionTokenMatches<double>> matches) {
  final names = <String>[];
  for (final match in matches) {
    final preferred = match.candidates
        .where((token) => token.kind != PregoInspectionTokenKind.spacingPrimitive)
        .firstOrNull;
    final token = preferred ?? match.candidates.firstOrNull;
    if (token != null && !names.contains(token.name)) names.add(token.name);
  }
  return names.isEmpty ? "Custom / unmapped" : names.join(" / ");
}

String? _primaryReference(_InspectionDetails details) =>
    _unambiguousReference(details.textTokens) ??
    _unambiguousReference(details.textColorTokens) ??
    _unambiguousReference(details.backgroundColorTokens) ??
    details.paddingTokens.map(_unambiguousReference).nonNulls.firstOrNull ??
    details.radiusTokens.map(_unambiguousReference).nonNulls.firstOrNull;

String? _unambiguousReference<T>(PregoInspectionTokenMatches<T>? matches) {
  if (matches == null) return null;
  final semantic = matches.candidates.where((token) => token.kind != PregoInspectionTokenKind.primitiveColor).toList();
  final candidates = semantic.isEmpty ? matches.candidates : semantic;
  return candidates.length == 1 ? candidates.single.reference : null;
}

String _shortReference(String reference) => reference.split(".").last;

String _sizeLabel(Size size) => "${_format(size.width)} × ${_format(size.height)}";

String _constraintsLabel(BoxConstraints constraints) =>
    "${_format(constraints.minWidth)}–${_bounded(constraints.maxWidth)} × "
    "${_format(constraints.minHeight)}–${_bounded(constraints.maxHeight)}";

String _bounded(double value) => value.isFinite ? _format(value) : "∞";

String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

String _colorHex(Color color) => "#${color.toARGB32().toRadixString(16).padLeft(8, "0").toUpperCase()}";

String _weightLabel(FontWeight? weight) => weight == null ? "Inherited" : weight.value.toString();

String _lineHeight(TextStyle style) => switch (style) {
  TextStyle(height: final height?, fontSize: final fontSize?) => "${_format(height * fontSize)} px",
  _ => "Inherited",
};
