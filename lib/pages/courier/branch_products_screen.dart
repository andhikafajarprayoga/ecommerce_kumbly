import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class BranchProductsScreen extends StatefulWidget {
  const BranchProductsScreen({Key? key}) : super(key: key);

  @override
  State<BranchProductsScreen> createState() => _BranchProductsScreenState();
}

class _BranchProductsScreenState extends State<BranchProductsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> branchProducts =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  TabController? _tabController;
  final List<String> _tabs = ['Perlu Dikirim', 'Selesai'];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID');
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController?.addListener(() {
      setState(() {});
    });
    _fetchBranchProducts();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchBranchProducts() async {
    try {
      isLoading.value = true;
      final courierId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('branch_products')
          .select('''
            *,
            product:products (
              name,
              description,
              price
            ),
            branch:branches (
              name,
              address,
              phone
            ),
            
            order:orders (
              shipping_address,
              total_amount,
              shipping_cost,
              information_merchant,
              payment_method:payment_methods (
                name,
                admin
              ),
              buyer:users!buyer_id (
                full_name,
                phone
            
              )
            )
          ''')
          .eq('courier_id', courierId)
          .order('created_at', ascending: false);

      branchProducts.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching branch products: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data produk cabang',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket dari Cabang'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController!,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredProducts = _tabController!.index == 0
            ? branchProducts
                .where((item) =>
                    item['courier_id'] == _supabase.auth.currentUser!.id &&
                    item['status'] == 'received' &&
                    item['shipping_status'] == null)
                .toList()
            : branchProducts
                .where((item) =>
                    item['courier_id'] == _supabase.auth.currentUser!.id &&
                    item['shipping_status'] == 'delivered')
                .toList();

        // Hitung total COD untuk tab Selesai
        if (_tabController!.index == 1) {
          double totalCOD = 0;
          for (var item in filteredProducts) {
            final order = item['order'] as Map<String, dynamic>;
            final paymentMethod =
                order['payment_method'] as Map<String, dynamic>?;
            if (paymentMethod != null && paymentMethod['name'] == 'COD') {
              totalCOD += (order['total_amount'] as num).toDouble();
            }
          }

          // Tampilkan ringkasan total COD jika ada
          if (totalCOD > 0) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan COD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Pembayaran COD:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(totalCOD),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildProductsList(filteredProducts),
                ),
              ],
            );
          }
        }

        return _buildProductsList(filteredProducts);
      }),
    );
  }

  Widget _buildProductsList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada paket ${_tabController!.index == 0 ? 'yang perlu dikirim' : 'yang selesai'}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBranchProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final item = products[index];
          final product = item['product'] as Map<String, dynamic>;
          final branch = item['branch'] as Map<String, dynamic>;
          final order = item['order'] as Map<String, dynamic>;
          final buyer = order['buyer'] as Map<String, dynamic>;
          final paymentMethod = order['payment_method'];

          // Hitung total
          double totalAmount = (order['total_amount'] ?? 0) +
              (order['shipping_cost'] ?? 0) +
              (order['payment_method']?['admin'] ?? 0);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Order #${item['order_id'].toString().substring(0, 8)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(item['status']),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  if (order['information_merchant'] != null) ...[
                    ..._buildMerchantInfo(order['information_merchant']),
                  ],
                  _buildInfoRow('Cabang', branch['name'], Icons.store),
                  _buildInfoRow('Jumlah', '${item['quantity']} unit',
                      Icons.shopping_basket),
                  _buildInfoRow('Pembeli', buyer['full_name'], Icons.person),
                  _buildInfoRowWithIcon(
                    Icons.phone,
                    'Telepon Pembeli',
                    InkWell(
                      onTap: () => _launchWhatsApp(buyer['phone']),
                      child: Text(
                        buyer['phone'],
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  _buildInfoRowWithIcon(
                    Icons.location_on,
                    'Alamat Pengiriman',
                    InkWell(
                      onTap: () => _launchMaps(order['shipping_address']),
                      child: Text(
                        order['shipping_address'],
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  _buildInfoRow(
                    'Metode Pembayaran',
                    paymentMethod != null
                        ? (paymentMethod as Map<String, dynamic>)['name'] ??
                            'Tidak diketahui'
                        : 'Tidak diketahui',
                    Icons.payment,
                  ),
                  _buildInfoRow(
                    'Ongkir',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(order['shipping_cost'] ?? 0),
                    Icons.local_shipping,
                  ),
                  _buildInfoRow(
                    'Admin Fee',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(order['payment_method']?['admin'] ?? 0),
                    Icons.attach_money,
                  ),
                  _buildInfoRow(
                    'Produk',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(order['total_amount'] ?? 0),
                    Icons.inventory_2_outlined,
                  ),
                  _buildInfoRow(
                    'Total',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(totalAmount), // Tampilkan total
                    Icons.attach_money,
                    // Ganti icon sesuai kebutuhan
                  ),
                  _buildInfoRow(
                    'Tanggal',
                    DateFormat('dd MMMM yyyy', 'id_ID').format(
                      DateTime.parse(item['created_at']),
                    ),
                    Icons.calendar_today,
                  ),
                  const SizedBox(height: 16),
                  if (item['status'] == 'received' &&
                      _tabController!.index == 0) ...[
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(
                                  source: ImageSource.camera);

                              if (image == null) {
                                Get.snackbar(
                                  'Error',
                                  'Mohon ambil foto bukti pengiriman',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }

                              // Upload bukti pengiriman
                              final String fileName =
                                  '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
                              final file = File(image.path);

                              try {
                                await _supabase.storage
                                    .from('products')
                                    .upload('shipping-proofs/$fileName', file);

                                // Setelah upload berhasil, lanjut ke dialog konfirmasi
                                _showConfirmationDialog(item['id']);
                              } catch (e) {
                                print('Error uploading image: $e');
                                Get.snackbar(
                                  'Error',
                                  'Gagal mengupload foto bukti pengiriman',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            label: const Text(
                              'Ambil Foto & Selesaikan',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (item['status'] == 'shipping') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _completeDelivery(
                          orderId: item['order_id'],
                          branchProductId: item['id'],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Selesai Pengiriman'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: value,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'received':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        text = 'Diterima';
        icon = Icons.inbox;
        break;
      case 'shipping':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        text = 'Dikirim';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = 'Terkirim';
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog(String branchProductId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Konfirmasi Pengiriman'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda menyelesaikan pengiriman paket ini?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Pastikan :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildChecklistItem('paket dalam kondisi baik'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startDelivery(branchProductId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Selesaikan Pengiriman',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      },
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _startDelivery(String branchProductId) async {
    try {
      // Update status di branch_products
      await _supabase
          .from('branch_products')
          .update({'shipping_status': 'delivered'}).eq('id', branchProductId);

      // Update status di orders
      final branchProduct =
          branchProducts.firstWhere((item) => item['id'] == branchProductId);
      await _supabase
          .from('orders')
          .update({'status': 'delivered'}).eq('id', branchProduct['order_id']);

      await _fetchBranchProducts();

      Get.snackbar(
        'Sukses',
        'Pengiriman dimulai',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error starting delivery: $e');
      Get.snackbar(
        'Error',
        'Gagal memulai pengiriman',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _completeDelivery({
    required String orderId,
    required String branchProductId,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        Get.snackbar(
          'Error',
          'Mohon ambil foto bukti pengiriman',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Upload bukti pengiriman
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final file = File(image.path);

      await _supabase.storage
          .from('products')
          .upload('shipping-proofs/$fileName', file);

      // Update status order dan branch product
      await _supabase.from('orders').update({
        'status': 'delivered',
        'shipping_proof': fileName,
      }).eq('id', orderId);

      await _supabase
          .from('branch_products')
          .update({'status': 'delivered'}).eq('id', branchProductId);

      await _fetchBranchProducts();

      Get.snackbar(
        'Sukses',
        'Pengiriman selesai',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error completing delivery: $e');
      Get.snackbar(
        'Error',
        'Gagal menyelesaikan pengiriman',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  List<Widget> _buildMerchantInfo(String merchantInfo) {
    try {
      final RegExp phoneRegex = RegExp(r'Telepon Toko: (\d+)');
      final RegExp addressRegex = RegExp(r'Alamat Toko: ({.*?})');

      final phoneMatch = phoneRegex.firstMatch(merchantInfo);
      final addressMatch = addressRegex.firstMatch(merchantInfo);

      String? phone = phoneMatch?.group(1);
      String? addressJson = addressMatch?.group(1);

      List<Widget> widgets = [];

      if (phone != null) {
        widgets.add(
          _buildInfoRowWithIcon(
            Icons.phone,
            'Telepon Penjual',
            InkWell(
              onTap: () => _launchWhatsApp(phone),
              child: Text(
                phone,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      }

      if (addressJson != null) {
        try {
          final addressMap = jsonDecode(addressJson);
          final formattedAddress = [
            addressMap['street'],
            addressMap['village'],
            addressMap['district'],
            addressMap['city'],
            addressMap['province'],
            addressMap['postal_code'],
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          widgets.add(
            _buildInfoRowWithIcon(
              Icons.location_on,
              'Alamat Penjual',
              InkWell(
                onTap: () => _launchMaps(formattedAddress),
                child: Text(
                  formattedAddress,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        } catch (e) {
          print('Error parsing address JSON: $e');
        }
      }

      return widgets;
    } catch (e) {
      print('Error parsing merchant info: $e');
      return [];
    }
  }

  void _launchWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62' + cleanPhone.substring(1);
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62' + cleanPhone;
    }
    final url = 'https://wa.me/$cleanPhone';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _launchMaps(String address) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
