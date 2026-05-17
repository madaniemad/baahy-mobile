import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  static const _suggestions = [
    'عطور', 'ساعات', 'ملابس نسائية', 'أحذية', 'حقائب', 'إلكترونيات',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) {
    if (q.trim().isEmpty) return;
    context.push('/search/results?q=${Uri.encodeComponent(q.trim())}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'ابحث عن منتج...',
              hintStyle: TextStyle(color: AppColors.ink3),
              prefixIcon: Icon(Icons.search, color: AppColors.ink3, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: _search,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.ink1, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اقتراحات',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink2)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) => GestureDetector(
                onTap: () => _search(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
