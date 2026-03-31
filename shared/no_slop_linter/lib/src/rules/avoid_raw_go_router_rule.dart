import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids raw GoRouter navigation methods.
///
/// This project provides type-safe BuildContext extensions (`goRoute`, `pushRoute`)
/// that accept [AppRoute] values and guarantee compile-time route correctness.
/// Using the raw GoRouter string-based methods bypasses these guarantees.
///
/// Examples that trigger this rule:
/// - `context.go('/some/path')`
/// - `context.push('/some/path')`
/// - `context.goNamed('routeName')`
/// - `context.pushNamed('routeName')`
/// - `context.pushReplacement('/some/path')`
/// - `context.replace('/some/path')`
///
/// Valid examples:
/// - `context.goRoute(AppRoute.xxx())` - Type-safe custom extension
/// - `context.pushRoute(AppRoute.xxx())` - Type-safe custom extension
/// - `context.pop()` - No path involved, always safe
class AvoidRawGoRouterRule extends NoSlopRule {
  AvoidRawGoRouterRule()
    : super(
        name: code.lowerCaseName,
        description: 'Forbids raw GoRouter string-based navigation methods.',
      );

  static const code = LintCode(
    'avoid_raw_go_router',
    'Avoid raw GoRouter navigation. Use typed extensions instead.',
    correctionMessage:
        'Use context.goRoute(AppRoute.xxx()) or context.pushRoute(AppRoute.xxx()).',
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

/// Raw GoRouter navigation method names that should be forbidden.
/// These accept string paths/names instead of typed route objects.
const _forbiddenMethods = {
  'go',
  'goNamed',
  'push',
  'pushNamed',
  'pushReplacement',
  'pushReplacementNamed',
  'replace',
  'replaceNamed',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidRawGoRouterRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (rule.isCurrentFileExcluded) return;

    final methodName = node.methodName.name;
    if (!_forbiddenMethods.contains(methodName)) return;

    // Only flag calls with a target (e.g., context.go(...), router.push(...)).
    // Standalone calls are not GoRouter extension methods.
    if (node.target == null) return;

    rule.reportAtNode(node);
  }
}
