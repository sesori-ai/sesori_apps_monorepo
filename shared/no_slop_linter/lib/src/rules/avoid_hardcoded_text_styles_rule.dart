import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids hardcoded TextStyle.
///
/// Using hardcoded TextStyle defeats the purpose of theming and makes it
/// difficult to maintain consistent typography across the app.
///
/// Examples that trigger this rule:
/// - `TextStyle(fontSize: 16)` - hardcoded TextStyle
/// - `TextStyle(fontWeight: FontWeight.bold, color: Colors.black)`
///
/// Valid examples:
/// - `context.textTheme.bodyLarge`
/// - `Theme.of(context).textTheme.headlineMedium`
/// - `textTheme.titleSmall?.copyWith(color: colorScheme.primary)` - extending theme style
/// - `defaultStyle.merge(TextStyle(fontWeight: FontWeight.bold))` - merging styles
class AvoidHardcodedTextStylesRule extends NoSlopRule {
  AvoidHardcodedTextStylesRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Forbids hardcoded TextStyle.');

  static const code = LintCode(
    'avoid_hardcoded_text_styles',
    'Avoid hardcoded TextStyle. Use Theme textTheme instead.',
    correctionMessage: 'Use context.textTheme.xxx or Theme.of(context).textTheme.xxx',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }

  /// Check if this TextStyle is being used to extend a theme style via copyWith/merge
  bool _isExtendingThemeStyle(InstanceCreationExpression node) {
    final parent = node.parent;

    if (parent is ArgumentList) {
      final grandparent = parent.parent;
      if (grandparent is MethodInvocation) {
        final methodName = grandparent.methodName.name;
        if (methodName == 'copyWith' || methodName == 'merge') {
          return true;
        }
      }
    }

    return false;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidHardcodedTextStylesRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'TextStyle') {
      if (!rule._isExtendingThemeStyle(node)) {
        rule.reportAtNode(node);
      }
    }
  }
}
