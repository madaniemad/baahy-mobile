import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/navigation.dart';
import '../theme/app_theme.dart';

// Preferred Arabic locales in order — ar-LY (Libyan) first, then Gulf, Egyptian, generic
const _arLocalePrefs = ['ar_LY', 'ar_SA', 'ar_AE', 'ar_EG', 'ar'];
const _enLocalePrefs = ['en_US', 'en_GB', 'en'];

class MicButton extends ConsumerStatefulWidget {
  final Color? color;
  final double size;
  const MicButton({this.color, this.size = 17, super.key});

  @override
  ConsumerState<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends ConsumerState<MicButton>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  bool _listening = false;
  bool _available = false;
  String? _preferredLocale;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(onError: (_) {
      if (mounted) setState(() => _listening = false);
    });
    if (!mounted) return;
    setState(() => _available = ok);
    if (!ok) return;

    // Pre-select best locale for current app language
    final locales = await _speech.locales();
    final ids = locales.map((l) => l.localeId).toSet();
    final isAr = ref.read(localeProvider).languageCode == 'ar';
    final prefs = isAr ? _arLocalePrefs : _enLocalePrefs;
    for (final pref in prefs) {
      if (ids.any((id) => id.startsWith(pref))) {
        _preferredLocale = ids.firstWhere((id) => id.startsWith(pref));
        break;
      }
    }
  }

  Future<void> _startListening() async {
    if (!_available) return;

    // Re-pick locale in case language was toggled since init
    final isAr = ref.read(localeProvider).languageCode == 'ar';
    if (_preferredLocale != null) {
      final currentIsAr = _arLocalePrefs.any((p) => _preferredLocale!.startsWith(p));
      if (currentIsAr != isAr) await _initSpeech();
    }

    setState(() => _listening = true);
    _speech.listen(
      localeId: _preferredLocale,
      onResult: (result) {
        if (result.finalResult &&
            result.recognizedWords.isNotEmpty &&
            mounted) {
          _stopListening();
          final q = Uri.encodeComponent(result.recognizedWords.trim());
          safePush(context, '/search/results?q=$q');
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: null,
    );
  }

  void _stopListening() {
    _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.col.ink3;

    if (!_available) {
      return Icon(Icons.mic_none_rounded, size: widget.size, color: color);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _listening ? _stopListening : _startListening,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _listening
            ? AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: _pulse.value,
                  child: Icon(Icons.mic_rounded,
                      size: widget.size, color: AppColors.primary),
                ),
              )
            : Icon(Icons.mic_none_rounded, size: widget.size, color: color),
      ),
    );
  }
}
