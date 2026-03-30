import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that detects implicit toString() calls in string interpolation.
///
/// When a non-String value is used in string interpolation (e.g., `"value: $obj"`),
/// Dart implicitly calls toString() on that value. This can lead to:
/// - Unexpected output if toString() is not properly overridden
/// - Less explicit code that hides the conversion
///
/// Allowed types (predictable toString()):
/// - String, int, double, bool
///
/// Instead, prefer explicit conversion for other types:
/// - `"value: ${obj.toString()}"` - explicit toString()
/// - `"value: ${obj.toStringShort()}"` - custom formatting method
class AvoidImplicitTostringRule extends NoSlopRule {
  AvoidImplicitTostringRule()
      : super(name: code.lowerCaseName, description: 'Detects implicit toString() calls in string interpolation.');

  static const code = LintCode(
    'avoid_implicit_tostring',
    'Implicit toString() call in string interpolation. '
        'The interpolated value is not a String.',
    correctionMessage: 'Call .toString() explicitly or use a formatting method.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInterpolationExpression(this, _Visitor(this));
  }

  bool _isExplicitToStringCall(Expression expression) {
    if (expression is MethodInvocation) {
      return expression.methodName.name == 'toString';
    }
    return false;
  }

  bool _isInsideLoggingCall(InterpolationExpression node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final name = current.methodName.name;
        if (name == 'logt' || name == 'logd') {
          return true;
        }
      }
      if (current is FunctionExpressionInvocation) {
        final function = current.function;
        if (function is Identifier) {
          final name = function.name;
          if (name == 'logt' || name == 'logd') {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidImplicitTostringRule rule;

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final expression = node.expression;
    final staticType = expression.staticType;

    if (staticType == null) return;
    if (staticType.isDartCoreString) return;
    if (staticType.isDartCoreInt || staticType.isDartCoreDouble || staticType.isDartCoreBool) return;
    if (staticType is DynamicType) return;
    if (rule._isExplicitToStringCall(expression)) return;
    if (rule._isInsideLoggingCall(node)) return;

    rule.reportAtNode(expression);
  }
}
