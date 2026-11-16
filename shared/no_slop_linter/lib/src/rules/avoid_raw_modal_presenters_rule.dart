import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// Forbids the SDK's modal presenters outside the Prego modal helpers, which
/// pick a bottom sheet for touch and a dialog for pointer.
class AvoidRawModalPresentersRule extends NoSlopRule {
  AvoidRawModalPresentersRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids direct use of Flutter modal presenters.',
      );

  static const code = LintCode(
    'avoid_raw_modal_presenters',
    'Avoid Flutter modal presenters; they ignore the touch/pointer interaction mode.',
    correctionMessage: 'Use showPregoModal, or showPregoModalRoute for a content-driven header.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

const _presenters = {
  'showModalBottomSheet',
  'showBottomSheet',
  'showDialog',
  'showAdaptiveDialog',
  'showGeneralDialog',
  'showRawDialog',
  'showCupertinoModalPopup',
  'showCupertinoDialog',
  'showCupertinoSheet',
};

const _presenterPackages = ['package:flutter/', 'package:material_ui/', 'package:cupertino_ui/'];

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidRawModalPresentersRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (rule.isCurrentFileExcluded) return;
    if (!_presenters.contains(node.methodName.name)) return;
    final element = node.methodName.element;
    if (element is! TopLevelFunctionElement) return;
    final libraryIdentifier = element.library.identifier;
    if (_presenterPackages.any(libraryIdentifier.startsWith)) {
      rule.reportAtNode(node.methodName);
    }
  }
}
