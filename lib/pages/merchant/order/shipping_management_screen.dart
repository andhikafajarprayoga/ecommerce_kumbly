import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class ShippingManagementScreen extends StatefulWidget {
  const ShippingManagementScreen({Key? key}) : super(key: key);

  @override
  _ShippingManagementScreenState createState() =>
      _ShippingManagementScreenState();
}

class _ShippingManagementScreenState extends State<ShippingManagementScreen> {
  final supabase = Supabase.instance.client;
  final orders = <Map<String, dynamic>>[].obs;
  final searchController = TextEditingController();
  final selectedStatus = 'all'.obs;
  final ImagePicker _picker = ImagePicker();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Tambahkan list status untuk filter
  final List<Map<String, String>> statusOptions = [
    {'value': 'all', 'label': 'Semua'},
    {'value': 'pending', 'label': 'Belum Siap'},
    {'value': 'processing', 'label': 'Menunggu Kurir'},
    {'value': 'shipping', 'label': 'Sedang Dikirim'},
    {'value': 'transit', 'label': 'Transit'},
  ];

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
          .neq('status',
              'delivered') // Tambahkan ini untuk mengabaikan status delivered
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

  Future<void> _generateAndDownloadReceipt(Map<String, dynamic> order) async {
    try {
      final merchantData = await supabase
          .from('merchants')
          .select('store_name, store_address, store_phone')
          .eq('id', order['merchant_id'])
          .single();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('RESI PENGIRIMAN',
                      style: pw.TextStyle(fontSize: 24)),
                ),
                pw.SizedBox(height: 20),

                // Informasi Order
                pw.Text(
                    'No. Order: #${order['id'].toString().substring(0, 8)}'),
                pw.Text(
                    'Tanggal: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(order['created_at']))}'),
                pw.SizedBox(height: 20),

                // Informasi Merchant
                pw.Text('INFORMASI PENJUAL:'),
                pw.Text('Nama: ${merchantData['store_name']}'),
                pw.Text('Alamat: ${merchantData['store_address']}'),
                pw.Text('Telepon: ${merchantData['store_phone']}'),
                pw.SizedBox(height: 20),

                // Informasi Pengiriman
                pw.Text('INFORMASI PENERIMA:'),
                pw.Text(
                    'Nama: ${order['customer_name'] ?? 'Nama tidak tersedia'}'),
                pw.Text(
                    'Alamat: ${order['shipping_address'] ?? 'Alamat tidak tersedia'}'),
                pw.Text(
                    'Telepon: ${order['customer_phone'] ?? 'Telepon tidak tersedia'}'),
                pw.SizedBox(height: 20),

                // Total
                pw.Text(
                    'Total Pembayaran: Rp${NumberFormat('#,###').format(order['total_amount'])}'),
              ],
            );
          },
        ),
      );

      // Mendapatkan direktori Downloads
      final Directory? downloadsDirectory = await getExternalStorageDirectory();
      final String downloadPath = '${downloadsDirectory?.path}/Download';

      // Membuat folder Download jika belum ada
      final Directory downloadFolder = Directory(downloadPath);
      if (!await downloadFolder.exists()) {
        await downloadFolder.create(recursive: true);
      }

      // Simpan PDF di folder Downloads
      final file = File(
          '${downloadFolder.path}/resi_${order['id'].toString().substring(0, 8)}.pdf');
      await file.writeAsBytes(await pdf.save());

      Get.snackbar(
        'Sukses',
        'PDF tersimpan di: ${file.path}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      print('Error generating receipt: $e');
      Get.snackbar(
        'Error',
        'Gagal membuat resi: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
      body: Column(
        children: [
          // Search dan Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari order...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => _filterOrders(),
                ),
                const SizedBox(height: 12),

                // Status Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Obx(() => DropdownButton<String>(
                        value: selectedStatus.value,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status['value'],
                            child: Text(status['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedStatus.value = value!;
                          _filterOrders();
                        },
                      )),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: Obx(() {
              final filteredOrders = orders.where((order) {
                // Filter berdasarkan status
                if (selectedStatus.value != 'all' &&
                    order['status'] != selectedStatus.value) {
                  return false;
                }

                // Filter berdasarkan search
                final searchQuery = searchController.text.toLowerCase();
                final orderId = order['id'].toString().toLowerCase();
                return orderId.contains(searchQuery);
              }).toList();

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada pesanan',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
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
              );
            }),
          ),
        ],
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
    // Tambahkan pengecekan admin_acc_note
    final String? adminAccNote = order['admin_acc_note'];

    if (adminAccNote == 'Tolak') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              'Dibatalkan karena ongkir tidak sesuai',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    switch (order['status']) {
      case 'pending':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: adminAccNote == 'Terima'
                    ? () =>
                        _showConfirmationDialog(order['id'], order['status'])
                    : null,
                icon: const Icon(Icons.local_shipping,
                    size: 18, color: Colors.white),
                label: Text(
                  adminAccNote == 'Terima'
                      ? 'Siapkan Pesanan'
                      : 'Menunggu Konfirmasi Admin',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      adminAccNote == 'Terima' ? AppTheme.primary : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _generateAndDownloadReceipt(order),
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Resi',
              color: AppTheme.primary,
            ),
          ],
        );

      case 'processing':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _generateAndDownloadReceipt(order),
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Resi',
              color: AppTheme.primary,
            ),
          ],
        );

      case 'shipping':
        return Column(
          children: [
            if (order['courier_handover_photo'] != null) ...[
              Container(
                width: double.infinity,
                height: 150,
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _generateAndDownloadReceipt(order),
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('Resi', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            child: const Text('Ya, Siap Dijemput',
                style: TextStyle(color: Colors.white)),
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

            // Perbaikan cara mengambil URL gambar
            String? imageUrl;
            if (product != null && product['image_url'] != null) {
              try {
                // Parse string JSON array menjadi List
                final List<dynamic> imageUrls =
                    json.decode(product['image_url']);
                if (imageUrls.isNotEmpty) {
                  imageUrl = imageUrls[0]; // Ambil URL pertama
                }
                print('Debug - Image URL: $imageUrl'); // Debug print
              } catch (e) {
                print('Error parsing image URL: $e');
                imageUrl = null;
              }
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
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
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

  void _filterOrders() {
    setState(() {
      // Trigger rebuild untuk menerapkan filter
    });
  }
}
