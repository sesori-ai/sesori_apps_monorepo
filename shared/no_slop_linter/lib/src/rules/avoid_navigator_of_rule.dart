import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids Navigator.of(context) usage.
///
/// This project uses GoRouter with custom extensions for navigation.
/// Using Navigator.of(context) bypasses the routing system and can lead
/// to inconsistent navigation behavior.
///
/// Examples that trigger this rule:
/// - `Navigator.of(context).push(...)`
/// - `Navigator.of(context).pop()`
/// - `Navigator.of(context, rootNavigator: true).pushNamed(...)`
///
/// Valid examples:
/// - `context.pushRoute(AppRoute.xxx())` - GoRouter custom extension
/// - `context.goRoute(AppRoute.xxx())` - GoRouter custom extension
/// - `context.pop()` - GoRouter pop (works for dialogs/sheets too)
class AvoidNavigatorOfRule extends NoSlopRule {
  AvoidNavigatorOfRule()
    : super(
        name: code.lowerCaseName,
        description: 'Forbids Navigator.of(context).',
      );

  static const code = LintCode(
    'avoid_navigator_of',
    'Avoid Navigator.of(context). Use GoRouter instead.',
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
      if (node.methodName.name == 'of') {
        rule.reportAtNode(node);
      }
    }
  }
}
