import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final userData = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .single();

      switch (userData['role']) {
        case 'admin':
          Get.offAllNamed('/admin/home_screen');
          break;
        case 'courier':
          Get.offAllNamed('/courier/home_screen');
          break;
        case 'branch':
          Get.offAllNamed('/branch/home_screen');
          break;
        case 'buyer':
        default:
          Get.offAllNamed('/buyer/home_screen');
          break;
      }
    } else {
      Get.offAllNamed('/buyer/home_screen');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo dengan fade animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 210,
                height: 210,
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
