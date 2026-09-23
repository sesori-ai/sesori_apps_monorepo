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
    registry.addPrefixedIdentifier(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidMaterialIconsRule rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (rule.isCurrentFileExcluded) return;
    final prefix = node.prefix.element;
    if (prefix is! ClassElement || prefix.name != 'Icons') return;
    final library = prefix.library.identifier;
    if (library.startsWith('package:material_ui/') || library.startsWith('package:flutter/')) {
      rule.reportAtNode(node);
    }
  }
}
