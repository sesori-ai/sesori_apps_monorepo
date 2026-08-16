// Catalog-only developer tooling is intentionally English and does not ship in product surfaces.
// ignore_for_file: no_slop_linter/avoid_string_literals_in_widgets

import "dart:math" as math;

import "package:flutter/services.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/module_prego.dart";

import "../cubits/prego_annotation_cubit.dart";
import "../models/prego_annotation.dart";
import "../repositories/prego_annotation_repository.dart";
import "prego_review_action.dart";
import "prego_review_target.dart";

const _annotationPinDiameter = 28.0;
const _annotationPinOffset = 20.0;

@visibleForTesting
Rect layoutPregoAnnotationPin({required Offset anchor, required Size canvasSize}) {
  final candidates = [
    const Offset(_annotationPinOffset, -_annotationPinOffset),
    const Offset(-_annotationPinOffset, -_annotationPinOffset),
    const Offset(_annotationPinOffset, _annotationPinOffset),
    const Offset(-_annotationPinOffset, _annotationPinOffset),
  ].map((offset) => _clampPinCenter(center: anchor + offset, canvasSize: canvasSize));
  final center = candidates.reduce(
    (best, candidate) => (candidate - anchor).distanceSquared > (best - anchor).distanceSquared ? candidate : best,
  );
  return Rect.fromCenter(center: center, width: _annotationPinDiameter, height: _annotationPinDiameter);
}

Offset _clampPinCenter({required Offset center, required Size canvasSize}) {
  const radius = _annotationPinDiameter / 2;
  return Offset(
    _clampPinAxis(value: center.dx, extent: canvasSize.width, radius: radius),
    _clampPinAxis(value: center.dy, extent: canvasSize.height, radius: radius),
  );
}

double _clampPinAxis({required double value, required double extent, required double radius}) =>
    extent <= radius * 2 ? extent / 2 : value.clamp(radius, extent - radius).toDouble();

class const PregoAnnotationLayer({
  required final Widget child,
  required final PregoAnnotationScope scope,
  required final PregoAnnotationRepository repository,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PregoAnnotationCubit(repository: repository, scope: scope),
    child: _AnnotationCanvas(child: child),
  );
}

class const _AnnotationCanvas({required final Widget child}) extends StatefulWidget {
  @override
  State<_AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState() extends State<_AnnotationCanvas> {
  static const _targetResolver = PregoReviewTargetResolver();

  final _rootKey = GlobalKey();
  final _contentKey = GlobalKey();
  var _showList = false;
  String? _copyStatus;
  Map<String, Offset> _pinAnchors = const {};
  bool _pinRefreshScheduled = false;

  @override
  Widget build(BuildContext context) => BlocBuilder<PregoAnnotationCubit, PregoAnnotationState>(
    builder: (context, state) => LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = math.min(300.0, math.max(220.0, constraints.maxWidth - 24));
        final editorState = switch (state) {
          final PregoAnnotationReadyState ready => ready.editor is PregoAnnotationEditorClosed ? null : ready,
          PregoAnnotationLoading() || PregoAnnotationLoadFailed() => null,
        };
        final importEditor = _importFor(state);
        if (state case final PregoAnnotationReadyState ready) {
          _schedulePinRefresh(document: ready.document);
        }
        return Stack(
          key: _rootKey,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _onCanvasTapUp,
                child: AbsorbPointer(
                  child: KeyedSubtree(key: _contentKey, child: widget.child),
                ),
              ),
            ),
            if (state case final PregoAnnotationReadyState ready)
              ..._buildPins(context: context, document: ready.document),
            if (editorState == null && importEditor == null)
              PositionedDirectional(
                top: 12,
                start: 12,
                width: panelWidth,
                child: _buildToolsPanel(context: context, state: state),
              ),
            if (editorState case final ready?)
              PositionedDirectional(
                top: 12,
                end: 12,
                width: panelWidth,
                child: _AnnotationEditorPanel(editor: ready.editor, state: ready),
              ),
            if (importEditor != null)
              PositionedDirectional(
                top: 12,
                end: 12,
                width: panelWidth,
                child: _AnnotationImportPanel(importEditor: importEditor),
              ),
          ],
        );
      },
    ),
  );

  List<Widget> _buildPins({required BuildContext context, required PregoAnnotationDocument document}) {
    final root = _rootKey.currentContext?.findRenderObject();
    final content = _contentKey.currentContext?.findRenderObject();
    if (root is! RenderBox || content == null) return const [];
    return [
      for (var index = 0; index < document.annotations.length; index += 1)
        ..._buildPin(
          context: context,
          annotation: document.annotations[index],
          number: index + 1,
          root: root,
          content: content,
        ),
    ];
  }

  List<Widget> _buildPin({
    required BuildContext context,
    required PregoAnnotation annotation,
    required int number,
    required RenderBox root,
    required RenderObject content,
  }) {
    final anchor = _pinAnchors[annotation.id] ?? _positionFor(annotation: annotation, root: root, content: content);
    final pinRect = layoutPregoAnnotationPin(anchor: anchor, canvasSize: root.size);
    final colors = context.prego.colors;
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey("prego-annotation-leader-${annotation.id}"),
            painter: PregoAnnotationPinLeaderPainter(
              anchor: anchor,
              pinCenter: pinRect.center,
              lineColor: colors.borderBrand,
              anchorColor: colors.bgBrandPrimary,
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: pinRect,
        child: _AnnotationPin(
          annotation: annotation,
          number: number,
          onTap: () => context.read<PregoAnnotationCubit>().edit(annotationId: annotation.id),
        ),
      ),
    ];
  }

  Widget _buildToolsPanel({required BuildContext context, required PregoAnnotationState state}) {
    final cubit = context.read<PregoAnnotationCubit>();
    return switch (state) {
      PregoAnnotationLoading() => const _ReviewPanel(child: Text("Loading local annotations…")),
      PregoAnnotationLoadFailed(:final message) => _ReviewPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Annotations could not be loaded"),
            const SizedBox(height: 4),
            Text(message),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PregoReviewAction(label: "Retry", text: "Retry", onPressed: cubit.load),
                PregoReviewAction(
                  label: "Import replacement",
                  text: "Import replacement",
                  onPressed: cubit.startImport,
                ),
              ],
            ),
          ],
        ),
      ),
      final PregoAnnotationReadyState ready => _ReviewPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_annotationSummary(ready.document.annotations)),
            const SizedBox(height: 4),
            Text("Click the canvas to add a note", style: context.prego.textTheme.textXs.regular),
            if (ready case PregoAnnotationSaveFailed(:final message)) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: context.prego.textTheme.textXs.medium.copyWith(color: context.prego.colors.textErrorPrimary),
              ),
            ],
            if (_copyStatus case final copyStatus?) ...[
              const SizedBox(height: 6),
              Text(copyStatus, style: context.prego.textTheme.textXs.medium),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PregoReviewAction(
                  label: _showList ? "Hide list" : "Show list",
                  text: _showList ? "Hide list" : "Show list",
                  onPressed: () => setState(() => _showList = !_showList),
                ),
                PregoReviewAction(label: "Copy JSON", text: "Copy JSON", onPressed: _copyJson),
                PregoReviewAction(label: "Import JSON", text: "Import JSON", onPressed: cubit.startImport),
              ],
            ),
            if (_showList) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < ready.document.annotations.length; index += 1)
                        _AnnotationListRow(
                          annotation: ready.document.annotations[index],
                          number: index + 1,
                          onTap: () => cubit.edit(annotationId: ready.document.annotations[index].id),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    };
  }

  void _onCanvasTapUp(TapUpDetails details) {
    final cubit = context.read<PregoAnnotationCubit>();
    final state = cubit.state;
    if (state is! PregoAnnotationReadyState ||
        state is PregoAnnotationImporting ||
        state.editor is! PregoAnnotationEditorClosed) {
      return;
    }
    final root = _rootKey.currentContext?.findRenderObject();
    final content = _contentKey.currentContext?.findRenderObject();
    if (root is! RenderBox || content == null) return;
    final local = root.globalToLocal(details.globalPosition);
    final normalizedX = (local.dx / root.size.width).clamp(0.0, 1.0).toDouble();
    final normalizedY = (local.dy / root.size.height).clamp(0.0, 1.0).toDouble();
    final target = _targetResolver.findAt(contentRoot: content, globalPosition: details.globalPosition).firstOrNull;
    final anchor = target == null
        ? PregoCanvasAnnotationAnchor(normalizedX: normalizedX, normalizedY: normalizedY)
        : _elementAnchor(
            target: target,
            root: root,
            localPosition: local,
            fallbackX: normalizedX,
            fallbackY: normalizedY,
          );
    cubit.startDraft(anchor: anchor);
  }

  void _schedulePinRefresh({required PregoAnnotationDocument document}) {
    if (_pinRefreshScheduled) return;
    _pinRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinRefreshScheduled = false;
      if (!mounted) return;
      final state = context.read<PregoAnnotationCubit>().state;
      if (state is! PregoAnnotationReadyState || !identical(state.document, document)) return;
      final root = _rootKey.currentContext?.findRenderObject();
      final content = _contentKey.currentContext?.findRenderObject();
      if (root is! RenderBox || content == null) return;
      final anchors = {
        for (final annotation in document.annotations)
          annotation.id: _positionFor(annotation: annotation, root: root, content: content),
      };
      if (_sameAnchors(_pinAnchors, anchors)) return;
      setState(() => _pinAnchors = anchors);
    });
  }

  PregoElementAnnotationAnchor _elementAnchor({
    required PregoReviewTarget target,
    required RenderBox root,
    required Offset localPosition,
    required double fallbackX,
    required double fallbackY,
  }) {
    final rect = target.rectIn(root: root);
    return PregoElementAnnotationAnchor(
      targetPath: target.path,
      relativeX: ((localPosition.dx - rect.left) / rect.width).clamp(0.0, 1.0).toDouble(),
      relativeY: ((localPosition.dy - rect.top) / rect.height).clamp(0.0, 1.0).toDouble(),
      fallbackX: fallbackX,
      fallbackY: fallbackY,
    );
  }

  Offset _positionFor({
    required PregoAnnotation annotation,
    required RenderBox root,
    required RenderObject content,
  }) {
    switch (annotation.anchor) {
      case PregoCanvasAnnotationAnchor(:final normalizedX, :final normalizedY):
        return Offset(normalizedX * root.size.width, normalizedY * root.size.height);
      case PregoElementAnnotationAnchor(
        :final targetPath,
        :final relativeX,
        :final relativeY,
        :final fallbackX,
        :final fallbackY,
      ):
        final target = _targetResolver.resolvePath(contentRoot: content, path: targetPath);
        if (target == null) {
          return Offset(fallbackX * root.size.width, fallbackY * root.size.height);
        }
        final rect = target.rectIn(root: root);
        return Offset(
          rect.left + rect.width * relativeX,
          rect.top + rect.height * relativeY,
        );
    }
  }

  Future<void> _copyJson() async {
    final encoded = context.read<PregoAnnotationCubit>().exportJson();
    if (encoded == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: encoded));
      if (!mounted) return;
      setState(() => _copyStatus = "Copied local annotation JSON.");
    } on Object {
      if (!mounted) return;
      setState(() => _copyStatus = "Clipboard access failed. Try again from this browser tab.");
    }
  }
}

bool _sameAnchors(Map<String, Offset> first, Map<String, Offset> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}

PregoAnnotationImportEditor? _importFor(PregoAnnotationState state) => switch (state) {
  PregoAnnotationImporting(:final importEditor) => importEditor,
  PregoAnnotationLoadFailed(:final importEditor) => importEditor,
  PregoAnnotationLoading() || PregoAnnotationReady() || PregoAnnotationSaveFailed() => null,
};

class const _AnnotationPin({
  required final PregoAnnotation annotation,
  required final int number,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return Semantics(
      button: true,
      label: "Annotation $number${annotation.resolved ? ", resolved" : ""}",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: annotation.resolved ? 0.5 : 1,
          child: Container(
            key: ValueKey("prego-annotation-pin-${annotation.id}"),
            width: _annotationPinDiameter,
            height: _annotationPinDiameter,
            decoration: BoxDecoration(
              color: colors.bgBrandPrimary,
              border: Border.all(color: colors.borderPrimary, width: 2),
              shape: BoxShape.circle,
              boxShadow: context.prego.shadows.sm,
            ),
            alignment: Alignment.center,
            child: Text(
              "$number",
              style: context.prego.textTheme.textXs.bold.copyWith(color: colors.textPrimaryOnBrand),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
final class PregoAnnotationPinLeaderPainter({
  required final Offset anchor,
  required final Offset pinCenter,
  required final Color lineColor,
  required final Color anchorColor,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final delta = anchor - pinCenter;
    final distance = delta.distance;
    final pinEdge = distance <= _annotationPinDiameter / 2
        ? pinCenter
        : pinCenter + delta / distance * (_annotationPinDiameter / 2);
    canvas
      ..drawLine(
        anchor,
        pinEdge,
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      )
      ..drawCircle(anchor, 2.5, Paint()..color = anchorColor);
  }

  @override
  bool shouldRepaint(PregoAnnotationPinLeaderPainter oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.pinCenter != pinCenter ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.anchorColor != anchorColor;
}

class const _AnnotationEditorPanel({
  required final PregoAnnotationEditor editor,
  required final PregoAnnotationReadyState state,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PregoAnnotationCubit>();
    final body = switch (editor) {
      PregoAnnotationDraftEditor(:final body) || PregoAnnotationExistingEditor(:final body) => body,
      PregoAnnotationEditorClosed() => "",
    };
    final validationError = switch (editor) {
      PregoAnnotationDraftEditor(:final validationError) ||
      PregoAnnotationExistingEditor(:final validationError) => validationError,
      PregoAnnotationEditorClosed() => null,
    };
    final existingId = switch (editor) {
      PregoAnnotationExistingEditor(:final annotationId) => annotationId,
      PregoAnnotationDraftEditor() || PregoAnnotationEditorClosed() => null,
    };
    final existing = existingId == null
        ? null
        : state.document.annotations.where((annotation) => annotation.id == existingId).firstOrNull;
    return _ReviewPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(existing == null ? "New annotation" : "Edit annotation"),
          const SizedBox(height: 8),
          material.TextFormField(
            key: ValueKey(existingId ?? "draft"),
            initialValue: body,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            onChanged: (value) => cubit.updateEditorBody(body: value),
            decoration: material.InputDecoration(
              hintText: "What should be reviewed?",
              errorText: validationError,
            ),
          ),
          if (state case PregoAnnotationSaveFailed(:final message)) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: context.prego.textTheme.textXs.medium.copyWith(
                color: context.prego.colors.textErrorPrimary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PregoReviewAction(label: "Cancel", text: "Cancel", onPressed: cubit.closeEditor),
              PregoReviewAction(label: "Save", text: "Save", onPressed: cubit.saveEditor),
              if (existing != null) ...[
                PregoReviewAction(
                  label: existing.resolved ? "Reopen" : "Resolve",
                  text: existing.resolved ? "Reopen" : "Resolve",
                  onPressed: () => cubit.toggleResolved(annotationId: existing.id),
                ),
                PregoReviewAction(
                  label: "Delete",
                  text: "Delete",
                  onPressed: () => cubit.delete(annotationId: existing.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class const _AnnotationImportPanel({required final PregoAnnotationImportEditor importEditor}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PregoAnnotationCubit>();
    final replacementError = switch (importEditor) {
      PregoAnnotationImportReplaceFailed(:final message) => message,
      PregoAnnotationImportInput() || PregoAnnotationImportPreview() => null,
    };
    return _ReviewPanel(
      child: switch (importEditor) {
        PregoAnnotationImportInput(:final encoded, :final validationError) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Import annotation JSON"),
            const SizedBox(height: 4),
            const Text("Paste an export for this exact component and viewport."),
            const SizedBox(height: 8),
            material.TextFormField(
              initialValue: encoded,
              autofocus: true,
              minLines: 5,
              maxLines: 9,
              onChanged: (value) => cubit.updateImportJson(encoded: value),
              decoration: material.InputDecoration(hintText: "Paste JSON", errorText: validationError),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                PregoReviewAction(label: "Cancel", text: "Cancel", onPressed: cubit.cancelImport),
                PregoReviewAction(label: "Validate", text: "Validate", onPressed: cubit.validateImport),
              ],
            ),
          ],
        ),
        PregoAnnotationImportPreview(:final encoded, :final document) ||
        PregoAnnotationImportReplaceFailed(:final encoded, :final document) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Replace local annotations?"),
            const SizedBox(height: 4),
            Text("Validated ${document.annotations.length} annotations for this canvas."),
            if (replacementError != null) ...[
              const SizedBox(height: 6),
              Text(
                replacementError,
                style: context.prego.textTheme.textXs.medium.copyWith(
                  color: context.prego.colors.textErrorPrimary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PregoReviewAction(label: "Cancel", text: "Cancel", onPressed: cubit.cancelImport),
                PregoReviewAction(
                  label: "Edit JSON",
                  text: "Edit JSON",
                  onPressed: () => cubit.updateImportJson(encoded: encoded),
                ),
                PregoReviewAction(label: "Replace", text: "Replace", onPressed: cubit.replaceImport),
              ],
            ),
          ],
        ),
      },
    );
  }
}

class const _AnnotationListRow({
  required final PregoAnnotation annotation,
  required final int number,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, child: Text("$number")),
            Expanded(
              child: Text(
                annotation.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: annotation.resolved
                    ? context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textTertiary)
                    : context.prego.textTheme.textXs.medium,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class const _ReviewPanel({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface1,
        border: Border.all(color: colors.borderSecondary),
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        boxShadow: context.prego.shadows.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: context.prego.textTheme.textXs.medium.copyWith(color: colors.textPrimary),
          child: child,
        ),
      ),
    );
  }
}

String _annotationSummary(List<PregoAnnotation> annotations) {
  final open = annotations.where((annotation) => !annotation.resolved).length;
  return "Annotations · $open open · ${annotations.length} total";
}
