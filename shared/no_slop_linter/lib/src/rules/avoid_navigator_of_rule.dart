import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids direct Navigator usage.
///
/// This project uses GoRouter with custom extensions for navigation.
/// Using Navigator directly bypasses the routing system.
///
/// Examples that trigger this rule:
/// - `Navigator.of(context).push(...)`
/// - `Navigator.of(context).pop()`
/// - `Navigator.pop(context)`
/// - `Navigator.push(context, route)`
///
/// Valid examples:
/// - `context.pushRoute(AppRoute.xxx())` - GoRouter custom extension
/// - `context.goRoute(AppRoute.xxx())` - GoRouter custom extension
/// - `context.pop()` - GoRouter pop (works for dialogs/sheets too)
class AvoidNavigatorOfRule extends NoSlopRule {
  AvoidNavigatorOfRule({required super.ignoreTestFiles}) : super(
        name: code.lowerCaseName,
        description: 'Forbids direct Navigator usage.',
      );

  static const code = LintCode(
    'avoid_navigator_of',
    'Avoid direct Navigator usage. Use GoRouter instead.',
    correctionMessage:
        'Use context.pushRoute/goRoute/pop() from GoRouter extensions.',
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

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidNavigatorOfRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (rule.isCurrentFileExcluded) return;
    final target = node.target;
    if (target is SimpleIdentifier && target.name == 'Navigator') {
      rule.reportAtNode(node);
    }
  }
}
