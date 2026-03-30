import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids hardcoded colors.
///
/// Using hardcoded colors defeats the purpose of theming and makes it difficult
/// to maintain consistent colors across the app or support dark/light modes.
///
/// Examples that trigger this rule:
/// - `Color(0xFF000000)` - hardcoded Color constructor
/// - `Colors.red` - Material Colors constant
/// - `Colors.blue.shade500` - Material Colors shade
///
/// Valid examples:
/// - `context.colorScheme.primary`
/// - `Theme.of(context).colorScheme.surface`
/// - `colorScheme.onBackground`
class AvoidHardcodedColorsRule extends NoSlopRule {
  AvoidHardcodedColorsRule() : super(name: code.lowerCaseName, description: 'Forbids hardcoded colors.');

  static const code = LintCode(
    'avoid_hardcoded_colors',
    'Avoid hardcoded colors. Use Theme colorScheme instead.',
    correctionMessage: 'Use context.colorScheme.xxx or Theme.of(context).colorScheme.xxx',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addPrefixedIdentifier(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidHardcodedColorsRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'Color') {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.prefix.name == 'Colors') {
      rule.reportAtNode(node);
    }
  }
}
