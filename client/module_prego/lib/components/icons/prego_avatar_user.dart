import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";

/// Background gradient of the avatar rectangle.
///
/// Figma `pregoAvatarUserRectangle` specifies a fixed top-to-bottom fade from
/// white at 4% opacity into brand blue (#3A6CFF) at 15% opacity.
const LinearGradient _backgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x0AFFFFFF), Color(0x263A6CFF)],
);

/// A rounded-rectangle user avatar matching the Figma
/// `pregoAvatarUserRectangle` component.
///
/// A hairline-bordered rounded square with a subtle blue gradient fill and a
/// user glyph filled with the hero-avatar brand gradient. Used as the account
/// image in settings while accounts have no custom avatar.
class PregoAvatarUser extends StatelessWidget {
  const PregoAvatarUser({
    super.key,
    this.size = 40,
  });

  /// Width and height of the avatar square. The glyph scales at half of it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _backgroundGradient,
        border: Border.all(color: colors.borderPrimary),
        borderRadius: BorderRadius.circular(PregoRadius.xl),
      ),
      child: Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.brandGradientTop, colors.brandGradientBottom],
          ).createShader(bounds),
          child: Icon(TablerRegular.user, size: size / 2, color: colors.fgWhite),
        ),
      ),
    );
  }
}
