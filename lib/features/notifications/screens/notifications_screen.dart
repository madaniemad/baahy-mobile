import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(context.s.activity,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(context.s.markAllRead,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      size: 64, color: AppColors.ink4),
                  const SizedBox(height: 12),
                  Text(context.s.upToDate,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink2)),
                  const SizedBox(height: 4),
                  Text(context.s.notifSub,
                      style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (today.isNotEmpty) ...[
                  _SectionLabel(context.s.today),
                  ...today.map((n) => _NotifCard(n: n)),
                  const SizedBox(height: 6),
                ],
                if (earlier.isNotEmpty) ...[
                  _SectionLabel(context.s.earlier),
                  ...earlier.map((n) => _NotifCard(n: n)),
                ],
              ],
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
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink3,
            letterSpacing: 0.6)),
  );
}

class _NotifCard extends ConsumerWidget {
  final AppNotification n;
  const _NotifCard({required this.n});

  static Color _iconBg(String? type) {
    switch (type) {
      case 'order': return AppColors.teal50bg;
      case 'promo': return const Color(0xFFFFF3E0);
      case 'system': return AppColors.surfaceSoft;
      default: return AppColors.surfaceSoft;
    }
  }

  static Color _iconColor(String? type) {
    switch (type) {
      case 'order': return AppColors.primary;
      case 'promo': return const Color(0xFFD97757);
      case 'system': return AppColors.ink2;
      default: return AppColors.ink2;
    }
  }

  static IconData _icon(String? type) {
    switch (type) {
      case 'order': return Icons.local_shipping_rounded;
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
        if (n.type == 'order' && n.data?['order_id'] != null) {
          safePush(context, '/orders/${n.data!['order_id']}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : AppColors.teal50bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: n.isRead ? AppColors.border : AppColors.teal100bg,
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
                color: _iconBg(n.type),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(n.type), color: _iconColor(n.type), size: 20),
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
                                color: AppColors.ink0)),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTime(),
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              color: AppColors.ink3)),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.ink2,
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
