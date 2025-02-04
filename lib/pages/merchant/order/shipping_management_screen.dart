import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ShippingManagementScreen extends StatefulWidget {
  const ShippingManagementScreen({Key? key}) : super(key: key);

  @override
  _ShippingManagementScreenState createState() =>
      _ShippingManagementScreenState();
}

class _ShippingManagementScreenState extends State<ShippingManagementScreen> {
  final supabase = Supabase.instance.client;
  final orders = <Map<String, dynamic>>[].obs;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase
          .from('orders')
          .select('''
          *,
          order_items (
            id,
            quantity,
            price,
            product:products (
              id,
              name,
              image_url,
              description
            )
          )
        ''')
          .eq('merchant_id', currentUserId)
          .or('status.eq.pending,status.eq.processing,status.eq.shipping')
          .order('created_at', ascending: false);

      orders.value = List<Map<String, dynamic>>.from(response);

      // Debug prints
      print('Response length: ${orders.value.length}');
      print('First order: ${orders.value.firstOrNull}');
      if (orders.value.isNotEmpty) {
        print('Order items: ${orders.value.first['order_items']}');
        if (orders.value.first['order_items'] != null) {
          final items = orders.value.first['order_items'] as List;
          if (items.isNotEmpty) {
            print('First product: ${items.first['product']}');
          }
        }
      }
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    try {
      if (currentStatus != 'pending') {
        Get.snackbar(
          'Peringatan',
          'Status ini hanya bisa diubah oleh kurir',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Hanya update status ke processing tanpa foto
      await supabase.from('orders').update({
        'status': 'processing',
      }).eq('id', orderId);

      Get.snackbar(
        'Sukses',
        'Pesanan siap untuk dijemput kurir',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _fetchOrders();
    } catch (e) {
      print('Error updating order: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui status pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<String?> _uploadCourierHandoverPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) return null;

      final String fileName =
          'handover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File(image.path);

      // Upload ke bucket yang sudah ada
      await supabase.storage
          .from('courier-handover-photos')
          .upload(fileName, file);

      // Dapatkan URL publik
      final String photoUrl = supabase.storage
          .from('courier-handover-photos')
          .getPublicUrl(fileName);

      return photoUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload foto',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengiriman'),
      ),
      body: Obx(
        () => orders.isEmpty
            ? const Center(child: Text('Tidak ada pesanan'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderItems = List<Map<String, dynamic>>.from(
                      order['order_items'] ?? []);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan ID dan Status
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order['id'].toString().substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _buildStatusChip(order['status']),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Daftar Produk yang Dipesan
                        _buildProductList(orderItems),

                        // Alamat
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order['shipping_address'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.payment_outlined,
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rp${order['total_amount'].toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildActionButtons(order),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Belum Siap';
        break;
      case 'processing':
        chipColor = Colors.blue;
        statusText = 'Menunggu Kurir';
        break;
      case 'shipping':
        chipColor = Colors.green;
        statusText = 'Sedang Dikirim';
        break;
      default:
        chipColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    switch (order['status']) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showConfirmationDialog(order['id'], order['status']),
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Siapkan Pesanan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showProcessingRequiredDialog(),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Foto Serah Terima'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );

      case 'processing':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Siapkan Pesanan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _uploadHandoverPhoto(order['id']),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Foto Serah Terima'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );

      case 'shipping':
        return Column(
          children: [
            if (order['courier_handover_photo'] != null) ...[
              Container(
                width: double.infinity,
                height: 150, // Ukuran foto lebih kecil
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(order['courier_handover_photo']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Sedang Dalam Pengiriman',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  void _showProcessingRequiredDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Peringatan'),
        content: const Text(
          'Anda harus mengubah status pesanan menjadi "Siap Dijemput" terlebih dahulu sebelum mengupload foto serah terima.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog(String orderId, String currentStatus) {
    return Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
          'Apakah pesanan sudah siap untuk dijemput kurir? '
          'Pastikan semua item sudah dikemas dengan baik.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _updateOrderStatus(orderId, currentStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Ya, Siap Dijemput'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadHandoverPhoto(String orderId) async {
    try {
      final String? photoUrl = await _uploadCourierHandoverPhoto();
      if (photoUrl == null) return;

      await supabase.from('orders').update({
        'courier_handover_photo': photoUrl,
        'status': 'shipping'
      }).eq('id', orderId);

      Get.snackbar(
        'Sukses',
        'Foto serah terima berhasil diupload',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _fetchOrders();
    } catch (e) {
      print('Error uploading handover photo: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload foto serah terima',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildProductList(List<Map<String, dynamic>> orderItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Produk yang Dipesan:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderItems.length,
          itemBuilder: (context, index) {
            final item = orderItems[index];
            final product = item['product'];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto Produk
                  if (product['image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product['image_url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 12),

                  // Informasi Produk
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Nama Produk Tidak Tersedia',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jumlah: ${item['quantity']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Harga: Rp${item['price']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Total: Rp${item['price'] * item['quantity']}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
