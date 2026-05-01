import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids default cases in switch statements on enums and sealed classes.
///
/// Using a default case prevents the compiler from warning you when new
/// enum values or sealed subtypes are added. Exhaustive switches ensure all cases are handled.
///
/// This rule only applies to:
/// - Enums (where all values are known at compile time)
/// - Sealed classes (where all subtypes are known at compile time)
///
/// For other types (String, int, Object, etc.), default cases are allowed since
/// exhaustive matching is not practical.
///
/// Examples that trigger this rule:
/// - switch (enumValue) { case A: ...; default: ... } - has default on enum
/// - switch (sealedValue) { case SubA(): ...; _ => ... } - wildcard on sealed
///
/// Valid examples:
/// - switch (enumValue) { case A: ...; case B: ...; } - exhaustive enum
/// - switch (stringValue) { case 'a': ...; default: ... } - default OK for String
class PreferExhaustiveSwitchRule extends NoSlopRule {
  PreferExhaustiveSwitchRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Forbids default case in switch on enums and sealed classes.');

  static const code = LintCode(
    'prefer_exhaustive_switch',
    'Avoid default case in switch. Handle all cases explicitly.',
    correctionMessage: 'Remove the default case and handle each enum/sealed value explicitly.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addSwitchStatement(this, visitor);
    registry.addSwitchExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final PreferExhaustiveSwitchRule rule;

  @override
  void visitSwitchStatement(SwitchStatement node) {
    if (rule.isCurrentFileExcluded) return;
    final expressionType = node.expression.staticType;
    if (!_isExhaustiveType(expressionType)) return;

    for (final member in node.members) {
      if (member is SwitchDefault) {
        rule.reportAtNode(member);
      }
    }
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final expressionType = node.expression.staticType;
    if (!_isExhaustiveType(expressionType)) return;

    for (final member in node.cases) {
      if (member.guardedPattern.pattern is WildcardPattern) {
        rule.reportAtNode(member);
      }
    }
  }

  bool _isExhaustiveType(DartType? type) {
    if (type == null) return false;
    if (type.isDartCoreNum) return false;

    final element = type.element;
    if (element == null) return false;

    if (element is EnumElement) return true;
    if (element is ClassElement && element.isSealed) return true;

    return false;
  }
}
