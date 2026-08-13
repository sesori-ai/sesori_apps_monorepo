import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// Forbids Flutter SDK Material and Cupertino imports after their extraction
/// into standalone packages.
class AvoidLegacyFlutterDesignImportsRule extends NoSlopRule {
  AvoidLegacyFlutterDesignImportsRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids legacy Flutter SDK design-library imports.',
      );

  static const code = LintCode(
    'avoid_legacy_flutter_design_imports',
    'Avoid legacy Flutter SDK design-library imports.',
    correctionMessage: 'Import package:material_ui/material_ui.dart or package:cupertino_ui/cupertino_ui.dart instead.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, _Visitor(this));
  }
}

const _legacyImports = {
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidLegacyFlutterDesignImportsRule rule;

  @override
  void visitImportDirective(ImportDirective node) {
    if (rule.isCurrentFileExcluded) return;
    if (_legacyImports.contains(node.uri.stringValue)) {
      rule.reportAtNode(node.uri);
    }
  }
}
