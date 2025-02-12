import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthController authController = Get.find<AuthController>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Tambahkan variable untuk mengontrol visibility password
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      Get.snackbar(
        'Error',
        'Password dan konfirmasi password tidak sama',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    try {
      await authController.register(
        emailController.text.trim(),
        passwordController.text,
        fullNameController.text.trim(),
        phoneController.text.trim(),
      );

      // Tampilkan dialog sukses dengan instruksi verifikasi email
      Get.dialog(
        AlertDialog(
          title: const Text('Registrasi Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Silakan cek email Anda untuk verifikasi akun.'),
              const SizedBox(height: 8),
              Text(
                'Email verifikasi telah dikirim ke: ${emailController.text}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Periksa folder spam jika email tidak ditemukan di inbox.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back(); // Tutup dialog
                Get.back(); // Kembali ke halaman login
              },
              child: const Text('OK'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Terjadi kesalahan: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withOpacity(0.9),
                AppTheme.primary.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Image.asset(
                        'images/saraja.png', // Ganti dengan path logo Anda
                        height: 100,
                        width: 180, // Sesuaikan tinggi logo
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Buat Akun Baru',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 0),
                      const Text(
                        'Daftar untuk mulai berbelanja',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Section
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildInputField(
                              controller: fullNameController,
                              label: 'Nama Lengkap',
                              icon: Icons.person,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Nama tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: emailController,
                              label: 'Email',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email tidak boleh kosong';
                                }
                                if (!GetUtils.isEmail(value)) {
                                  return 'Email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: phoneController,
                              label: 'Nomor Telepon',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Nomor telepon tidak boleh kosong';
                                }
                                if (!GetUtils.isPhoneNumber(value)) {
                                  return 'Nomor telepon tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: passwordController,
                              label: 'Password',
                              icon: Icons.lock,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                if (value.length < 6) {
                                  return 'Password minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: confirmPasswordController,
                              label: 'Konfirmasi Password',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Konfirmasi password tidak boleh kosong';
                                }
                                if (value != passwordController.text) {
                                  return 'Password tidak sama';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            Obx(
                              () => Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primary,
                                      AppTheme.primary.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: authController.isLoading.value
                                      ? null
                                      : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: authController.isLoading.value
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Daftar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: TextStyle(color: AppTheme.textHint),
                                ),
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword
            ? (controller == passwordController
                ? !_isPasswordVisible
                : !_isConfirmPasswordVisible)
            : false,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(icon, color: AppTheme.primary),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    controller == passwordController
                        ? (_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off)
                        : (_isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      if (controller == passwordController) {
                        _isPasswordVisible = !_isPasswordVisible;
                      } else {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      }
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: validator,
      ),
    );
  }
}
