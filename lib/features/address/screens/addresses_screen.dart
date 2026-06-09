import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

final _addressesProvider =
    StateNotifierProvider<_AddressesNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return _AddressesNotifier();
});

class _AddressesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  _AddressesNotifier() : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      state = AsyncData((res.data['data'] as List?)
          ?.map((a) => Map<String, dynamic>.from(a)).toList() ?? []);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> setDefault(int id) async {
    await ApiClient.instance.dio.put('/addresses/$id/default');
    await load();
  }

  Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/addresses/$id');
    await load();
  }
}

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(_addressesProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.col.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.col.ink0)),
        title: Text(context.s.addressesTitle,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            onPressed: () async {
              await safePush(context, '/addresses/edit');
              ref.read(_addressesProvider.notifier).load();
            },
            icon: Icon(Icons.add_rounded, size: 22, color: context.col.ink0)),
        ],
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(child: Text(context.s.loadAddressesFailed)),
        data: (addresses) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: [
            // ── Info banner ───────────────────────────────────────────────
            _InfoBanner(),

            const SizedBox(height: 20),

            // ── Section title ─────────────────────────────────────────────
            if (addresses.isNotEmpty) ...[
              Text(
                context.tr('عناويني المحفوظة', 'Saved Addresses'),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: context.col.ink0, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 12),
            ],

            // ── Address cards ─────────────────────────────────────────────
            ...addresses.map((addr) => _AddressCard(
              addr: addr,
              onEdit: () async {
                await safePush(context, '/addresses/edit', extra: addr);
                ref.read(_addressesProvider.notifier).load();
              },
              onSetDefault: addr['is_default'] == true ? null : () =>
                ref.read(_addressesProvider.notifier).setDefault(addr['id'] as int),
              onDelete: addr['is_default'] == true ? null : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(context.s.deleteAddrTitle,
                      style: const TextStyle(fontFamily: 'Cairo')),
                    content: Text(context.s.deleteAddrConf),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text(context.s.cancel)),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text(context.s.deleteAddress,
                          style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) {
                  ref.read(_addressesProvider.notifier).delete(addr['id'] as int);
                }
              },
            )),

            // ── Add new address ───────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                await safePush(context, '/addresses/edit');
                ref.read(_addressesProvider.notifier).load();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: context.col.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, size: 18, color: context.col.ink1),
                  const SizedBox(width: 6),
                  Text(context.s.addNewAddress,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: context.col.ink0, fontFamily: 'Cairo')),
                ]),
              ),
            ),

            // ── Delivery tip card ─────────────────────────────────────────
            _DeliveryTipCard(),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(children: [
        // Text (first child = RIGHT in RTL)
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              Text(
                context.tr('اختر عنواناً سريعاً عند الطلب', 'Choose an address at checkout'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: context.col.ink0, fontFamily: 'Cairo'),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
            ]),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'سيتم استخدام العنوان المحدد عند إتمام الطلب',
                'The selected address will be used when placing your order'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: context.col.ink2,
                fontFamily: 'Cairo', height: 1.5),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        // Pin icon only (second child = LEFT in RTL)
        Icon(Icons.location_on_rounded, size: 44, color: context.col.ink2),
      ]),
    );
  }
}

// ── Address card ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> addr;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;
  const _AddressCard({
    required this.addr, required this.onEdit,
    this.onSetDefault, this.onDelete});

  IconData _labelIcon(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('home') || r.contains('منزل')) return Icons.home_rounded;
    if (r.contains('office') || r.contains('مكتب')) return Icons.business_rounded;
    if (r.contains('family') || r.contains('عائلة')) return Icons.home_work_rounded;
    return Icons.location_on_rounded;
  }

  void _share(BuildContext context) {
    final label = context.s.translateAddrLabel(
      (addr['label'] as String?)?.isNotEmpty == true
        ? addr['label'] as String : context.s.addrLabel);
    final parts = [
      label,
      if (addr['name'] != null) addr['name'] as String,
      if (addr['phone'] != null) addr['phone'] as String,
      if (addr['city'] != null) addr['city'] as String,
      if (addr['district'] != null) addr['district'] as String,
      if (addr['street'] != null) addr['street'] as String,
      if (addr['notes'] != null && addr['notes'].toString().isNotEmpty)
        addr['notes'] as String,
    ];
    Share.share(parts.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = addr['is_default'] == true;
    final rawLabel = (addr['label'] as String?) ?? '';
    final label = context.s.translateAddrLabel(
        rawLabel.isNotEmpty ? rawLabel : context.s.addrLabel);
    final city = (addr['city'] as String?) ?? '';
    final district = (addr['district'] as String?) ?? '';
    final street = (addr['street'] as String?) ?? '';
    final cityLine = [city, district].where((s) => s.isNotEmpty).join('، ');
    final name = (addr['name'] as String?) ?? '';
    final phone = (addr['phone'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isDefault ? AppColors.primary : context.col.border,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row (RTL): right=icon+label, left=name+phone
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First child = RIGHT in RTL: icon box + label/city/street
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: context.col.surfaceSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_labelIcon(rawLabel), size: 22,
                              color: isDefault ? AppColors.primary : context.col.ink2),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: context.col.ink0, fontFamily: 'Cairo')),
                              if (cityLine.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(cityLine,
                                  style: TextStyle(fontSize: 12.5,
                                    color: context.col.ink2, fontFamily: 'Cairo')),
                              ],
                              if (street.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(street,
                                  style: TextStyle(fontSize: 12.5,
                                    color: context.col.ink2, fontFamily: 'Cairo')),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Second child = LEFT in RTL: name + phone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (name.isNotEmpty)
                              Text(name,
                                textAlign: TextAlign.end,
                                style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600, color: context.col.ink1,
                                  fontFamily: 'Cairo')),
                            if (phone.isNotEmpty)
                              Text(phone,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.end,
                                style: TextStyle(fontSize: 13,
                                  color: context.col.ink2, fontFamily: 'PlusJakartaSans')),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (addr['notes'] != null && addr['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('📍 ${addr['notes']}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF7a5e10))),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom action row
                  Row(children: [
                    // Delete (only non-default)
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                            size: 17, color: AppColors.danger),
                        ),
                      ),
                    if (onDelete != null) const SizedBox(width: 8),

                    // Edit
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: context.col.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_outlined, size: 13, color: context.col.ink1),
                          const SizedBox(width: 4),
                          Text(context.s.editLabel,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                              color: context.col.ink1, fontFamily: 'Cairo')),
                        ]),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Share
                    GestureDetector(
                      onTap: () => _share(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: context.col.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.ios_share_outlined, size: 13, color: context.col.ink1),
                          const SizedBox(width: 4),
                          Text(context.tr('مشاركة', 'Share'),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                              color: context.col.ink1, fontFamily: 'Cairo')),
                        ]),
                      ),
                    ),

                    const Spacer(),

                    // Radio / set default
                    GestureDetector(
                      onTap: onSetDefault,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDefault ? AppColors.primary : context.col.ink3,
                            width: isDefault ? 2 : 1.5),
                          color: isDefault
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        ),
                        child: isDefault
                          ? Center(child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle),
                            ))
                          : null,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ── Delivery tip card ─────────────────────────────────────────────────────────

class _DeliveryTipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.col.border),
      ),
      child: Row(children: [
        // Text (first child = RIGHT in RTL)
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              context.tr('توصيل أسرع لليبيا', 'Faster delivery in Libya'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: context.col.ink0, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'أضف عناوين متعددة للوصول إليك بسرعة، أقرب، وأكثر دقة.',
                'Add multiple addresses to reach you faster, closer, and more accurately.'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: context.col.ink2,
                fontFamily: 'Cairo', height: 1.5),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // Truck illustration (second child = LEFT in RTL)
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_shipping_outlined, size: 30, color: context.col.ink2),
        ),
      ]),
    );
  }
}
