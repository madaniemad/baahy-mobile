import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _ctrl.text.trim();
    if (phone.length < 9) {
      setState(() => _error = 'أدخل رقم هاتف صحيح');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).requestOtp(phone);
      if (mounted) context.push('/otp', extra: phone);
    } catch (e) {
      setState(() => _error = 'تعذر الإرسال، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.close, color: AppColors.ink0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('تسجيل الدخول',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('أدخل رقم هاتفك وسنرسل لك رمز التحقق',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.ink2)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _error != null ? AppColors.danger : AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                    child: const Text('+218',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16,
                        fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: '091 234 5678',
                        hintStyle: TextStyle(color: AppColors.ink4),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            AppButton(label: 'إرسال الرمز', onTap: _send, loading: _loading),
          ],
        ),
      ),
    );
  }
}
