import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchOrders();
    _listenToOrderChanges();
  }

  @override
  void dispose() {
    // Batalkan subscription stream jika ada
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final orderId = response.payload;
          final order = orders.firstWhereOrNull((o) => o['id'] == orderId);
          if (order != null) {
            // Navigasi ke detail pesanan jika diperlukan
          }
        }
      },
    );
  }

  void _listenToOrderChanges() {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', currentUserId)
        .listen((List<Map<String, dynamic>> updatedOrders) {
          print(
              'DEBUG: Stream received update with ${updatedOrders.length} orders'); // Debug print

          // Filter untuk status yang relevan
          final filteredOrders = updatedOrders
              .where((order) =>
                  order['status'] != 'cancelled' &&
                  ['pending', 'processing', 'shipping', 'transit']
                      .contains(order['status']))
              .toList();

          print(
              'DEBUG: Filtered orders count: ${filteredOrders.length}'); // Debug print

          for (var order in filteredOrders) {
            final oldOrder =
                orders.firstWhereOrNull((o) => o['id'] == order['id']);
            if (oldOrder != null && oldOrder['status'] != order['status']) {
              if (order['status'] == 'delivered' ||
                  order['status'] == 'completed') {
                _showNotification(
                  'Status Pesanan Berubah',
                  'Pesanan #${order['id'].toString().substring(0, 8)} telah ${order['status'] == 'delivered' ? 'diterima pembeli' : 'selesai'}',
                  order['id'],
                );
              }
            }
          }

          if (mounted) {
            orders.assignAll(filteredOrders);
            print(
                'DEBUG: Updated orders list with ${orders.length} items'); // Debug print
          }
        });
  }

  Future<void> _showNotification(
      String title, String body, String orderId) async {
    const androidDetails = AndroidNotificationDetails(
      'merchant_order_status',
      'Merchant Order Status',
      channelDescription: 'Notifications for merchant order status changes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: orderId,
    );
  }

  Future<void> _fetchOrders() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      print('DEBUG: Fetching orders for merchant: $currentUserId');

      final response = await supabase
          .from('orders')
          .select('''
            *,
            order_items!inner (
              id,
              quantity,
              price,
              product_id,
              products!inner (
                id,
                name,
                image_url,
                description
              )
            )
          ''')
          .eq('merchant_id', currentUserId)
          .neq('status', 'cancelled')
          .inFilter('status', ['pending', 'processing', 'shipping', 'transit'])
          .order('created_at', ascending: false);

      print(
          'DEBUG: Raw response: $response'); // Debug print untuk melihat response mentah

      if (response != null && response is List) {
        orders.value = List<Map<String, dynamic>>.from(response);
        print('DEBUG: Orders loaded: ${orders.length}');

        // Debug print untuk setiap order
        for (var order in orders) {
          print('DEBUG: Order ID: ${order['id']}');
          print('DEBUG: Order Status: ${order['status']}');
          print(
              'DEBUG: Order Items Length: ${(order['order_items'] as List?)?.length ?? 0}');
          print('DEBUG: Full Order Data: $order'); // Tambahan debug print
        }
      }
    } catch (e, stackTrace) {
      print('Error fetching orders: $e');
      print(
          'Stack trace: $stackTrace'); // Tambahan debug print untuk stack trace
      Get.snackbar(
        'Error',
        'Gagal mengambil data pesanan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('orders')
          .update({'status': 'processing'})
          .eq('id', orderId)
          .eq('merchant_id', userId);

      await _fetchOrders(); // Refresh data setelah update

      Get.snackbar(
        'Sukses',
        'Pesanan siap untuk dijemput kurir',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
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

      // Ubah format nama file untuk membedakan dengan bukti pembayaran
      final String fileName =
          'handover_courier_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File(image.path);

      print('Debug: Uploading to bucket: payment-proofs');
      print('Debug: File name: $fileName');

      // Upload ke bucket payment-proofs
      await supabase.storage.from('payment-proofs').upload(fileName, file);

      // Dapatkan URL publik
      final String photoUrl =
          supabase.storage.from('payment-proofs').getPublicUrl(fileName);

      print('Debug: Upload successful. URL: $photoUrl');
      return photoUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload foto serah terima',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengiriman'),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Obx(
        () => orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderItems = List<Map<String, dynamic>>.from(
                      order['order_items'] ?? []);

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Order #${order['id'].toString().substring(0, 8)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              _buildStatusChip(order['status']),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Daftar Produk yang Dipesan
                        _buildProductList(orderItems),

                        // Alamat dan Total
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 20, color: AppTheme.primary),
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
                                  Icon(Icons.payments_outlined,
                                      size: 20, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total: Rp${NumberFormat('#,###').format(order['total_amount'])}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
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
    IconData statusIcon;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Belum Siap';
        statusIcon = Icons.pending_outlined;
        break;
      case 'processing':
        chipColor = Colors.blue;
        statusText = 'Menunggu Kurir';
        statusIcon = Icons.local_shipping_outlined;
        break;
      case 'shipping':
        chipColor = Colors.green;
        statusText = 'Sedang Dikirim';
        statusIcon = Icons.delivery_dining;
        break;
      default:
        chipColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: chipColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                icon: const Icon(Icons.local_shipping,
                    size: 18, color: Colors.white),
                label: const Text(
                  'Siapkan Pesanan',
                  style: TextStyle(color: Colors.white),
                ),
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
                icon:
                    const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                label: const Text('Foto pengiriman',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 104, 104, 104),
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
                icon: const Icon(Icons.local_shipping,
                    size: 18, color: Colors.white),
                label: const Text('Siapkan Pesanan',
                    style: TextStyle(color: Colors.white)),
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
                icon:
                    const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                label: const Text('Foto Serah Terima',
                    style: TextStyle(color: Colors.white)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Produk yang Dipesan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderItems.length,
          itemBuilder: (context, index) {
            final item = orderItems[index];
            final product = item['products'];

            // Ambil URL gambar pertama dari array
            String? imageUrl;
            if (product != null &&
                product['image_url'] != null &&
                product['image_url'] is List &&
                (product['image_url'] as List).isNotEmpty) {
              imageUrl = (product['image_url'] as List)[0] as String;
              print('Debug - Product: $product'); // Debug print
              print(
                  'Debug - Image URLs: ${product['image_url']}'); // Debug print
              print('Debug - Selected Image URL: $imageUrl'); // Debug print
            }

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
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error'); // Debug print
                          return _buildImagePlaceholder();
                        },
                      ),
                    ),
                  ] else
                    _buildImagePlaceholder(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product?['name'] ?? 'Nama Produk Tidak Tersedia',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jumlah: ${item['quantity']} pcs',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@Rp${NumberFormat('#,###').format(item['price'])}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: Rp${NumberFormat('#,###').format(item['price'] * item['quantity'])}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
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

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 30,
      ),
    );
  }
}
