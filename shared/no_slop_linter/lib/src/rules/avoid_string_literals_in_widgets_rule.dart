import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids string literals in Text widgets.
///
/// All user-facing strings should use localization keys for i18n support.
/// Hardcoded strings make translation impossible.
///
/// Examples that trigger this rule:
/// - `Text('Hello World')` - hardcoded string
/// - `Text("Welcome back!")` - hardcoded string
///
/// Valid examples:
/// - `Text(context.l10n.helloWorld)` - localized string
/// - `Text(AppStrings.welcomeBack)` - string constant
/// - `Text(widget.title)` - dynamic string from parameter
/// - `Text('$count items')` - interpolated (likely dynamic, allowed)
class AvoidStringLiteralsInWidgetsRule extends NoSlopRule {
  AvoidStringLiteralsInWidgetsRule()
      : super(name: code.lowerCaseName, description: 'Forbids hardcoded strings in Text widgets.');

  static const code = LintCode(
    'avoid_string_literals_in_widgets',
    'Avoid hardcoded strings in Text widgets. Use localization.',
    correctionMessage: 'Use context.l10n.xxx or a string constant instead.',
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

  final AvoidStringLiteralsInWidgetsRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;

    if (typeName == 'Text') {
      _checkFirstArgument(node);
    }
  }

  void _checkFirstArgument(InstanceCreationExpression node) {
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;

    final firstArg = args.first;

    if (firstArg is NamedExpression) return;

    if (firstArg is SimpleStringLiteral) {
      if (firstArg.value.isEmpty) return;
      if (firstArg.value.length == 1) return;
      rule.reportAtNode(firstArg);
    }

    if (firstArg is AdjacentStrings) {
      rule.reportAtNode(firstArg);
    }
  }
}
