# CLAUDE.md — Baahy Mobile

This file provides guidance to Claude Code when working in this repository.

# Baahy Mobile — Project Reference

## What this is
Baahy (باهي) customer mobile app. Flutter for iOS and Android. Connects to the same Laravel backend as the web. The **web project** (`baahy-web`) owns the backend — direct backend changes there, not here.

## Stack
- **Flutter 3.41.9** (stable), Dart 3.11.5
- **State management**: Riverpod (`flutter_riverpod ^2.5.1`)
- **Navigation**: GoRouter (`go_router ^13.2.0`)
- **HTTP**: Dio (`dio ^5.4.3`)
- **Storage**: SharedPreferences (general), flutter_secure_storage (tokens)
- **Images**: cached_network_image
- **Push notifications**: Firebase Messaging + flutter_local_notifications
- **Voice search**: `speech_to_text ^6.6.0` — locale preference: ar_LY → ar_SA → ar_AE → ar_EG → ar
- **Fonts**: **Manrope** (English/Latin, primary) + **Tajawal** (Arabic) — `Manrope-VF.ttf` + `Tajawal-{Regular,Medium,Bold,ExtraBold}.ttf`. Manrope has NO Arabic glyphs, so every TextStyle sets `fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']` → Latin renders in Manrope, Arabic falls through to Tajawal at the glyph level. PlusJakartaSans still used for numbers/monospace; Outfit registered. (Replaced Cairo 2026-07-05; several trial Arabic fonts — Rubik/IBMPlex/Readex/Alexandria/Almarai — were tried then removed. **Tajawal metrics are patched** in the `.ttf` files: hhea/typo ascent 643→820, descent →-375, lineGap →0, USE_TYPO_METRICS on — so Arabic sits vertically centred in pills/buttons instead of riding high. `main.dart` also wraps the app in `DefaultTextHeightBehavior(leadingDistribution: even)`.)
- **Bundle ID**: iOS `com.baahy.app` · Android `com.baahy.baahyapp` (production identity — adopted 2026-07-02 to match the existing live App Store / Play Store listings so the new app ships as an in-place UPDATE. Do NOT revert to the old `com.example.baahyCustomer` placeholder.)

## Backend
- **API base URL**: `https://api.baahy.com/api`
- Hardcoded in `lib/core/api/api_client.dart` (can be overridden via `--dart-define=API_BASE_URL=...`)
- Mobile hits Cloudways **directly** — no Vercel proxy (unlike web). Imunify360 can block IPs.
- Auth token stored in `SharedPreferences` under key `auth_token`
- OTP dev bypass exists — see backend `.env` (disabled once WhatsApp/Sendly live)
- Backend SSH credentials: see Cloudways dashboard (do not commit here)

## Key Files
```
lib/
  main.dart                          — app entry, Riverpod scope, Firebase init
  core/
    api/api_client.dart              — Dio singleton, auth header, 401 handler
    models/product.dart              — Product, Category, Vendor, ProductVariation
    models/banner.dart               — AppBanner + BannersData (slots: hero, sub_hero, promo_*, fashion_banner, tile_*, mid_banner)
    models/order.dart                — Order, OrderItem, OrderStatus
    models/cart.dart                 — CartItem
    providers/home_provider.dart     — HomeNotifier: all home screen data + disk cache
    providers/auth_provider.dart     — AuthNotifier: login/logout, city selection
    providers/cart_provider.dart     — CartNotifier: add/remove/update
    providers/banner_provider.dart   — BannerNotifier: slot-based banner loading
    providers/recently_viewed_provider.dart — RecentlyViewedNotifier: disk-persisted
    providers/wishlist_provider.dart — WishlistNotifier
    services/cache_service.dart      — TTL-based SharedPreferences JSON cache
    utils/router.dart                — GoRouter config, all routes, 401→signin redirect
    utils/navigation.dart            — safePush() helper (avoids double-tap crash)
    l10n/strings.dart                — All UI strings AR/EN (AppStrings class)
  shared/
    theme/app_theme.dart             — AppColors, AppRadius, AppShadows, buildAppTheme()
    widgets/product_card.dart        — ProductCard + ProductCardSkeleton
  features/
    home/screens/home_screen.dart    — Full home screen (carousels, banners, sections)
    product/screens/product_detail_screen.dart
    search/screens/search_results_screen.dart
    cart/screens/cart_screen.dart
    checkout/screens/checkout_screen.dart
    auth/screens/phone_signin_screen.dart + otp_screen.dart
    account/screens/account_screen.dart
    orders/screens/order_tracking_screen.dart
```

## Design Tokens
All from `lib/shared/theme/app_theme.dart`:

**Colors:**
- `AppColors.primary` — `#1FD7E2` tiffany (buttons, CTAs)
- `AppColors.teal` / `teal600` — `#4ECDC4` teal (active nav, links, selections, spinner)
- `AppColors.ink0–ink4` — text hierarchy (ink0 = primary text, ink3 = placeholder)
- `AppColors.bg` — `#FAFBFC` page background
- `AppColors.surfaceSoft` — `#F6F7F7` search boxes, input backgrounds
- `AppColors.danger` — `#E2553F` red (errors, OOS, cancelled)
- `AppColors.success` — `#1F8A5B` green (delivered, in-stock)
- `AppColors.gold` — `#D4A82E` star ratings

**Radius:** All corners **12px** (standardized 2026-07-01 — screens use `BorderRadius.circular(12)`; note `AppRadius.card` constant still reads 6 but the app UI is 12px). Cards use a flat border (`Color(0xFFE2E4E4)`) instead of `AppShadows.shadowCard`. Pills use `AppRadius.pill = 9999`.

**Shadows:** `AppShadows.shadowCard` — 2-layer subtle shadow for cards.

## l10n Pattern
- All UI strings in `lib/core/l10n/strings.dart` as `AppStrings` class
- Access via `context.s.keyName` (extension in `lib/core/utils/l10n.dart`)
- Both AR and EN in the same getter: `String get addToCart => isAr ? 'أضف للسلة' : 'Add to Cart'`
- App locale: Arabic first (`ar-LY`, `en-LY`). RTL by default.
- When adding new strings: add to `AppStrings`, use `context.s.newKey` — never hardcode Arabic strings directly in widgets unless it's a truly one-off thing

## Navigation
- `safePush(context, '/route')` — always use this instead of `context.push()` to prevent double-tap crashes
- `context.go('/route')` — for replace-stack navigation (e.g. after login → home)
- Routes are defined in `lib/core/utils/router.dart`
- Main shell routes (bottom nav): `/home`, `/wishlist`, `/browse`, `/cart`, `/account`
  - Branch order (must match): home=0, wishlist=1, browse=2, cart=3, account=4
  - No AI tab in nav bar — AI accessible via `/chat` push route and AI cards on search + account screens
- Deep routes: `/product/:id`, `/search/results`, `/orders/:id`, `/checkout`, `/notifications`, `/chat`, etc.

## Home Screen Architecture
`home_provider.dart` fetches everything in one `fetch()` call:
- **Featured** (`home.featured`): `/products/recommended` — personalized via viewed/cart/order signals; fetched independently via `_fetchRecommended()` (slow call, fires in parallel with fast batch)
- **New Arrivals** (`home.newArrivals`): `/products?sort=latest`
- **Popular/Bestsellers** (`home.popular`): 1 random from each of 6 root categories (men/women/electronics/beauty/perfumes/home)
- **Deals** (`home.deals`): preferred-category deals interleaved + generic fallback
- **Two-phase loading**: fast 10-call batch emits partial state (newArrivals, popular, categories, sections) immediately; `featured` and `deals` fill in a second emit when slower calls finish. Skeleton gates on `(home.loading && home.featured.isEmpty && home.newArrivals.isEmpty) || !banners.initialized`. Banner `initialized` flag is set immediately on cache load (prewarm runs concurrently — no blocking delay).
- **Ordered dynamic sections** (`home.orderedDynamicSections`): unified list of `HomeDynamicItem` subclasses — preserves exact admin position order, rendered as a single block after New Arrivals:
  - `DynGrid` — price-capped product grid (type: `grid`)
  - `DynCarousel` — category product carousel (type: `carousel`)
  - `DynBannerDuo` — 2 square banners side-by-side (type: `banner_duo`)
  - `DynBanner` — single full-width banner 1920/700 (type: `banner`)
  - `DynStripBanner` — half-height wide banner 1920/350 (type: `strip_banner`)
  - `DynCategoryCarousel` — 1-row horizontal category image carousel (type: `category_carousel`)
- **Cache key**: `home_data_v5` — 5-minute TTL, stale-while-revalidate on cold start

Admin controls sections at `/admin/home-section-resources`. Sections API: `GET /api/home/sections?platform=mobile`.
`home_screen.dart` renders all sections with `if (data.isNotEmpty)` guards — empty sections just disappear, no layout breaks.

## Home Screen Header
- `SliverAppBar` (pinned) with tiffany (`#32DDE5`) background + `onb-pattern.png` at 0.28 opacity
- `toolbarHeight: 28` + `bottom: PreferredSize(height: 50)` — location row in title, outlined white search bar in bottom
- Location tap → `/city`; notification icon top-right with red dot badge

## Banner Slots (BannersData model)
| Slot | Widget | Aspect ratio | Notes |
|---|---|---|---|
| `hero` | `_HeroBannerSlider` | 1400/480 | PageView, viewportFraction 0.9, infinite loop, 4s auto-advance |
| `sub_hero` | `_SubHeroBanner` | 1920/350 | `AnimatedSwitcher` fade, 4s auto-advance, 16px side padding |
| `promo_left` + `promo_right` | `_BannerStack` | 1920/700 | stacked vertically, 16px side padding |
| `fashion_banner` | `_FashionBannerTiles` | portrait 1:1.7 | horizontal scroll, 2.5 cards visible |
| `promo_strip` | `_BrandCarousel` | square | brand logos, 78×64 tiles |
| `tile_1/2/3` | `_TileCarousel` | 1920/700 | auto-advance PageView |
| `mid_banner` | `_BannerStack` | 1920/700 | |

Hero images should be uploaded at **1400×480 px**. Sub-hero at any wide landscape ratio.

## Onboarding Flow (unified swipeable carousel, 2026-07-03)
- **One swipeable `PageView`** in `rewards_intro_screen.dart` (route `/rewards-intro`) with **3 mandatory pages: city → products → rewards**. No Skip button — city is page 0 so it can't be bypassed; every page is reachable by swipe OR by tapping the dots (`_Dots count:3, active:_page`, tappable to any page).
  - **Page 0 `_citySlide`** — language toggle (`localeProvider.toggle()`, sets the language the whole onboarding renders in), title/subtitle, white search field, white city-list card (`Flexible` + internal `Scrollbar`/`SingleChildScrollView`, rows = plain text + hairline `Divider(0xFFEDF1F2)`, selected = `_teal.withOpacity(0.10)` tint + navy bold + teal `check_circle`). Cities from `shippingRatesProvider`; selection held in `_selectedCity` (default `طرابلس`). Search + list capped `maxWidth 320`.
  - **Page 1 `_productsSlide`** — "آلاف المنتجات", `onb-products.png` (float animation).
  - **Page 2 `_rewardsSlide`** — "تسوّق واكسب", 3 `_BenefitCard`s from `appConfigProvider`.
  - Bottom `_ActionBar` label: last page = `startShopping`, else `nextBtn`. `_finish()` persists the city (`cityProvider.setCity(_selectedCity)`), sets `onboarding_v2_done=true`, requests push → `/home`.
- Splash (`splash_screen.dart`): `v2Done ? '/home' : '/rewards-intro'` (city lives inside the carousel now).
- `city_screen.dart` (route `/city`) is now **only** the standalone "change city" screen used later from the home header (returning mode → `/home`). It keeps the same white-card list + scrollbar; onboarding does NOT use it.
- `onboarding_screen.dart` + the `/onboarding` route are **orphaned/dead** (nothing navigates there). Safe to delete later.
- To review onboarding from scratch: `xcrun simctl uninstall B764355C-AE75-49CC-8E30-8B5089A32CAB com.baahy.app` then `flutter run` (prefs reset — `onboarding_v2_done`/`city` cleared).

## Rewards / Loyalty Hub
- Route: `/rewards-hub` (also `/rewards`) — `RewardsHubScreen` in `lib/features/rewards/screens/`
- **Tier display names (2026-07-06 rebrand): Silver → Gold → Platinum → Black.** The internal DB/API keys are UNCHANGED (`bronze`→Silver, `silver`→Gold, `gold`→Platinum, `platinum`→Black) — no migration; only labels changed (app + backend TierService/ChatController/TierSettingsPage).
- **Tier badge icons**: `assets/images/tier_{bronze,silver,gold,platinum}.png` = the metal 3D `b` (white / gold / chrome / onyx). `_TierBadge` renders them with a drop shadow (dark on light bg, light halo on dark) so they never blend.
- **Tier colors** (`_palettes` accent, used for names/numbers): Silver `#7C8894`, Gold `#C69320`, Platinum `#3B82C4`, Black `#1C1C22` (Black uses `ink0` at runtime so it flips white in dark mode).
- **Benefits table** (`_TierCard`): copies a reference mockup — white card, subtle header tint with icon + tier name (bold, colored), colored value numbers + grey labels, light dividers, active card has a cyan `AppColors.primary` glow border. Hero card = the tier's metal gradient (`gradA/gradB/fg`).
- Cashback rates and referral amounts come from `appConfigProvider`.
- **Rewards only count post-launch delivered orders**: backend `rewards_start_date` site_setting (default `2026-06-15`) filters legacy WooCommerce imports (bulk-marked delivered 2026-06-14) out of tier stats/milestones.

## Product Card Details
- "توصيل سريع" (fast delivery) badge: solid yellow `#FFF500`, black text, `fontSize: 8`, `icon size: 9`
- Vendor button on product detail: `AppColors.success` green border + text (not primary blue)
- Load-more button: outlined `StadiumBorder`, compact width, black border
- Search bar (search screen): white fill `Colors.white`, `border: Border.all(color: context.col.border, width: 1.2)`, radius 10. TextField must set `enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, border: InputBorder.none` to avoid double-border appearance.
- Search screen layout: `[back arrow outside] [Container: search icon | TextField | mic/clear]` — all icons inside the single white box
- `CachedNetworkImage`: use only `memCacheWidth` — do NOT set `memCacheHeight` (forces exact pixel dimensions via ResizeImage, distorts aspect ratio)

## Product Image Fit
- **`BoxFit.cover`** for clothing categories (checks `category.nameAr.contains('ملاب')` AND parent)
- **`BoxFit.contain`** for everything else (electronics, perfumes, shoes, bags, home, etc.)
- Backend returns `category.parent` object so full path is available on the frontend
- Logic is in `ProductCard` — `_isClothesCat()` helper

## Critical Rules
1. **Always full `flutter run` after code changes** — never rely on hot reload for provider/model/router changes. Hot reload safe only for pure widget cosmetic tweaks.
2. **Never use `context.push()` directly** — always `safePush()` from `lib/core/utils/navigation.dart` to prevent the double-tap crash (GoRouter `isLoading` guard pattern).
3. **`_safeGet()` swallows all errors** — if an API call fails, it returns `null`. `_products(null, 'data.data')` returns `[]`. So empty sections are expected on network failure, not crashes.
4. **Categories vs Products bug**: if ALL product sections are empty but banners/categories show, the likely cause is a stale cached binary (old compiled version). Do `flutter run` to rebuild.
5. **SharedPreferences key `baahy_cat_affinity`** does NOT exist in the mobile app — the mobile uses its own affinity system in `home_provider._loadPreferredCategoryIds()` (reads `viewed_product_ids` + `baahy_cart`). The web uses a different localStorage key.

## Running / Building
```bash
# Run on connected simulator or device
flutter run

# Run on specific simulator
flutter run --device-id <UDID>

# List available devices
flutter devices

# Analyze for errors
flutter analyze lib/

# Build for release (iOS)
flutter build ipa

# Build for release (Android)
flutter build apk --release
```

The booted simulator UDID as of last session: `B764355C-AE75-49CC-8E30-8B5089A32CAB` (iPhone 17 Pro)

## AI Assistant Screen (`assistant_screen.dart`)
- **Route**: `/chat` push route (no tab bar) — same `AssistantScreen` with back button. Pass `String` via `state.extra` to pre-fill and auto-send an initial message.
- **Entry points**: search screen empty state AI card (bottom), account screen AI card — both `safePush(context, '/chat')`
- **Chat API**: POST `/chat` with `{message, history, image?}` — `Options(receiveTimeout: Duration(seconds: 60))` required (two-pass Claude call takes 15-25s)
- **`_ChatMessage` model**: includes `suggestedCategories: List<Map<String,dynamic>>` — rendered as `Wrap` of teal pill buttons
- **Browse buttons**: tap → `safePush(context, '/search/results?q=&category=${cat['id']}')` — opens product listing filtered by that subcategory, NOT the categories overview page
- **Error handling**: exceptions → persistent chat bubble with error text; `limit_hit:true` in DioException response body also handled (shows WhatsApp card)
- **Image picker**: camera + photo library enabled; iOS privacy keys in `Info.plist` (NSCamera, NSPhotoLibrary, NSPhotoLibraryAdd, NSMicro)
- **Conversation history**: persisted to SharedPreferences as JSON list; trimmed to last 10 messages for API (4 when >10)
- **Rate limits** (from backend): 15 msg/hr, 5 img/hr, 50 msg/day — `limit_hit:true` triggers WhatsApp fallback card

## AI Cards / Banner (baahy AI branding — 2026-07-07)
- **Now a single banner image** `assets/images/ai_banner.png` ("baahy AI" + tagline + sparkles + chevron), wrapped in a rounded `Container` (border + `AppShadows.shadowCard`), tappable → `/chat`. Replaced the old teal-gradient card.
- Standalone `assets/images/ai_icon.png` (cyan `b` + sparkle, transparent bg) available for other AI touchpoints.
- **Locations**: account screen (just above logout) + search screen (pinned to the BOTTOM via a `Spacer` inside a viewport-filling `LayoutBuilder`+`ConstrainedBox`+`IntrinsicHeight` scroll).
- Both conditional on `config.aiEnabled`.

## Dark Mode = outline style (2026-07-06)
`BaahyColors.dark`: `surface`/`surfaceSoft` ≈ the scaffold `bg` (near-black) so cards have **no visible fill**; `border`/`borderStrong` are **white** (`0x80FFFFFF`/`0xB3FFFFFF`) → cards read as white outlines. Structural surfaces (appbar, sheets, inputs) stay opaque since they're near-bg, not transparent.

## Invite / Referral link
Share link is built in `friends_screen.dart` → `https://baahy-web.vercel.app/invite/CODE?from=&reward=` (the Next.js invite landing page that deep-links via `baahy://invite/CODE`). **NOT** `baahy.com` (that's the WordPress store, no `/invite` route → 404). Switch host to `baahy.com` at launch. `deep_link_service.dart` recognizes both hosts.

## Browse Screen (`browse_screen.dart`)
- **Sidebar rail**: white background, teal left accent bar on active item, 1px right border divider, width 108px
- **Sidebar font**: 13px, maxLines 3 (handles long Arabic names like "الجمال والعناية الشخصية")
- **Subcategory grid**: 2 columns, `childAspectRatio: 0.88` (calibrated for 600×600 square images)
- **Search bar margin**: `fromLTRB(12, 10, 12, 12)` — 12px below for breathing room

## Cart Screen (`cart_screen.dart`)
- **Item card layout**: horizontal Row — image (78×78, RIGHT in RTL) + Expanded column (name/price + action row). Action row: stepper (RIGHT) · Spacer · احفظ لاحقاً bookmark · trash icon (LEFT)
- **Variable product guard**: `_RecommendedCard` checks `product.productType == 'variable' || product.variations.isNotEmpty` before adding — navigates to product detail instead. Variations may be empty from the recommended API even for variable products; `productType` is always returned.
- **Free shipping achieved banner**: green `Color(0xFF2E8B57)`, padding `vertical:9`, icon 26×26 circle / truck 20px
- **AppBar**: `leading` = back arrow (RIGHT in RTL), `actions` = "مسح الكل" TextButton (LEFT in RTL)
- **Delivery section**: truck circle icon is FIRST child (RIGHT in RTL), text Expanded is second

## Product Detail Screen (`product_detail_screen.dart`)
- **Section order**: Price → Variations/Size → Quantity+Trust+Delivery → Description → Vendor → Similar products
- **Grid**: LayoutBuilder dynamic `mainAxisExtent` (no hardcoded height, adapts to screen width)
- **`_trySelectVariation`**: returns `null` (not `variations.first`) when no full attribute match; `_addToCart` guard uses `product.variations.isNotEmpty` (not `productType == 'variable'`)

## Wallet Screen (`wallet_screen.dart`)
- Full redesign: teal gradient hero card (`Color(0xFF32DDE5)` → `Color(0xFF08AAAC)`), 4-stat row, tier progress, earn-more horizontal scroll, last-5 transactions
- All original `_TopUpSheet` payment flows preserved (Mobicash OTP, Tadawel, Moamlat)

## Home Screen Categories
- Category tiles in horizontal scroll: `ClipOval` + `BoxShape.circle` (circular frames)

## Simulator / flutter run Notes
- **Bundle ID**: iOS `com.baahy.app` · Android `com.baahy.baahyapp` (production identity — see Stack section; do NOT revert to `com.example.baahyCustomer`)
- **Lost connection bug**: caused by stale `development-service` process from iPhone session + wrong bundle ID app still running on simulator. Fix: `pkill -f "development-service"` + `xcrun simctl terminate ... com.baahy.app` before running
- **Stable run pattern**: terminate stale app, then `flutter run --no-devtools` in same shell session keeping process alive
- **flutter run stability**: must keep start + monitor in same bash shell session — background processes from separate tool calls get killed when parent shell exits

## iOS Permissions (`ios/Runner/Info.plist`)
Required keys already present:
- `NSCameraUsageDescription` — for assistant image capture
- `NSPhotoLibraryUsageDescription` — for assistant image picker
- `NSPhotoLibraryAddUsageDescription` — for saving images
- `NSMicrophoneUsageDescription` — required alongside camera AND for voice search
- `NSSpeechRecognitionUsageDescription` — for voice search (added with ar-LY preference)
- `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription` — city detection

## Product Detail — Delivery ETA
- Helper functions at top of `product_detail_screen.dart`: `_nextWorkingDay`, `_addWorkingDays`, `_deliveryRange`, `_formatDeliveryDay`
- Libya working week: Sat–Thu (Friday off) — all ETA calculations skip Fridays
- Cutoff: 4pm. Orders after 4pm or on Fridays start processing next working day
- Day names in Arabic: الأحد/الاثنين/الثلاثاء/الأربعاء/الخميس/السبت + اليوم/غداً for today/tomorrow
- ETA from shipping rate: `etaMin` and `etaMax` fields; fallback to `deliveryDays` if null

## City / Address Sync
- Home header city label (`_CityLabel`) reads from `cityFromAddressProvider` (if user has saved address) or falls back to `cityProvider`
- After any address mutation (set default, delete, add, edit): call `ref.read(cityProvider.notifier).refresh()` in the UI callback
- City screen loads cities from `shippingRatesProvider` (live API) — no hardcoded list
- Cities available = cities with active shipping rates

## Search Screen (`search_screen.dart`)
- **Suggestions API**: `GET /api/search-suggestions?q=...` — returns `[{type, text_ar, text_en, q, category_id, product_id?, image?}]`
- **Types**: `suggestion` ("X في Y"), `brand` (verified icon), `product` (thumbnail, direct to `/product/:id`)
- **SKU/code search**: typing a hyphenated code like "V162-1WCL1006" returns the actual product with thumbnail in suggestions; tapping goes directly to product detail
- **Brand phonetics**: "انكر"→Anker, "نايك"→NIKE, "شانيل"→Chanel, etc. — resolved in backend before searching
- **Arabic plural stems**: "ساعات"→"ساعة", "حقائب"→"حقيبة" etc. — resolved in backend for both suggestions and results
- **Trending now**: horizontal pills carousel (tiffany color: `teal50` bg, `teal100` border, `teal700` text); tapping runs text search
- **Recent searches**: persisted to SharedPreferences under `recent_searches_v1`; max 8 entries
- **Routing**: brand → `/search/results?q=X&brand=X`; category → `?q=X&category=ID`; product → `/product/:id`; else → `?q=X`

## Camera Visual Search — baahyVision (`camera_search_screen.dart`)
- **Route**: `/search/camera` — launched from search screen camera icon
- **States**: `loading` (spinner), `live` (viewfinder + brackets), `scanning` (frozen image + scan line), `error`
- **Gallery tap**: sets `_CamState.loading` immediately (spinner within one frame), reverts to `live` on cancel
- **After navigation**: auto-resets to `_CamState.live` so back button returns to fresh live camera
- **API**: `POST /api/search-by-image` with base64 image; response: `{query, brand, category_id, products, alternative_brand}`
- **Normal flow**: navigates to `/search/results?category=X&brand=Y&q=Z` (brand as filter param, Arabic type as text query)
- **alternative_brand panel**: when backend returns `alternative_brand != null` (brand exists but not in scanned category) — shows bottom sheet: "لا يوجد {brand} في باهي" + "شاهد {type} مشابهة" button + "ابحث بصورة أخرى"; button navigates then resets to live camera
- **Backend logic** (`ProductController::searchByImage`): Claude Haiku Vision picks category from 3-level tree; brand alias expansion (HUGO→Hugo Boss, ARMANI→Giorgio Armani, etc.); short-circuit returns all brand+category products when both known; fallback cascade; `alternative_brand` triggered when brand not found in scanned category

## Backend Search Notes (Laravel — server only, no local git)
All search logic is in `app/Http/Controllers/API/ProductController.php`:
- **`suggestions()`**: Arabic termMap (EN→AR), brand phonetics map (AR phonetic→EN brand), `$wordGroups` AND logic, starts-with brand completion, word-boundary LIKE (`CONCAT(' ',col,' ') LIKE '% term%'`), SKU code returns `product` type with image
- **`index()` (product listing)**: FULLTEXT AGAINST + LIKE OR fallback for Arabic; Arabic plural stem map; SKU/code queries (contains `-` + digits) bypass FULLTEXT and use exact `sku LIKE`
- **MySQL FULLTEXT**: broken for Arabic (returns 0). LIKE fallback is the primary Arabic match path.

## Android CI — GitHub Actions (2026-07-09, LIVE)

Signed `.aab` built entirely in the cloud — no local JDK/keystore needed.

- **Workflow**: `.github/workflows/android-release.yml` (commit `ab393d5`)
- **Trigger**: Actions tab → Run workflow (manual dispatch)
- **Output**: signed `.aab` artifact downloadable from the Actions run; also auto-downloaded to `~/Desktop/baahy-builds/app-release.aab`
- **Secrets** (set in GitHub repo settings — never shown in chat):
  - `KEYSTORE_BASE64` — baahy-upload.jks
  - `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`
  - `GOOGLE_SERVICES_JSON` — com.baahy.baahyapp Firebase config
- **Upload key verified**: SHA-256 `AF:7F:21:F7:B1:F2:4A:F1:6F:8B:92:AA:A4:8E:82:93:01:14:66:F7:4C:87:F9:1B:95:EE:04:D6:71:D3:6C:6F` matches Play Console ✅
- **App signing key SHA-256**: `6C:93:FE:35:7D:F2:42:BF…` (for `assetlinks.json` + Firebase Android restriction)
- **App signing key SHA-1**: `96:8A:5D:62:D3:40:EA:03…` (for Google Maps Android key)

## WhatsApp OTP (2026-07-09, FULLY LIVE ✅)

- **App**: "Baahy WtsOTP" (Facebook App ID `3086550571539456`)
- **Number**: `+218 93-5589486` — verified, registered, active, end-to-end tested
- **Template**: `baahy_otp` (Arabic, copy-code button) — approved and active
- **Backend**: `WHATSAPP_PHONE_NUMBER_ID` + `WHATSAPP_ACCESS_TOKEN` wired in `.env`
- **Flow**: WhatsApp OTP first → Sendly SMS fallback. Both channels confirmed working.

## WooCommerce Migration — Backend Status (2026-07-10)

The backend (`api.baahy.com`) already holds the full migrated Woo data. **No mobile code changes needed** — app already points to `api.baahy.com` and will work after DNS cutover.

Migration state: 46,471 orders · 8,887 products · 47,238 users. Order numbers still `BH-{id}` until cutover seeds the sequence. See baahy-web `CLAUDE.md` for full migration details.

## Known Issues / TODO
- Bundle ID adopted production identity 2026-07-02 (iOS `com.baahy.app`, Android `com.baahy.baahyapp`) — ships as an in-place UPDATE to the live listings. Android **versionCode** (`+N` in pubspec `version:`) MUST be set higher than the live Play Console versionCode before Android release, and the iOS version must be > 4.4.18 (currently `5.0.0+1`).
- Firebase **WIRED (2026-07-02)**: `google-services.json` (Android, package `com.baahy.baahyapp`) and `GoogleService-Info.plist` (iOS, bundle `com.baahy.app`) are present; the `com.google.gms.google-services` Gradle plugin is enabled in `android/app/build.gradle.kts` + declared in `settings.gradle.kts`. `main.dart` calls `Firebase.initializeApp()`; `push_notification_service.dart` fetches the FCM token and POSTs it to `/device-token`. iOS has APNs capability + `UIBackgroundModes: remote-notification`. **Crashlytics stays deferred** (`firebase_crashlytics` commented out in pubspec + Gradle).
- iOS push entitlements (2026-07-03): Release config uses `Runner/RunnerRelease.entitlements` (`aps-environment=production`) so TestFlight/App Store builds register against production APNs; Debug + Profile stay on `Runner/Runner.entitlements` (`development`). Do NOT set the Debug/Profile entitlement to production — it breaks dev-signed `flutter run`.
- Wallet screen is UI-only (no backend wallet feature yet)
- Referral screen is UI-only
- Order tracking shows mock timeline steps (backend returns status string only, no step history)
- Map picker in address flow needs real Google Maps API key

## What This App Does NOT Own
- Backend PHP code → lives only on Cloudways server (no local git); SSH via Cloudways dashboard
- Admin panel → at `https://api.baahy.com/admin`
- Web frontend → edit in `baahy-web` project
