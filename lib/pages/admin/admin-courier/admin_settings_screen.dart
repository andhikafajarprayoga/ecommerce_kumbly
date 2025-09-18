import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;
  int? courierCodFee;
  int? adminSettingsId;
  bool isLoading = true;
  final TextEditingController feeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSettings();
  }

  Future<void> fetchSettings() async {
    setState(() => isLoading = true);
    try {
      final res = await supabase
          .from('admin_settings')
          .select('id, courier_cod_fee')
          .limit(1)
          .maybeSingle();
      if (res != null) {
        setState(() {
          adminSettingsId = res['id'];
          courierCodFee = res['courier_cod_fee'];
          feeController.text = courierCodFee?.toString() ?? '';
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data admin settings');
    }
    setState(() => isLoading = false);
  }

  Future<void> saveSettings() async {
    final int? fee = int.tryParse(feeController.text);
    if (fee == null || fee < 0) {
      Get.snackbar('Error', 'Fee harus berupa angka positif');
      return;
    }
    setState(() => isLoading = true);
    try {
      if (adminSettingsId != null) {
        await supabase
            .from('admin_settings')
            .update({'courier_cod_fee': fee}).eq('id', adminSettingsId!);
      } else {
        await supabase.from('admin_settings').insert({'courier_cod_fee': fee});
      }
      Get.snackbar('Sukses', 'Fee berhasil disimpan');
      fetchSettings();
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan data');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan Admin'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Admin Kurir (per paket)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: feeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Fee (contoh: 2000)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
