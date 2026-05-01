import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

import '../utils/no_slop_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that forbids non-final public instance fields in classes.
///
/// Public mutable fields expose internal state and make code harder to reason
/// about. Use final fields or provide getters/setters for controlled access.
/// Private fields (starting with `_`) are allowed to be mutable.
/// Fields in private classes (class name starts with `_`) are also allowed.
///
/// Examples that trigger this rule:
/// - `String name;` - public mutable field
/// - `int? count;` - public mutable nullable field
/// - `late String value;` - public late mutable field
///
/// Valid examples:
/// - `final String name;` - immutable field
/// - `String _name;` - private mutable field (allowed)
/// - `int? _count;` - private mutable nullable field (allowed)
/// - `static int counter;` - static fields are allowed (class-level state)
/// - `external String name;` - external fields (JS interop) are allowed
/// - Fields in private classes (`class _Foo { String bar; }`) are allowed
class AvoidMutableClassFieldsRule extends NoSlopRule {
  AvoidMutableClassFieldsRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Forbids non-final public instance fields.');

  static const code = LintCode(
    'avoid_mutable_class_fields',
    'Avoid public mutable class fields. Use final instead.',
    correctionMessage: 'Add the final keyword, make the field private, or use a getter/setter.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addFieldDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidMutableClassFieldsRule rule;

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (rule.isCurrentFileExcluded) return;
    if (node.isStatic) return;
    if (node.externalKeyword != null) return;
    if (node.fields.isFinal || node.fields.isConst) return;

    final classDecl = node.parent?.parent;
    if (classDecl is ClassDeclaration) {
      if (classDecl.namePart.typeName.lexeme.startsWith('_')) return;
    }

    final allPrivate = node.fields.variables.every(
      (variable) => variable.name.lexeme.startsWith('_'),
    );
    if (allPrivate) return;

    rule.reportAtNode(node);
  }
}
