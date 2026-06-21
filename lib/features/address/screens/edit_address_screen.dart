import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/shipping_rate.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../features/map/map_location_picker.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class EditAddressScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? address;
  const EditAddressScreen({this.address, super.key});

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  late String _label;
  late String? _city;
  late final _streetCtrl = TextEditingController(
      text: widget.address?['address'] ?? widget.address?['street'] ?? '');
  late final _notesCtrl = TextEditingController(text: widget.address?['notes'] ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.address?['phone'] ?? '');
  late final _nameCtrl  = TextEditingController(text: widget.address?['name'] ?? '');
  late bool _isDefault  = widget.address == null ? true : widget.address?['is_default'] == true;
  double? _lat;
  double? _lng;
  bool _loading = false;
  final _phoneFocus = FocusNode();
  final _notesFocus = FocusNode();

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
        ? existing : _labels[0].$1;
    _city = widget.address?['city'] as String?;
    final rawLat = widget.address?['latitude'];
    final rawLng = widget.address?['longitude'];
    _lat = rawLat != null ? double.tryParse(rawLat.toString()) : null;
    _lng = rawLng != null ? double.tryParse(rawLng.toString()) : null;
    _phoneFocus.addListener(_onFocusChange);
    _notesFocus.addListener(_onFocusChange);

    if (!_isEdit) {
      // Pre-fill name + phone from user profile
      final user = ref.read(currentUserProvider);
      if (user != null) {
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = user.name;
        if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = user.phone;
      }
      // Auto-open map picker so the customer sets their pin first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMapPicker();
      });
    }
  }

  void _onFocusChange() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    for (final c in [_streetCtrl, _notesCtrl, _phoneCtrl, _nameCtrl]) c.dispose();
    _phoneFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final initial = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : null;
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => MapLocationPicker(initial: initial)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _city = result.city;
      _lat  = result.lat;
      _lng  = result.lng;
      if (_streetCtrl.text.trim().isEmpty && result.address.isNotEmpty) {
        _streetCtrl.text = result.address;
      }
    });
  }

  Future<void> _pickCitySheet() async {
    final rates = ref.read(shippingRatesProvider).valueOrNull ?? [];
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(current: _city, rates: rates),
    );
    if (!mounted) return;
    // Clear residual keyboard focus from the sheet's search field (iOS keyboard bug)
    FocusScope.of(context).unfocus();
    if (picked != null) setState(() => _city = picked);
  }

  Future<void> _save() async {
    if (_city == null || _streetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.selectCityAndStreet)));
      return;
    }
    setState(() => _loading = true);
    final data = {
      'label':      _label,
      'name':       _nameCtrl.text.trim(),
      'city':       _city,
      'address':    _streetCtrl.text.trim(),
      'notes':      _notesCtrl.text.trim(),
      'phone':      _phoneCtrl.text.trim(),
      'is_default': _isDefault,
      if (_lat != null) 'latitude':  _lat,
      if (_lng != null) 'longitude': _lng,
    };
    try {
      if (_isEdit) {
        await ApiClient.instance.dio.put('/addresses/${widget.address!['id']}', data: data);
      } else {
        await ApiClient.instance.dio.post('/addresses', data: data);
      }
      // If saved as default, update the city pill in the home header
      if (_isDefault && _city != null) {
        await ref.read(cityProvider.notifier).setCity(_city!);
      } else {
        ref.read(cityProvider.notifier).refresh();
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e))));
      }
    }
  }

  String _extractError(Object e) {
    try {
      final dynamic err = e;
      final resp = err.response;
      if (resp != null) {
        final data = resp.data;
        if (data is Map) {
          final msg = data['message'] ?? data['error'];
          if (msg != null) return msg.toString();
          final errors = data['errors'];
          if (errors is Map) return errors.values.first.toString();
        }
      }
    } catch (_) {}
    return 'حدث خطأ، حاول مجدداً';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.col.surface,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        title: Text(_isEdit ? 'تعديل عنوان' : 'عنوان جديد',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Label selector ─────────────────────────────────────────────
              const _FieldLabel('التسمية'),
              Row(children: _labels.map((l) {
                final isSelected = _label == l.$1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: l.$1 != _labels.last.$1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _label = l.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : const Color(0xFFF5F5F5))
                              : context.col.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : context.col.border,
                            width: isSelected ? 1.5 : 1),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(l.$2, size: 18, color: context.col.ink1),
                          const SizedBox(height: 4),
                          Text(l.$1, style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 16),

              _TextField('الاسم الكامل', _nameCtrl, hint: 'محمد علي', autofocus: true),

              // ── Phone ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _FieldLabel('رقم الهاتف'),
                  Container(
                    decoration: BoxDecoration(
                      color: context.col.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _phoneFocus.hasFocus ? AppColors.primary : context.col.border,
                        width: _phoneFocus.hasFocus ? 1.5 : 1),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        controller: _phoneCtrl,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: '+218 91 234 5678',
                          hintStyle: TextStyle(color: context.col.ink3, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── City — GPS + tap to pick ───────────────────────────────────
              const _FieldLabel('المدينة'),
              Row(children: [
                // City display / picker
                Expanded(
                  child: GestureDetector(
                    onTap: _pickCitySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: context.col.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _city != null ? AppColors.primary : context.col.border,
                          width: _city != null ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            _city ?? 'اختر مدينة',
                            style: TextStyle(
                              fontSize: 14,
                              color: _city != null ? context.col.ink0 : context.col.ink3,
                              fontWeight: _city != null
                                  ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded,
                          color: context.col.ink3, size: 20),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // ── Map pin ────────────────────────────────────────────────────
              GestureDetector(
                onTap: _openMapPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _lat != null
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : context.col.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _lat != null ? AppColors.primary : context.col.border,
                      width: _lat != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _lat != null ? Icons.location_on : Icons.add_location_alt_outlined,
                      color: _lat != null ? AppColors.primary : context.col.ink3,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lat != null
                            ? 'موقع محدد على الخريطة ✓'
                            : 'تحديد موقع التوصيل على الخريطة',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _lat != null ? FontWeight.w600 : FontWeight.normal,
                          color: _lat != null ? AppColors.primary : context.col.ink2,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.col.ink3, size: 18),
                  ]),
                ),
              ),
              if (_lat != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => setState(() { _lat = null; _lng = null; }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('إزالة الموقع', style: TextStyle(
                      fontSize: 11, color: context.col.ink3)),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              _TextField('الشارع، المبنى، الشقة', _streetCtrl,
                hint: 'شارع 7 أبريل، مبنى 12، شقة 4'),

              const _FieldLabel('📍 ملاحظات معلم بارز (مستحسن)'),
              Container(
                decoration: BoxDecoration(
                  color: context.col.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _notesFocus.hasFocus ? AppColors.primary : context.col.border,
                    width: _notesFocus.hasFocus ? 1.5 : 1),
                ),
                child: TextField(
                  controller: _notesCtrl,
                  focusNode: _notesFocus,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'مثل: "مقابل المسجد الأبيض، بجانب مخبز المدينة"',
                    hintStyle: TextStyle(color: context.col.ink3, fontSize: 12.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يساعد سائقينا في الوصول إليك بسرعة.',
                style: TextStyle(fontSize: 11, color: context.col.ink3, height: 1.4)),
              const SizedBox(height: 16),

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

// ── City picker bottom sheet ──────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final String? current;
  final List<ShippingRate> rates;
  const _CityPickerSheet({this.current, required this.rates});
  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';
  final _ctrl = TextEditingController();

  List<ShippingRate> get _filtered => _query.isEmpty
      ? widget.rates
      : widget.rates.where((r) =>
          r.cityAr.contains(_query) ||
          r.city.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: context.col.border,
            borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 16),
        Text(context.s.selectCity,
          style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.col.border),
          ),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => _query = v),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث…',
              hintStyle: TextStyle(color: context.col.ink3, fontSize: 14),
              prefixIcon: _query.isEmpty
                  ? Icon(Icons.search_rounded, color: context.col.ink3, size: 18)
                  : GestureDetector(
                      onTap: () { _ctrl.clear(); setState(() => _query = ''); },
                      child: Icon(Icons.close_rounded,
                          color: context.col.ink3, size: 18)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (widget.rates.isEmpty)
          Expanded(child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ))
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final r = _filtered[i];
                final selected = r.cityAr == widget.current;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(r.cityAr),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(0xFFF5F5F5) : context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? AppColors.primary : context.col.border,
                        width: selected ? 1.5 : 1),
                    ),
                    child: Text(r.cityAr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : context.col.ink0,
                      )),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: context.col.ink2)),
  );
}

class _TextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? hint;
  final bool autofocus;
  const _TextField(this.label, this.controller,
    {this.keyboardType = TextInputType.text, this.hint, this.autofocus = false,
     super.key});

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(widget.label),
      Container(
        decoration: BoxDecoration(
          color: context.col.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _focused ? AppColors.primary : context.col.border,
            width: _focused ? 1.5 : 1),
        ),
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          focusNode: _focus,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: context.col.ink3, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          ),
        ),
      ),
    ]),
  );
}
