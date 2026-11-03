// The entrypoint for the no_slop_linter analysis server plugin.
//
// Every rule below is registered as a warning rule, so it is enabled by
// default wherever the plugin is loaded:
// - `avoid_as_cast`: Forbids force casts, use `is` checks or patterns
// - `avoid_bang_operator`: Forbids the null assertion operator (`!`)
// - `avoid_dynamic_return_type`: Forbids implicit or `dynamic` return types
// - `avoid_flutter_spinners`: Forbids direct Flutter spinner widgets
// - `avoid_implicit_tostring`: Forbids implicit toString() in string interpolation
// - `avoid_legacy_flutter_design_imports`: Forbids SDK Material/Cupertino imports
// - `avoid_material_icons`: Forbids Material Icons glyphs, use Tabler
// - `avoid_mutable_class_fields`: Forbids non-final public instance fields
// - `avoid_navigator_of`: Forbids direct Navigator usage, use GoRouter
// - `avoid_raw_go_router`: Forbids raw GoRouter navigation, use the typed extensions
// - `avoid_raw_modal_presenters`: Forbids showDialog/showModalBottomSheet/etc., use showPregoModal
// - `avoid_string_literals_in_widgets`: Forbids hardcoded strings in Text()
// - `prefer_edge_insets_directional`: Enforces EdgeInsetsDirectional for RTL
// - `prefer_exhaustive_switch`: Forbids default case in switch statements
// - `prefer_required_named_parameters`: Enforces required named params for multi-arg functions
// - `prefer_specific_type`: Forbids `Object` and `dynamic` (except fromJson/toJson maps and error values)
// - `prefer_text_align_directional`: Enforces TextAlign.start/end for RTL

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/plugin_server.dart' show PluginServer;
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/registry.dart' show PluginRegistryImpl;

import 'src/fixes/add_return_type_fix.dart';
import 'src/fixes/exhaustive_switch_fix.dart';
import 'src/fixes/required_named_parameters_fix.dart';
import 'src/rules/avoid_as_cast_rule.dart';
import 'src/rules/avoid_bang_operator_rule.dart';
import 'src/rules/avoid_dynamic_return_type_rule.dart';
import 'src/rules/avoid_flutter_spinners_rule.dart';
import 'src/rules/avoid_material_icons_rule.dart';
import 'src/rules/prefer_specific_type_rule.dart';
import 'src/rules/avoid_implicit_tostring_rule.dart';
import 'src/rules/avoid_legacy_flutter_design_imports_rule.dart';
import 'src/rules/avoid_mutable_class_fields_rule.dart';
import 'src/rules/avoid_navigator_of_rule.dart';
import 'src/rules/avoid_raw_go_router_rule.dart';
import 'src/rules/avoid_raw_modal_presenters_rule.dart';
import 'src/rules/avoid_string_literals_in_widgets_rule.dart';
import 'src/rules/prefer_edge_insets_directional_rule.dart';
import 'src/rules/prefer_exhaustive_switch_rule.dart';
import 'src/rules/prefer_required_named_parameters_rule.dart';
import 'src/rules/prefer_text_align_directional_rule.dart';

/// The analysis server plugin instance.
final plugin = _NoSlopLinterPlugin();

class _NoSlopLinterPlugin extends Plugin {
  @override
  String get name => 'no_slop_linter';

  @override
  void register(PluginRegistry registry) {
    // Warning rules (enabled by default)
    registry.registerWarningRule(AvoidAsCastRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidBangOperatorRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidDynamicReturnTypeRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidFlutterSpinnersRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidImplicitTostringRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidLegacyFlutterDesignImportsRule(ignoreTestFiles: false));
    registry.registerWarningRule(AvoidMaterialIconsRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidMutableClassFieldsRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidNavigatorOfRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidRawGoRouterRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidRawModalPresentersRule(ignoreTestFiles: true));
    registry.registerWarningRule(AvoidStringLiteralsInWidgetsRule(ignoreTestFiles: true));
    registry.registerWarningRule(PreferSpecificTypeRule(ignoreTestFiles: true));
    registry.registerWarningRule(PreferEdgeInsetsDirectionalRule(ignoreTestFiles: true));
    registry.registerWarningRule(PreferExhaustiveSwitchRule(ignoreTestFiles: true));
    registry.registerWarningRule(PreferRequiredNamedParametersRule(ignoreTestFiles: true));
    registry.registerWarningRule(PreferTextAlignDirectionalRule(ignoreTestFiles: true));

    // Fixes
    registry.registerFixForRule(
      AvoidDynamicReturnTypeRule.code,
      AddReturnTypeFix.new,
    );
    registry.registerFixForRule(
      PreferExhaustiveSwitchRule.code,
      ExhaustiveSwitchCombinedFix.new,
    );
    registry.registerFixForRule(
      PreferExhaustiveSwitchRule.code,
      ExhaustiveSwitchIndividualFix.new,
    );
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codePositionalParams,
      RequiredNamedParamsAllNamedFix.new,
    );
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codePositionalParams,
      RequiredNamedParamsKeepFirstFix.new,
    );
    registry.registerFixForRule(
      PreferRequiredNamedParametersRule.codeMissingRequired,
      RequiredNamedParamsAddRequiredFix.new,
    );

    // Workaround: The old PluginServer() constructor stores registries with
    // numeric keys (e.g., '0'), which the ignore suggestion's _code getter
    // skips. This means auto-generated ignore comments lack the plugin name
    // prefix, making them ineffective. Adding a named entry ensures that:
    // 1. Ignore suggestions generate "// ignore: no_slop_linter/rule_name"
    // 2. Those comments correctly suppress the diagnostic
    // This is a no-op when PluginServer.new2() is used (named key exists).
    if (registry is PluginRegistryImpl) {
      PluginServer.registries.putIfAbsent(name.toLowerCase(), () => registry);
    }
  }
}
