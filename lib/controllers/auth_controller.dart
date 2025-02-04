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
        userRole.value = 'seller';
      }
    } catch (e) {
      print('Error getting user role: $e');
      userRole.value = 'seller';
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

  Future<bool> signIn({required String email, required String password}) async {
    try {
      isLoading.value = true;
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        currentUser.value = response.user;
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing in: $e');
      return false;
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

        Get.back();
        Get.snackbar(
          'Sukses',
          'Registrasi berhasil! Silakan login.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offNamed('/login');
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', e.toString());
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
        final userData = await _supabase
            .from('users')
            .select('role')
            .eq('id', res.user!.id)
            .single();

        Get.back();

        switch (userData['role']) {
          case 'buyer':
            Get.offAllNamed('/buyer/home_screen');
            break;
          case 'buyer_seller':
            Get.offAllNamed('/merchant/home_screen');
            break;
          default:
            Get.offAllNamed('/buyer/home_screen');
        }

        Get.snackbar('Sukses', 'Login berhasil');
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
      Get.snackbar('Error', 'Email atau password salah');
    }
  }

  Future<void> refreshUser() async {
    final userData = await _supabase
        .from('users')
        .select('*')
        .eq('id', _supabase.auth.currentUser!.id)
        .single();

    currentUser.value = _supabase.auth.currentUser;
    userRole.value = userData['role'] ?? '';
    isMerchant.value = userData['role'] == 'seller';
  }
}
