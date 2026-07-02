import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  String _wishlist  = 'friends';
  String _purchases = 'friends';
  String _reviews   = 'public';
  String _tier      = 'friends';
  bool   _saving    = false;

  @override
  void initState() {
    super.initState();
    _loadFromUser();
  }

  void _loadFromUser() {
    final user = ref.read(authProvider).user;
    _wishlist  = user?.privacyWishlist  ?? 'friends';
    _purchases = user?.privacyPurchases ?? 'friends';
    _reviews   = user?.privacyReviews   ?? 'public';
    _tier      = user?.privacyTier      ?? 'friends';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.tr('إعدادات الخصوصية', 'Privacy Settings'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
              : TextButton(
                  onPressed: _save,
                  child: Text(context.tr('حفظ', 'Save'),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: context.tr('من يمكنه رؤية...', 'Who can see...')),
          const SizedBox(height: 8),
          _PrivacyTile(
            icon: Icons.favorite_border,
            label: context.tr('قائمة الرغبات', 'Wishlist'),
            value: _wishlist,
            options: const ['friends', 'nobody'],
            optionLabels: const {'friends': 'أصدقاء / Friends', 'nobody': 'لا أحد / Nobody'},
            onChanged: (v) => setState(() => _wishlist = v),
          ),
          _PrivacyTile(
            icon: Icons.shopping_bag_outlined,
            label: context.tr('المشتريات', 'Purchases'),
            value: _purchases,
            options: const ['friends', 'nobody'],
            optionLabels: const {'friends': 'أصدقاء / Friends', 'nobody': 'لا أحد / Nobody'},
            onChanged: (v) => setState(() => _purchases = v),
          ),
          _PrivacyTile(
            icon: Icons.star_border,
            label: context.tr('التقييمات', 'Reviews'),
            value: _reviews,
            options: const ['public', 'friends', 'nobody'],
            optionLabels: const {
              'public':  'الجميع / Public',
              'friends': 'أصدقاء / Friends',
              'nobody':  'لا أحد / Nobody',
            },
            onChanged: (v) => setState(() => _reviews = v),
          ),
          _PrivacyTile(
            icon: Icons.workspace_premium_outlined,
            label: context.tr('درجة العضوية', 'Tier Badge'),
            value: _tier,
            options: const ['friends', 'nobody'],
            optionLabels: const {'friends': 'أصدقاء / Friends', 'nobody': 'لا أحد / Nobody'},
            onChanged: (v) => setState(() => _tier = v),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.patch('/user/privacy', data: {
        'privacy_wishlist':  _wishlist,
        'privacy_purchases': _purchases,
        'privacy_reviews':   _reviews,
        'privacy_tier':      _tier,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('تم الحفظ', 'Saved'), style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success, duration: const Duration(seconds: 2)),
        );
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('حدث خطأ', 'Error occurred'), style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: context.col.ink3, fontWeight: FontWeight.w600)),
  );
}

class _PrivacyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final Map<String, String> optionLabels;
  final ValueChanged<String> onChanged;

  const _PrivacyTile({
    required this.icon, required this.label, required this.value,
    required this.options, required this.optionLabels, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: context.col.ink2),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14))),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: context.col.ink1),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(optionLabels[o] ?? o))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ]),
    );
  }
}
