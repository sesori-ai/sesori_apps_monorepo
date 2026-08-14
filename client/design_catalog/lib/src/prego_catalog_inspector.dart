// ignore_for_file: deprecated_member_use, no_slop_linter/avoid_as_cast, no_slop_linter/avoid_bang_operator, no_slop_linter/avoid_string_literals_in_widgets, no_slop_linter/prefer_edge_insets_directional, no_slop_linter/prefer_required_named_parameters, unnecessary_type_name_in_constructor, use_declaring_parameters, use_if_null_to_convert_nulls_to_bools, use_primary_constructors

import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

import "inspector/prego_inspection_tokens.dart";

final class PregoCatalogInspectorAddon() extends WidgetbookAddon<bool> {
  this : super(name: "Inspector");

  @override
  List<Field<bool>> get fields => [BooleanField(name: "isEnabled", initialValue: false)];

  @override
  bool valueFromQueryGroup(Map<String, String> group) => valueOf<bool>("isEnabled", group) ?? false;

  @override
  Widget buildUseCase(BuildContext context, Widget child, bool setting) =>
      setting ? PregoCatalogInspector(child: child) : child;
}

typedef PregoInspectorCopyText = Future<void> Function(String text);

class const PregoCatalogInspector({
  required this.child,
  this.copyText,
  super.key,
}) extends StatefulWidget {
  final Widget child;
  final PregoInspectorCopyText? copyText;

  @override
  State<PregoCatalogInspector> createState() => _PregoCatalogInspectorState();
}

class _PregoCatalogInspectorState extends State<PregoCatalogInspector> {
  final _rootKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _focusNode = FocusNode(debugLabel: "Prego catalog inspector");

  List<_InspectionCandidate> _hoverCandidates = const [];
  List<_InspectionCandidate> _pinnedCandidates = const [];
  int _pinnedIndex = 0;
  Offset _pointerPosition = Offset.zero;
  String? _copiedReference;

  bool get _hasPinnedSelection => _pinnedCandidates.isNotEmpty;
  _InspectionCandidate? get _hovered => _hoverCandidates.firstOrNull;
  _InspectionCandidate? get _pinned => _hasPinnedSelection ? _pinnedCandidates[_pinnedIndex] : null;
  _InspectionCandidate? get _active => _pinned ?? _hovered;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final active = _active;
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final activeRect = active == null || root == null ? null : _rectFor(candidate: active, root: root);

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
    required _InspectionCandidate candidate,
    required Rect targetRect,
  }) {
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null) return const SizedBox.shrink();

    final details = _InspectionDetails.from(
      candidate: candidate,
      candidates: _hasPinnedSelection ? _pinnedCandidates : _hoverCandidates,
      root: root,
      resolver: PregoInspectionTokenResolver(context: context),
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
      child: _InspectorCard(
        key: const Key("prego-inspector-card"),
        details: details,
        expanded: _hasPinnedSelection,
        position: _pinnedIndex,
        candidateCount: _hasPinnedSelection ? _pinnedCandidates.length : _hoverCandidates.length,
        copiedReference: _copiedReference,
        onPrevious: _hasPinnedSelection ? () => _cycle(by: -1) : null,
        onNext: _hasPinnedSelection ? () => _cycle(by: 1) : null,
        onClear: _hasPinnedSelection ? _clearPinned : null,
        onCopy: _hasPinnedSelection ? _copy : null,
      ),
    );
  }

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
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onHover(PointerHoverEvent event) {
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null) return;
    final candidates = _findCandidates(globalPosition: event.position);
    final localPosition = root.globalToLocal(event.position);
    if (_sameCandidates(_hoverCandidates, candidates) && _pointerPosition == localPosition) return;
    setState(() {
      _hoverCandidates = candidates;
      _pointerPosition = localPosition;
      _copiedReference = null;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _focusNode.requestFocus();
    final candidates = _findCandidates(globalPosition: event.position);
    if (candidates.isEmpty) return;
    setState(() {
      if (_sameCandidates(_pinnedCandidates, candidates)) {
        _pinnedIndex = (_pinnedIndex + 1) % candidates.length;
      } else {
        _pinnedCandidates = candidates;
        _pinnedIndex = 0;
      }
      _hoverCandidates = candidates;
      _copiedReference = null;
    });
  }

  void _cycle({required int by}) {
    if (!_hasPinnedSelection) return;
    setState(() {
      _pinnedIndex = (_pinnedIndex + by) % _pinnedCandidates.length;
      _copiedReference = null;
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
    if (widget.copyText case final copyText?) {
      await copyText(value);
    } else {
      await Clipboard.setData(ClipboardData(text: value));
    }
    if (!mounted) return;
    setState(() => _copiedReference = value);
  }

  List<_InspectionCandidate> _findCandidates({required Offset globalPosition}) {
    final content = _contentKey.currentContext?.findRenderObject();
    if (content == null) return const [];
    final candidates = <_InspectionCandidate>[];

    void visit(RenderObject object, int depth) {
      if (object case final RenderBox box when box.attached && box.hasSize && !box.size.isEmpty) {
        final label = _labelFor(box);
        if (label != null && _containsGlobalPosition(box: box, globalPosition: globalPosition)) {
          candidates.add(_InspectionCandidate(renderBox: box, label: label, depth: depth));
        }
      }
      object.visitChildren((child) => visit(child, depth + 1));
    }

    visit(content, 0);
    candidates.sort((first, second) {
      final area = (first.renderBox.size.width * first.renderBox.size.height).compareTo(
        second.renderBox.size.width * second.renderBox.size.height,
      );
      if (area != 0) return area;
      return second.depth.compareTo(first.depth);
    });
    return candidates;
  }
}

final class const _InspectionCandidate({
  required this.renderBox,
  required this.label,
  required this.depth,
}) {
  final RenderBox renderBox;
  final String label;
  final int depth;
}

final class const _InspectionDetails({
  required this.label,
  required this.logicalSize,
  required this.renderedSize,
  required this.constraints,
  required this.textStyle,
  required this.textTokens,
  required this.textColor,
  required this.textColorTokens,
  required this.backgroundColor,
  required this.backgroundColorTokens,
  required this.padding,
  required this.paddingTokens,
  required this.radius,
  required this.radiusTokens,
  required this.semanticLabel,
  required this.semanticRole,
  required this.isInteractive,
  required this.contrastRatio,
}) {
  factory _InspectionDetails.from({
    required _InspectionCandidate candidate,
    required List<_InspectionCandidate> candidates,
    required RenderBox root,
    required PregoInspectionTokenResolver resolver,
    required TextDirection textDirection,
  }) {
    final box = candidate.renderBox;
    final rect = _rectFor(candidate: candidate, root: root);
    final style = box is RenderParagraph ? _firstTextStyle(box.text) : null;
    final decoration = box is RenderDecoratedBox && box.decoration is BoxDecoration
        ? box.decoration as BoxDecoration
        : null;
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
      isInteractive: semantics?.button == true || semantics?.onTap != null || box is RenderSemanticsGestureHandler,
      contrastRatio: textColor == null || background == null ? null : _contrast(textColor, background),
    );
  }

  final String label;
  final Size logicalSize;
  final Size renderedSize;
  final BoxConstraints constraints;
  final TextStyle? textStyle;
  final PregoInspectionTokenMatches<TextStyle>? textTokens;
  final Color? textColor;
  final PregoInspectionTokenMatches<Color>? textColorTokens;
  final Color? backgroundColor;
  final PregoInspectionTokenMatches<Color>? backgroundColorTokens;
  final EdgeInsets? padding;
  final List<PregoInspectionTokenMatches<double>> paddingTokens;
  final List<double>? radius;
  final List<PregoInspectionTokenMatches<double>> radiusTokens;
  final String? semanticLabel;
  final SemanticsRole? semanticRole;
  final bool isInteractive;
  final double? contrastRatio;
}

class const _InspectorCard({
  required this.details,
  required this.expanded,
  required this.position,
  required this.candidateCount,
  required this.copiedReference,
  required this.onPrevious,
  required this.onNext,
  required this.onClear,
  required this.onCopy,
  super.key,
}) extends StatelessWidget {
  final _InspectionDetails details;
  final bool expanded;
  final int position;
  final int candidateCount;
  final String? copiedReference;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onClear;
  final ValueChanged<String>? onCopy;

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
                    child: SingleChildScrollView(child: _buildExpanded(context, primaryText, secondaryText)),
                  )
                : _buildSummary(primaryText, secondaryText),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(TextStyle primaryText, TextStyle secondaryText) => Column(
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

  Widget _buildExpanded(BuildContext context, TextStyle primaryText, TextStyle secondaryText) {
    final copyValue = _primaryReference(details);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(details.label, style: primaryText)),
            _InspectorButton(label: "Previous target", text: "‹", onTap: onPrevious),
            const SizedBox(width: 4),
            Text("${position + 1}/$candidateCount", key: const Key("prego-inspector-position"), style: secondaryText),
            const SizedBox(width: 4),
            _InspectorButton(label: "Next target", text: "›", onTap: onNext),
            const SizedBox(width: 4),
            _InspectorButton(label: "Close inspector details", text: "×", onTap: onClear),
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
          _InspectorButton(
            label: "Copy PREGO token reference",
            text: copiedReference == copyValue ? "Copied" : "Copy ${_shortReference(copyValue)}",
            onTap: onCopy == null ? null : () => onCopy!(copyValue),
            wide: true,
          ),
        ],
      ],
    );
  }
}

class const _Section({required this.title, required this.rows}) extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

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
            padding: const EdgeInsets.only(top: 3),
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

class const _InspectorButton({
  required this.label,
  required this.text,
  required this.onTap,
  this.wide = false,
}) extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface2,
          border: Border.all(color: colors.borderSecondary),
          borderRadius: BorderRadius.circular(PregoRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: wide ? SizedBox(width: double.infinity, child: child) : child,
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

String? _labelFor(RenderBox box) => switch (box) {
  RenderParagraph() => "Text",
  RenderSemanticsAnnotations() => "Semantic element",
  RenderSemanticsGestureHandler() => "Interactive element",
  RenderDecoratedBox() => "Decoration",
  RenderPadding() => "Padding",
  RenderConstrainedBox() => "Constraints",
  RenderFlex(:final direction) => direction == Axis.horizontal ? "Row" : "Column",
  RenderOpacity() => "Opacity",
  RenderClipRRect() => "Rounded clip",
  RenderPhysicalModel() => "Physical surface",
  _ => null,
};

Rect _rectFor({required _InspectionCandidate candidate, required RenderBox root}) => MatrixUtils.transformRect(
  candidate.renderBox.getTransformTo(root),
  Offset.zero & candidate.renderBox.size,
);

bool _sameCandidates(List<_InspectionCandidate> first, List<_InspectionCandidate> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index += 1) {
    if (!identical(first[index].renderBox, second[index].renderBox)) return false;
  }
  return true;
}

TextStyle? _firstTextStyle(InlineSpan span) {
  if (span.style case final style?) return style;
  if (span is TextSpan && span.children != null) {
    for (final child in span.children!) {
      if (_firstTextStyle(child) case final style?) return style;
    }
  }
  return null;
}

Color? _nearestBackground({
  required _InspectionCandidate candidate,
  required List<_InspectionCandidate> candidates,
}) {
  final target = candidate.renderBox;
  final decorated = candidates
      .where((item) => item.renderBox is RenderDecoratedBox && item.renderBox.size >= target.size)
      .cast<_InspectionCandidate>();
  for (final item in decorated) {
    final decoration = (item.renderBox as RenderDecoratedBox).decoration;
    if (decoration is BoxDecoration && decoration.color != null) return decoration.color;
  }
  return null;
}

double _contrast(Color first, Color second) {
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

String _weightLabel(FontWeight? weight) => weight == null ? "Inherited" : ((weight.index + 1) * 100).toString();

String _lineHeight(TextStyle style) {
  if (style.height == null || style.fontSize == null) return "Inherited";
  return "${_format(style.height! * style.fontSize!)} px";
}
