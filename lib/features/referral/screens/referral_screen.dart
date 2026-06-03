import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

final _referralProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/referrals');
  return Map<String, dynamic>.from(res.data['data'] ?? {});
});

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _parseDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final referralAsync = ref.watch(_referralProvider);
    final config = ref.watch(appConfigProvider);
    final giver = config.referralGiverAmount;
    final receiver = config.referralReceiverAmount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(context.s.inviteTitle,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F5F5), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              const Text('🎁', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(context.isAr ? config.referralTextAr : config.referralTextEn,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo',
                  fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(
                context.s.referralSubtitle(receiver, giver),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.ink2,
                  height: 1.5)),
            ]),
          ),

          // Code card
          Transform.translate(
            offset: const Offset(0, -12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: referralAsync.when(
                loading: () => const SizedBox(height: 80,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                error: (_, __) => _CodeCard(code: user?.referralCode ?? 'BAAHY10',
                  giverAmount: giver, receiverAmount: receiver),
                data: (data) => _CodeCard(
                  code: data['code'] as String? ?? user?.referralCode ?? 'BAAHY10',
                  invited: _parseInt(data['invited_count']),
                  joined: _parseInt(data['used_count']),
                  earned: _parseDouble(data['earned_amount']),
                  giverAmount: giver, receiverAmount: receiver,
                ),
              ),
            ),
          ),

          // How it works
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(context.s.howItWorks,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 0.4, color: AppColors.ink1)),
              ),
              ...[
                (1, context.s.referralStep1),
                (2, context.s.referralStep2),
                (3, context.s.referralStep3(giver)),
              ].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                    child: Center(child: Text('${s.$1}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.primary))),
                  ),
                  const SizedBox(width: 12),
                  Text(s.$2, style: const TextStyle(fontSize: 13.5)),
                ]),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CodeCard extends StatefulWidget {
  final String code;
  final int invited;
  final int joined;
  final double earned;
  final int giverAmount;
  final int receiverAmount;
  const _CodeCard({required this.code,
    this.invited = 0, this.joined = 0, this.earned = 0,
    this.giverAmount = 10, this.receiverAmount = 10});

  @override
  State<_CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends State<_CodeCard> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(children: [
        Text(context.s.yourCode,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
            letterSpacing: 0.5, color: AppColors.ink2)),
        const SizedBox(height: 6),

        // Code row
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.borderStrong,
                  style: BorderStyle.solid),
              ),
              child: Text(widget.code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _copy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _copied ? AppColors.success.withValues(alpha: 0.1) : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Icon(_copied ? Icons.check_rounded : Icons.upload_outlined,
                  size: 16, color: _copied ? AppColors.success : AppColors.ink1),
                const SizedBox(width: 6),
                Text(_copied ? context.s.copied : context.s.copyBtn,
                  style: TextStyle(fontWeight: FontWeight.w700,
                    color: _copied ? AppColors.success : AppColors.ink0)),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 14),

        // Share options
        Text(context.s.orShareVia,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.ink3, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ShareBtn(label: context.s.whatsapp, color: const Color(0xFF25D366),
            icon: Icons.chat_rounded,
            onTap: () => Share.share(
              context.s.referralShareWhatsApp(widget.code, widget.receiverAmount))),
          _ShareBtn(label: context.s.viaSMS, color: const Color(0xFF1f8a5b),
            icon: Icons.sms_outlined,
            onTap: () => Share.share(
              context.s.referralShareSMS(widget.code, widget.receiverAmount))),
          _ShareBtn(label: context.s.moreOptions, color: AppColors.ink2,
            icon: Icons.share_outlined,
            onTap: () => Share.share(
              context.s.referralShareGeneral(widget.code, widget.receiverAmount))),
        ]),

        // Stats
        if (widget.invited > 0 || widget.joined > 0 || widget.earned > 0) ...[
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              _StatCell('${widget.invited}', context.s.statInvited),
              Container(width: 1, height: 40, color: AppColors.border),
              _StatCell('${widget.joined}', context.s.statJoined),
              Container(width: 1, height: 40, color: AppColors.border),
              _StatCell('${widget.earned.toStringAsFixed(0)}', context.s.statEarned, isMoney: true),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ShareBtn({required this.label, required this.color,
    required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool isMoney;
  const _StatCell(this.value, this.label, {this.isMoney = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value,
            style: const TextStyle(fontFamily: 'PlusJakartaSans',
              fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
          if (isMoney)
            Text(' ${context.s.lydUnit}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.ink2)),
        ]),
        const SizedBox(height: 4),
        Text(label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.ink3)),
      ]),
    ),
  );
}
