import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// Forbids reading the desktop/touch interaction mode in shared client code.
///
/// A desktop difference lives in metrics, a behaviour wrapper or a desktop
/// variant, so a widget never asks "is this desktop?" inline. The product
/// shells choose the mode and are free to read it, as are the files that
/// define a mode.
class AvoidInteractionModeReadsRule extends NoSlopRule {
  AvoidInteractionModeReadsRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids interaction-mode reads in shared client code.',
      );

  static const code = LintCode(
    'avoid_interaction_mode_reads',
    'Avoid reading the interaction mode in shared client code.',
    correctionMessage:
        'Put the desktop difference in metrics, a behaviour wrapper or a desktop variant. '
        'A read that has to stay for now carries an ignore naming its home: `pending: <home>`.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final library = context.libraryElement?.uri.toString();
    if (library == null || !_isChecked(library)) return;
    final visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
    registry.addSimpleIdentifier(this, visitor);
  }
}

const _themePrego = 'package:theme_prego/';
const _appUi = 'package:sesori_app_ui/';

/// The libraries that define a mode, and later the wrappers that own one.
const _definitions = [
  '${_themePrego}interactions/',
  '${_themePrego}theme/prego_design_system.dart',
  '${_appUi}src/features/session_detail/composer_presentation_scope.dart',
];

bool _isChecked(String library) =>
    (library.startsWith(_themePrego) || library.startsWith(_appUi)) && !_definitions.any(library.startsWith);

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidInteractionModeReadsRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (rule.isCurrentFileExcluded) return;
    if (_isScopeRead(node)) rule.reportAtNode(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (rule.isCurrentFileExcluded) return;
    // A doc comment's `[PregoInteractionMode.pointer]` reads nothing.
    if (node.thisOrAncestorOfType<CommentReference>() != null) return;
    final element = node.element;
    if (element is GetterElement &&
        element.name == 'isDesktopScale' &&
        _isClass(element.enclosingElement, name: 'PregoDesignSystem', package: _themePrego)) {
      rule.reportAtNode(node);
      return;
    }
    if (element is! PropertyAccessorElement) return;
    final constant = element.variable;
    if (constant is! FieldElement || !constant.isEnumConstant) return;
    final reference = _constantReference(node);
    if (_isClass(constant.enclosingElement, name: 'ComposerPresentation', package: _appUi)) {
      rule.reportAtNode(reference);
    } else if (_isClass(constant.enclosingElement, name: 'PregoInteractionMode', package: _themePrego) &&
        !_isMatchedAgainstScopeRead(reference)) {
      // A mode handed in as a value. Compared with, or switched on against, a
      // scope read, it is part of that read's finding.
      rule.reportAtNode(reference);
    }
  }
}

/// `PregoInteractionScope.of(context)`, or an inherited-widget lookup of
/// `PregoInteractionScope`.
bool _isScopeRead(MethodInvocation node) {
  final name = node.methodName.name;
  if (name == 'of') {
    final element = node.methodName.element;
    return element is MethodElement &&
        element.isStatic &&
        _isClass(element.enclosingElement, name: 'PregoInteractionScope', package: _themePrego);
  }
  if (!name.endsWith('InheritedWidgetOfExactType')) return false;
  // Resolved, so a type argument inferred from the declared type counts too.
  final typeArguments = node.typeArgumentTypes ?? const [];
  return typeArguments.length == 1 &&
      _isClass(typeArguments.first.element, name: 'PregoInteractionScope', package: _themePrego);
}

/// Whether [expression] is a scope read, or the `mode` of an inherited-widget
/// lookup.
bool _readsScope(Expression expression) => switch (expression.unParenthesized) {
  final MethodInvocation invocation => _isScopeRead(invocation),
  PropertyAccess(:final target?, propertyName: SimpleIdentifier(name: 'mode')) => _readsScope(target),
  _ => false,
};

/// Whether the enum constant [reference] is an operand of `==` or `!=` beside a
/// scope read, or a case pattern of a switch on one.
bool _isMatchedAgainstScopeRead(AstNode reference) {
  final parent = reference.parent;
  if (parent is BinaryExpression) {
    final other = identical(parent.leftOperand, reference) ? parent.rightOperand : parent.leftOperand;
    return _readsScope(other);
  }
  if (parent is! ConstantPattern) return false;
  AstNode? node = parent;
  while (node is DartPattern || node is GuardedPattern || node is SwitchExpressionCase || node is SwitchPatternCase) {
    node = node?.parent;
  }
  return switch (node) {
    SwitchExpression(:final expression) || SwitchStatement(:final expression) => _readsScope(expression),
    _ => false,
  };
}

/// The whole reference to the enum constant named by [node]:
/// `PregoInteractionMode.pointer`, its import-prefixed form, or `.pointer`.
AstNode _constantReference(SimpleIdentifier node) => switch (node.parent) {
  final PrefixedIdentifier parent when identical(parent.identifier, node) => parent,
  final PropertyAccess parent when identical(parent.propertyName, node) => parent,
  final DotShorthandPropertyAccess parent => parent,
  _ => node,
};

bool _isClass(Element? element, {required String name, required String package}) =>
    element is InterfaceElement && element.name == name && element.library.uri.toString().startsWith(package);
