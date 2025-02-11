import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../controllers/auth_controller.dart';

class AdminAccountScreen extends StatefulWidget {
  @override
  _AdminAccountScreenState createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _deleteAccount() async {
    if (_passwordController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Mohon masukkan password untuk konfirmasi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      // Verifikasi password
      final response = await supabase.auth.signInWithPassword(
        email: supabase.auth.currentUser!.email!,
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Password salah');
      }

      // Hapus data admin dari database
      await supabase
          .from('admin_users')
          .delete()
          .eq('id', supabase.auth.currentUser!.id);

      // Hapus akun auth
      await supabase.auth.admin.deleteUser(
        supabase.auth.currentUser!.id,
      );

      // Sign out dan kembali ke halaman login
      await authController.signOut();
      Get.offAllNamed('/login');

      Get.snackbar(
        'Sukses',
        'Akun admin berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus akun: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showDeleteConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Text('Hapus Akun Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apakah Anda yakin ingin menghapus akun admin ini?'),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                hintText: 'Masukkan password untuk konfirmasi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: isLoading ? null : _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Hapus',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Akun Admin'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.email),
                title: Text('Email'),
                subtitle: Text(supabase.auth.currentUser?.email ?? ''),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showDeleteConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                'Hapus Akun Admin',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
