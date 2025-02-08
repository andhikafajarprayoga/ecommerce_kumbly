import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../controllers/auth_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../screens/home_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final AuthController authController = Get.find<AuthController>();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitDeletionRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Mohon isi alasan penghapusan akun',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase.from('account_deletion_requests').insert({
        'user_id': supabase.auth.currentUser!.id,
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      Get.dialog(
        AlertDialog(
          title: const Text('Permintaan Terkirim'),
          content: const Text(
              'Permintaan penghapusan akun Anda telah diterima. Tim kami akan memproses permintaan Anda dalam waktu 3-5 hari kerja. Anda akan menerima email konfirmasi setelah akun Anda dihapus.'),
          actions: [
            TextButton(
              onPressed: () {
                Get.offAll(() => const HomeScreen());
                authController.signOut();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Terjadi kesalahan: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Akun'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penting!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Setelah akun Anda dihapus:\n'
                      '• Semua data dan riwayat transaksi akan dihapus\n'
                      '• Anda tidak dapat mengakses akun ini lagi\n'
                      '• Proses ini tidak dapat dibatalkan\n'
                      '• Toko yang Anda miliki akan dihapus',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alasan Penghapusan Akun',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ceritakan alasan Anda ingin menghapus akun...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitDeletionRequest,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Ajukan Penghapusan Akun',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
