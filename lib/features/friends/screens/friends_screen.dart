import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/friend.dart';
import '../../../core/providers/friends_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.username == null || (user?.username?.isEmpty ?? true)) {
        safePush(context, '/username-setup');
      } else {
        ref.read(friendsProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);
    final pendingCount = state.incomingRequests.length;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.tr('الأصدقاء', 'Friends'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_outlined),
            onPressed: () => safePush(context, '/friends/qr'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w500, fontSize: 14),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.ink2,
          tabs: [
            Tab(text: context.tr('أصدقائي', 'My Friends')),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(context.tr('الطلبات', 'Requests'),
                  style: const TextStyle(fontFamily: 'Cairo')),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => safePush(context, '/friends/search'),
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: [
                _FriendsList(friends: state.friends),
                _RequestsList(requests: state.incomingRequests),
              ],
            ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  final List<Friend> friends;
  const _FriendsList({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.people_outline, size: 64, color: context.col.ink3),
          const SizedBox(height: 16),
          Text(context.tr('لا يوجد أصدقاء بعد', 'No friends yet'),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: context.col.ink1)),
          const SizedBox(height: 8),
          Text(context.tr('ابحث عن أشخاص تعرفهم', 'Search for people you know'),
            style: TextStyle(fontSize: 13, color: context.col.ink3)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: friends.length,
      itemBuilder: (_, i) => _FriendTile(friend: friends[i]),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final List<Friend> requests;
  const _RequestsList({required this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_outlined, size: 64, color: context.col.ink3),
          const SizedBox(height: 16),
          Text(context.tr('لا توجد طلبات معلقة', 'No pending requests'),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: context.col.ink1)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final req = requests[i];
        return _RequestTile(friend: req, onAccept: () async {
          if (req.friendshipId != null) {
            await ref.read(friendsProvider.notifier).acceptRequest(req.friendshipId!);
          }
        }, onDecline: () async {
          if (req.friendshipId != null) {
            await ref.read(friendsProvider.notifier).declineRequest(req.friendshipId!);
          }
        });
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => safePush(context, '/friends/${friend.username}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(avatar: friend.avatar, name: friend.name),
      title: Text(friend.name,
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: friend.username != null
          ? Text('@${friend.username}', style: TextStyle(fontSize: 12, color: context.col.ink3))
          : null,
      trailing: friend.currentTier != null
          ? _TierChip(tier: friend.currentTier!)
          : null,
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RequestTile({required this.friend, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.shadowCard,
          border: Border.all(color: context.col.border),
        ),
        child: Row(children: [
          _Avatar(avatar: friend.avatar, name: friend.name),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.name,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
              if (friend.username != null)
                Text('@${friend.username}', style: TextStyle(fontSize: 12, color: context.col.ink3)),
            ],
          )),
          Row(children: [
            TextButton(
              onPressed: onDecline,
              style: TextButton.styleFrom(foregroundColor: AppColors.ink2, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(context.tr('رفض', 'Decline'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(context.tr('قبول', 'Accept'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatar;
  final String name;
  const _Avatar({this.avatar, required this.name});

  @override
  Widget build(BuildContext context) {
    if (avatar != null && avatar!.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatar!));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      'silver'   => const Color(0xFF9E9E9E),
      'gold'     => const Color(0xFFD4A82E),
      'platinum' => const Color(0xFF4FC3F7),
      _          => const Color(0xFFCD7F32),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(tier, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'Cairo')),
    );
  }
}
