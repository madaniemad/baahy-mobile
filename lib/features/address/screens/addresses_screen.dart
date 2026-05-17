import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

final _addressesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.dio.get('/addresses');
  return (res.data['data'] as List?)
      ?.map((a) => Map<String, dynamic>.from(a)).toList() ?? [];
});

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(_addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('عناويني',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
        actions: [
          IconButton(
            onPressed: () => context.push('/addresses/edit'),
            icon: const Icon(Icons.add, color: AppColors.primary)),
        ],
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('تعذر تحميل العناوين')),
        data: (addresses) => addresses.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 72, color: AppColors.ink4),
                      const SizedBox(height: 12),
                      const Text('لا توجد عناوين محفوظة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'إضافة عنوان',
                        width: 200,
                        onTap: () => context.push('/addresses/edit'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final addr = addresses[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: addr['is_default'] == true ? AppColors.primary : AppColors.border,
                        width: addr['is_default'] == true ? 2 : 1),
                      boxShadow: AppShadows.shadowCard,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(addr['label'] ?? 'عنوان',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  if (addr['is_default'] == true) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4)),
                                      child: const Text('افتراضي',
                                        style: TextStyle(fontSize: 10, color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [addr['city'], addr['district'], addr['street']]
                                  .where((v) => v != null && v.toString().isNotEmpty)
                                  .join('، '),
                                style: const TextStyle(fontSize: 13, color: AppColors.ink2),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/addresses/edit', extra: addr),
                          icon: const Icon(Icons.edit_outlined, color: AppColors.ink2, size: 20)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
