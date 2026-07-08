import 'package:flutter/material.dart';
import '../../core/utils/l10n.dart';
import '../theme/app_theme.dart';

/// baahy+ — the "fulfilled by baahy" premium program.
/// Products in the program are stocked, inspected and shipped by baahy itself:
/// faster delivery, guaranteed-authentic, easy returns, priority support.
///
/// This file owns the visual language of the program in one place:
///   • [BaahyPlusBadge]  — the compact brand mark used on product cards / detail
///   • [showBaahyPlusSheet] — the explainer bottom sheet (tap the badge)
class BaahyPlusBadge extends StatelessWidget {
  /// Height of the wordmark glyphs. Card ≈ 12, detail ≈ 15.
  final double height;

  /// When true the badge is tappable and opens the benefits sheet.
  final bool tappable;

  const BaahyPlusBadge({super.key, this.height = 12, this.tappable = false});

  static const double _ratio = 925 / 268; // trimmed asset aspect ratio

  @override
  Widget build(BuildContext context) {
    final badge = Image.asset(
      'assets/images/baahy_plus.png',
      height: height,
      width: height * _ratio,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!tappable) return badge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showBaahyPlusSheet(context),
      child: Padding(
        // small hit-area padding without a visible pill
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: badge,
      ),
    );
  }
}

/// Bottom sheet that explains what the baahy+ program guarantees the customer.
Future<void> showBaahyPlusSheet(BuildContext context) {
  final isAr = context.isAr;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final col = ctx.col;
      final benefits = <_PlusBenefit>[
        _PlusBenefit(
          icon: Icons.rocket_launch_rounded,
          titleAr: 'توصيل أسرع',
          titleEn: 'Faster delivery',
          bodyAr: 'يُشحن من مستودعات باهي — جاهز للتوصيل فور طلبه.',
          bodyEn: 'Shipped straight from baahy warehouses — ready to go the moment you order.',
        ),
        _PlusBenefit(
          icon: Icons.verified_rounded,
          titleAr: 'أصلي ومضمون',
          titleEn: 'Authentic & guaranteed',
          bodyAr: 'تم فحص كل منتج وتخزينه لدى باهي لضمان جودته وأصالته.',
          bodyEn: 'Every item is inspected and stored by baahy for guaranteed quality.',
        ),
        _PlusBenefit(
          icon: Icons.assignment_return_rounded,
          titleAr: 'إرجاع سهل',
          titleEn: 'Easy returns',
          bodyAr: 'إرجاع بدون تعقيد خلال فترة السماح، تتكفل باهي بالباقي.',
          bodyEn: 'Hassle-free returns within the return window — baahy handles the rest.',
        ),
        _PlusBenefit(
          icon: Icons.support_agent_rounded,
          titleAr: 'دعم أولوية',
          titleEn: 'Priority support',
          bodyAr: 'طلبات باهي+ لها الأولوية في خدمة العملاء والمتابعة.',
          bodyEn: 'baahy+ orders get priority in customer service and follow-up.',
        ),
      ];

      return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: col.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: col.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Image.asset('assets/images/baahy_plus.png',
                    height: 30, fit: BoxFit.contain),
              ),
              const SizedBox(height: 10),
              Text(
                isAr
                    ? 'منتجات يوفّرها ويشحنها باهي مباشرةً'
                    : 'Products stocked & shipped by baahy itself',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: col.ink2),
              ),
              const SizedBox(height: 20),
              ...benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(b.icon, size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isAr ? b.titleAr : b.titleEn,
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: col.ink0)),
                              const SizedBox(height: 3),
                              Text(isAr ? b.bodyAr : b.bodyEn,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: col.ink2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(isAr ? 'فهمت' : 'Got it',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PlusBenefit {
  final IconData icon;
  final String titleAr, titleEn, bodyAr, bodyEn;
  const _PlusBenefit({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });
}
