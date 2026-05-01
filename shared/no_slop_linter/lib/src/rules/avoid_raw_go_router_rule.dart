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
  AvoidRawGoRouterRule({required super.ignoreTestFiles}) : super(
        name: code.lowerCaseName,
        description:
            'Forbids raw GoRouter navigation and direct GoRouter access.',
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

    final target = node.target;

    // Block GoRouter.of(...) and GoRouter.maybeOf(...)
    if (target is SimpleIdentifier && target.name == 'GoRouter') {
      final method = node.methodName.name;
      if (method == 'of' || method == 'maybeOf') {
        rule.reportAtNode(node);
        return;
      }
    }

    final methodName = node.methodName.name;
    if (!_forbiddenMethods.contains(methodName)) return;

    // Only flag calls with a target (e.g., context.go(...), router.push(...)).
    if (target == null) return;

    // When target is a MethodInvocation, only flag if it's a GoRouter accessor
    // (e.g. GoRouter.of(context).go(...)). Skip unrelated chains like
    // Uri.parse(...).replace(...) or String.replaceAll(...).
    if (target is MethodInvocation) {
      final targetMethod = target.methodName.name;
      if (targetMethod != 'of' && targetMethod != 'maybeOf') return;
    }

    rule.reportAtNode(node);
  }
}
