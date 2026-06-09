import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/friendship_status.dart';
import '../../../core/models/public_profile.dart';
import '../../../core/providers/friends_provider.dart';
import '../../../core/providers/public_profile_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class FriendProfileScreen extends ConsumerWidget {
  final String username;
  const FriendProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(username));

    return Scaffold(
      backgroundColor: context.col.bg,
      body: profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => Scaffold(
          appBar: AppBar(leading: BackButton()),
          body: Center(child: Text(context.tr('لم يتم العثور على المستخدم', 'User not found'))),
        ),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final PublicProfile profile;
  const _ProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = profile.user;
    final status = user.friendshipStatus;

    return CustomScrollView(
      slivers: [
        // ── App bar ─────────────────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: context.col.surface,
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.col.ink0),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('@${user.username ?? user.name}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          actions: [
            if (status == FriendshipStatus.accepted && user.friendshipId != null)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'remove') {
                    await ref.read(friendsProvider.notifier).removeFriend(user.friendshipId!);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'remove',
                    child: Text(context.tr('إزالة الصديق', 'Remove Friend'),
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.danger))),
                ],
              ),
          ],
        ),

        SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accept/decline banner ──────────────────────────────────────
            if (status == FriendshipStatus.pendingReceived && user.friendshipId != null)
              _PendingBanner(friendshipId: user.friendshipId!),

            // ── Profile header ─────────────────────────────────────────────
            _ProfileHeader(profile: profile),

            // ── Send/pending button ────────────────────────────────────────
            if (status == FriendshipStatus.none || status == FriendshipStatus.pendingSent)
              _AddFriendSection(user: user),

            // ── Wishlist ───────────────────────────────────────────────────
            if (profile.wishlist != null && profile.wishlist!.isNotEmpty)
              _WishlistSection(items: profile.wishlist!),

            // ── Recent purchases ───────────────────────────────────────────
            if (profile.recentPurchases != null && profile.recentPurchases!.isNotEmpty)
              _PurchasesSection(purchases: profile.recentPurchases!),

            // ── Reviews ───────────────────────────────────────────────────
            if (profile.reviews != null && profile.reviews!.isNotEmpty)
              _ReviewsSection(reviews: profile.reviews!),

            const SizedBox(height: 40),
          ],
        )),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final PublicProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final u = profile.user;
    final tierColor = switch (u.currentTier) {
      'silver'   => const Color(0xFF9E9E9E),
      'gold'     => const Color(0xFFD4A82E),
      'platinum' => const Color(0xFF4FC3F7),
      String()   => const Color(0xFFCD7F32),
      null       => null,
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        u.avatar != null && u.avatar!.isNotEmpty
            ? CircleAvatar(radius: 36, backgroundImage: NetworkImage(u.avatar!))
            : CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 24)),
              ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800)),
          if (u.username != null)
            Text('@${u.username}', style: TextStyle(fontSize: 13, color: context.col.ink3)),
          if (tierColor != null && u.currentTier != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierColor.withValues(alpha: 0.4)),
              ),
              child: Text(u.currentTier!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tierColor, fontFamily: 'Cairo')),
            ),
          ],
        ])),
      ]),
    );
  }
}

class _PendingBanner extends ConsumerWidget {
  final int friendshipId;
  const _PendingBanner({required this.friendshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Text(context.tr('أرسل لك هذا المستخدم طلب صداقة', 'This user sent you a friend request'),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () async => await ref.read(friendsProvider.notifier).declineRequest(friendshipId),
          child: Text(context.tr('رفض', 'Decline'), style: const TextStyle(fontFamily: 'Cairo', color: AppColors.danger)),
        ),
        ElevatedButton(
          onPressed: () async => await ref.read(friendsProvider.notifier).acceptRequest(friendshipId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 32),
          ),
          child: Text(context.tr('قبول', 'Accept'), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _AddFriendSection extends ConsumerStatefulWidget {
  final dynamic user;
  const _AddFriendSection({required this.user});

  @override
  ConsumerState<_AddFriendSection> createState() => _AddFriendSectionState();
}

class _AddFriendSectionState extends ConsumerState<_AddFriendSection> {
  bool _sent = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isPending = widget.user.friendshipStatus == FriendshipStatus.pendingSent || _sent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isPending || _loading ? null : _send,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(isPending ? Icons.hourglass_empty : Icons.person_add_outlined),
          label: Text(isPending ? context.tr('تم الإرسال', 'Request Sent') : context.tr('إضافة صديق', 'Add Friend'),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isPending ? context.col.surfaceSoft : AppColors.primary,
            foregroundColor: isPending ? context.col.ink2 : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final username = widget.user.username as String?;
    if (username == null) return;
    setState(() => _loading = true);
    final ok = await ref.read(friendsProvider.notifier).sendRequest(username);
    setState(() { _loading = false; if (ok) _sent = true; });
  }
}

class _WishlistSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _WishlistSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: context.tr('قائمة الرغبات', 'Wishlist')),
      SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final product = items[i]['product'] as Map<String, dynamic>? ?? {};
            final images  = (product['images'] as List?)?.cast<String>() ?? [];
            return GestureDetector(
              onTap: () => safePush(context, '/product/${product['id']}'),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.col.border),
                  boxShadow: AppShadows.shadowLifted,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    child: images.isNotEmpty
                        ? CachedNetworkImage(imageUrl: images.first, width: 120, height: 100, fit: BoxFit.cover)
                        : Container(width: 120, height: 100, color: context.col.surfaceSoft),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      context.isAr ? (product['name_ar'] ?? product['name'] ?? '') : (product['name'] ?? ''),
                      style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: context.col.ink1),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _PurchasesSection extends StatelessWidget {
  final List<Map<String, dynamic>> purchases;
  const _PurchasesSection({required this.purchases});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: context.tr('مشتريات أخيرة', 'Recent Purchases')),
      ...purchases.map((order) {
        final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag_outlined, color: context.col.ink3),
          ),
          title: Text(context.tr('طلب', 'Order') + ' #${order['order_number']}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('${items.length} ${context.tr('منتج', 'items')}',
            style: TextStyle(fontSize: 12, color: context.col.ink3)),
          trailing: Text('${order['total']} ${context.tr('د.ل', 'LYD')}',
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 13)),
        );
      }),
      const SizedBox(height: 16),
    ]);
  }
}

class _ReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  const _ReviewsSection({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: context.tr('التقييمات', 'Reviews')),
      ...reviews.map((r) {
        final product = r['product'] as Map<String, dynamic>? ?? {};
        final rating  = (r['rating'] as num?)?.toDouble() ?? 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(context.isAr ? (product['name_ar'] ?? product['name'] ?? '') : (product['name'] ?? ''),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Row(children: [
            ...List.generate(5, (i) => Icon(
              i < rating ? Icons.star : Icons.star_border,
              size: 14, color: AppColors.gold,
            )),
            const SizedBox(width: 6),
            if (r['comment'] != null)
              Expanded(child: Text(r['comment'] as String,
                style: TextStyle(fontSize: 12, color: context.col.ink2), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        );
      }),
      const SizedBox(height: 16),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }
}
