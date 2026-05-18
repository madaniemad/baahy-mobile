import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  List<Map<String, dynamic>> _cities = [];
  bool _loading = true;
  String _query = '';

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
        _cities = data.map((c) =>
          {'id': c['id'], 'name': c['city'] ?? c['name'] ?? ''}).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _cities;
    return _cities.where((c) =>
      c['name'].toString().contains(_query)).toList();
  }

  Future<void> _pick(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', cityName);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Brand header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('baahy',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: AppColors.primary, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              const Text('إلى أي مدينة نوصّل؟',
                style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 4),
              const Text('اختر مدينتك — الأسعار والشحن ووقت الوصول تتحدّث مباشرةً.',
                style: TextStyle(fontSize: 14, color: AppColors.ink2)),
            ]),
          ),

          const SizedBox(height: 16),

          // GPS button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _pick('طرابلس'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.location_on_outlined,
                      color: AppColors.ink0, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('استخدم موقعي',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('ضغطة واحدة · وصول دقيق',
                        style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
                ]),
              ),
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('أو اختر',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    letterSpacing: 1, color: AppColors.ink3)),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ]),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن مدينة…',
                  hintStyle: TextStyle(color: AppColors.ink3, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink3, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Cities list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final city = _filtered[i];
                      final name = city['name'].toString();
                      return GestureDetector(
                        onTap: () => _pick(name),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSoft, shape: BoxShape.circle),
                              child: const Icon(Icons.location_on_outlined,
                                size: 16, color: AppColors.ink2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                              color: AppColors.ink3, size: 18),
                          ]),
                        ),
                      );
                    },
                  ),
          ),

          // Skip
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16,
              MediaQuery.of(context).padding.bottom + 16),
            child: Center(
              child: GestureDetector(
                onTap: () => _pick('كل ليبيا'),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('تخطي — اعرض كل شيء',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.ink2)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
