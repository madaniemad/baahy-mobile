import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({required this.phone, super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _focuses) f.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).verifyOtp(widget.phone, _code);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() { _error = 'الرمز غير صحيح، حاول مجدداً'; _loading = false; });
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
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text('رمز التحقق',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'أرسلنا رمز مكون من 6 أرقام إلى ${widget.phone}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.ink2),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => SizedBox(
                width: 44,
                height: 54,
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _focuses[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    fontFamily: 'PlusJakartaSans'),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.bg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      _focuses[i + 1].requestFocus();
                    }
                    if (v.isEmpty && i > 0) {
                      _focuses[i - 1].requestFocus();
                    }
                    if (_code.length == 6) _verify();
                  },
                ),
              )),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13),
                textAlign: TextAlign.center),
            ],
            const SizedBox(height: 32),
            AppButton(label: 'تحقق', onTap: _verify, loading: _loading),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => ref.read(authProvider.notifier).requestOtp(widget.phone),
                child: const Text('إعادة إرسال الرمز',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
