import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
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
/// - `uri.replace(...)`, `delete(table).go()` - Not a navigation receiver
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

/// Receiver types whose navigation methods bypass the typed extensions:
/// go_router's `BuildContext` extensions, a `GoRouter`, and a `NavigatorState`
/// held directly.
const _navigationReceiverTypes = {'BuildContext', 'GoRouter', 'NavigatorState'};

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

    if (!_forbiddenMethods.contains(node.methodName.name)) return;

    // The names are navigation only on a navigation receiver. Drift's
    // `delete(table).go()`, `Uri.replace(...)` and other types' own methods
    // with these names are not.
    if (target == null || !_isNavigationReceiver(target.staticType)) return;

    rule.reportAtNode(node);
  }

  static bool _isNavigationReceiver(DartType? type) {
    if (type is! InterfaceType) return false;
    return [type, ...type.allSupertypes].any(
      (candidate) => _navigationReceiverTypes.contains(candidate.element.name),
    );
  }
}
