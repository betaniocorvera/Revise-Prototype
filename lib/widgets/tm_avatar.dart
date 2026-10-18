// ─────────────────────────────────────────────────────────────────────────────
// The avatar.
//
// A person is text in this product, so their placeholder is text too: the
// initials, set in the sans because initials are a label, inside the same
// hairline-ruled square every other entry uses. No generated cartoon, no
// coloured circle pretending to be a photo. When real photos exist, this is the
// widget that grows an `image` argument.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/theme/app_theme.dart';

class TMAvatar extends StatelessWidget {
  const TMAvatar({required this.name, this.size = 40, super.key});

  final String name;
  final double size;

  /// First letter of the first two words. "Amara Okonkwo" gives AO.
  static String initialsOf(String name) {
    final StringBuffer out = StringBuffer();
    for (final String word in name.trim().split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      out.write(word[0].toUpperCase());
      if (out.length == 2) break;
    }
    return out.isEmpty ? '?' : out.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.paperSunken,
          border: Border.all(color: AppColors.rule),
          borderRadius: BorderRadius.circular(Radii.sharp),
        ),
        child: Text(
          initialsOf(name),
          style: AppType.label
              .copyWith(fontSize: size * 0.34, letterSpacing: 0.06)
              .tone(AppColors.inkSecondary),
        ),
      ),
    );
  }
}
