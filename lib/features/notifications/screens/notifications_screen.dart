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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('الإشعارات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('قراءة الكل',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
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
                  Text('لا توجد إشعارات',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return GestureDetector(
                  onTap: () {
                    ref.read(notificationsProvider.notifier).markRead(n.id);
                    // Navigate based on type
                    if (n.type == 'order' && n.data?['order_id'] != null) {
                      context.push('/orders/${n.data!['order_id']}');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: n.isRead ? AppColors.border : AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_rounded,
                            color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                style: TextStyle(
                                  fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(n.body,
                                style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
                              const SizedBox(height: 4),
                              Text(
                                '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 11, color: AppColors.ink4),
                              ),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
