import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import './pengiriman_form_screen.dart';

class PengirimanScreen extends StatefulWidget {
  @override
  _PengirimanScreenState createState() => _PengirimanScreenState();
}

class _PengirimanScreenState extends State<PengirimanScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pengirimanList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPengiriman();
  }

  Future<void> fetchPengiriman() async {
    try {
      final response = await supabase
          .from('pengiriman')
          .select()
          .order('id_pengiriman', ascending: true);

      setState(() {
        pengirimanList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengambil data pengiriman: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> deletePengiriman(int id) async {
    try {
      await supabase.from('pengiriman').delete().eq('id_pengiriman', id);

      Get.snackbar(
        'Sukses',
        'Pengiriman berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      fetchPengiriman();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus pengiriman: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => PengirimanFormScreen())
            ?.then((_) => fetchPengiriman()),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: pengirimanList.length,
              itemBuilder: (context, index) {
                final pengiriman = pengirimanList[index];
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(pengiriman['nama_pengiriman']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Harga per KG: Rp ${pengiriman['harga_per_kg']}'),
                        Text('Harga per KM: Rp ${pengiriman['harga_per_km']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => Get.to(
                            () => PengirimanFormScreen(pengiriman: pengiriman),
                          )?.then((_) => fetchPengiriman()),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Konfirmasi'),
                              content:
                                  Text('Yakin ingin menghapus pengiriman ini?'),
                              actions: [
                                TextButton(
                                  child: Text('Batal'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                TextButton(
                                  child: Text('Hapus'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    deletePengiriman(
                                        pengiriman['id_pengiriman']);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
