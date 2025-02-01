import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final Rxn<User> currentUser = Rxn<User>();
  final RxString userRole = ''.obs;
  var isMerchant = false.obs;

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((event) {
      currentUser.value = event.session?.user;
      if (currentUser.value != null) {
        _getUserRole();
      }
    });
  }

  Future<void> _getUserRole() async {
    try {
      final userData = await _supabase
          .from('users')
          .select('role')
          .eq('id', currentUser.value!.id)
          .maybeSingle();

      if (userData != null) {
        userRole.value = userData['role'] as String;
      } else {
        userRole.value = 'buyer';
      }
    } catch (e) {
      print('Error getting user role: $e');
      userRole.value = 'buyer';
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
    required String phone,
  }) async {
    try {
      isLoading.value = true;

      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'role': role,
          'full_name': fullName,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });

        Get.snackbar(
          'Sukses',
          'Registrasi berhasil! Silakan periksa email Anda untuk verifikasi akun sebelum login.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );

        Get.offNamed('/login');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      print('Error registrasi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      userRole.value = '';
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  Future<void> register(
      String email, String password, String fullName, String phone) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'role': 'buyer',
          'full_name': fullName,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });

        Get.back(); // Tutup loading

        // Tampilkan snackbar dan langsung navigasi
        Get.snackbar(
          'Sukses',
          'Registrasi berhasil! Silakan login.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.TOP,
        );

        // Langsung navigasi ke login page
        Get.offNamed('/login');
      }
    } catch (e) {
      Get.back(); // Tutup loading
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      print('Error registrasi: $e'); // Tambahkan log untuk debugging
    }
  }

  Future<void> login(String email, String password) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null && res.user!.confirmedAt != null) {
        Get.back(); // Tutup loading
        Get.offAllNamed('/buyer/home_screen');
        Get.snackbar(
          'Sukses',
          'Login berhasil',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.back();
        Get.snackbar(
          'Perhatian',
          'Silakan verifikasi email Anda terlebih dahulu',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Email atau password salah',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
