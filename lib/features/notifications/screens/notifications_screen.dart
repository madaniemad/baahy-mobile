import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch whenever the screen opens — the provider only fetches once at
    // app launch (for the header badge), so notifications created afterwards
    // (e.g. a fresh order) wouldn't appear without this.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    // Group into Today / Earlier
    final now = DateTime.now();
    final today = notifications.where((n) =>
        n.createdAt.year == now.year &&
        n.createdAt.month == now.month &&
        n.createdAt.day == now.day).toList();
    final earlier = notifications.where((n) =>
        !(n.createdAt.year == now.year &&
          n.createdAt.month == now.month &&
          n.createdAt.day == now.day)).toList();

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(context.s.activity,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(context.s.markAllRead,
                  style: const TextStyle(
                      fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(notificationsProvider.notifier).fetch(),
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                  Center(
                    child: Icon(Icons.notifications_none_rounded,
                        size: 64, color: context.col.ink4),
                  ),
                  const SizedBox(height: 12),
                  Text(context.s.upToDate,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.col.ink2)),
                  const SizedBox(height: 4),
                  Text(context.s.notifSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: context.col.ink3)),
                ],
              )
            : Builder(builder: (context) {
                // Flatten to [label, ...cards, label, ...cards] and render lazily.
                // A plain ListView builds EVERY row up front — one vendor account had
                // 2,829 notifications, which made this screen unusable (2026-08-14).
                final items = <Object>[];
                if (today.isNotEmpty) {
                  items.add(context.s.today);
                  items.addAll(today);
                }
                if (earlier.isNotEmpty) {
                  items.add(context.s.earlier);
                  items.addAll(earlier);
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return item is String
                        ? _SectionLabel(item)
                        : _NotifCard(n: item as AppNotification);
                  },
                );
              }),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.col.ink3,
            letterSpacing: 0.6)),
  );
}

class _NotifCard extends ConsumerWidget {
  final AppNotification n;
  const _NotifCard({required this.n});

  static bool _isOrder(String? type) => type == 'order' || type == 'order_update';

  /// Where tapping this notification should go.
  ///
  /// Until 2026-08-14 only order notifications navigated anywhere, so ~95% of what
  /// customers received was a dead tap — "a product in your cart dropped in price"
  /// went nowhere. Prefer the payload (set by the backend), fall back to a sensible
  /// destination per type, and return null rather than navigating somewhere wrong.
  static String? _target(AppNotification n) {
    final d = n.data ?? const <String, dynamic>{};
    String? val(String k) {
      final v = d[k];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final orderId = val('order_id');
    if (orderId != null) return '/orders/$orderId';

    final productId = val('product_id');
    if (productId != null) return '/product/$productId';

    final brand = val('brand');
    if (brand != null) {
      return '/search/results?q=&brand=${Uri.encodeComponent(brand)}&on_sale=1';
    }

    final categoryId = val('category_id');
    if (categoryId != null) return '/search/results?q=&category=$categoryId&on_sale=1';

    switch (n.type) {
      case 'wallet_unused':
      case 'welcome_bonus':
      case 'welcome_incentive_reminder':
      case 'referral_reward_earned':
        return '/wallet';
      case 'referral_reminder':
      case 'friend_joined':
        return '/referral';
      case 'cart_low_stock':
      case 'cart_price_drop':
      case 'abandoned_cart':
        return '/cart';
      case 'deal_of_the_day':
      case 'deals_in_your_categories':
      case 'trending_this_week':
      case 'new_arrivals_affinity':
      case 'comeback_offer':
      case 'lapsed_buyer_30d':
      case 'lapsed_buyer_60d':
      case 'lapsed_buyer_90d':
      case 'reengagement_7d':
      case 'reengagement_21d':
      case 'reengagement_45d':
        return '/search/results?q=&on_sale=1';
      case 'tier_upgrade_close':
      case 'milestone':
        return '/rewards-hub';
      case 'review_reminder':
      case 'reorder_suggestion':
      case 'order_cross_sell':
        return '/orders';
      default:
        return null;
    }
  }

  static Color _iconBg(String? type, BuildContext context) {
    if (_isOrder(type)) return AppColors.primary.withValues(alpha: 0.08);
    switch (type) {
      case 'promo': return const Color(0xFFFFF3E0);
      case 'system': return context.col.surfaceSoft;
      default: return context.col.surfaceSoft;
    }
  }

  static Color _iconColor(String? type, BuildContext context) {
    if (_isOrder(type)) return AppColors.primary;
    switch (type) {
      case 'promo': return const Color(0xFFD97757);
      case 'system': return context.col.ink2;
      default: return context.col.ink2;
    }
  }

  static IconData _icon(String? type) {
    if (_isOrder(type)) return Icons.local_shipping_rounded;
    switch (type) {
      case 'promo': return Icons.local_offer_rounded;
      case 'system': return Icons.info_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  String _formatTime() {
    final h = n.createdAt.hour.toString().padLeft(2, '0');
    final m = n.createdAt.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final isToday = n.createdAt.year == now.year &&
        n.createdAt.month == now.month &&
        n.createdAt.day == now.day;
    if (isToday) return '$h:$m';
    return '${n.createdAt.day}/${n.createdAt.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(notificationsProvider.notifier).markRead(n.id);
        final target = _target(n);
        if (target != null) safePush(context, target);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.isRead ? context.col.surface : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.isRead ? context.col.border : AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: n.isRead ? null : AppShadows.shadowCard,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color-coded icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _iconBg(n.type, context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(n.type), color: _iconColor(n.type, context), size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 13.5,
                                height: 1.3,
                                color: context.col.ink0)),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTime(),
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: context.col.ink3)),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.col.ink2,
                            height: 1.45)),
                  ],
                ],
              ),
            ),

            // Unread dot
            if (!n.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
