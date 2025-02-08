import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import 'home_screen.dart';

class RegisterBranchScreen extends StatefulWidget {
  const RegisterBranchScreen({super.key});

  @override
  State<RegisterBranchScreen> createState() => _RegisterBranchScreenState();
}

class _RegisterBranchScreenState extends State<RegisterBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Cabang'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Cabang',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Nama cabang wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Nomor telepon wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Alamat wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _registerBranch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Daftar Cabang'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registerBranch() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Cek apakah nama cabang sudah digunakan
      final existingBranch = await supabase
          .from('branches')
          .select()
          .eq('name', nameController.text)
          .maybeSingle();

      if (existingBranch != null) {
        throw 'Nama cabang sudah digunakan';
      }

      // Daftarkan cabang baru
      await supabase.from('branches').insert({
        'name': nameController.text,
        'phone': phoneController.text,
        'address': {
          'full_address': addressController.text,
        },
        'user_id': authController.currentUser.value!.id,
      });

      Get.snackbar(
        'Sukses',
        'Cabang berhasil didaftarkan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAll(() => const BranchHomeScreen());
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }
}
