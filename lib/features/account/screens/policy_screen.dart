import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

enum PolicyType { privacy, terms, returnPolicy }

class PolicyScreen extends ConsumerWidget {
  final PolicyType type;
  const PolicyScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(appPagesProvider);
    final isAr = context.isAr;

    final title = switch (type) {
      PolicyType.privacy    => isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
      PolicyType.terms      => isAr ? 'الشروط والأحكام' : 'Terms of Service',
      PolicyType.returnPolicy => isAr ? 'سياسة الإرجاع' : 'Return Policy',
    };

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(title,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: _buildBody(context, pages, isAr),
    );
  }

  Widget _buildBody(BuildContext context, AppPages pages, bool isAr) {
    switch (type) {
      case PolicyType.returnPolicy:
        return _ReturnPolicyBody(sections: pages.returnSections, isAr: isAr);
      case PolicyType.privacy:
        final content = isAr
            ? pages.privacyAr
            : (pages.privacyEn.isNotEmpty ? pages.privacyEn : context.s.privacyPolicyEn);
        return _TextBody(content: content);
      case PolicyType.terms:
        final content = isAr
            ? pages.termsAr
            : (pages.termsEn.isNotEmpty ? pages.termsEn : context.s.termsOfServiceEn);
        return _TextBody(content: content);
    }
  }
}

class _TextBody extends StatelessWidget {
  final String content;
  const _TextBody({required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: paragraphs.length,
      itemBuilder: (_, i) {
        final para = paragraphs[i].trim();
        final isHeader = !para.startsWith('•') && para.length < 60 && !para.contains('\n');
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            para,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: isHeader ? 15 : 13.5,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
              color: isHeader ? context.col.ink0 : context.col.ink1,
              height: 1.7,
            ),
          ),
        );
      },
    );
  }
}

class _ReturnPolicyBody extends StatelessWidget {
  final List<Map<String, String>> sections;
  final bool isAr;
  const _ReturnPolicyBody({required this.sections, required this.isAr});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = sections[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.col.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isAr ? (s['title_ar'] ?? '') : (s['title_en']?.isNotEmpty == true ? s['title_en']! : (s['title_ar'] ?? '')),
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Text(isAr ? (s['body_ar'] ?? '') : (s['body_en']?.isNotEmpty == true ? s['body_en']! : (s['body_ar'] ?? '')),
                  style: TextStyle(
                      fontSize: 13, color: context.col.ink2, height: 1.6)),
            ],
          ),
        );
      },
    );
  }
}
