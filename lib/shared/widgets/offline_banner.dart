import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Slides in from the top when the device goes offline. Auto-hides when back online.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).isOnline;

    return AnimatedSlide(
      offset: isOnline ? const Offset(0, -1) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isOnline ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: Material(
          color: AppColors.ink0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('لا يوجد اتصال بالإنترنت',
                    style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 13,
                      fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
