import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Skip arrow
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.arrow_forward,
                      size: 22, color: context.col.ink2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Greeting + title + subtitle
              Text(context.s.authHi,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: context.col.ink0, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(context.s.authTitle,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: context.col.ink0, height: 1.3)),
              const SizedBox(height: 10),
              Text(context.s.authSub,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                  fontSize: 14.5, color: context.col.ink2, height: 1.55)),

              const SizedBox(height: 28),

              // 3 benefit cards
              Row(children: [
                _BenefitCard(icon: Icons.card_giftcard_outlined, label: context.s.authBenefit1),
                const SizedBox(width: 10),
                _BenefitCard(icon: Icons.inventory_2_outlined,   label: context.s.authBenefit2),
                const SizedBox(width: 10),
                _BenefitCard(icon: Icons.favorite_border_rounded, label: context.s.authBenefit3),
              ]),

              const SizedBox(height: 32),

              // Sign in button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => safePush(context, '/phone-signin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.s.signIn,
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontWeight: FontWeight.w800, fontSize: 15,
                      color: Colors.white)),
                ),
              ),

              const SizedBox(height: 10),

              // Create account button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => safePush(context, '/phone-signin'),
                  icon: Icon(Icons.person_add_outlined,
                    size: 18, color: context.col.ink1),
                  label: Text(context.s.createAccount,
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontWeight: FontWeight.w700, fontSize: 15,
                      color: context.col.ink0)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.col.borderStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Continue as guest
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.s.continueGuest,
                      style: TextStyle(
                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: context.col.ink2,
                        decoration: TextDecoration.underline,
                        decorationColor: context.col.ink2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BenefitCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 10),
          Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontSize: 11.5, fontWeight: FontWeight.w600,
              color: context.col.ink1, height: 1.3)),
        ]),
      ),
    );
  }
}
