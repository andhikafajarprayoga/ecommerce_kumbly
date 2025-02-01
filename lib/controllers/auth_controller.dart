import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final Rxn<User> currentUser = Rxn<User>();
  final RxString userRole = ''.obs;

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

      // Validasi format email
      if (!GetUtils.isEmail(email)) {
        throw 'Format email tidak valid';
      }

      // Daftar user baru
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': role},
      );

      if (response.user != null) {
        // Tambahkan data user ke tabel users
        await _supabase.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'role': role,
          'full_name': fullName,
          'phone': phone,
        });
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
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
      if (!GetUtils.isEmail(email)) {
        throw 'Format email tidak valid';
      }

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
      }

      Get.back();
      Get.snackbar('Sukses', 'Registrasi berhasil, silakan cek email Anda');
    } catch (e) {
      Get.back();
      if (e.toString().contains('rate_limit')) {
        Get.snackbar('Error', 'Mohon tunggu 50 detik sebelum mencoba lagi',
            backgroundColor: Colors.red, colorText: Colors.white);
      } else {
        Get.snackbar('Error', e.toString(),
            backgroundColor: Colors.red, colorText: Colors.white);
      }
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

      if (res.user != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();

          if (userData == null) {
            await _supabase.from('users').upsert({
              'id': res.user!.id,
              'email': email,
              'role': 'buyer',
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // Set current user dan role
          currentUser.value = res.user;
          userRole.value = userData?['role'] ?? 'buyer';

          Get.back(); // Tutup loading

          // Navigasi berdasarkan role
          if (userRole.value == 'buyer') {
            Get.offAllNamed(
                '/buyer/home'); // Pastikan route ini sudah didefinisikan
          } else if (userRole.value == 'seller') {
            Get.offAllNamed('/seller/home');
          }

          Get.snackbar('Sukses', 'Login berhasil');
        } catch (e) {
          print('Error saat cek/insert user: $e');
          Get.back();
          Get.snackbar('Error', 'Gagal mendapatkan data user');
        }
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
