import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class ShippingRatesScreen extends StatefulWidget {
  @override
  _ShippingRatesScreenState createState() => _ShippingRatesScreenState();
}

class _ShippingRatesScreenState extends State<ShippingRatesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> shippingRates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchShippingRates();
  }

  Future<void> fetchShippingRates() async {
    try {
      final response =
          await supabase.from('shipping_rates').select().order('type');

      setState(() {
        shippingRates =
            (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching shipping rates: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteShippingRate(String id) async {
    try {
      await supabase.from('shipping_rates').delete().eq('id', id);

      Get.snackbar(
        'Sukses',
        'Tarif ongkir berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      fetchShippingRates();
    } catch (e) {
      print('Error deleting shipping rate: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus tarif ongkir',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Ongkir'),
        backgroundColor: AppTheme.primary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => AddEditShippingRateScreen())
            ?.then((value) => value == true ? fetchShippingRates() : null),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : shippingRates.isEmpty
              ? Center(child: Text('Tidak ada data ongkir'))
              : ListView.builder(
                  itemCount: shippingRates.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final rate = shippingRates[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          rate['type'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Rp ${rate['base_rate'].toString()}',
                          style: TextStyle(color: AppTheme.primary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => Get.to(
                                () => AddEditShippingRateScreen(rate: rate),
                              )?.then(
                                (value) =>
                                    value == true ? fetchShippingRates() : null,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Konfirmasi'),
                                  content: Text(
                                      'Yakin ingin menghapus tarif ongkir ini?'),
                                  actions: [
                                    TextButton(
                                      child: Text('Batal'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    TextButton(
                                      child: Text(
                                        'Hapus',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        deleteShippingRate(rate['id']);
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

class AddEditShippingRateScreen extends StatefulWidget {
  final Map<String, dynamic>? rate;

  AddEditShippingRateScreen({this.rate});

  @override
  _AddEditShippingRateScreenState createState() =>
      _AddEditShippingRateScreenState();
}

class _AddEditShippingRateScreenState extends State<AddEditShippingRateScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController typeController;
  late TextEditingController baseRateController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    typeController = TextEditingController(text: widget.rate?['type'] ?? '');
    baseRateController = TextEditingController(
      text: widget.rate?['base_rate']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    typeController.dispose();
    baseRateController.dispose();
    super.dispose();
  }

  Future<void> saveShippingRate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final data = {
        'type': typeController.text,
        'base_rate': int.parse(baseRateController.text),
      };

      if (widget.rate != null) {
        await supabase
            .from('shipping_rates')
            .update(data)
            .eq('id', widget.rate!['id']);
      } else {
        await supabase.from('shipping_rates').insert(data);
      }

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Tarif ongkir berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving shipping rate: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan tarif ongkir',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rate != null ? 'Edit Ongkir' : 'Tambah Ongkir'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: typeController,
              decoration: InputDecoration(
                labelText: 'Jenis Pengiriman',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jenis pengiriman tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: baseRateController,
              decoration: InputDecoration(
                labelText: 'Tarif Dasar (Rp)',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Tarif dasar tidak boleh kosong';
                }
                if (int.tryParse(value) == null) {
                  return 'Tarif dasar harus berupa angka';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : saveShippingRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
