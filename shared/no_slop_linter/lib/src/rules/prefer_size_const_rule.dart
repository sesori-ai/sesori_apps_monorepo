import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that discourages hardcoded size values in common widgets.
///
/// This project uses SizeConst for consistent spacing. Hardcoded numeric
/// values make it difficult to maintain consistent spacing across the app.
///
/// Examples that trigger this rule:
/// - `SizedBox(height: 16)` - hardcoded value
/// - `SizedBox(width: 8, height: 8)` - hardcoded values
/// - `Padding(padding: EdgeInsets.all(16))` - hardcoded padding
///
/// Valid examples:
/// - `SizedBox(height: SizeConst.s16)` - using constant
/// - `SizeConst.h16` - using predefined SizedBox
/// - `Gap(SizeConst.s8)` - using constant with Gap widget
class PreferSizeConstRule extends NoSlopRule {
  PreferSizeConstRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Enforces SizeConst for spacing values.');

  static const code = LintCode(
    'prefer_size_const',
    'Avoid hardcoded size values. Use SizeConst instead.',
    correctionMessage: 'Use SizeConst.sXX for spacing values.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final PreferSizeConstRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;

    if (typeName == 'SizedBox') {
      _checkSizedBoxArgs(node);
    } else if (typeName == 'Gap') {
      _checkGapArgs(node);
    }
  }

  void _checkSizedBoxArgs(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if ((name == 'height' || name == 'width') && _isHardcodedNumber(arg.expression)) {
          rule.reportAtNode(arg);
        }
      }
    }
  }

  void _checkGapArgs(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression && _isHardcodedNumber(arg)) {
        rule.reportAtNode(arg);
      }
    }
  }

  bool _isHardcodedNumber(Expression expr) {
    if (expr is IntegerLiteral || expr is DoubleLiteral) {
      return true;
    }
    return false;
  }
}
