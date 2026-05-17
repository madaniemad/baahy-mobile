import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final cityChosen = prefs.getString('city') != null;
    final auth = ref.read(authProvider);

    if (!cityChosen) {
      context.go('/city');
    } else if (auth.isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 16),
              const Text(
                'baahy',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تسوق بسهولة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
