import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  String? _error;
  bool _available = false;
  bool _checking  = false;
  bool _saving    = false;
  Timer? _debounce;

  static final _validPattern = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() { _available = false; _error = null; });
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length < 3) { setState(() => _error = 'min3'); return; }
    if (!_validPattern.hasMatch(trimmed)) { setState(() => _error = 'invalid'); return; }
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 600), () => _checkAvailability(trimmed));
  }

  Future<void> _checkAvailability(String username) async {
    try {
      final res = await ApiClient.instance.dio.get('/users/search', queryParameters: {'q': username, 'exact': '1'});
      final data = res.data['data'] as List? ?? [];
      setState(() {
        _checking  = false;
        _available = data.isEmpty;
        _error     = data.isEmpty ? null : 'taken';
      });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      setState(() { _checking = false; });
    }
  }

  Future<void> _save() async {
    final username = _controller.text.trim();
    if (!_available || username.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.patch('/user/username', data: {'username': username});
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      setState(() { _saving = false; _error = 'saveFailed'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final canSave = _available && value.length >= 3 && !_saving && !_checking;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.tr('اختر اسم مستخدم', 'Choose Username'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.alternate_email, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(context.tr('اسم مستخدم فريد', 'Unique Username'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'يستخدمه أصدقاؤك للعثور عليك. 3-30 حرف، أرقام وشرطة سفلية فقط.',
              'Friends use this to find you. 3–30 chars, letters, numbers and underscore only.',
            ),
            style: TextStyle(fontSize: 13, color: context.col.ink2, fontFamily: 'Cairo', height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textDirection: TextDirection.ltr,
            onChanged: _onChanged,
            decoration: InputDecoration(
              prefixText: '@',
              prefixStyle: TextStyle(color: context.col.ink2, fontSize: 16, fontWeight: FontWeight.w600),
              hintText: 'username',
              hintStyle: TextStyle(color: context.col.ink4),
              filled: true,
              fillColor: context.col.surfaceSoft,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _errorColor, width: 1.5),
              ),
              suffixIcon: _suffixIcon(),
              errorText: _errorText(context),
            ),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, letterSpacing: 0.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.col.surfaceSoft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(context.tr('تأكيد', 'Confirm'),
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Color get _errorColor {
    if (_error != null) return AppColors.danger;
    if (_available) return AppColors.success;
    return AppColors.primary;
  }

  Widget? _suffixIcon() {
    if (_checking) return const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    if (_available) return const Icon(Icons.check_circle, color: AppColors.success);
    if (_error == 'taken') return const Icon(Icons.cancel, color: AppColors.danger);
    return null;
  }

  String? _errorText(BuildContext context) {
    return switch (_error) {
      'taken'      => context.tr('هذا الاسم محجوز', 'This username is taken'),
      'min3'       => context.tr('3 أحرف على الأقل', 'At least 3 characters'),
      'invalid'    => context.tr('أحرف وأرقام وشرطة سفلية فقط', 'Letters, numbers and underscore only'),
      'saveFailed' => context.tr('فشل الحفظ، حاول مجدداً', 'Save failed, try again'),
      _            => null,
    };
  }
}
