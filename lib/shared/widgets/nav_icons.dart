import 'package:flutter/widgets.dart';

/// The 5 bottom-nav icons, subset from Material Symbols Outlined.
///
/// The full `material_symbols_icons` package ships THREE ~11 MB variable fonts
/// (32 MB) for its thousands of glyphs. Flutter's release icon tree-shaker
/// mangles those variable fonts (it dropped glyphs → home/wishlist/cart vanished
/// in release builds), so the workaround was `--no-tree-shake-icons`, which
/// shipped all 32 MB → +16 MB app size.
///
/// Instead we subset the Outlined font to just these 5 codepoints (10 MB → 14 KB)
/// and ship that as `assets/fonts/BaahyNavIcons.ttf`. All four variable axes
/// (FILL, GRAD, opsz, wght) survive, so `Icon(..., weight: 300)` on the active
/// tab still works. Regenerate with:
///
///   python3 -m fontTools.subset <MaterialSymbolsOutlined.ttf> \
///     --unicodes=e9b2,e87e,e9b0,e8cc,f0d3 --output-file=BaahyNavIcons.ttf \
///     --no-hinting --desubroutinize
class NavIcons {
  const NavIcons._();

  static const _family = 'BaahyNavIcons';

  static const IconData home          = IconData(0xe9b2, fontFamily: _family);
  static const IconData favorite      = IconData(0xe87e, fontFamily: _family);
  static const IconData grid_view     = IconData(0xe9b0, fontFamily: _family);
  static const IconData shopping_cart = IconData(0xe8cc, fontFamily: _family);
  static const IconData person        = IconData(0xf0d3, fontFamily: _family);
}
