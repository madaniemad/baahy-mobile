import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;
  const EditAddressScreen({this.address, super.key});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  late final _labelCtrl = TextEditingController(text: widget.address?['label'] ?? '');
  late final _cityCtrl = TextEditingController(text: widget.address?['city'] ?? '');
  late final _districtCtrl = TextEditingController(text: widget.address?['district'] ?? '');
  late final _streetCtrl = TextEditingController(text: widget.address?['street'] ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.address?['phone'] ?? '');
  late bool _isDefault = widget.address?['is_default'] == true;
  bool _loading = false;

  bool get _isEdit => widget.address != null;

  @override
  void dispose() {
    for (final c in [_labelCtrl, _cityCtrl, _districtCtrl, _streetCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_cityCtrl.text.trim().isEmpty || _streetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المدينة والشارع')));
      return;
    }
    setState(() => _loading = true);
    final data = {
      'label': _labelCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'is_default': _isDefault,
    };
    try {
      if (_isEdit) {
        await ApiClient.instance.dio.put('/addresses/${widget.address!['id']}', data: data);
      } else {
        await ApiClient.instance.dio.post('/addresses', data: data);
      }
      if (mounted) context.pop();
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ، حاول مجدداً')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(_isEdit ? 'تعديل العنوان' : 'إضافة عنوان',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Field('التسمية (مثال: البيت)', _labelCtrl),
                  _Field('المدينة *', _cityCtrl),
                  _Field('الحي', _districtCtrl),
                  _Field('الشارع *', _streetCtrl),
                  _Field('رقم الهاتف', _phoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v ?? false),
                    title: const Text('تعيين كعنوان افتراضي',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
            child: AppButton(label: 'حفظ', onTap: _save, loading: _loading),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  const _Field(this.label, this.controller,
    {this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.ink1)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    ),
  );
}
