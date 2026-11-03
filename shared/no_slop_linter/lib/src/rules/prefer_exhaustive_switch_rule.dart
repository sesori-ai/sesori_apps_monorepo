import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids catch-all cases in switches on enums and sealed classes.
///
/// A catch-all case prevents the compiler from warning you when new enum
/// values or sealed subtypes are added. Exhaustive switches ensure all cases
/// are handled.
///
/// A catch-all is an unguarded case that matches every non-null value:
/// - `default:`
/// - `case _:` and `_ =>`
/// - an untyped variable such as `case final x:`, `final x =>` or `var x =>`
/// - a variable, wildcard or object pattern typed as the scrutinee type or a
///   supertype of it, ignoring nullability, such as `MySealed _ =>`,
///   `final MySealed x =>` or `MySealed(:final id) =>`
/// - any of these followed by `?`, such as `final x? =>`
///
/// Guarded cases such as `_ when cond =>` are not catch-alls, because the
/// compiler ignores them when it checks exhaustiveness.
///
/// Catch-alls are reported only when another case picks out a specific value
/// or subtype. A switch that only tells null apart from the rest, such as
/// `switch (maybe) { null => a, final value => b }`, decides nothing per value.
///
/// This rule only applies to:
/// - Enums (where all values are known at compile time)
/// - Sealed classes (where all subtypes are known at compile time)
///
/// For other types (String, int, Object, etc.), catch-all cases are allowed
/// since exhaustive matching is not practical.
///
/// Examples that trigger this rule:
/// - switch (enumValue) { case A: ...; default: ... } - has default on enum
/// - switch (sealedValue) { case SubA(): ...; _ => ... } - wildcard on sealed
/// - switch (sealedValue) { case SubA(): ...; case final other: ... } - binding catch-all
///
/// Valid examples:
/// - switch (enumValue) { case A: ...; case B: ...; } - exhaustive enum
/// - switch (stringValue) { case 'a': ...; default: ... } - default OK for String
class PreferExhaustiveSwitchRule extends NoSlopRule {
  PreferExhaustiveSwitchRule({required super.ignoreTestFiles})
    : super(name: code.lowerCaseName, description: 'Forbids catch-all cases in switches on enums and sealed classes.');

  static const code = LintCode(
    'prefer_exhaustive_switch',
    'Avoid catch-all cases in switches on enums and sealed classes. Handle all cases explicitly.',
    correctionMessage: 'Replace the catch-all case with the remaining enum values or sealed subtypes.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(rule: this, typeSystem: context.typeSystem);
    registry.addSwitchStatement(this, visitor);
    registry.addSwitchExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor({required this.rule, required this.typeSystem});

  final PreferExhaustiveSwitchRule rule;
  final TypeSystem typeSystem;

  @override
  void visitSwitchStatement(SwitchStatement node) {
    if (rule.isCurrentFileExcluded) return;
    final scrutineeType = node.expression.staticType;
    if (scrutineeType == null || !_isExhaustiveType(scrutineeType)) return;

    final picksOutValues = node.members.any(
      (member) => switch (member) {
        SwitchPatternCase(:final guardedPattern) => _picksOutValue(
          pattern: guardedPattern.pattern,
          scrutineeType: scrutineeType,
        ),
        SwitchCase() => true,
        SwitchDefault() => false,
      },
    );
    if (!picksOutValues) return;

    for (final member in node.members) {
      final isCatchAll = switch (member) {
        SwitchDefault() => true,
        SwitchPatternCase(:final guardedPattern) => _isCatchAll(
          guardedPattern: guardedPattern,
          scrutineeType: scrutineeType,
        ),
        SwitchCase() => false,
      };
      if (isCatchAll) {
        rule.reportAtNode(member);
      }
    }
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final scrutineeType = node.expression.staticType;
    if (scrutineeType == null || !_isExhaustiveType(scrutineeType)) return;

    final picksOutValues = node.cases.any(
      (member) => _picksOutValue(pattern: member.guardedPattern.pattern, scrutineeType: scrutineeType),
    );
    if (!picksOutValues) return;

    for (final member in node.cases) {
      if (_isCatchAll(guardedPattern: member.guardedPattern, scrutineeType: scrutineeType)) {
        rule.reportAtNode(member);
      }
    }
  }

  bool _isExhaustiveType(DartType type) {
    if (type.isDartCoreNum) return false;

    final element = type.element;
    if (element == null) return false;

    if (element is EnumElement) return true;
    if (element is ClassElement && element.isSealed) return true;

    return false;
  }

  /// Whether [guardedPattern] is unguarded and matches every non-null value of
  /// [scrutineeType].
  bool _isCatchAll({required GuardedPattern guardedPattern, required DartType scrutineeType}) {
    if (guardedPattern.whenClause != null) return false;
    return _matchesEveryValue(pattern: guardedPattern.pattern, scrutineeType: scrutineeType);
  }

  /// Whether [pattern] names a specific value or subtype, rather than matching
  /// every non-null value or only null.
  bool _picksOutValue({required DartPattern pattern, required DartType scrutineeType}) {
    final unwrapped = pattern.unParenthesized;
    if (unwrapped is ConstantPattern && unwrapped.expression is NullLiteral) return false;
    return !_matchesEveryValue(pattern: unwrapped, scrutineeType: scrutineeType);
  }

  bool _matchesEveryValue({required DartPattern pattern, required DartType scrutineeType}) {
    return switch (pattern.unParenthesized) {
      WildcardPattern(:final type) || DeclaredVariablePattern(:final type) => _coversScrutinee(
        typeAnnotation: type,
        scrutineeType: scrutineeType,
      ),
      NullCheckPattern(:final pattern) => _matchesEveryValue(pattern: pattern, scrutineeType: scrutineeType),
      ObjectPattern(:final type, :final fields) =>
        _coversScrutinee(typeAnnotation: type, scrutineeType: scrutineeType) &&
            fields.every((field) => _bindsWholeField(field.pattern)),
      _ => false,
    };
  }

  /// Whether a field subpattern matches every value of its field, null included.
  bool _bindsWholeField(DartPattern pattern) {
    return switch (pattern.unParenthesized) {
      WildcardPattern(type: null) || DeclaredVariablePattern(type: null) => true,
      _ => false,
    };
  }

  bool _coversScrutinee({required TypeAnnotation? typeAnnotation, required DartType scrutineeType}) {
    if (typeAnnotation == null) return true;
    final patternType = typeAnnotation.type;
    if (patternType == null) return false;
    return typeSystem.isSubtypeOf(typeSystem.promoteToNonNull(scrutineeType), patternType);
  }
}
