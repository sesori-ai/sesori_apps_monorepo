import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// Forbids Material `Icons` glyphs: the app draws every icon from Tabler.
class AvoidMaterialIconsRule extends NoSlopRule {
  AvoidMaterialIconsRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids Material Icons glyphs.',
      );

  static const code = LintCode(
    'avoid_material_icons',
    'Avoid Material Icons glyphs.',
    correctionMessage: 'Use the TablerRegular or TablerSolid equivalent.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addPrefixedIdentifier(this, visitor);
    // `material.Icons.add`, through an import prefix.
    registry.addPropertyAccess(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidMaterialIconsRule rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (rule.isCurrentFileExcluded) return;
    if (_isMaterialIcons(node.prefix.element)) rule.reportAtNode(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (rule.isCurrentFileExcluded) return;
    final target = node.target;
    if (target is PrefixedIdentifier && _isMaterialIcons(target.identifier.element)) {
      rule.reportAtNode(node);
    }
  }

  bool _isMaterialIcons(Element? element) {
    if (element is! ClassElement || element.name != 'Icons') return false;
    final library = element.library.identifier;
    return library.startsWith('package:material_ui/') || library.startsWith('package:flutter/');
  }
}
