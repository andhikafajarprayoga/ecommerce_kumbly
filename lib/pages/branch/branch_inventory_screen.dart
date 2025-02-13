import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class BranchInventoryScreen extends StatefulWidget {
  const BranchInventoryScreen({super.key});

  @override
  State<BranchInventoryScreen> createState() => _BranchInventoryScreenState();
}

class _BranchInventoryScreenState extends State<BranchInventoryScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Cabang'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadBranchProducts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data!;
            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada produk di inventory',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadBranchProducts() async {
    // Get current branch ID
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw 'User tidak ditemukan';

    final branchData = await supabase
        .from('branches')
        .select()
        .eq('user_id', currentUser.id)
        .single();

    // Fetch products with joins
    final products = await supabase
        .from('branch_products')
        .select('''
          *,
          products:product_id(*)
        ''')
        .eq('branch_id', branchData['id'])
        .eq('status', 'received')
        .order('created_at', ascending: false);

    print('\nDEBUG: Loaded branch products:');
    print('  - Count: ${products.length}');
    products.forEach((product) {
      print(
          '  - Product: ${product['products']['name']} (${product['quantity']})');
    });

    return products;
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showProductDetail(product),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product['products']['name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () => _printReceipt(product),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Quantity: ${product['quantity']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                'Tanggal Masuk: ${_formatDate(product['created_at'])}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetail(Map<String, dynamic> product) {
    Get.dialog(
      AlertDialog(
        title: const Text('Detail Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama: ${product['products']['name']}'),
            const SizedBox(height: 8),
            Text('Quantity: ${product['quantity']}'),
            const SizedBox(height: 8),
            Text('Tanggal Masuk: ${_formatDate(product['created_at'])}'),
            const SizedBox(height: 8),
            Text('Status: ${product['status']}'),
            if (product['courier_id'] != null) ...[
              const SizedBox(height: 8),
              Text('Kurir: ${product['name_courier'] ?? 'Unknown'}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () => _printReceipt(product),
            icon: const Icon(Icons.print),
            label: const Text('Print Resi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> product) async {
    try {
      final pdf = pw.Document();

      // Ambil data branch
      final branchData = await supabase
          .from('branches')
          .select('name, address')
          .eq('id', product['branch_id'])
          .single();

      // Format alamat cabang
      String formattedAddress = '';
      if (branchData['address'] != null) {
        try {
          if (branchData['address'] is Map) {
            final addressMap = branchData['address'] as Map<String, dynamic>;
            formattedAddress = [
              addressMap['street'],
              addressMap['village'],
              addressMap['district'],
              addressMap['city'],
              addressMap['province'],
              addressMap['postal_code'],
            ].where((e) => e != null && e.isNotEmpty).join(', ');
          } else {
            formattedAddress = branchData['address'].toString();
          }
        } catch (e) {
          formattedAddress = branchData['address'].toString();
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BUKTI INVENTORY BARANG',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'No. #${product['id'].toString().substring(0, 8)}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: product['id'].toString(),
                        width: 70,
                        height: 70,
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 20),

                  // Informasi Cabang
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('INFORMASI CABANG:',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text(branchData['name'] ?? '-'),
                        pw.Text(formattedAddress),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Informasi Produk
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DETAIL PRODUK:',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        _buildInfoRow(
                            'Nama Produk', product['products']['name']),
                        _buildInfoRow('Jumlah', '${product['quantity']} pcs'),
                        _buildInfoRow('Status', product['status']),
                        _buildInfoRow('Tanggal Masuk',
                            _formatDate(product['created_at'])),
                      ],
                    ),
                  ),

                  // Footer
                  pw.Positioned(
                    bottom: 20,
                    child: pw.Text(
                      'Dicetak pada: ${_formatDate(DateTime.now().toIso8601String())}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Simpan ke folder Downloads
      final output = await getDownloadsDirectory();
      final file = File(
          '${output!.path}/inventory_${product['id'].toString().substring(0, 8)}.pdf');
      await file.writeAsBytes(await pdf.save());

      Get.snackbar(
        'Sukses',
        'PDF tersimpan di folder Downloads',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Buka file PDF
      await OpenFile.open(file.path);
    } catch (e) {
      print('Error saving PDF: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan PDF: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
          pw.Text(': '),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}
