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

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Cek apakah token sudah expired
        if (session.expiresAt != null &&
            DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(
                session.expiresAt! * 1000))) {
          // Token expired, logout dan tampilkan dialog
          await Supabase.instance.client.auth.signOut();
          Get.offAllNamed('/login');

          // Tunggu sebentar agar halaman login ter-render
          await Future.delayed(const Duration(milliseconds: 500));

          Get.dialog(
            AlertDialog(
              title: const Text('Sesi Berakhir'),
              content: const Text(
                  'Sesi login Anda telah berakhir. Silakan login kembali.'),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('OK'),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          return;
        }

        try {
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
        } catch (e) {
          print('Error getting user data: $e');
          if (e is PostgrestException && e.code == 'PGRST301') {
            // Token invalid/expired, logout dan tampilkan dialog
            await Supabase.instance.client.auth.signOut();
            Get.offAllNamed('/login');

            await Future.delayed(const Duration(milliseconds: 500));

            Get.dialog(
              AlertDialog(
                title: const Text('Sesi Berakhir'),
                content: const Text(
                    'Sesi login Anda telah berakhir. Silakan login kembali.'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('OK'),
                  ),
                ],
              ),
              barrierDismissible: false,
            );
          } else {
            // Error lain, arahkan ke halaman login
            Get.offAllNamed('/login');
          }
        }
      } else {
        Get.offAllNamed('/buyer/home_screen');
      }
    } catch (e) {
      print('Error in auth check: $e');
      Get.offAllNamed('/login');
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
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo dengan fade animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 250,
                height: 250,
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'images/saraja.png',
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
