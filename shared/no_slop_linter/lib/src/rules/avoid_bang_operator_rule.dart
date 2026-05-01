import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that detects usage of the bang operator (`!`).
///
/// The bang operator (null assertion operator) is considered a code smell
/// because it can lead to runtime exceptions if the value is null.
/// Instead, prefer using null-safe alternatives like:
/// - Null checks with `if` statements
/// - The null-aware operator `?.`
/// - The `??` operator for default values
/// - Pattern matching with `case` statements
class AvoidBangOperatorRule extends NoSlopRule {
  AvoidBangOperatorRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Detects usage of the bang operator.');

  static const code = LintCode(
    'avoid_bang_operator',
    "Avoid using the bang operator ('!'). "
        'Use null-safe alternatives like null checks, '
        "the '?.' operator, or the '??' operator instead.",
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addPostfixExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidBangOperatorRule rule;

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.operator.type == TokenType.BANG) {
      rule.reportAtToken(node.operator);
    }
  }
}
