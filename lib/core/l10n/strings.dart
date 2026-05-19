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
  String get under50        => isAr ? 'تحت 50 د.ل'             : 'Under 50 LYD';
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
  String get noInternet     => isAr ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection';
  String get checkInternet  => isAr ? 'تحقق من اتصالك وحاول مجدداً' : 'Check your connection and try again';
  String get lyd            => isAr ? 'د.ل'                    : 'LYD';
}
