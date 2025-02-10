import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'BUKTI INVENTORY BARANG',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Produk: ${product['products']['name']}'),
                pw.Text('Quantity: ${product['quantity']}'),
                pw.Text('Tanggal Masuk: ${_formatDate(product['created_at'])}'),
                pw.Text('Status: ${product['status']}'),
                if (product['courier_id'] != null)
                  pw.Text('Kurir: ${product['name_courier'] ?? 'Unknown'}'),
                pw.SizedBox(height: 20),
                pw.Text('Branch ID: ${product['branch_id']}'),
              ],
            );
          },
        ),
      );

      // Get directory
      final output = await getExternalStorageDirectory(); // Android only
      // For iOS, use: await getApplicationDocumentsDirectory();

      final fileName =
          'inventory_receipt_${product['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output?.path}/$fileName');

      // Save PDF
      await file.writeAsBytes(await pdf.save());

      Get.snackbar(
        'Sukses',
        'PDF tersimpan di: ${file.path}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () async {
            // Buka PDF
            await Printing.sharePdf(
              bytes: await pdf.save(),
              filename: fileName,
            );
          },
          child: const Text(
            'Buka',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menyimpan PDF: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('Error saving PDF: $e');
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}
