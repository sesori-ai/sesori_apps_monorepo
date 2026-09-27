import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// The attached [TranscriptPromptSlot]s by opener id. Each slot keeps itself
/// in here; the owner only says which bubbles a pin stands in for.
class TranscriptPromptSlots() {
  final Map<String, RenderTranscriptPromptSlot> _slots = {};

  /// Hides the bubbles of [openerIds] and shows every other.
  void hideOnly({required Set<String> openerIds}) {
    for (final MapEntry(key: openerId, value: slot) in _slots.entries) {
      slot._hide(value: openerIds.contains(openerId));
    }
  }
}

/// Wraps a prompt turn's opener bubble in the transcript, so the pinned
/// prompts can stop it painting while a pin stands in for it.
class const TranscriptPromptSlot({
  super.key,
  required final String openerId,
  required final TranscriptPromptSlots registry,
  required super.child,
}) extends SingleChildRenderObjectWidget {
  @override
  RenderTranscriptPromptSlot createRenderObject(BuildContext context) =>
      RenderTranscriptPromptSlot(openerId: openerId, registry: registry);

  @override
  void updateRenderObject(BuildContext context, RenderTranscriptPromptSlot renderObject) {
    renderObject.openerId = openerId;
  }
}

class RenderTranscriptPromptSlot({
  required String openerId,
  required final TranscriptPromptSlots registry,
}) extends RenderProxyBox {
  String _openerId = openerId;
  String get openerId => _openerId;
  set openerId(String value) {
    if (value == _openerId) return;
    _unregister();
    _openerId = value;
    if (attached) registry._slots[value] = this;
  }

  bool _hidden = false;
  bool get hidden => _hidden;
  void _hide({required bool value}) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    registry._slots[_openerId] = this;
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  void _unregister() {
    if (identical(registry._slots[_openerId], this)) registry._slots.remove(_openerId);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  /// The pin stands in for a hidden bubble with the reader too.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_hidden) super.visitChildrenForSemantics(visitor);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !_hidden && super.hitTest(result, position: position);
}
