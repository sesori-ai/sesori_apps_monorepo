import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// What the options block says when the bridge answered with no harness at all.
///
/// A machine with no coding tool installed reports an empty harness list, which
/// left the screen blank: the chooser has nothing to offer and the composer has
/// nothing to send to. This names the reason in the chooser's place and points
/// at harness settings, where each harness reports what it is still missing.
///
/// The floating refresh action above the composer is the other half of the
/// answer — it re-runs discovery once a harness has been installed.
class NewSessionNoHarnessNotice extends StatelessWidget {
  final VoidCallback onSettingsPressed;

  const NewSessionNoHarnessNotice({super.key, required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    // The options block sits on a narrower inset than the composer so that its
    // chrome-less rows land on the design's margin. This card carries no such
    // padding of its own, so it takes the difference back to line its edges up
    // with the composer below.
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.sm),
      child: PregoGroupedRows(
        key: const Key("new_session_no_harness_notice"),
        children: [
          PregoGroupedRow(
            icon: TablerRegular.plug_off,
            title: Text(loc.newSessionNoHarnessTitle),
            subtitle: Text(loc.newSessionNoHarnessDescription),
          ),
          PregoGroupedRow(
            key: const Key("new_session_no_harness_settings"),
            icon: TablerRegular.adjustments_horizontal,
            title: Text(loc.newSessionHarnessSettings),
            trailing: const Icon(TablerRegular.chevron_right),
            onTap: onSettingsPressed,
            isLast: true,
          ),
        ],
      ),
    );
  }
}
