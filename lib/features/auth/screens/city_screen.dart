import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  String? _selected;
  List<Map<String, dynamic>> _cities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final res = await ApiClient.instance.dio.get('/shipping');
      final data = res.data['data'] as List? ?? [];
      setState(() {
        _cities = data.map((c) => {'id': c['id'], 'name': c['city'] ?? c['name'] ?? ''}).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', _selected!);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'أهلاً بك في باهي',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر مدينتك لنعرض لك العروض والشحن المتاح',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.ink2),
              ),
              const SizedBox(height: 32),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _cities.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final city = _cities[i];
                      final name = city['name'].toString();
                      final isSelected = _selected == name;
                      return ListTile(
                        title: Text(name,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.ink0,
                          )),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () => setState(() => _selected = name),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              AppButton(
                label: 'تأكيد',
                onTap: _selected != null ? _confirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
