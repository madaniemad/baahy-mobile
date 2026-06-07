import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _ChatMessage {
  final String role;
  final String content;
  final List<dynamic> products;
  final bool isLimitHit;
  final String? imageBase64;
  final Map<String, dynamic>? whatsappData;
  final List<Map<String, dynamic>> suggestedCategories;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.products = const [],
    this.isLimitHit = false,
    this.imageBase64,
    this.whatsappData,
    this.suggestedCategories = const [],
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'products': products,
        'isLimitHit': isLimitHit,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (whatsappData != null) 'whatsappData': whatsappData,
        if (suggestedCategories.isNotEmpty) 'suggestedCategories': suggestedCategories,
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> j) => _ChatMessage(
        role: j['role'] as String,
        content: j['content'] as String,
        products: j['products'] as List<dynamic>? ?? [],
        isLimitHit: j['isLimitHit'] as bool? ?? false,
        imageBase64: j['imageBase64'] as String?,
        whatsappData: j['whatsappData'] as Map<String, dynamic>?,
        suggestedCategories: (j['suggestedCategories'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
      );
}

class _SavedConversation {
  final String firstMessage;
  final DateTime time;
  final List<_ChatMessage> messages;

  const _SavedConversation({
    required this.firstMessage,
    required this.time,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() => {
        'msg': firstMessage,
        'ts': time.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory _SavedConversation.fromJson(Map<String, dynamic> j) =>
      _SavedConversation(
        firstMessage: j['msg'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        messages: (j['messages'] as List<dynamic>? ?? [])
            .map((m) => _ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class _SuggestionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final String prompt;
  const _SuggestionData(
      this.icon, this.title, this.subtitle, this.iconBg, this.iconColor, this.prompt);
}

// ── Screen ────────────────────────────────────────────────────────────────────

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
  List<_SavedConversation> _savedConvos = [];
  DateTime? _currentConvoTime;

  late AnimationController _dotAnimCtrl;

  @override
  void initState() {
    super.initState();
    _dotAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadHistory();
  }

  @override
  void dispose() {
    _dotAnimCtrl.dispose();
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('ai_chat_history') ?? [];
    if (!mounted) return;
    setState(() {
      _savedConvos = raw
          .map((s) =>
              _SavedConversation.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _persistConversation() async {
    final userMsg = _messages.firstWhere(
      (m) => m.role == 'user' && m.content.isNotEmpty,
      orElse: () => const _ChatMessage(role: 'user', content: ''),
    );
    if (userMsg.content.isEmpty) return;

    _currentConvoTime ??= DateTime.now();

    final convo = _SavedConversation(
      firstMessage: userMsg.content,
      time: _currentConvoTime!,
      messages: List.unmodifiable(_messages),
    );

    final ts = _currentConvoTime!.millisecondsSinceEpoch;
    final existingIdx = _savedConvos.indexWhere((c) => c.time.millisecondsSinceEpoch == ts);

    List<_SavedConversation> updated;
    if (existingIdx >= 0) {
      updated = List.of(_savedConvos);
      updated[existingIdx] = convo;
    } else {
      updated = [convo, ..._savedConvos].take(20).toList();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'ai_chat_history',
      updated.map((c) => jsonEncode(c.toJson())).toList(),
    );
    if (mounted) setState(() => _savedConvos = updated);
  }

  void _restoreConversation(_SavedConversation convo) {
    if (convo.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المحادثات القديمة لا يمكن استعادتها',
              style: TextStyle(fontFamily: 'Cairo'),
              textDirection: TextDirection.rtl),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _messages
        ..clear()
        ..addAll(convo.messages);
      _history
        ..clear()
        ..addAll(convo.messages
            .where((m) => m.content.isNotEmpty)
            .map((m) => {'role': m.role, 'content': m.content}));
      _currentConvoTime = convo.time;
    });
    _scrollToBottom();
  }

  void _clearConversation() {
    if (_messages.isNotEmpty) _persistConversation();
    setState(() {
      _messages.clear();
      _history.clear();
      _currentConvoTime = null;
    });
  }

  static const _storageBase =
      'https://phplaravel-1620145-6391034.cloudwaysapps.com/storage/';

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final fixed = path.replaceAll('/api/storage/', '/storage/');
    if (fixed.startsWith('http')) return fixed;
    var p = fixed.replaceAll(RegExp(r'^/+'), '');
    if (p.startsWith('storage/')) p = p.substring(8);
    return '$_storageBase$p';
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
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('معرض الصور',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
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
      _messages.add(_ChatMessage(role: 'user', content: text, imageBase64: b64));
      _loading = true;
      _imageFile = null;
    });
    _textCtrl.clear();
    _scrollToBottom();

    final historyToSend = _history.length > 10
        ? _history.sublist(_history.length - 4)
        : _history;

    try {
      final body = <String, dynamic>{
        'message': text,
        'history': historyToSend,
        if (b64 != null) 'image': b64,
      };

      final res = await ApiClient.instance.dio.post(
        '/chat',
        data: body,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
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
        _persistConversation();
        _scrollToBottom();
        return;
      }

      final reply = data['message'] as String? ?? '';
      final products = data['products'] as List<dynamic>? ?? [];
      final suggestedCategories =
          (data['suggested_categories'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: reply,
          products: products,
          suggestedCategories: suggestedCategories,
        ));
        _loading = false;
      });

      if (text.isNotEmpty) _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 4);
      }

      _persistConversation();
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;

      // Limit hit can also come back as a non-200 DioException
      if (e is DioException) {
        final respData = e.response?.data;
        if (respData is Map && respData['limit_hit'] == true) {
          final wa = respData['whatsapp'] as Map<String, dynamic>?;
          setState(() {
            _messages.add(_ChatMessage(
              role: 'assistant',
              content: (respData['message'] as String?)?.isNotEmpty == true
                  ? respData['message'] as String
                  : context.s.assistantLimitHit,
              isLimitHit: true,
              whatsappData: wa,
            ));
          });
          _persistConversation();
          _scrollToBottom();
          return;
        }
      }

      // Show error as a persistent bubble so the user sees it even after scrolling
      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: context.s.assistantError,
        ));
      });
      _scrollToBottom();
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
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.3)),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.edit_note_rounded, color: context.col.ink2, size: 22),
              tooltip: 'محادثة جديدة',
              onPressed: _clearConversation,
            )
          else if (_savedConvos.isNotEmpty)
            IconButton(
              icon: Icon(Icons.history_rounded, color: context.col.ink2, size: 22),
              tooltip: 'المحادثات السابقة',
              onPressed: () {},
            ),
        ],
      ),
      body: _messages.isEmpty
          ? _EmptyState(
              onChipTap: _send,
              onRestoreConvo: _restoreConversation,
              textCtrl: _textCtrl,
              loading: _loading,
              imageFile: _imageFile,
              onPickImage: _showImagePicker,
              onClearImage: () => setState(() => _imageFile = null),
              savedConvos: _savedConvos,
            )
          : Column(
              children: [
                Expanded(
                  child: _MessagesList(
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerStatefulWidget {
  final void Function({String? overrideText}) onChipTap;
  final void Function(_SavedConversation) onRestoreConvo;
  final TextEditingController textCtrl;
  final bool loading;
  final XFile? imageFile;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final List<_SavedConversation> savedConvos;

  const _EmptyState({
    required this.onChipTap,
    required this.onRestoreConvo,
    required this.textCtrl,
    required this.loading,
    required this.imageFile,
    required this.onPickImage,
    required this.onClearImage,
    required this.savedConvos,
  });

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  bool _showAll = false;

  static const _suggestions = [
    _SuggestionData(
        Icons.local_shipping_outlined,
        'وين طلبي؟',
        'تتبع حالة طلبك',
        AppColors.teal50,
        AppColors.primary,
        'وين طلبي؟'),
    _SuggestionData(
        Icons.assignment_return_outlined,
        'سياسة الإرجاع',
        'شروط وخطوات الإرجاع',
        Color(0xFFFFE5EC),
        Color(0xFFE91E63),
        'ما هي سياسة الإرجاع؟'),
    _SuggestionData(
        Icons.payments_outlined,
        'طرق الدفع',
        'الطرق المتاحة والرسوم',
        Color(0xFFFFF3E0),
        Color(0xFFF57C00),
        'ما هي طرق الدفع المتاحة؟'),
    _SuggestionData(
        Icons.workspace_premium_outlined,
        'المكافآت والولاء',
        'نقاطك ومزايا عضويتك',
        Color(0xFFFFF8E1),
        Color(0xFFD4A82E),
        'كيف يعمل نظام المكافآت والولاء؟'),
    _SuggestionData(
        Icons.support_agent_outlined,
        'تواصل معنا',
        'دعم سريع عبر واتساب',
        AppColors.teal50,
        AppColors.primary,
        'كيف أتواصل مع خدمة العملاء؟'),
    _SuggestionData(
        Icons.card_giftcard_outlined,
        'اقتراح هدية',
        'أخبرني لمن وما المناسبة',
        Color(0xFFEDE7F6),
        Color(0xFF7B1FA2),
        'ساعدني أختار هدية مناسبة'),
  ];

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(currentUserProvider)?.name ?? '';
    final firstName = userName.split(' ').first;
    final visibleConvos =
        _showAll ? widget.savedConvos : widget.savedConvos.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Hero icon ──
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.teal50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 26),
          ),
        ),
        const SizedBox(height: 12),

        // ── Greeting + title ──
        if (firstName.isNotEmpty) ...[
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                text: '👋 ',
                style: TextStyle(fontSize: 18),
              ),
              TextSpan(
                text: 'أهلين $firstName',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink0),
              ),
            ]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
        ],
        Text(
          'كيف أقدر أساعدك؟',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: firstName.isEmpty ? 20 : 18,
              fontWeight: FontWeight.w800,
              color: context.col.ink0),
        ),
        const SizedBox(height: 6),
        Text(
          'اسألني عن طلباتك، الشحن، الإرجاع، المكافآت، أو أي مساعدة تحتاجها',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.col.ink3),
        ),
        const SizedBox(height: 20),

        // ── Inline input ──
        _InlineInput(
          textCtrl: widget.textCtrl,
          loading: widget.loading,
          imageFile: widget.imageFile,
          onPickImage: widget.onPickImage,
          onClearImage: widget.onClearImage,
          onSend: widget.onChipTap,
        ),
        const SizedBox(height: 28),

        // ── Quick suggestions header ──
        Row(
          children: [
            const Spacer(),
            Text('يمكنني مساعدتك في',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.col.ink0)),
            const SizedBox(width: 6),
            const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2×3 suggestions grid ──
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: _suggestions
              .map((s) => _SuggestionCard(
                    data: s,
                    onTap: () => widget.onChipTap(overrideText: s.prompt),
                  ))
              .toList(),
        ),

        // ── Previous conversations ──
        if (widget.savedConvos.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Spacer(),
              Text('المحادثات السابقة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.col.ink0)),
              const SizedBox(width: 6),
              Icon(Icons.history_rounded, size: 16, color: context.col.ink3),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.col.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < visibleConvos.length; i++) ...[
                  _HistoryRow(
                    convo: visibleConvos[i],
                    onTap: () => widget.onRestoreConvo(visibleConvos[i]),
                  ),
                  if (i < visibleConvos.length - 1)
                    Divider(height: 1, color: context.col.border),
                ],
              ],
            ),
          ),
          if (widget.savedConvos.length > 5 && !_showAll)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: const Text('عرض المزيد',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 13)),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Inline Input ──────────────────────────────────────────────────────────────

class _InlineInput extends StatelessWidget {
  final TextEditingController textCtrl;
  final bool loading;
  final XFile? imageFile;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final void Function({String? overrideText}) onSend;

  const _InlineInput({
    required this.textCtrl,
    required this.loading,
    required this.imageFile,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(imageFile!.path),
                  height: 70,
                  width: 70,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onClearImage,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
              BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
                // In RTL context: send appears on the right, camera on the left
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: textCtrl,
                  builder: (_, val, __) {
                    final canSend = !loading &&
                        (val.text.trim().isNotEmpty || imageFile != null);
                    return Padding(
                      padding: const EdgeInsets.all(6),
                      child: GestureDetector(
                        onTap: canSend ? () => onSend() : null,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: canSend ? AppColors.primary : AppColors.teal50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: canSend ? Colors.white : AppColors.ink4,
                            size: 17,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: textCtrl,
                    enabled: !loading,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 14, color: AppColors.ink0),
                    decoration: const InputDecoration(
                      hintText: 'اسأل عن منتج، هدية، مقاس، طلب...',
                      hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.ink3),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : onPickImage,
                  icon: Icon(Icons.camera_alt_outlined,
                      color: loading ? AppColors.ink4 : AppColors.ink3,
                      size: 21),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final _SuggestionData data;
  final VoidCallback onTap;
  const _SuggestionCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.col.ink0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.iconColor, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Row ───────────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final _SavedConversation convo;
  final VoidCallback onTap;
  const _HistoryRow({required this.convo, required this.onTap});

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);

    if (d == today) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = h < 12 ? 'ص' : 'م';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $ampm';
    } else if (d == yesterday) {
      return 'أمس';
    } else {
      const months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.chevron_left_rounded, size: 18, color: context.col.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                convo.firstMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: context.col.ink0),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatTime(convo.time),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: context.col.ink3),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chat_bubble_outline_rounded,
                size: 14, color: context.col.ink3),
          ],
        ),
      ),
    );
  }
}

// ── Messages List ─────────────────────────────────────────────────────────────

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

// ── User Bubble ───────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _UserBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.imageBase64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(msg.imageBase64!),
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (msg.content.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(msg.content,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink0)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Assistant Bubble ──────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final _ChatMessage msg;
  final String Function(String?) imageUrl;
  const _AssistantBubble({required this.msg, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (msg.isLimitHit) return _LimitHitBubble(msg: msg);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.col.border),
              ),
              child: Text(msg.content,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.col.ink0)),
            ),
            if (msg.products.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 204,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: msg.products.length,
                  itemBuilder: (_, i) => _AssistantProductCard(
                    product: msg.products[i] as Map<String, dynamic>,
                    imageUrl: imageUrl,
                  ),
                ),
              ),
              if (msg.suggestedCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: msg.suggestedCategories.map((cat) {
                    return GestureDetector(
                      onTap: () => safePush(context, '/search/results?q=&category=${cat['id']}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.teal50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.grid_view_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'تصفح ${cat['name_ar']}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_back_ios_rounded,
                                size: 10, color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Limit Hit Bubble ──────────────────────────────────────────────────────────

class _LimitHitBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _LimitHitBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
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
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink0)),
                ),
              ],
            ),
            if (msg.whatsappData != null) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_rounded, size: 16),
                label: Text(context.s.assistantWhatsapp,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
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

// ── Assistant Product Card ────────────────────────────────────────────────────

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
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: img.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: img,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      memCacheWidth: 240,
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: 90,
                        color: context.col.cardImageBg,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.ink4, size: 24),
                      ),
                    )
                  : Container(
                      width: 120,
                      height: 90,
                      color: context.col.cardImageBg,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.ink4, size: 24),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.col.ink0)),
                  const SizedBox(height: 4),
                  if (hasSale) ...[
                    Text('${salePrice.toStringAsFixed(0)} ${context.s.lyd}',
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger)),
                    Text('${price.toStringAsFixed(0)} ${context.s.lyd}',
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.ink3)),
                  ] else
                    Text('${price.toStringAsFixed(0)} ${context.s.lyd}',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.col.ink0)),
                  if (rating > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.gold, size: 11),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
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

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends AnimatedWidget {
  const _TypingIndicator({required AnimationController animCtrl})
      : super(listenable: animCtrl);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as AnimationController;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
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
                    : t <= (end - 1.0)
                        ? t / (end - 1.0)
                        : 0.0);
            final scale = 0.7 + 0.3 * normalized;
            return Padding(
              padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
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

// ── Input Bar (chat mode) ─────────────────────────────────────────────────────

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
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageFile != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imageFile!.path),
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: onClearImage,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              // In RTL context: send appears on the right, camera on the left
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: textCtrl,
                builder: (_, val, __) {
                  final canSend = !loading &&
                      (val.text.trim().isNotEmpty || imageFile != null);
                  return GestureDetector(
                    onTap: canSend ? () => onSend() : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: canSend
                            ? AppColors.primary
                            : context.col.surfaceSoft,
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
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  enabled: !loading,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: context.col.ink0),
                  decoration: InputDecoration(
                    hintText: context.s.assistantInputHint,
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: context.col.ink3),
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
                        borderSide:
                            const BorderSide(color: AppColors.primary)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: loading ? null : onPickImage,
                icon: Icon(Icons.camera_alt_outlined,
                    color: loading ? context.col.ink4 : AppColors.primary,
                    size: 22),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
