import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class _ChatMessage {
  final String role;
  final String content;
  final List<dynamic> products;
  final bool isLimitHit;
  final String? imageBase64;
  final Map<String, dynamic>? whatsappData;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.products = const [],
    this.isLimitHit = false,
    this.imageBase64,
    this.whatsappData,
  });
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  final List<Map<String, String>> _history = [];
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  XFile? _imageFile;

  late AnimationController _dotAnimCtrl;

  @override
  void initState() {
    super.initState();
    _dotAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotAnimCtrl.dispose();
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  String get _serverBase =>
      ApiClient.instance.dio.options.baseUrl.replaceAll('/api', '');

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_serverBase$path';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (img != null && mounted) {
      setState(() => _imageFile = img);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('الكاميرا',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('معرض الصور',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _send({String? overrideText}) async {
    final text = overrideText ?? _textCtrl.text.trim();
    final image = _imageFile;

    if (_loading) return;
    if (text.isEmpty && image == null) return;

    String? b64;
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      b64 = base64Encode(bytes);
    }

    setState(() {
      _messages.add(_ChatMessage(
        role: 'user',
        content: text,
        imageBase64: b64,
      ));
      _loading = true;
      _imageFile = null;
    });
    _textCtrl.clear();
    _scrollToBottom();

    // Build history: last 10 text-only exchanges
    final historyToSend = _history.length > 10
        ? _history.sublist(_history.length - 4)
        : _history;

    try {
      final body = <String, dynamic>{
        'message': text,
        'history': historyToSend,
        if (b64 != null) 'image': b64,
      };

      final res = await ApiClient.instance.dio.post('/chat', data: body);
      final data = res.data as Map<String, dynamic>;

      if (data['limit_hit'] == true) {
        final wa = data['whatsapp'] as Map<String, dynamic>?;
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: data['message'] ?? context.s.assistantLimitHit,
            isLimitHit: true,
            whatsappData: wa,
          ));
          _loading = false;
        });
        _scrollToBottom();
        return;
      }

      final reply = data['message'] as String? ?? '';
      final products = data['products'] as List<dynamic>? ?? [];

      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: reply,
          products: products,
        ));
        _loading = false;
      });

      // Update history (text only)
      if (text.isNotEmpty) _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 4);
      }

      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.s.assistantError,
              style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.s.assistantTitle,
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 0.3)),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: context.col.ink2, size: 20),
              tooltip: 'محادثة جديدة',
              onPressed: () => setState(() {
                _messages.clear();
                _history.clear();
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onChipTap: _send)
                : _MessagesList(
                    messages: _messages,
                    loading: _loading,
                    scrollCtrl: _scrollCtrl,
                    dotAnimCtrl: _dotAnimCtrl,
                    imageUrl: _imageUrl,
                  ),
          ),
          _InputBar(
            textCtrl: _textCtrl,
            loading: _loading,
            imageFile: _imageFile,
            onPickImage: _showImagePicker,
            onClearImage: () => setState(() => _imageFile = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  final void Function({String? overrideText}) onChipTap;
  const _EmptyState({required this.onChipTap});

  static const _chips = [
    (Icons.search_rounded,              'ابحث عن منتج'),
    (Icons.local_shipping_outlined,     'وين طلبي؟'),
    (Icons.assignment_return_outlined,  'سياسة الإرجاع'),
    (Icons.delivery_dining_outlined,    'رسوم التوصيل'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(homeProvider).categories;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        // Logo + greeting
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(context.s.assistantGreeting,
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink1)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _chips.map((chip) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _QuickChip(
                icon: chip.$1,
                label: chip.$2,
                onTap: () => onChipTap(overrideText: chip.$2),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Categories section header
        if (categories.isNotEmpty) ...[
          Row(children: [
            Container(width: 3, height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(context.s.browseCategories,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                fontSize: 14, color: context.col.ink0)),
          ]),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              return GestureDetector(
                onTap: () => safePush(context, '/search/results?q=&category=${cat.id}'),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: cat.image != null
                            ? CachedNetworkImage(
                                imageUrl: cat.image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.grid_view_rounded,
                                    color: AppColors.primary, size: 24)),
                              )
                            : Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.grid_view_rounded,
                                  color: AppColors.primary, size: 24)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr ? cat.nameAr : cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.col.ink0,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12,
                fontWeight: FontWeight.w600, color: context.col.ink0)),
          ],
        ),
      ),
    );
  }
}

// ── Messages List ────────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  final List<_ChatMessage> messages;
  final bool loading;
  final ScrollController scrollCtrl;
  final AnimationController dotAnimCtrl;
  final String Function(String?) imageUrl;

  const _MessagesList({
    required this.messages,
    required this.loading,
    required this.scrollCtrl,
    required this.dotAnimCtrl,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length + (loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length) {
          return _TypingIndicator(animCtrl: dotAnimCtrl);
        }
        final msg = messages[i];
        return msg.role == 'user'
            ? _UserBubble(msg: msg)
            : _AssistantBubble(msg: msg, imageUrl: imageUrl);
      },
    );
  }
}

// ── User Bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _UserBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imageBase64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(msg.imageBase64!),
                  width: 140, height: 140, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(msg.content,
                  style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w500, color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Assistant Bubble ─────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final _ChatMessage msg;
  final String Function(String?) imageUrl;
  const _AssistantBubble({required this.msg, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (msg.isLimitHit) {
      return _LimitHitBubble(msg: msg);
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.col.border),
              ),
              child: Text(msg.content,
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14,
                  fontWeight: FontWeight.w400, color: context.col.ink0)),
            ),
            if (msg.products.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: msg.products.length,
                  itemBuilder: (_, i) =>
                      _AssistantProductCard(
                        product: msg.products[i] as Map<String, dynamic>,
                        imageUrl: imageUrl,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Limit Hit Bubble ─────────────────────────────────────────────────────────

class _LimitHitBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _LimitHitBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warn.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warn, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(msg.content,
                    style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13,
                      fontWeight: FontWeight.w500, color: AppColors.ink0)),
                ),
              ],
            ),
            if (msg.whatsappData != null) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: Text(context.s.assistantWhatsapp,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                    fontWeight: FontWeight.w600)),
                onPressed: () async {
                  final wa = msg.whatsappData ?? {};
                  final number = wa['number']?.toString() ?? '';
                  final text = wa['text']?.toString() ?? '';
                  final url = Uri.parse(
                    'https://wa.me/$number?text=${Uri.encodeComponent(text)}');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Assistant Product Card ───────────────────────────────────────────────────

class _AssistantProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String Function(String?) imageUrl;
  const _AssistantProductCard({required this.product, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final id = product['id'];
    final nameAr = product['name_ar']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final salePrice = (product['sale_price'] as num?)?.toDouble();
    final rating = (product['average_rating'] as num?)?.toDouble() ?? 0;
    final img = imageUrl(product['image']?.toString());
    final hasSale = salePrice != null && salePrice > 0 && salePrice < price;

    return GestureDetector(
      onTap: () => safePush(context, '/product/$id'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: img.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: img,
                      width: 120, height: 90, fit: BoxFit.cover,
                      memCacheWidth: 240, memCacheHeight: 180,
                      errorWidget: (_, __, ___) => Container(
                        width: 120, height: 90,
                        color: context.col.cardImageBg,
                        child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.ink4, size: 24)),
                    )
                  : Container(width: 120, height: 90,
                      color: context.col.cardImageBg,
                      child: const Icon(Icons.image_outlined,
                        color: AppColors.ink4, size: 24)),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameAr,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 11,
                      fontWeight: FontWeight.w600, color: context.col.ink0)),
                  const SizedBox(height: 4),
                  if (hasSale) ...[
                    Text('${salePrice.toStringAsFixed(0)} ${context.s.lyd}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 12,
                        fontWeight: FontWeight.w700, color: AppColors.danger)),
                    Text('${price.toStringAsFixed(0)} ${context.s.lyd}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.ink3)),
                  ] else
                    Text('${price.toStringAsFixed(0)} ${context.s.lyd}',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 12,
                        fontWeight: FontWeight.w700, color: context.col.ink0)),
                  if (rating > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                          color: AppColors.gold, size: 11),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans', fontSize: 10,
                            color: AppColors.ink2)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends AnimatedWidget {
  const _TypingIndicator({required AnimationController animCtrl})
      : super(listenable: animCtrl);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as AnimationController;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final start = delay;
            final end = delay + 0.33;
            final t = anim.value;
            final normalized = end <= 1.0
                ? (t >= start && t <= end ? (t - start) / 0.33 : 0.0)
                : (t >= start
                    ? (t - start) / (1.0 - start)
                    : t <= (end - 1.0) ? t / (end - 1.0) : 0.0);
            final scale = 0.7 + 0.3 * normalized;
            return Padding(
              padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.ink3, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController textCtrl;
  final bool loading;
  final XFile? imageFile;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final void Function({String? overrideText}) onSend;

  const _InputBar({
    required this.textCtrl,
    required this.loading,
    required this.imageFile,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        border: Border(top: BorderSide(color: context.col.border)),
      ),
      padding: EdgeInsets.only(
        left: 8, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview
          if (imageFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imageFile!.path),
                    height: 80, width: 80, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: GestureDetector(
                    onTap: onClearImage,
                    child: Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Input row
          Row(
            children: [
              // Camera button
              IconButton(
                onPressed: loading ? null : onPickImage,
                icon: Icon(Icons.camera_alt_outlined,
                  color: loading ? context.col.ink4 : AppColors.primary, size: 22),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // Text field
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  enabled: !loading,
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                    color: context.col.ink0),
                  decoration: InputDecoration(
                    hintText: context.s.assistantInputHint,
                    hintStyle: TextStyle(fontFamily: 'Cairo',
                      fontSize: 14, color: context.col.ink3),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.col.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.col.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Send button
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: textCtrl,
                builder: (_, val, __) {
                  final canSend =
                      !loading && (val.text.trim().isNotEmpty || imageFile != null);
                  return GestureDetector(
                    onTap: canSend ? () => onSend() : null,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: canSend ? AppColors.primary : context.col.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: canSend ? Colors.white : context.col.ink3,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
