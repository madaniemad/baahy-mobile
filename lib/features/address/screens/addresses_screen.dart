import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        backgroundColor: context.col.surface, elevation: 0,
        title: Text(context.s.addressesTitle,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(child: Text(context.s.loadAddressesFailed)),
        data: (addresses) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Address cards
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
                    title: Text(context.s.deleteAddrTitle, style: const TextStyle(fontFamily: 'Cairo')),
                    content: Text(context.s.deleteAddrConf),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text(context.s.cancel)),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text(context.s.deleteAddress, style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) {
                  ref.read(_addressesProvider.notifier).delete(addr['id'] as int);
                }
              },
            )),

            // Add new
            GestureDetector(
              onTap: () async {
                await safePush(context, '/addresses/edit');
                ref.read(_addressesProvider.notifier).load();
              },
              child: Container(
                margin: EdgeInsets.only(top: addresses.isEmpty ? 0 : 6, bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.col.borderStrong,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, size: 18, color: context.col.ink2),
                  const SizedBox(width: 8),
                  Text(context.s.addNewAddress,
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.col.ink1)),
                ]),
              ),
            ),

            // Libya tip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.col.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.s.libyaLandmarkTip,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: context.col.ink1)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> addr;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;
  const _AddressCard({
    required this.addr, required this.onEdit,
    this.onSetDefault, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDefault = addr['is_default'] == true;
    final rawLabel = (addr['label'] as String?) ?? '';
    final label = context.s.translateAddrLabel(rawLabel.isNotEmpty ? rawLabel : context.s.addrLabel);
    final icon = (rawLabel == 'Home' || rawLabel == 'المنزل')
        ? Icons.home_outlined
        : (rawLabel == 'Office' || rawLabel == 'المكتب')
            ? Icons.business_outlined
            : Icons.location_on_outlined;
    final address = [addr['city'], addr['district'], addr['street']]
        .where((v) => v != null && v.toString().isNotEmpty).join('، ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault ? context.col.surfaceSoft : context.col.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDefault ? AppColors.primary : context.col.border,
          width: isDefault ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6)),
              child: Text(context.s.defaultAddr,
                style: TextStyle(color: context.col.ink0,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        if (addr['name'] != null || addr['phone'] != null)
          Text('${addr['name'] ?? ''} · ${addr['phone'] ?? ''}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(address,
            style: TextStyle(fontSize: 12.5, color: context.col.ink2, height: 1.4)),
        ],
        if (addr['notes'] != null && addr['notes'].toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('📍 ${addr['notes']}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF7a5e10))),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          _ActionBtn(
            icon: Icons.edit_outlined, label: context.s.editLabel, onTap: onEdit),
          if (onSetDefault != null) ...[
            const SizedBox(width: 8),
            _ActionBtn(label: context.s.makeDefaultLabel, onTap: onSetDefault!),
          ],
          if (onDelete != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.danger)),
          ],
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: context.col.ink1),
            const SizedBox(width: 4),
          ],
          Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: context.col.ink1)),
        ]),
      ),
    );
  }
}
