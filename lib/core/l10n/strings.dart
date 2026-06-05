// Centralised UI strings — add new keys here, use context.s.key in widgets.
class AppStrings {
  final bool isAr;
  const AppStrings(this.isAr);

  String get appName        => isAr ? 'باهي'            : 'Baahy';
  String get tagline        => isAr ? 'سوق ليبيا الإلكتروني' : 'Libya\'s Online Market';

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  String get navHome        => isAr ? 'الرئيسية'  : 'Home';
  String get navWishlist    => isAr ? 'المفضلة'   : 'Wishlist';
  String get navBrowse      => isAr ? 'الأقسام'   : 'Categories';
  String get navCart        => isAr ? 'السلة'      : 'Cart';
  String get navAccount     => isAr ? 'حسابي'      : 'Account';

  // ── Auth ────────────────────────────────────────────────────────────────────
  String get enterPhone     => isAr ? 'أدخل رقم هاتفك'          : 'Enter your phone number';
  String get phoneSub       => isAr ? 'سنرسل لك رمزاً من 6 أرقام للتأكد من هويتك.' : 'We\'ll send you a 6-digit code to verify your identity.';
  String get sendCode       => isAr ? 'إرسال الرمز'             : 'Send Code';
  String get viaWhatsapp    => isAr ? 'المتابعة عبر واتساب'     : 'Continue via WhatsApp';
  String get browseAsGuest  => isAr ? 'تصفّح كزائر'             : 'Browse as guest';
  String get termsAgreement => isAr ? 'بالمتابعة أنت توافق على الشروط وسياسة الخصوصية.' : 'By continuing you agree to the Terms and Privacy Policy.';

  String get confirmNumber  => isAr ? 'تأكيد رقمك'              : 'Confirm your number';
  String get codeSentTo     => isAr ? 'أرسلنا رمزاً من 6 أرقام إلى' : 'We sent a 6-digit code to';
  String get verify         => isAr ? 'تحقق'                    : 'Verify';
  String get resendIn       => isAr ? 'إعادة الإرسال خلال'      : 'Resend in';
  String get seconds        => isAr ? 'ثانية'                   : 's';
  String get resendCode     => isAr ? 'إعادة إرسال الرمز'       : 'Resend code';
  String get wrongCode      => isAr ? 'رمز خاطئ، حاول مجدداً'  : 'Wrong code, please try again';
  String get notReceivedInfo=> isAr ? 'إذا لم يصلك الرمز، تحقق من صحة رقم الهاتف أو حاول مجدداً.' : 'If you didn\'t receive the code, check your number and try again.';

  // ── Home ────────────────────────────────────────────────────────────────────
  String get seeAll         => isAr ? 'عرض الكل'               : 'See all';
  String get newArrivals    => isAr ? 'وصل حديثاً'             : 'New Arrivals';
  String get bestSellers    => isAr ? 'الأكثر مبيعاً'          : 'Bestsellers';
  String get featuredDeals  => isAr ? 'عروض مميزة'             : 'Featured Deals';
  String get under50        => isAr ? 'تحت 50 د.ل'             : 'Under 50 LD';
  String get recentlyViewed => isAr ? 'شاهدته مؤخراً'          : 'Recently Viewed';
  String get activeOrder    => isAr ? 'طلبك في الطريق'         : 'Your order is on the way';
  String get trackOrder     => isAr ? 'تتبّع الطلب'            : 'Track Order';

  // ── Product ─────────────────────────────────────────────────────────────────
  String get brand          => isAr ? 'الماركة'                : 'Brand';
  String get size           => isAr ? 'المقاس'                 : 'Size';
  String get color          => isAr ? 'اللون'                  : 'Color';
  String get qty            => isAr ? 'الكمية'                 : 'Quantity';
  String get inStock        => isAr ? 'متوفّر'                 : 'In Stock';
  String get outOfStock     => isAr ? 'نفدت الكمية'            : 'Out of Stock';
  String get lowStock       => isAr ? 'كمية محدودة'            : 'Low Stock';
  String get addToCart      => isAr ? 'أضف للسلة'              : 'Add to Cart';
  String get buyNow         => isAr ? 'اشترِ الآن'             : 'Buy Now';
  String get selectSize     => isAr ? 'اختر المقاس'            : 'Select Size';
  String get selectOptions  => isAr ? 'اختر الخيارات أولاً'    : 'Select options first';
  String get notifyMe       => isAr ? 'أعلمني عند التوفر'      : 'Notify me when available';
  String get description    => isAr ? 'الوصف'                  : 'Description';
  String get reviews        => isAr ? 'التقييمات'              : 'Reviews';
  String get writeReview    => isAr ? 'اكتب تقييماً'           : 'Write a Review';
  String get noReviews      => isAr ? 'لا توجد تقييمات بعد'   : 'No reviews yet';
  String get delivery       => isAr ? 'التوصيل'                : 'Delivery';
  String get returns        => isAr ? 'الإرجاع'                : 'Returns';
  String get addedToCart    => isAr ? 'تمت الإضافة للسلة'      : 'Added to Cart';
  String get viewCart       => isAr ? 'عرض السلة'              : 'View Cart';
  String get continueShopping=>isAr ? 'مواصلة التسوق'          : 'Continue Shopping';
  String get shareProd      => isAr ? 'مشاركة المنتج'          : 'Share Product';

  // ── Cart ────────────────────────────────────────────────────────────────────
  String get cartTitle      => isAr ? 'السلة'                  : 'Cart';
  String get emptyCart      => isAr ? 'السلة فارغة'            : 'Your cart is empty';
  String get shopNow        => isAr ? 'تسوق الآن'              : 'Shop Now';
  String get clearAll       => isAr ? 'مسح الكل'               : 'Clear All';
  String get clearCart      => isAr ? 'مسح السلة'              : 'Clear Cart';
  String get clearCartMsg   => isAr ? 'هل تريد إزالة جميع المنتجات من السلة؟' : 'Remove all items from your cart?';
  String get remove         => isAr ? 'إزالة'                  : 'Remove';
  String get cancel         => isAr ? 'إلغاء'                  : 'Cancel';
  String get confirm        => isAr ? 'تأكيد'                  : 'Confirm';
  String get freeShippingIn => isAr ? 'أضف'                    : 'Add';
  String get toFreeShip     => isAr ? 'للشحن المجاني'          : 'for free shipping';
  String get freeShipEarned => isAr ? '🎉 حصلت على شحن مجاني!' : '🎉 You earned free shipping!';
  String get deliveryBy     => isAr ? 'توصيل باهي'             : 'Baahy Delivery';
  String get oneShipment    => isAr ? 'شحنة واحدة · 1-2 يوم'  : 'One shipment · 1-2 days';
  String get coupon         => isAr ? 'كوبون خصم'              : 'Discount Coupon';
  String get couponHint     => isAr ? 'أدخل الكوبون'           : 'Enter coupon code';
  String get apply          => isAr ? 'تطبيق'                  : 'Apply';
  String get couponApplied  => isAr ? 'تم تطبيق الكوبون'       : 'Coupon applied';
  String get subtotal       => isAr ? 'المجموع الجزئي'         : 'Subtotal';
  String get shipping       => isAr ? 'الشحن'                  : 'Shipping';
  String get discount       => isAr ? 'الخصم'                  : 'Discount';
  String get total          => isAr ? 'الإجمالي'               : 'Total';
  String get free           => isAr ? 'مجاني'                  : 'Free';
  String get checkout       => isAr ? 'إتمام الشراء'           : 'Checkout';

  // ── Checkout ────────────────────────────────────────────────────────────────
  String get checkoutTitle  => isAr ? 'الدفع'                  : 'Checkout';
  String get address        => isAr ? 'العنوان'                : 'Address';
  String get payment        => isAr ? 'الدفع'                  : 'Payment';
  String get review         => isAr ? 'المراجعة'               : 'Review';
  String get shippingAddr   => isAr ? 'عنوان التوصيل'          : 'Delivery Address';
  String get addAddress     => isAr ? 'إضافة عنوان'            : 'Add Address';
  String get paymentMethod  => isAr ? 'طريقة الدفع'            : 'Payment Method';
  String get placeOrder     => isAr ? 'تأكيد الطلب'            : 'Place Order';
  String get orderSummary   => isAr ? 'ملخص الطلب'             : 'Order Summary';
  String get continueBtn    => isAr ? 'متابعة'                 : 'Continue';
  String get back           => isAr ? 'رجوع'                   : 'Back';

  // ── Order confirmed ─────────────────────────────────────────────────────────
  String get orderConfirmed => isAr ? 'تم تأكيد طلبك! 🎉'     : 'Order Confirmed! 🎉';
  String get orderConfirmSub=> isAr ? 'سنبدأ بتجهيز طلبك قريباً وسنُعلمك عند الشحن.' : 'We\'ll prepare your order soon and notify you when it ships.';
  String get trackOrders    => isAr ? 'تتبع طلباتي'            : 'Track My Orders';
  String get backHome       => isAr ? 'العودة للرئيسية'        : 'Back to Home';
  String get orderNum       => isAr ? 'رقم الطلب'              : 'Order Number';
  String get estimatedDel   => isAr ? 'التسليم المتوقع'        : 'Estimated Delivery';

  // ── Orders ──────────────────────────────────────────────────────────────────
  String get myOrders       => isAr ? 'طلباتي'                 : 'My Orders';
  String get allOrders      => isAr ? 'الكل'                   : 'All';
  String get activeOrders   => isAr ? 'نشطة'                   : 'Active';
  String get completedOrders=> isAr ? 'مكتملة'                 : 'Completed';
  String get noOrders       => isAr ? 'لا توجد طلبات'          : 'No orders yet';
  String get loadFailed     => isAr ? 'تعذر تحميل الطلبات'     : 'Failed to load orders';
  String get items          => isAr ? 'منتج'                   : 'item(s)';

  String statusLabel(String s) {
    switch (s) {
      case 'pending':    return isAr ? 'قيد الانتظار' : 'Pending';
      case 'confirmed':  return isAr ? 'مؤكد'          : 'Confirmed';
      case 'processing': return isAr ? 'قيد التجهيز'  : 'Processing';
      case 'shipped':    return isAr ? 'في الطريق'     : 'Shipped';
      case 'delivered':  return isAr ? 'تم التسليم'    : 'Delivered';
      case 'cancelled':  return isAr ? 'ملغي'          : 'Cancelled';
      case 'returned':   return isAr ? 'مُرجَع'        : 'Returned';
      default: return s;
    }
  }

  // ── Browse / Search ─────────────────────────────────────────────────────────
  String get categories     => isAr ? 'الأقسام'               : 'Categories';
  String get searchHint     => isAr ? 'ابحث عن منتجات، ماركات، متاجر…' : 'Search products, brands, stores…';
  String get noResults      => isAr ? 'لا نتائج لـ'            : 'No results for';
  String get searchAnyway   => isAr ? 'ابحث على أي حال'        : 'Search anyway';
  String get trendingNow    => isAr ? 'رائج الآن'              : 'Trending Now';
  String get filters        => isAr ? 'الفلاتر'                : 'Filters';
  String get resetFilters   => isAr ? 'إعادة ضبط'              : 'Reset';
  String get applyFilters   => isAr ? 'تطبيق الفلاتر'          : 'Apply Filters';
  String get category       => isAr ? 'القسم'                  : 'Category';
  String get priceRange     => isAr ? 'نطاق السعر'             : 'Price Range';
  String get dealsOnly      => isAr ? 'عروض فقط'               : 'Deals Only';
  String get removeFilters  => isAr ? 'إزالة الفلاتر'          : 'Remove Filters';
  String get noResultsFound => isAr ? 'لا توجد نتائج'           : 'No results found';
  String get inStockOnly    => isAr ? 'متوفّر فقط'             : 'In Stock Only';
  String get sortBy         => isAr ? 'ترتيب حسب'              : 'Sort By';
  String get noProducts     => isAr ? 'لا توجد منتجات'         : 'No products';
  String get loadError      => isAr ? 'تعذر التحميل'           : 'Failed to load';
  String get all            => isAr ? 'الكل'                   : 'All';
  String get products       => isAr ? 'المنتجات'               : 'Products';

  // ── Account ─────────────────────────────────────────────────────────────────
  String get myAccount      => isAr ? 'حسابي'                  : 'My Account';
  String get signIn         => isAr ? 'تسجيل الدخول'           : 'Sign In';
  String get signOut        => isAr ? 'تسجيل الخروج'           : 'Sign Out';
  String get signInPrompt   => isAr ? 'سجّل دخولك إلى باهي'   : 'Sign in to Baahy';
  String get signInSub      => isAr ? 'احفظ مفضلتك، تتبّع طلباتك، وزامن عبر الأجهزة.' : 'Save your wishlist, track orders, and sync across devices.';
  String get myProfile      => isAr ? 'ملفي الشخصي'            : 'My Profile';
  String get myAddresses    => isAr ? 'عناويني'                : 'My Addresses';
  String get myWallet       => isAr ? 'محفظتي'                 : 'My Wallet';
  String get inviteFriends  => isAr ? 'أدعُ أصدقاء'            : 'Invite Friends';
  String get notifications  => isAr ? 'الإشعارات'              : 'Notifications';
  String get language       => isAr ? 'اللغة'                  : 'Language';
  String get switchLang     => isAr ? 'English'                : 'العربية';
  String get verified       => isAr ? 'موثّق'                  : 'Verified';
  String get activeOrdersLbl=> isAr ? 'طلبات نشطة'             : 'Active Orders';
  String get totalOrdersLbl => isAr ? 'إجمالي الطلبات'        : 'Total Orders';
  String get savedItems     => isAr ? 'محفوظة'                 : 'Saved';
  String get hello          => isAr ? 'أهلاً بك'              : 'Hello';

  // ── Wishlist ─────────────────────────────────────────────────────────────────
  String get wishlistTitle  => isAr ? 'المفضلة'                : 'Wishlist';
  String get wishlistEmpty  => isAr ? 'مفضلتك فارغة'           : 'Your wishlist is empty';
  String get wishlistSub    => isAr ? 'اضغط على القلب لحفظ المنتج للوقت لاحق.' : 'Tap the heart to save products for later.';
  String get priceDrops     => isAr ? 'تخفيضات الأسعار'        : 'Price Drops';
  String get priceDropBanner=> isAr ? 'انخفض سعره — أضفه قبل نفاد الكمية' : 'dropped in price — add before it sells out';
  String get choose         => isAr ? 'اختر'                   : 'Pick';
  String get add            => isAr ? 'أضف'                    : 'Add';
  String get soldOut        => isAr ? 'نفد'                    : 'Sold Out';

  // ── Addresses ────────────────────────────────────────────────────────────────
  String get addressesTitle => isAr ? 'عناويني'                : 'My Addresses';
  String get addNewAddress  => isAr ? 'إضافة عنوان جديد'       : 'Add New Address';
  String get defaultAddr    => isAr ? 'افتراضي'                : 'Default';
  String get setDefault     => isAr ? 'تعيين كافتراضي'         : 'Set as Default';
  String get editAddress    => isAr ? 'تعديل'                  : 'Edit';
  String get deleteAddress  => isAr ? 'حذف'                    : 'Delete';
  String get deleteAddrConf => isAr ? 'هل تريد حذف هذا العنوان؟' : 'Delete this address?';
  String get homeLabel      => isAr ? 'المنزل'                 : 'Home';
  String get officeLabel    => isAr ? 'العمل'                  : 'Office';
  String get otherLabel     => isAr ? 'أخرى'                   : 'Other';
  String get cityLabel      => isAr ? 'المدينة'                : 'City';
  String get streetLabel    => isAr ? 'الشارع والمنطقة'        : 'Street & Area';
  String get notesLabel     => isAr ? 'ملاحظات للسائق'         : 'Notes for driver';
  String get saveAddress    => isAr ? 'حفظ العنوان'            : 'Save Address';

  // ── Wallet ───────────────────────────────────────────────────────────────────
  String get walletTitle    => isAr ? 'المحفظة'                : 'Wallet';
  String get walletBalance  => isAr ? 'الرصيد المتاح'          : 'Available Balance';
  String get topUp          => isAr ? 'شحن الرصيد'             : 'Top Up';
  String get transactions   => isAr ? 'المعاملات'              : 'Transactions';
  String get noTransactions => isAr ? 'لا توجد معاملات'        : 'No transactions yet';

  // ── Notifications ────────────────────────────────────────────────────────────
  String get activity       => isAr ? 'النشاط'                 : 'Activity';
  String get markAllRead    => isAr ? 'قراءة الكل'             : 'Mark all read';
  String get upToDate       => isAr ? 'أنت على اطلاع تام.'    : 'You\'re all caught up.';
  String get notifSub       => isAr ? 'ستظهر هنا إشعارات الطلبات والعروض.' : 'Order updates and promotions will appear here.';
  String get today          => isAr ? 'اليوم'                  : 'Today';
  String get earlier        => isAr ? 'سابقاً'                 : 'Earlier';

  // ── General ──────────────────────────────────────────────────────────────────
  String get save           => isAr ? 'حفظ'                    : 'Save';
  String get close          => isAr ? 'إغلاق'                  : 'Close';
  String get loading        => isAr ? 'جارٍ التحميل…'          : 'Loading…';
  String get retry          => isAr ? 'إعادة المحاولة'         : 'Retry';
  String get error          => isAr ? 'حدث خطأ'                : 'Something went wrong';
  String get tryAgain       => isAr ? 'حاول مجدداً'            : 'Try again';
  String get errorTryAgain  => isAr ? 'حدث خطأ، حاول مجدداً'   : 'Something went wrong, try again';
  String get noInternet     => isAr ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection';
  String get checkInternet  => isAr ? 'تحقق من اتصالك وحاول مجدداً' : 'Check your connection and try again';
  String get lyd            => isAr ? 'د.ل'                    : 'LD';
  String get change         => isAr ? 'تغيير'                  : 'Change';

  // ── Home extras ──────────────────────────────────────────────────────────────
  String get shopByBrand       => isAr ? 'تسوق حسب البراند'    : 'Shop by Brand';
  String get welcomeBaahy      => isAr ? 'أهلاً بك في باهي'    : 'Welcome to Baahy';
  String get discoverProducts  => isAr ? 'اكتشف آلاف المنتجات من متاجر ليبيا' : 'Discover thousands of products from Libya\'s stores';
  String get baahyPromise      => isAr ? 'وعد باهي'             : 'Baahy Promise';
  String get baahyPromiseSub   => isAr ? 'نختار ونخزّن ونوصّل كل طلب بأنفسنا.' : 'We hand-pick, store & deliver every order ourselves.';
  String baahyPromiseDetail(int cities) => isAr
      ? 'منتجات مفحوصة. مستودعات حقيقية. سائقو باهي في $cities مدينة. إذا حدث خطأ، نحن من يحلّه.'
      : 'Inspected products. Real warehouses. Baahy drivers in $cities cities. If something goes wrong, we fix it.';
  String get onTheWay          => isAr ? 'في الطريق'            : 'On the way';

  // ── Checkout extras ──────────────────────────────────────────────────────────
  String get pleaseSelectAddr  => isAr ? 'يرجى اختيار عنوان التوصيل' : 'Please select a delivery address';
  String get orderError        => isAr ? 'حدث خطأ، حاول مجدداً'  : 'Something went wrong, please try again';
  String get whereToDeliver    => isAr ? 'أين نوصل الطلب؟'       : 'Where should we deliver?';
  String get notesOptional     => isAr ? 'ملاحظات (اختياري)'     : 'Notes (optional)';
  String get codTripiliOnly    => isAr ? 'الدفع عند الاستلام متاح فقط لمناطق طرابلس. يرجى اختيار طريقة دفع إلكترونية.' : 'Cash on delivery is available for Tripoli area only. Please choose an electronic payment method.';
  String walletCoversAll(String amt) => isAr ? 'محفظتك تغطي كامل الطلب ($amt د.ل)' : 'Your wallet covers the full order ($amt LD)';
  String walletPartial(String w, String d) => isAr ? 'محفظة: $w د.ل  +  $d د.ل عبر:' : 'Wallet: $w LD  +  $d LD via:';
  String walletBalanceLabel(String amt) => isAr ? 'رصيدك: $amt د.ل' : 'Balance: $amt LD';
  String get walletEmpty       => isAr ? 'رصيدك فارغ'             : 'Your wallet is empty';
  String serviceFeeN(String n) => isAr ? 'رسوم خدمة $n د.ل'      : 'Service fee $n LD';
  String get noFees            => isAr ? 'بدون رسوم'              : 'No fees';
  String get notesHint         => isAr ? 'أي تعليمات خاصة بطلبك...' : 'Any special instructions for your order...';
  String get reviewOrderTitle  => isAr ? 'مراجعة الطلب'          : 'Review Order';
  String get deliverTo         => isAr ? 'التسليم إلى'            : 'Deliver to';
  String get topUpShort        => isAr ? 'شحن'                   : 'Top Up';
  String get addrLabel         => isAr ? 'عنوان'                  : 'Address';
  String productsCountN(int n) => isAr ? 'المنتجات ($n)'          : 'Products ($n)';

  // ── Order confirmed extras ───────────────────────────────────────────────────
  String get orderDone         => isAr ? 'تم الطلب!'             : 'Order Placed!';
  String get deliveryLabel     => isAr ? 'التسليم'               : 'Delivery';
  String get paidLabel         => isAr ? 'المدفوع'               : 'Paid';
  String confirmSent(String n) => isAr
      ? 'أرسلنا رسالة تأكيد · رقم الطلب $n'
      : 'Confirmation sent · Order $n';
  String daysUnit(String d)    => isAr ? '$d يوم'                 : '$d day(s)';

  // ── Product detail extras ────────────────────────────────────────────────────
  String get notifyAvailability=> isAr ? 'سنعلمك عند توفر المنتج'  : "We'll notify you when available";
  String get requestFailed     => isAr ? 'تعذّر تسجيل الطلب، حاول مجدداً' : 'Failed to register request, try again';
  String get loadProductFailed => isAr ? 'تعذر تحميل المنتج'      : 'Failed to load product';
  String nSold(int n)          => isAr ? '$n مُباع'               : '$n sold';
  String get trustedSellers    => isAr ? 'منتجات موثوقة من بائعين معتمدين • الدفع آمن ومضمون' : 'Trusted products from verified sellers • Safe & secure payment';
  String get soldByBaahy       => isAr ? 'يُباع ويُسلَّم عبر باهي'  : 'Sold & delivered by Baahy';
  String get qualityChecked    => isAr ? 'مفحوص الجودة · مخزَّن في مستودعنا بطرابلس' : 'Quality checked · Stored in our Tripoli warehouse';
  String get deliveredDirect   => isAr ? 'يُوصَّل مباشرةً من مستودعات باهي' : 'Delivered from Baahy warehouses';
  String get frequentlyBought  => isAr ? 'تُشترى عادةً معاً'      : 'Frequently Bought Together';
  String totalForN(int n)      => isAr ? 'الإجمالي لـ $n منتج'    : 'Total for $n item(s)';
  String addNToCart(int n)     => isAr ? 'أضف $n للسلة'           : 'Add $n to Cart';
  String reviewsCountN(int n)  => isAr ? 'التقييمات ($n)'          : 'Reviews ($n)';
  String get seeAllReviews     => isAr ? 'الكل ←'                 : 'See all →';
  String basedOnN(int n)       => isAr ? 'بناءً على $n تقييم موثّق' : 'Based on $n verified review(s)';
  String deliveryToCity(String c) => isAr ? 'التوصيل إلى $c' : 'Delivery to ${translateCity(c)}';
  String get visitStore        => isAr ? 'زيارة المتجر'            : 'Visit Store';
  String get hasCoupon         => isAr ? 'هل لديك كوبون خصم؟'     : 'Have a discount coupon?';
  String get priceLabel        => isAr ? 'السعر'                   : 'Price';

  // ── Search extras ────────────────────────────────────────────────────────────
  String get seeAllResultsFor  => isAr ? 'عرض كل النتائج لـ'      : 'See all results for';

  // ── Reviews extras ───────────────────────────────────────────────────────────
  String get loadReviewsFailed => isAr ? 'تعذر تحميل التقييمات'   : 'Failed to load reviews';
  String noReviewsForN(int n)  => isAr ? 'لا توجد تقييمات لـ $n نجوم' : 'No $n-star reviews';
  String get reviewSent        => isAr ? 'شكراً! تم إرسال تقييمك' : 'Thank you! Review submitted';
  String get writeYourReview   => isAr ? 'اكتب تقييمك'            : 'Write Your Review';
  String get shareThoughtsHint => isAr ? 'شارك رأيك في هذا المنتج...' : 'Share your thoughts on this product...';
  String get publishReview     => isAr ? 'نشر التقييم'             : 'Submit Review';
  String reviewCountN(int n)   => isAr ? '$n تقييم'                : '$n review(s)';

  // ── Referral extras ──────────────────────────────────────────────────────────
  String get inviteTitle       => isAr ? 'ادعُ أصدقاءك'           : 'Invite Your Friends';
  String get howItWorks        => isAr ? 'كيف يعمل'               : 'How it Works';
  String get yourCode          => isAr ? 'رمزك'                   : 'Your Code';
  String get copied            => isAr ? 'نُسخ'                   : 'Copied';
  String get copyBtn           => isAr ? 'نسخ'                    : 'Copy';
  String get orShareVia        => isAr ? 'أو شارك عبر'            : 'Or share via';
  String get whatsapp          => isAr ? 'واتساب'                  : 'WhatsApp';
  String get viaSMS            => isAr ? 'رسالة'                   : 'Message';
  String get moreOptions       => isAr ? 'المزيد'                  : 'More';
  String referralSubtitle(int receiver, int giver) => isAr
      ? 'شارك رمزك. صديقك يحصل على خصم $receiver د.ل في طلبه الأول، وأنت تحصل على $giver د.ل عند شرائه.'
      : 'Share your code. Your friend gets $receiver LD off their first order, and you get $giver LD when they buy.';
  String get referralStep1     => isAr ? 'شارك رمزك مع صديق'      : 'Share your code with a friend';
  String get referralStep2     => isAr ? 'يسجّل ويقوم بطلبه الأول' : 'They sign up and place their first order';
  String referralStep3(int giver) => isAr
      ? 'تحصلان معاً على $giver د.ل في المحفظة'
      : 'You both get $giver LD in your wallet';
  String get statInvited       => isAr ? 'دعوة'                    : 'Invites';
  String get statJoined        => isAr ? 'انضموا'                  : 'Joined';
  String get statEarned        => isAr ? 'ربحت'                    : 'Earned';
  String get lydUnit           => isAr ? 'د.ل'                     : 'LD';
  String referralShareWhatsApp(String code, int amount) => isAr
      ? 'جرّب تطبيق باهي للتسوق! استخدم رمزي $code واحصل على $amount د.ل خصم على أول طلب 🛍️'
      : 'Try the Baahy shopping app! Use my code $code and get $amount LD off your first order 🛍️';
  String referralShareSMS(String code, int amount) => isAr
      ? 'رمز باهي: $code · خصم $amount د.ل'
      : 'Baahy code: $code · $amount LD off';
  String referralShareGeneral(String code, int amount) => isAr
      ? 'جرّب تطبيق باهي للتسوق! استخدم رمزي $code واحصل على $amount د.ل خصم على أول طلب'
      : 'Try the Baahy shopping app! Use my code $code and get $amount LD off your first order';

  // ── Onboarding extras ────────────────────────────────────────────────────────
  String get startShopping     => isAr ? 'ابدأ التسوق'            : 'Start Shopping';
  String versionN(String v)    => isAr ? 'الإصدار $v'             : 'Version $v';
  String get addingToCart      => isAr ? 'جارٍ إضافة المنتجات إلى السلة...' : 'Adding items to cart...';
  String get noItemsInStock    => isAr ? 'المنتجات غير متوفرة حالياً' : 'Items are currently out of stock';
  String get reorder           => isAr ? 'إعادة الطلب'            : 'Reorder';
  String get downloadInvoice   => isAr ? 'تنزيل الفاتورة'         : 'Download Invoice';
  String get pleaseSelectPayment => isAr ? 'يرجى اختيار طريقة الدفع' : 'Please select a payment method';
  String get skipBtn           => isAr ? 'تخطي'                   : 'Skip';
  String get saveForLater      => isAr ? 'احفظ للاحقاً'           : 'Save for Later';
  String get savedToWishlist   => isAr ? 'تمت الإضافة للمفضلة'   : 'Saved to Wishlist';
  String get viewAllProducts   => isAr ? 'عرض الكل'               : 'View All';
  String get daysLabel         => isAr ? 'يوم'                    : 'day(s)';
  String orderNumber(String n) => isAr ? 'الطلب $n'               : 'Order $n';
  String get orderDetails      => isAr ? 'تفاصيل الطلب'           : 'Order Details';
  String get loadOrderFailed   => isAr ? 'تعذر تحميل الطلب'       : 'Failed to load order';
  String get orderStatus       => isAr ? 'حالة الطلب'             : 'Order Status';
  String get subtotalOrder     => isAr ? 'المجموع الفرعي'         : 'Subtotal';
  String get shippingLabel     => isAr ? 'الشحن'                  : 'Shipping';
  String get discountLabel     => isAr ? 'الخصم'                  : 'Discount';
  String get totalLabel        => isAr ? 'الإجمالي'               : 'Total';
  String get returnItems       => isAr ? 'إرجاع منتجات'           : 'Return Items';
  String get orderHelp         => isAr ? 'مساعدة بخصوص هذا الطلب' : 'Help with this order';
  String get inDelivery        => isAr ? 'قيد التوصيل'            : 'Out for Delivery';
  String get stepPending       => isAr ? 'تم استلام الطلب'        : 'Order Received';
  String get stepConfirmed     => isAr ? 'مؤكد'                   : 'Confirmed';
  String get stepProcessing    => isAr ? 'قيد التجهيز'            : 'Processing';
  String get stepShipped       => isAr ? 'في الطريق'              : 'On the Way';
  String get stepDelivered     => isAr ? 'تم التسليم'             : 'Delivered';
  String get deliveryPromise   => isAr ? '1-2 يوم · طرابلس'       : '1-2 days · Tripoli';
  String get cartUpdateTitle   => isAr ? 'تحديث السلة'            : 'Cart Update';
  String get itemsUnavailable  => isAr ? 'المنتجات التالية غير متاحة حالياً:' : 'The following items are unavailable:';
  String get priceChangedItems => isAr ? 'تغير سعر المنتجات التالية:' : 'Prices changed for the following items:';
  String get removeAndContinue => isAr ? 'إزالة والمتابعة'        : 'Remove & Continue';
  String get willRemoveUnavailable => isAr ? 'سيتم إزالة المنتجات غير المتاحة والمتابعة.' : 'Unavailable items will be removed before continuing.';
  String get continueUpdatedPrices => isAr ? 'هل تريد المتابعة بالأسعار المحدّثة؟' : 'Continue with updated prices?';
  String get profileUpdated    => isAr ? 'تم تحديث البيانات'      : 'Profile updated';
  String get editProfileTitle  => isAr ? 'تعديل الملف الشخصي'     : 'Edit Profile';
  String get nameLabel         => isAr ? 'الاسم'                  : 'Name';
  String get fullNameHint      => isAr ? 'اسمك الكامل'            : 'Your full name';
  String get saveChanges       => isAr ? 'حفظ التغييرات'          : 'Save Changes';
  String get freeShipTag       => isAr ? 'شحن'                    : 'Free Ship';
  String get loadAddressesFailed => isAr ? 'تعذر تحميل العناوين'  : 'Failed to load addresses';
  String get deleteAddrTitle   => isAr ? 'حذف العنوان'            : 'Delete Address';
  String get storeLabel        => isAr ? 'المتجر'                 : 'Store';
  String get storeProducts     => isAr ? 'منتجات المتجر'          : 'Store Products';
  String get loadProductsFailed => isAr ? 'تعذّر تحميل المنتجات' : 'Failed to load products';
  String get noProductsNow     => isAr ? 'لا توجد منتجات حالياً' : 'No products available';
  String get baahyWallet       => isAr ? 'محفظة باهي'             : 'Baahy Wallet';
  String get walletHistory     => isAr ? 'السجل'                  : 'History';
  String get availableBalance  => isAr ? 'الرصيد المتاح'          : 'Available Balance';
  String get topUpWallet       => isAr ? 'شحن'                    : 'Top Up';
  String get sendMoney         => isAr ? 'إرسال'                  : 'Send';
  String get returnReason      => isAr ? 'ما سبب الإرجاع؟'        : 'Reason for return?';
  String get additionalNotes   => isAr ? 'ملاحظات إضافية (اختياري)' : 'Additional notes (optional)';
  String get productPhotos     => isAr ? 'صور المنتج (اختياري)'   : 'Product photos (optional)';
  String get addPhoto          => isAr ? 'إضافة'                  : 'Add';
  String get returnSubmitted   => isAr ? 'تم تقديم طلب الإرجاع'  : 'Return Request Submitted';
  String get refundTo          => isAr ? 'سيعاد الاسترداد إلى'   : 'Refund will be sent to';
  String get baahyWalletInstant => isAr ? 'محفظة باهي (فوري)'    : 'Baahy Wallet (instant)';
  String quantityN(int n)      => isAr ? 'الكمية: $n'             : 'Qty: $n';
  String get loadReturnFailed  => isAr ? 'تعذر تحميل المنتجات'   : 'Failed to load products';
  String get next              => isAr ? 'التالي'                 : 'Next';
  String get done              => isAr ? 'تم'                     : 'Done';
  String get youMayAlsoLike    => isAr ? 'قد يعجبك أيضاً'        : 'You May Also Like';
  String get viewMore          => isAr ? 'عرض المزيد'             : 'View More';
  String get locationFailed    => isAr ? 'تعذّر تحديد الموقع'    : 'Failed to detect location';
  String get selectCityAndStreet => isAr ? 'يرجى اختيار المدينة وإدخال الشارع' : 'Please select a city and enter the street';
  String get tapToOpenMap      => isAr ? 'اضغط لفتح الخريطة وتحديد مدينتك' : 'Tap to open map and set your location';
  String get setAsDefault      => isAr ? 'تعيين كعنوان افتراضي'  : 'Set as default address';
  String get selectCity        => isAr ? 'اختر مدينة'             : 'Select City';
  String get faqTitle          => isAr ? 'الأسئلة الشائعة'        : 'FAQ';
  String get contactUs         => isAr ? 'تواصل معنا'             : 'Contact Us';
  String get hereToHelp        => isAr ? 'نحن هنا لمساعدتك'      : 'We\'re here to help';
  String get supportAvailable  => isAr ? 'فريق الدعم متاح 7 أيام في الأسبوع' : 'Support team available 7 days a week';
  String get discoverCategories=> isAr ? 'تسوّق أحدث المنتجات من مختلف الفئات' : 'Shop the latest products across all categories';

  // ── Browse ───────────────────────────────────────────────────────────────────
  String get sneakPeek         => isAr ? 'عينة عالسريع'            : 'Sneak Peek';

  // ── AI Assistant ─────────────────────────────────────────────────────────────
  String get assistantTitle    => 'BaahyAi';
  String get assistantGreeting => isAr ? 'كيف يمكنني مساعدتك اليوم؟' : 'How can I help you today?';
  String get assistantInputHint=> isAr ? 'اكتب رسالتك...'         : 'Type your message...';
  String get assistantLimitHit => isAr ? 'استنفدت رصيدك من المحادثات اليوم.' : 'You\'ve reached your daily limit.';
  String get assistantWhatsapp => isAr ? 'تواصل مع الدعم على واتساب' : 'Contact support on WhatsApp';
  String get assistantError    => isAr ? 'حدث خطأ، حاول مجدداً'  : 'Something went wrong, try again';
  String get browseCategories  => isAr ? 'تصفح الأقسام'           : 'Browse Categories';
  String get askAssistant      => isAr ? 'اسأل المساعد الذكي'     : 'Ask AI Assistant';

  // ── Product detail extras ─────────────────────────────────────────────────────
  String lowStockN(int n)      => isAr ? 'تبقّى $n فقط'            : 'Only $n left';
  String get trustReturn       => isAr ? 'إرجاع واستبدال'          : 'Returns';
  String get trustPayment      => isAr ? 'الدفع عند الاستلام'      : 'Cash on Delivery';
  String get trustDelivery     => isAr ? 'توصيل سريع'              : 'Fast Delivery';
  String get saveAmountPrefix  => isAr ? 'وفّر'                    : 'Save';

  // ── Account extras ──────────────────────────────────────────────────────────
  String get inviteEarnBadge   => isAr ? 'احصل على 10 د.ل'         : 'Get 10 LD';

  // ── Address extras ──────────────────────────────────────────────────────────
  String get editLabel         => isAr ? 'تعديل'                   : 'Edit';
  String get makeDefaultLabel  => isAr ? 'اجعله افتراضياً'         : 'Set as Default';
  String get libyaLandmarkTip  => isAr
      ? 'في ليبيا، المعالم تساعد سائقينا في الوصول إليك بسرعة. أضف مسجداً قريباً أو مخبزاً أو متجراً.'
      : 'In Libya, landmarks help our drivers find you faster. Add a nearby mosque, bakery, or store.';
  String translateAddrLabel(String raw) {
    if (isAr) return raw;
    if (raw == 'المنزل' || raw == 'Home') return 'Home';
    if (raw == 'المكتب' || raw == 'Office') return 'Office';
    if (raw == 'آخر' || raw == 'أخرى' || raw == 'Other') return 'Other';
    return raw;
  }

  // ── Checkout extras ─────────────────────────────────────────────────────────
  String get subtotalLabel     => isAr ? 'المجموع الفرعي'          : 'Subtotal';
  String get shippingCost      => isAr ? 'الشحن'                   : 'Shipping';
  String get couponDiscount    => isAr ? 'خصم الكوبون'             : 'Coupon Discount';
  String get orderTotal        => isAr ? 'الإجمالي'                : 'Total';
  String get freeText          => isAr ? 'مجاني'                   : 'Free';

  // ── Wallet ───────────────────────────────────────────────────────────────────
  String get chargeWallet      => isAr ? 'شحن'                     : 'Charge';

  // ── Contact screen ────────────────────────────────────────────────────────────
  String get whatsappLabel     => isAr ? 'واتساب'                  : 'WhatsApp';
  String get phoneLabel        => isAr ? 'هاتف'                    : 'Phone';
  String get emailLabel        => isAr ? 'البريد الإلكتروني'       : 'Email';
  String get orderComplaintTip => isAr
      ? 'لشكاوى الطلبات، يرجى فتح الطلب من صفحة "طلباتي" والضغط على "مساعدة" للحصول على دعم أسرع.'
      : 'For order issues, open the order from "My Orders" and tap "Help" for faster support.';

  // ── Static policy fallbacks (used when backend has no EN content) ─────────────
  String get privacyPolicyEn => '''Baahy is committed to protecting your privacy. We collect the information you provide voluntarily (name, phone number, address) solely to deliver our service.

We do not share your data with third parties except for delivery and order fulfillment purposes.

We retain your data as long as your account is active. You may request account deletion at any time by contacting support.

We use SSL encryption to protect your data during transmission.

Contact: info@baahy.com''';

  String get termsOfServiceEn => '''By using the Baahy app, you agree to the following terms:

Permitted Use: The app is for personal shopping use only.

Orders: Once confirmed, an order becomes binding. The store reserves the right to cancel in rare cases with a full refund.

Pricing: Prices are in Libyan Dinar and subject to change without notice. The price at confirmation time is binding.

Liability: Baahy is an intermediary between merchants and customers. The merchant bears responsibility for the product and its quality.

Account Termination: We reserve the right to suspend any account that violates these terms.''';

  // ── City translation ─────────────────────────────────────────────────────────
  String translateCity(String city) {
    if (isAr) return city;
    const map = <String, String>{
      'طرابلس': 'Tripoli',
      'بنغازي': 'Benghazi',
      'مصراتة': 'Misrata',
      'الزاوية': 'Zawia',
      'سرت': 'Sirte',
      'درنة': 'Derna',
      'البيضاء': 'Al-Bayda',
      'الخمس': 'Khoms',
      'زليتن': 'Zliten',
      'تاجوراء': 'Tajura',
      'جنزور': 'Janzour',
      'قرجي': 'Gurji',
      'غريان': 'Gharyan',
      'ترهونة': 'Tarhuna',
      'أجدابيا': 'Ajdabiya',
      'الزنتان': 'Zintan',
      'كل ليبيا': 'All Libya',
      'ليبيا': 'Libya',
    };
    return map[city] ?? city;
  }
}
