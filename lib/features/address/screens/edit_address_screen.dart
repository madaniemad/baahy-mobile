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
  late String _label;
  late final _cityCtrl = TextEditingController(text: widget.address?['city'] ?? '');
  late final _districtCtrl = TextEditingController(text: widget.address?['district'] ?? '');
  late final _streetCtrl = TextEditingController(text: widget.address?['street'] ?? '');
  late final _notesCtrl = TextEditingController(text: widget.address?['notes'] ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.address?['phone'] ?? '');
  late final _nameCtrl = TextEditingController(text: widget.address?['name'] ?? '');
  late bool _isDefault = widget.address?['is_default'] == true;
  bool _loading = false;

  static const _labels = [
    ('المنزل', Icons.home_outlined),
    ('المكتب', Icons.business_outlined),
    ('أخرى',  Icons.location_on_outlined),
  ];

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.address?['label'] as String?;
    _label = existing != null && _labels.any((l) => l.$1 == existing)
        ? existing
        : _labels[0].$1;
  }

  @override
  void dispose() {
    for (final c in [_cityCtrl, _districtCtrl, _streetCtrl, _notesCtrl, _phoneCtrl, _nameCtrl]) {
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
      'label': _label,
      'name': _nameCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'district': _districtCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
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
        title: Text(_isEdit ? 'تعديل عنوان' : 'عنوان جديد',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Label selector
              _FieldLabel('التسمية'),
              Row(children: _labels.map((l) {
                final isSelected = _label == l.$1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: l.$1 != _labels.last.$1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _label = l.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEAF8F8) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(l.$2, size: 18, color: AppColors.ink1),
                          const SizedBox(height: 4),
                          Text(l.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 16),

              _TextField('الاسم الكامل', _nameCtrl, hint: 'محمد علي'),
              _TextField('رقم الهاتف', _phoneCtrl,
                keyboardType: TextInputType.phone, hint: '+218 91 234 5678'),
              Row(children: [
                Expanded(child: _TextField('المدينة', _cityCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _TextField('الحي', _districtCtrl, hint: 'الأندلس')),
              ]),
              _TextField('الشارع، المبنى، الشقة', _streetCtrl,
                hint: 'شارع 7 أبريل، مبنى 12، شقة 4'),
              _FieldLabel('📍 ملاحظات معلم بارز (مستحسن)'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'مثل: "مقابل المسجد الأبيض، بجانب مخبز المدينة"',
                    hintStyle: TextStyle(color: AppColors.ink3, fontSize: 12.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'يساعد سائقينا في الوصول إليك بسرعة. أفضل نصيحة للعنوان في ليبيا.',
                style: TextStyle(fontSize: 11, color: AppColors.ink3, height: 1.4)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _isDefault = !_isDefault),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: _isDefault ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isDefault ? AppColors.primary : AppColors.borderStrong,
                        width: 1.5),
                    ),
                    child: _isDefault
                        ? const Icon(Icons.check_rounded, size: 13, color: AppColors.ink0)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Text('تعيين كعنوان افتراضي',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 80),
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16,
            MediaQuery.of(context).padding.bottom + 16),
          child: AppButton(
            label: _isEdit ? 'حفظ التغييرات' : 'حفظ العنوان',
            onTap: _save, loading: _loading),
        ),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
        color: AppColors.ink2)),
  );
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? hint;
  const _TextField(this.label, this.controller,
    {this.keyboardType = TextInputType.text, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label),
      Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.ink3, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    ]),
  );
}
