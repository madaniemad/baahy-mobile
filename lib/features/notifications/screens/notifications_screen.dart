import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../shared/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('النشاط',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('قراءة الكل',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.teal600,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 72, color: AppColors.ink4),
                  SizedBox(height: 12),
                  Text('أنت على اطلاع تام.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink1)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (_, i) {
                final n = notifications[i];
                return GestureDetector(
                  onTap: () {
                    ref.read(notificationsProvider.notifier).markRead(n.id);
                    if (n.type == 'order' && n.data?['order_id'] != null) {
                      context.push('/orders/${n.data!['order_id']}');
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : const Color(0xFFEAF8F8).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(0),
                      border: const Border(
                        bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForType(n.type ?? ''),
                            color: AppColors.ink1, size: 18),
                        ),
                        const SizedBox(width: 12),
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
                                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                        fontSize: 14, height: 1.3)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                      fontSize: 11, color: AppColors.ink3)),
                                ],
                              ),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(n.body,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink2,
                                    height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                        if (!n.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.danger, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'order': return Icons.local_shipping_outlined;
      case 'promo': return Icons.local_offer_outlined;
      case 'system': return Icons.info_outline_rounded;
      default: return Icons.notifications_outlined;
    }
  }
}
