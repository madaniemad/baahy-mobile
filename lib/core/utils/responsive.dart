import 'package:flutter/widgets.dart';

/// Layout metrics for product grids across phone and tablet.
///
/// The product card is designed at [kCardDesignW] x [kCardDesignH] and scaled
/// proportionally to whatever column width it lands in. Grids must therefore
/// derive their cell height from the column width via [productCellHeight] —
/// hard-coding `mainAxisExtent` clips the card on wide columns, because the
/// card's image is an AspectRatio that grows with width while the extent
/// doesn't.

const double kCardDesignW = 165;

/// Everything in a ProductCard BELOW the image, which does NOT scale with width.
///
/// 8 top pad + 38 name (2 lines) + 5 + 20 badge row + 5 + 14 stars + 5 + 18
/// price + 8 bottom pad = 121, plus a little headroom.
const double kCardChromeH = 124;

/// Design height of a product card at [kCardDesignW] (image + chrome).
const double kCardDesignH = kCardDesignW / 0.8 + kCardChromeH; // ~330

/// Columns for a product grid at [width].
///
/// Phones stay at 2. Tablets get more columns so cards keep their intended
/// size instead of ballooning to fill the extra width — a 2-column grid on a
/// 13" iPad renders two enormous cards, which is what Apple's Guideline 4.0
/// flags as "an iPhone app stretched onto iPad".
int productGridColumns(double width) {
  if (width < 600) return 2; // phones (SE through Pro Max)
  if (width < 900) return 3; // large phones landscape, small tablets, split view
  if (width < 1200) return 4; // iPad portrait
  if (width < 1600) return 5; // iPad landscape
  return 6; // 13" iPad landscape and wider
}

/// Cell height for a column of [colW].
///
/// The card's IMAGE is an AspectRatio(0.8), so it grows with the column width;
/// everything under it (name/badge/stars/price) is a FIXED height. Scaling the
/// whole card proportionally therefore overshoots on wide columns and left dead
/// space under the price (visible on the store page). Size the image by width
/// and simply add the chrome.
double productCellHeight(double colW) => colW / 0.8 + kCardChromeH;

/// Column width given the space available to the grid.
double productColumnWidth({
  required double maxWidth,
  required int columns,
  required double spacing,
  double horizontalPadding = 0,
}) =>
    (maxWidth - horizontalPadding - spacing * (columns - 1)) / columns;

/// True when the layout is wide enough to be a tablet rather than a phone.
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;
