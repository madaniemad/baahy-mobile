import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/friend.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/friends_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

const _tiffany = Color(0xFF1FD7E2);
const _tiffanyDeep = Color(0xFF08AAAC);

final _referralDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/referrals');
  final data = res.data['data'] as Map<String, dynamic>? ?? {};
  return {
    'code':      data['referral_code'] as String? ?? '',
    'invited':   (data['total_referrals'] as num?)?.toInt() ?? 0,
    'completed': (data['completed'] as num?)?.toInt() ?? 0,
    'earned':    (data['total_earned'] as num?)?.toDouble() ?? 0.0,
    'referrals': data['referrals'] as List? ?? [],
  };
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final referralAsync = ref.watch(_referralDataProvider);
    final user = ref.watch(currentUserProvider);
    final config = ref.watch(appConfigProvider);
    final giver = config.referralGiverAmount;
    // Friend's benefit = standard new-user welcome bonus (instant on signup),
    // not a stacked referral reward (referral_receiver_amount is 0).
    final friendBonus = config.welcomeBonusAmount.round();
    final minOrder = config.referralMinOrder.round();
    final friendsState = ref.watch(friendsProvider);
    final pendingCount = friendsState.incomingRequests.length;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: Text(context.s.friends,
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_outlined, size: 22),
            color: context.col.ink0,
            onPressed: () => safePush(context, '/friends/qr'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w500, fontSize: 14),
          indicatorColor: _tiffany,
          labelColor: _tiffany,
          unselectedLabelColor: AppColors.ink2,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: const Color(0xFFE5E7EB),
          tabs: [
            Tab(text: context.s.myFriends),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(context.s.friendRequests, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
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
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Tab 1: Invite & Referrals ──
          RefreshIndicator(
            color: _tiffany,
            onRefresh: () => ref.refresh(_referralDataProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                referralAsync.when(
                  loading: () => _InviteCard(code: user?.referralCode ?? '', giver: giver, receiver: friendBonus, minOrder: minOrder),
                  error: (_, __) => _InviteCard(code: user?.referralCode ?? '', giver: giver, receiver: friendBonus, minOrder: minOrder),
                  data: (d) => _InviteCard(
                    code: (d['code'] as String).isNotEmpty ? d['code'] as String : (user?.referralCode ?? ''),
                    giver: giver, receiver: friendBonus, minOrder: minOrder,
                  ),
                ),

                const SizedBox(height: 22),

                Text(context.tr('أرباحك حتى الآن', 'Your Earnings'),
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),

                referralAsync.when(
                  loading: () => const _EarningsRow(earned: 0, joined: 0, pending: 0),
                  error:   (_, __) => const _EarningsRow(earned: 0, joined: 0, pending: 0),
                  data:    (d) {
                    final invited   = d['invited'] as int;
                    final completed = d['completed'] as int;
                    final earned    = d['earned'] as double;
                    final pending   = ((invited - completed).clamp(0, 9999) * giver).toDouble();
                    return _EarningsRow(earned: earned, joined: completed, pending: pending);
                  },
                ),

                const SizedBox(height: 22),

                Text(context.tr('أصدقاؤك', 'Your Friends'),
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),

                referralAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(color: _tiffany, strokeWidth: 2))),
                  error: (_, __) => _EmptyFriends(),
                  data: (d) {
                    final list = d['referrals'] as List;
                    if (list.isEmpty) return _EmptyFriends();
                    final shown = _showAll ? list : list.take(3).toList();
                    return Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          color: context.col.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.col.border),
                          boxShadow: AppShadows.shadowLifted,
                        ),
                        child: Column(
                          children: List.generate(shown.length, (i) => _ReferralRow(
                            data: Map<String, dynamic>.from(shown[i] as Map),
                            hasBorder: i < shown.length - 1,
                            giverAmount: giver,
                          )),
                        ),
                      ),
                      if (list.length > 3) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => setState(() => _showAll = !_showAll),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(
                              _showAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18, color: _tiffanyDeep),
                            Text(_showAll ? context.tr('عرض أقل', 'Show Less') : context.s.viewMore,
                              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                                color: _tiffanyDeep, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ],
                    ]);
                  },
                ),

                const SizedBox(height: 20),
                _FaqCard(giver: giver, friendBonus: friendBonus, minOrder: minOrder),

              ]),
            ),
          ),

          // ── Tab 2: Friend Requests ──
          _RequestsTab(
            requests: friendsState.incomingRequests,
            loading: friendsState.loading,
          ),
        ],
      ),
    );
  }
}

// ── Invite Card ────────────────────────────────────────────────────────────────

class _InviteCard extends ConsumerStatefulWidget {
  final String code;
  final int giver;
  final int receiver;
  final int minOrder;
  const _InviteCard({required this.code, required this.giver, required this.receiver, required this.minOrder});

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share() async {
    final user = ref.read(currentUserProvider);
    final senderName = (user?.name ?? '').trim(); // FULL name, not just the first word
    // The invite landing page (which deep-links into the app) is served by the
    // Next.js site, now live on the canonical baahy.com domain.
    final inviteLink = Uri(
      scheme: 'https',
      host: 'baahy.com',
      path: '/invite/${widget.code}',
      queryParameters: {
        if (senderName.isNotEmpty) 'from': senderName,
        'reward': '${widget.receiver}',
      },
    ).toString();
    // Prefix each Arabic line with U+200F (RLM) so the line's base direction is RTL even when
    // it starts with a Latin name (e.g. "Kabour") — otherwise WhatsApp flips the whole line LTR
    // and the name reads disconnected from the Arabic.
    final rlm = String.fromCharCode(0x200F); // U+200F Right-to-Left Mark
    final greeting = senderName.isNotEmpty
        ? '$rlm$senderName دعاك للانضمام لباهي!'
        : '${rlm}دعوة للانضمام لباهي!';
    final text =
        '$greeting\n'
        '${rlm}احصل على ${widget.receiver} د.ل هدية ترحيبية فور انضمامك 🎁\n'
        '$inviteLink';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Simulator can't open share sheet — copy to clipboard as fallback
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('تم نسخ رابط الدعوة', 'Invite link copied'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: gift + text
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Gift box illustration
          Image.asset('assets/images/referral_gift.png',
            width: 80, height: 80, fit: BoxFit.contain),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('ادع أصدقاءك واربح مكافآت', 'Invite friends & earn rewards'),
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 5),
              Text(
                context.isAr
                  ? 'صديقك يحصل على ${widget.receiver} د.ل عند انضمامه،\nوتحصل أنت على ${widget.giver} د.ل بعد أول طلب له'
                  : 'Your friend gets ${widget.receiver} LD when they join,\nand you get ${widget.giver} LD after their first order',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                  color: context.col.ink2, height: 1.45)),
              const SizedBox(height: 10),
              // Code box
              widget.code.isEmpty
                ? Container(height: 34,
                    decoration: BoxDecoration(color: context.col.surfaceSoft, borderRadius: BorderRadius.circular(12)))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(widget.code,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'PlusJakartaSans',
                            fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      ),
                      GestureDetector(
                        onTap: _copy,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 1, height: 18, color: context.col.border,
                            margin: const EdgeInsets.only(left: 8, right: 8)),
                          Icon(_copied ? Icons.check_rounded : Icons.copy_outlined,
                            size: 14,
                            color: _copied ? AppColors.success : context.col.ink2),
                          const SizedBox(width: 4),
                          Text(_copied ? context.s.copied : context.s.copyBtn,
                            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5,
                              color: _copied ? AppColors.success : context.col.ink2,
                              fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ),
            ]),
          ),
        ]),

        const SizedBox(height: 14),

        // Share button
        GestureDetector(
          onTap: _share,
          child: Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              color: _tiffany,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.share_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(context.tr('شارك رابط الدعوة', 'Share Invite Link'),
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800,
                  fontSize: 14, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Earnings Row ───────────────────────────────────────────────────────────────

class _EarningsRow extends StatelessWidget {
  final double earned;
  final int joined;
  final double pending;
  const _EarningsRow({required this.earned, required this.joined, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _EarnStat(
        icon: Icons.account_balance_wallet_outlined,
        value: '${earned.toInt()} د.ل',
        label: context.tr('إجمالي الأرباح', 'Total Earned'),
      ),
      const SizedBox(width: 8),
      _EarnStat(
        icon: Icons.person_add_alt_1_outlined,
        value: '$joined',
        label: context.tr('أصدقاء انضموا', 'Friends Joined'),
      ),
      const SizedBox(width: 8),
      _EarnStat(
        icon: Icons.calendar_today_outlined,
        value: '${pending.toInt()} د.ل',
        label: context.tr('بانتظار التأكيد', 'Pending'),
      ),
    ]);
  }
}

class _EarnStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _EarnStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowLifted,
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: _tiffanyDeep),
          const SizedBox(height: 8),
          Text(value,
            style: const TextStyle(fontFamily: 'PlusJakartaSans',
              fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10.5,
              color: context.col.ink2, height: 1.3)),
        ]),
      ),
    );
  }
}

// ── Referral Row ───────────────────────────────────────────────────────────────

class _ReferralRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool hasBorder;
  final int giverAmount;
  const _ReferralRow({required this.data, required this.hasBorder, required this.giverAmount});

  static const _arMonths = [
    'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];

  String _fmt(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day} ${_arMonths[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = data['referred_name'] as String?
        ?? data['name'] as String?
        ?? 'مستخدم';
    final dateStr = data['created_at'] as String?;
    final status = (data['status'] as String? ?? '').toLowerCase();
    final isCompleted = status == 'completed' || status == 'مكتمل';
    final initial = name.isNotEmpty ? name[0] : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: hasBorder ? Border(bottom: BorderSide(color: context.col.border)) : null,
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: context.col.surfaceSoft,
          child: Text(initial,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700,
              fontSize: 15, color: context.col.ink1)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(isCompleted ? context.tr('اكتمل الطلب', 'Order completed') : context.tr('بانتظار إتمام الطلب', 'Awaiting first order'),
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5,
              color: isCompleted ? _tiffanyDeep : context.col.ink3,
              fontWeight: FontWeight.w500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (dateStr != null)
            Text(_fmt(dateStr),
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10.5, color: context.col.ink3)),
          const SizedBox(height: 3),
          isCompleted
            ? Text('+$giverAmount د.ل',
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 13, fontWeight: FontWeight.w800, color: _tiffanyDeep))
            : Text('—  —',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: context.col.ink3)),
        ]),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyFriends extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFE2F9FA), shape: BoxShape.circle),
          child: const Icon(Icons.group_outlined, size: 32, color: _tiffanyDeep),
        ),
        const SizedBox(height: 12),
        Text(context.tr('لم تدعُ أحداً بعد', 'No invites yet'),
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(context.tr('شارك كودك وابدأ بكسب المكافآت', 'Share your code and start earning'),
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: AppColors.ink2)),
      ])),
    );
  }
}

// ── Requests Tab ───────────────────────────────────────────────────────────────

class _RequestsTab extends ConsumerWidget {
  final List<Friend> requests;
  final bool loading;
  const _RequestsTab({required this.requests, required this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _tiffany, strokeWidth: 2));
    }
    if (requests.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F9FA), shape: BoxShape.circle),
            child: const Icon(Icons.inbox_outlined, size: 32, color: _tiffanyDeep),
          ),
          const SizedBox(height: 12),
          Text(context.tr('لا توجد طلبات معلقة', 'No pending requests'),
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final req = requests[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border),
              boxShadow: AppShadows.shadowLifted,
            ),
            child: Row(children: [
              _FriendAvatar(name: req.name, avatar: req.avatar),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(req.name,
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700, fontSize: 14)),
                if (req.username != null)
                  Text('@${req.username}',
                    style: TextStyle(fontSize: 12, color: context.col.ink3)),
              ])),
              Row(children: [
                TextButton(
                  onPressed: () async {
                    if (req.friendshipId != null) {
                      await ref.read(friendsProvider.notifier).declineRequest(req.friendshipId!);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.col.ink2,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(context.tr('رفض', 'Decline'), style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (req.friendshipId != null) {
                      await ref.read(friendsProvider.notifier).acceptRequest(req.friendshipId!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tiffany,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.tr('قبول', 'Accept'),
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  const _FriendAvatar({required this.name, this.avatar});

  @override
  Widget build(BuildContext context) {
    if (avatar != null && avatar!.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatar!));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFE2F9FA),
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(color: _tiffanyDeep, fontWeight: FontWeight.w700,
          fontSize: 16, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
      ),
    );
  }
}

// ── FAQ Card ───────────────────────────────────────────────────────────────────

class _FaqCard extends StatelessWidget {
  final int giver;
  final int friendBonus;
  final int minOrder;
  const _FaqCard({required this.giver, required this.friendBonus, required this.minOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 17, color: context.col.ink2),
          const SizedBox(width: 7),
          Text(context.tr('كيف تعمل مكافآت الأصدقاء؟', 'How do friend rewards work?'),
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13.5, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text(
          context.isAr
            ? 'يحصل صديقك على $friendBonus د.ل رصيد ترحيبي فور انضمامه للتطبيق. أمّا مكافأتك أنت ($giver د.ل) فتُضاف إلى رصيدك بعد أن يُكمل صديقك أول طلب له بقيمة $minOrder د.ل أو أكثر ويتم استلامه بنجاح.'
            : 'Your friend gets a $friendBonus LD welcome credit the moment they join. Your own $giver LD reward is added to your wallet after your friend completes and receives their first order of $minOrder LD or more.',
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
            color: context.col.ink2, height: 1.55)),
      ]),
    );
  }
}
