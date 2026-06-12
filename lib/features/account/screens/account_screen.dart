import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

const _kActiveStatuses = ['out_for_delivery'];


final _ordersCountsProvider = FutureProvider<({int active, int total})>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/orders', queryParameters: {'per_page': 50});
    final d = res.data['data'];
    List? raw;
    if (d is Map) raw = d['data'] as List?;
    else if (d is List) raw = d;
    final orders = raw ?? [];
    final total = (d is Map ? (d['total'] as num?)?.toInt() : null) ?? orders.length;
    final active = orders.where((o) => _kActiveStatuses.contains(o['status'])).length;
    return (active: active, total: total);
  } catch (_) {
    return (active: 0, total: 0);
  }
});

final _freshWalletBalanceProvider = FutureProvider<double>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/wallet');
    return (res.data['data']?['balance'] as num?)?.toDouble() ?? 0.0;
  } catch (_) {
    return 0.0;
  }
});

final _referralCountProvider = FutureProvider<int>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/referrals');
    return (res.data['data']?['total_referrals'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(_freshWalletBalanceProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(_freshWalletBalanceProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final config = ref.watch(appConfigProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: context.col.bg,
        appBar: AppBar(
          title: Text(context.s.myAccount,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: context.col.surface, elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft, shape: BoxShape.circle),
                  child: Icon(Icons.person_outline, size: 44, color: context.col.ink3),
                ),
                const SizedBox(height: 16),
                Text(context.s.signInPrompt,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(context.s.signInSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: context.col.ink2)),
                const SizedBox(height: 24),
                AppButton(label: context.s.signIn, onTap: () => safePush(context, '/signin')),
              ],
            ),
          ),
        ),
      );
    }

    final user          = auth.user!;

    // Re-fetch wallet when authProvider's balance changes (e.g. after wallet top-up)
    ref.listen(
      authProvider.select((a) => a.user?.walletBalance),
      (_, __) => ref.invalidate(_freshWalletBalanceProvider),
    );

    final wishlistCount = ref.watch(wishlistProductsProvider).valueOrNull?.length
        ?? ref.watch(wishlistProvider).length;
    final counts        = ref.watch(_ordersCountsProvider).value;
    final freshWallet   = ref.watch(_freshWalletBalanceProvider);
    final walletDisplay = freshWallet.valueOrNull ?? user.walletBalance;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.col.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(context.s.myAccount,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          GestureDetector(
            onTap: () => safePush(context, '/notifications'),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_outlined, size: 24, color: context.col.ink0),
                  if (unread > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          _ProfileCard(
            user: user,
            onEdit: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: context.col.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
              builder: (_) => _EditProfileSheet(
                currentName: user.name,
                onSaved: () => ref.read(authProvider.notifier).refreshProfile(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats row ─────────────────────────────────────────────────────
          IntrinsicHeight(
           child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _StatTile(
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFE11D48),
              iconBg: const Color(0xFFFFE4E8),
              value: '$wishlistCount',
              label: context.tr('المفضلة', 'Saved'),
              onTap: () => safePush(context, '/wishlist'),
            ),
            const SizedBox(width: 10),
            _StatTile(
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF0891B2),
              iconBg: const Color(0xFFE0F7FA),
              value: counts == null ? '—' : '${counts.active}',
              label: context.tr('نشطة', 'Active'),
              onTap: () => safePush(context, '/orders'),
            ),
            const SizedBox(width: 10),
            _StatTile(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFFEDE9FE),
              value: counts == null ? '—' : '${counts.total}',
              label: context.tr('طلباتي', 'My Orders'),
              onTap: () => safePush(context, '/orders'),
            ),
          ])),

          const SizedBox(height: 12),

          // ── Wallet card ───────────────────────────────────────────────────
          _WalletCard(balance: walletDisplay),

          const SizedBox(height: 12),

          // ── Tier card ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => safePush(context, '/rewards-hub'),
            child: const _TierCard(),
          ),

          const SizedBox(height: 12),

          // ── Referral / invite card ────────────────────────────────────────
          _ReferralCard(giverAmount: config.referralGiverAmount),

          const SizedBox(height: 12),

          // ── AI assistant card ─────────────────────────────────────────────
          if (config.aiEnabled)
            GestureDetector(
              onTap: () => safePush(context, '/chat'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C4BE), Color(0xFF00DEDA), Color(0xFF4DF5EF)],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF00DEDA).withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('baahyAi',
                        style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(context.tr('تحتاج مساعدة اضافية؟ اسال مساعدك الذكي',
                          'Need more help? Ask your AI assistant'),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                          color: Color(0xFF004D54))),
                    ],
                  )),
                  Icon(context.isAr ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.80)),
                ]),
              ),
            ),

          const SizedBox(height: 12),

          // ── Menu group 1 ─────────────────────────────────────────────────
          _MenuGroup([
            _MenuRow(
              icon: Icons.shopping_bag_outlined,
              label: context.s.myOrders,
              onTap: () => safePush(context, '/orders'),
            ),
            _MenuRow(
              icon: Icons.location_on_outlined,
              label: context.s.myAddresses,
              onTap: () => safePush(context, '/addresses'),
            ),
            _MenuRow(
              icon: Icons.assignment_return_outlined,
              label: context.tr('الإرجاعات والاسترداد', 'Returns & Refunds'),
              onTap: () => safePush(context, '/return-policy'),
            ),
          ]),

          // ── Birthday row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _BirthdayRow(user: user),
          ),

          const SizedBox(height: 8),

          // ── Menu group 2 ─────────────────────────────────────────────────
          _MenuGroup([
            _MenuRow(
              icon: Icons.notifications_outlined,
              label: context.s.notifications,
              onTap: () => safePush(context, '/notifications'),
            ),
            _MenuRow(
              icon: Icons.language_outlined,
              label: context.s.switchLang,
              onTap: () => ref.read(localeProvider.notifier).toggle(),
            ),
            _MenuRow(
              icon: Icons.settings_outlined,
              label: context.tr('الإعدادات', 'Settings'),
              onTap: () => safePush(context, '/settings'),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Sign out ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => ref.read(authProvider.notifier).logout(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_rounded, size: 17, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(context.s.signOut,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.danger, fontFamily: 'Cairo')),
              ]),
            ),
          ),

          const SizedBox(height: 20),
          Center(child: Text('baahy v1.0 · 2026',
            style: TextStyle(fontSize: 11, color: context.col.ink4))),
        ],
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  final dynamic user;
  final VoidCallback onEdit;
  const _ProfileCard({required this.user, required this.onEdit});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _uploading = false;
  String? _localImagePath; // shown immediately after pick, before network URL loads

  String _tierName(BuildContext context, String? tier) {
    switch (tier) {
      case 'bronze':   return context.tr('برونزي', 'Bronze');
      case 'silver':   return context.s.silverTier;
      case 'gold':     return context.s.goldTier;
      case 'platinum': return context.s.platinumTier;
      default:         return context.tr('برونزي', 'Bronze');
    }
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'silver':   return Colors.grey.shade600;
      case 'gold':     return const Color(0xFFD4A82E);
      case 'platinum': return Colors.blueAccent;
      default:         return const Color(0xFFCD7F32); // bronze
    }
  }

  IconData _tierIcon(String? tier) {
    if (tier == 'platinum') return Icons.diamond_outlined;
    return Icons.workspace_premium_rounded;
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: ctx.col.border,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(ctx.tr('التقاط صورة', 'Take photo'),
              style: const TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.tr('اختيار من المعرض', 'Choose from gallery'),
              style: const TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null || !mounted) return;

    final img = await picker.pickImage(
      source: choice,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (img == null || !mounted) return;

    // Show local image immediately before upload completes
    setState(() { _uploading = true; _localImagePath = img.path; });
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(img.path, filename: 'avatar.jpg'),
      });
      final res = await ApiClient.instance.dio.post('/auth/profile/avatar', data: formData);
      final newUrl = res.data['avatar'] as String?;
      if (newUrl != null) {
        await ref.read(authProvider.notifier).updateAvatar(newUrl);
      } else {
        ref.read(authProvider.notifier).refreshProfile();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _localImagePath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initial = (user.name as String).isNotEmpty
        ? (user.name as String)[0].toUpperCase() : 'U';
    final networkAvatar = user.avatar as String?;
    final tierAsync = ref.watch(tierProvider);
    final tier = tierAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Row(children: [
        // Avatar
        GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Stack(
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: ClipOval(
                  child: _uploading
                    ? const Center(child: SizedBox(width: 28, height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)))
                    : _localImagePath != null
                      ? Image.file(File(_localImagePath!), fit: BoxFit.cover,
                          width: 68, height: 68)
                      : networkAvatar != null && networkAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: networkAvatar,
                            fit: BoxFit.cover,
                            width: 68, height: 68,
                            placeholder: (_, __) => Center(child: Text(initial,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                                color: AppColors.primary, fontFamily: 'Cairo'))),
                            errorWidget: (_, __, ___) => Center(child: Text(initial,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                                color: AppColors.primary, fontFamily: 'Cairo'))),
                          )
                        : Center(child: Text(initial,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                              color: AppColors.primary, fontFamily: 'Cairo'))),
                ),
              ),
              Positioned(
                bottom: 0, left: 0,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: context.col.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.col.border, width: 1.2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 11, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // Info column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name as String,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                  color: context.col.ink0, fontFamily: 'Cairo', height: 1.2)),
              const SizedBox(height: 3),
              Text(user.phone as String,
                textDirection: TextDirection.ltr,
                style: TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 13, color: context.col.ink2)),
              const SizedBox(height: 8),
              Row(children: [
                // Verified — icon + text, no border
                Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(context.s.verified,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.success, fontFamily: 'Cairo')),
                const SizedBox(width: 12),
                // Tier — icon + text, no border
                Icon(_tierIcon(tier?.tier), size: 14, color: _tierColor(tier?.tier)),
                const SizedBox(width: 4),
                Text(_tierName(context, tier?.tier),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _tierColor(tier?.tier), fontFamily: 'Cairo')),
              ]),
            ],
          ),
        ),

        GestureDetector(
          onTap: widget.onEdit,
          child: Icon(Icons.chevron_right,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.45) : context.col.ink3),
        ),
      ]),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _StatTile({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.value, required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.col.border),
            boxShadow: AppShadows.shadowLifted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20, fontWeight: FontWeight.w800,
                color: context.col.ink0, height: 1.1)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(label,
                      style: TextStyle(fontSize: 10.5, color: context.col.ink2),
                      maxLines: 2),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? context.col.surfaceSoft : iconBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 17, color: isDark ? context.col.ink2 : iconColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wallet card ───────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final double balance;
  const _WalletCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.adaptive(context);
    return GestureDetector(
      onTap: () => safePush(context, '/wallet'),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isDark ? accent.withValues(alpha: 0.30) : AppColors.primary.withValues(alpha: 0.35),
          width: 0.8),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: isDark ? Border.all(color: accent.withValues(alpha: 0.35)) : null,
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.myWallet,
              style: TextStyle(fontSize: 12, color: context.col.ink2, fontFamily: 'Cairo')),
            Text('${balance.toStringAsFixed(0)} ${context.s.lyd}',
              style: TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 22, fontWeight: FontWeight.w800,
                color: context.col.ink0, height: 1.1)),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () => safePush(context, '/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.col.borderStrong, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(context.tr('تحويل', 'Transfer'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: context.col.ink1, fontFamily: 'Cairo')),
                const SizedBox(width: 4),
                Icon(Icons.swap_horiz_rounded, size: 12, color: context.col.ink1),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => safePush(context, '/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(context.s.chargeWallet,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFFF0F0F0), fontFamily: 'Cairo')),
                const SizedBox(width: 4),
                const Icon(Icons.add, size: 12, color: Color(0xFFF0F0F0)),
              ]),
            ),
          ),
        ]),
      ]),
    ));
  }
}

// ── Tier card ─────────────────────────────────────────────────────────────────

class _TierCard extends ConsumerWidget {
  const _TierCard();

  String _tierName(BuildContext context, String? tier) {
    switch (tier) {
      case 'bronze':   return context.tr('برونزي', 'Bronze');
      case 'silver':   return context.s.silverTier;
      case 'gold':     return context.s.goldTier;
      case 'platinum': return context.s.platinumTier;
      default:         return context.tr('برونزي', 'Bronze');
    }
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'silver':   return Colors.grey.shade600;
      case 'gold':     return const Color(0xFFD4A82E);
      case 'platinum': return Colors.blueAccent;
      default:         return const Color(0xFFCD7F32); // bronze
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(tierProvider);

    return tierAsync.when(
      loading: () => Container(
        height: 90,
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (tier) {
        final isPlatinum = tier.tier == 'platinum';
        final tierColor  = _tierColor(tier.tier);
        final tierName   = _tierName(context, tier.tier);

        double progress = 0.0;
        if (!isPlatinum && tier.ordersNeeded > 0 && tier.spendNeeded > 0) {
          final orderRatio = tier.ordersCount / tier.ordersNeeded;
          final spendRatio = tier.spendAmount / tier.spendNeeded;
          progress = (orderRatio < spendRatio ? orderRatio : spendRatio).clamp(0.0, 1.0);
        } else if (isPlatinum) {
          progress = 1.0;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.col.border),
            boxShadow: AppShadows.shadowLifted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Image.asset(
                  'assets/images/tier_${tier.tier?.toLowerCase() ?? 'bronze'}.png',
                  width: 42, height: 42, fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tierName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: context.col.ink0, fontFamily: 'Cairo', height: 1.2)),
                    const SizedBox(height: 3),
                    Text('${context.s.cashbackLabel} ${tier.cashbackRate.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: tierColor, fontFamily: 'Cairo')),
                  ]),
                ),
                Icon(Icons.chevron_right,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.45) : context.col.ink3),
              ]),

              const SizedBox(height: 10),

              // Progress bar + % + label all inline
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: context.col.surfaceSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(progress * 100).round()}%',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 11, fontWeight: FontWeight.w700, color: context.col.ink2)),
              ]),

              const SizedBox(height: 5),

              if (isPlatinum)
                Text(context.s.topTier,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.blueAccent, fontFamily: 'Cairo'))
              else
                Text(
                  context.isAr
                    ? 'متبقي ${tier.ordersRemaining} ${context.s.ordersToNextTier}'
                    : '${tier.ordersRemaining} ${context.s.ordersToNextTier}',
                  style: TextStyle(fontSize: 11, color: context.col.ink2, fontFamily: 'Cairo'),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Referral card ─────────────────────────────────────────────────────────────

class _ReferralCard extends ConsumerWidget {
  final int giverAmount;
  const _ReferralCard({required this.giverAmount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_referralCountProvider).valueOrNull ?? 0;

    return GestureDetector(
      onTap: () => safePush(context, '/friends'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowLifted,
        ),
        child: Row(children: [
          Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            if (isDark) {
              return Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group_rounded, size: 34, color: AppColors.primary),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/referral_illustration.png',
                width: 68, height: 68, fit: BoxFit.contain),
            );
          }),
          const SizedBox(width: 12),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s.inviteTitle,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: context.col.ink0, fontFamily: 'Cairo')),
              const SizedBox(height: 2),
              Text(
                context.isAr
                  ? 'اكسب $giverAmount ${context.s.lyd} لكل صديق'
                  : 'Earn $giverAmount ${context.s.lyd} per friend',
                style: TextStyle(fontSize: 12, color: context.col.ink2, fontFamily: 'Cairo')),
              const SizedBox(height: 3),
              Text(
                context.isAr ? '$count صديق' : '$count friends',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.primary, fontFamily: 'Cairo')),
            ]),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary, width: 1.2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.ios_share_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(context.tr('مشاركة', 'Share'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary, fontFamily: 'Cairo')),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Menu group ────────────────────────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  final List<_MenuRow> rows;
  const _MenuGroup(this.rows);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.col.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.col.border),
      boxShadow: AppShadows.shadowLifted,
    ),
    child: Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1)
            Divider(height: 1,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : context.col.border,
              indent: 58, endIndent: 0),
        ],
      ],
    ),
  );
}

// ── Menu row ──────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: context.col.ink0),
        ),
        const SizedBox(width: 13),
        Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500,
            fontFamily: 'Cairo'))),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Text(badge!,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: Color(0xFF7C3AED), fontFamily: 'Cairo')),
          ),
          const SizedBox(width: 6),
        ],
        Icon(Icons.arrow_forward_ios, size: 13,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.45)
              : context.col.ink4),
      ]),
    ),
  );
}

// ── Birthday row ──────────────────────────────────────────────────────────────

class _BirthdayRow extends ConsumerStatefulWidget {
  final dynamic user;
  const _BirthdayRow({required this.user});

  @override
  ConsumerState<_BirthdayRow> createState() => _BirthdayRowState();
}

class _BirthdayRowState extends ConsumerState<_BirthdayRow> {
  bool _saving = false;

  String? get _birthday => widget.user.birthday?.toString();

  String _formatBirthday(String raw) {
    try {
      final parts = raw.split('-');
      if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
      return raw;
    } catch (_) { return raw; }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year, now.month, now.day - 1),
      locale: Localizations.localeOf(context),
    );
    if (result == null || !mounted) return;
    final formatted = '${result.year.toString().padLeft(4, '0')}-'
        '${result.month.toString().padLeft(2, '0')}-'
        '${result.day.toString().padLeft(2, '0')}';
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.patch('/user/profile/birthday', data: {'birthday': formatted});
      ref.read(authProvider.notifier).refreshProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(tierProvider);
    final tier = tierAsync.valueOrNull;
    final isGoldPlus = tier?.tier == 'gold' || tier?.tier == 'platinum';

    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: GestureDetector(
        onTap: _birthday == null && !_saving ? _pickDate : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: context.col.surfaceSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: _saving
                ? const Padding(padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cake_outlined, size: 17),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s.birthdayLabel,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                if (_birthday == null && isGoldPlus) ...[
                  const SizedBox(height: 2),
                  Text(context.s.birthdayRewardHint,
                    style: TextStyle(fontSize: 11, color: AppColors.gold)),
                ],
              ]),
            ),
            if (_birthday != null)
              Text(_formatBirthday(_birthday!),
                style: TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink2))
            else
              Text(context.s.addBirthday,
                style: TextStyle(fontSize: 12, color: AppColors.primary,
                  fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
            const SizedBox(width: 4),
            if (_birthday == null)
              Icon(Icons.arrow_forward_ios, size: 13, color: context.col.ink4),
          ]),
        ),
      ),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.currentName, required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.dio.put('/auth/profile', data: {'name': name});
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.profileUpdated),
            backgroundColor: AppColors.success));
      }
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.col.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(context.s.editProfileTitle,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(context.s.nameLabel,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink1)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: context.s.fullNameHint,
              hintStyle: TextStyle(fontFamily: 'Cairo', color: context.col.ink3),
              filled: true,
              fillColor: context.col.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.col.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.col.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink0,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(context.s.saveChanges,
                    style: const TextStyle(fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
