import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../pages/buyer/profile/detail_pesanan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../pages/buyer/profile/detail_pesanan_hotel.dart';
import '../../../utils/date_formatter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../pages/buyer/profile/hotel_rating_screen.dart';
import '../../../../pages/buyer/chat/chat_detail_screen.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../kirim_barang/detail_shipping_request_screen.dart';

final supabase = Supabase.instance.client;

class PesananSayaScreen extends StatefulWidget {
  const PesananSayaScreen({super.key});

  @override
  State<PesananSayaScreen> createState() => _PesananSayaScreenState();
}

class _PesananSayaScreenState extends State<PesananSayaScreen>
    with SingleTickerProviderStateMixin {
  final OrderController orderController = Get.put(OrderController());
  late TabController _tabController;
  RxString selectedFilter = 'all'.obs; // Ubah default dari 'pending' ke 'all'
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Tambahkan variable untuk shipping requests
  RxList<Map<String, dynamic>> shippingRequests = <Map<String, dynamic>>[].obs;
  RxBool isLoadingShipping = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _tabController = TabController(length: 3, vsync: this); // Ubah dari 2 ke 3
    orderController.fetchOrders();
    orderController.fetchHotelBookings();
    fetchShippingRequests(); // Tambahkan ini
    _listenToOrderChanges();
  }

  // Tambahkan fungsi untuk mengambil data shipping requests
  Future<void> fetchShippingRequests() async {
    try {
      isLoadingShipping.value = true;
      final response = await supabase
          .from('shipping_requests')
          .select('''
            *,
            pengiriman(nama_pengiriman),
            payment_methods(name)
          ''')
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      shippingRequests.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching shipping requests: $e');
    } finally {
      isLoadingShipping.value = false;
    }
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Tambahkan handler untuk notifikasi
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notifikasi ketika di-tap
        if (response.payload != null) {
          final orderId = response.payload;
          // Navigasi ke detail pesanan
          final order = orderController.orders
              .firstWhereOrNull((o) => o['id'] == orderId);
          if (order != null) {
            Get.to(() => DetailPesananScreen(order: order));
          }
        }
      },
    );
  }

  void _listenToOrderChanges() {
    supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', supabase.auth.currentUser!.id)
        .listen((List<Map<String, dynamic>> orders) {
          for (var order in orders) {
            final oldStatus = orderController.orders
                .firstWhereOrNull((o) => o['id'] == order['id'])?['status'];
            if (oldStatus != null && oldStatus != order['status']) {
              _showNotification(
                'Status Pesanan Berubah',
                'Pesanan #${formatOrderId(order['id'])} sekarang ${order['status']}',
                order['id'],
              );
            }
          }
        });
  }

  Future<void> _showNotification(
      String title, String body, String orderId) async {
    const androidDetails = AndroidNotificationDetails(
      'order_status_channel',
      'Order Status',
      channelDescription: 'Notifications for order status changes',
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

  String formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date).toLocal();
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
    } catch (e) {
      print('Error formatting currency: $e');
      return 'Rp 0';
    }
  }

  double calculateTotalPayment(Map<String, dynamic> order) {
    try {
      final totalAmount =
          double.tryParse(order['total_amount'].toString()) ?? 0.0;
      final shippingCost =
          double.tryParse(order['shipping_cost'].toString()) ?? 0.0;
      return totalAmount + shippingCost; // Hanya total produk + ongkir
    } catch (e) {
      print('Error calculating total payment: $e');
      return 0.0;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_cancellation':
        return Colors.orange.shade700;
      case 'processing':
        return Colors.blue;
      case 'shipping':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatOrderId(String orderId) {
    if (orderId.length > 6) {
      return '#${orderId.substring(orderId.length - 6)}';
    }
    return '#$orderId';
  }

  void _showCancelDialog(Map<String, dynamic> order) {
    final reasonController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: Text(
          'Batalkan Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan pesanan ini?',
              style: AppTheme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan',
                hintText: 'Masukkan alasan pembatalan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                Get.snackbar(
                  'Error',
                  'Harap masukkan alasan pembatalan',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              Get.back();
              _requestCancellation(order['id'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCancellation(String orderId, String reason) async {
    try {
      await supabase.from('order_cancellations').insert({
        'order_id': orderId,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
        'requested_by': supabase.auth.currentUser!.id,
        'reason': reason,
      });

      await supabase
          .from('orders')
          .update({'status': 'pending_cancellation'}).eq('id', orderId);

      Get.back();
      Get.snackbar(
        'Berhasil',
        'Permintaan pembatalan telah dikirim dan menunggu persetujuan Seller',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      orderController.fetchOrders();
    } catch (e) {
      print('Error requesting cancellation: $e');
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat memproses permintaan pembatalan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Di dalam ListView.builder, tambahkan tombol batalkan jika status pending
  Widget _buildCancelButton(Map<String, dynamic> order) {
    if (order['status'].toString().toLowerCase() != 'pending') {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () => _showCancelDialog(order),
      icon: const Icon(
        Icons.cancel_outlined,
        color: Colors.red,
        size: 18,
      ),
      label: Text(
        'Batalkan Pesanan',
        style: AppTheme.textTheme.bodySmall?.copyWith(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Update fungsi untuk build action buttons
  Widget _buildOrderActions(Map<String, dynamic> order) {
    final status = order['status'].toString().toLowerCase();
    final hasRating = order['has_rating'] ?? false;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (status == 'pending')
              _buildCancelButton(order)
            else if (status == 'pending_cancellation')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Menunggu Persetujuan seller',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (status == 'delivered')
              TextButton.icon(
                onPressed: () => _showCompleteOrderDialog(order),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 18,
                ),
                label: Text(
                  'Selesaikan Pesanan',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Get.to(() => DetailPesananScreen(order: order));
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Lihat Detail',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Tambahkan tombol chat dengan penjual
        TextButton.icon(
          onPressed: () => _chatWithSeller(order),
          icon: const Icon(
            Icons.chat_outlined,
            color: Colors.blue,
            size: 18,
          ),
          label: Text(
            'Hubungi Penjual',
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Tambahkan fungsi untuk memulai chat dengan penjual
  void _chatWithSeller(Map<String, dynamic> order) async {
    try {
      // Cek apakah merchant_id ada di order
      if (order['merchant_id'] == null) {
        // Jika tidak ada, coba ambil dari database
        final orderData = await supabase
            .from('orders')
            .select('merchant_id')
            .eq('id', order['id'])
            .single();

        if (orderData == null || orderData['merchant_id'] == null) {
          throw Exception('Merchant ID tidak ditemukan dalam order');
        }

        // Update order dengan merchant_id yang baru didapat
        order['merchant_id'] = orderData['merchant_id'];
      }

      // Ambil detail merchant user
      final merchantUser = await supabase
          .from('users')
          .select('*, merchants(*)')
          .eq('id', order['merchant_id'])
          .single();

      if (merchantUser == null) {
        throw Exception('Data user merchant tidak ditemukan');
      }

      // Cek apakah chat room sudah ada
      final existingRoom = await supabase
          .from('chat_rooms')
          .select()
          .eq('buyer_id', supabase.auth.currentUser!.id)
          .eq('seller_id', order['merchant_id'])
          .maybeSingle();

      String chatRoomId;
      Map<String, dynamic> chatRoom;

      if (existingRoom != null) {
        chatRoomId = existingRoom['id'];
        chatRoom = existingRoom;
      } else {
        // Buat chat room baru
        final newRoom = await supabase
            .from('chat_rooms')
            .insert({
              'buyer_id': supabase.auth.currentUser!.id,
              'seller_id': order['merchant_id'],
              'last_message_time': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        chatRoomId = newRoom['id'];
        chatRoom = newRoom;
      }

      // Siapkan data seller untuk ChatDetailScreen
      final seller = {
        'id': merchantUser['id'],
        'store_name': merchantUser['merchants']?[0]?['store_name'] ??
            merchantUser['full_name'],
        'full_name': merchantUser['full_name'],
        'image_url': merchantUser['image_url'],
      };

      // Navigasi ke halaman chat dengan mengirim data order
      Get.to(() => ChatDetailScreen(
            chatRoom: chatRoom,
            seller: seller,
            isAdminRoom: false,
            orderToConfirm: order,
          ));
    } catch (e) {
      print('Error starting chat: $e');
      Get.snackbar(
        'Gagal',
        'Tidak dapat memulai chat dengan penjual: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: AppTheme.primary,
        title: Text(
          'Pesanan Saya',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Produk'),
            Tab(text: 'Hotel'),
            Tab(text: 'Kirim Barang'), // Tambahkan tab baru
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductOrders(),
                _buildHotelBookings(),
                _buildShippingRequests(), // Tambahkan widget baru
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      child: Obx(() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _filterChip('Menunggu Pembayaran', 'pending'),
                _filterChip('Dikemas', 'processing'),
                _filterChip('Dikirim', 'shipping', 'transit', 'to_branch', 'delivered'),
                _filterChip('Selesai', 'completed'),
                _filterChip('Dibatalkan', 'cancelled'),
                _filterChip('Semua', 'all'), // Pastikan chip "Semua" ada di akhir dan default terpilih
              ],
            ),
          )),
    );
  }

  Widget _filterChip(String label, String value,
      [String? secondaryValue,
      String? tertiaryValue,
      String? quaternaryValue]) {
    final isSelected = selectedFilter.value == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey[200],
        selectedColor: AppTheme.primary,
        checkmarkColor: Colors.white, // ceklis jadi putih
        onSelected: (bool selected) {
          if (selected) {
            selectedFilter.value = value;

            // Cek apakah ini filter dengan multiple status
            if (secondaryValue != null) {
              List<String> statuses = [value];

              // Tambahkan status kedua
              statuses.add(secondaryValue);

              // Tambahkan status ketiga jika ada
              if (tertiaryValue != null) {
                statuses.add(tertiaryValue);
              }

              // Tambahkan status keempat jika ada
              if (quaternaryValue != null) {
                statuses.add(quaternaryValue);
              }

              orderController.filterOrdersByMultipleStatus(statuses);
            } else {
              // Filter normal untuk status tunggal
              orderController.filterOrders(value);
            }
          }
        },
      ),
    );
  }

  Widget _buildProductOrders() {
    return Obx(() {
      if (orderController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      // Tambahkan filter tambahan di sini untuk memastikan hanya status yang sesuai yang ditampilkan
      final filteredOrders = selectedFilter.value == 'processing'
          ? orderController.orders
              .where((order) =>
                  order['status'].toString().toLowerCase() == 'processing')
              .toList()
          : orderController.orders;

      if (filteredOrders.isEmpty) {
        return _buildEmptyState('Belum ada pesanan');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final totalAmount =
              double.tryParse(order['total_amount'].toString()) ?? 0.0;
          final shippingCost =
              double.tryParse(order['shipping_cost'].toString()) ?? 0.0;
          final totalPayment = totalAmount + shippingCost;

          print('Order: ${order}');
          print('Merchant ID: ${order['merchant_id']}');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Order ${formatOrderId(order['id'])}',
                            style: AppTheme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              getStatusColor(order['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order['status'].toUpperCase(),
                          style: AppTheme.textTheme.bodySmall?.copyWith(
                            color: getStatusColor(order['status']),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Tanggal Pesanan',
                        DateFormatter.formatShortDate(order['created_at'] ??
                            DateTime.now().toIso8601String()),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                        Icons.payments_outlined,
                        'Total Produk + Ongkir',
                        formatCurrency(totalPayment),
                      ),
                      if (order['payment_group_id'] != null) ...[
                        FutureBuilder<Map<String, dynamic>?>(
                          future: supabase
                              .from('payment_groups')
                              .select()
                              .eq('id', order['payment_group_id'])
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final adminFee = double.tryParse(
                                      snapshot.data!['admin_fee'].toString()) ??
                                  0.0;
                              return Column(
                                children: [
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.payments_outlined,
                                    'Biaya Admin',
                                    formatCurrency(adminFee),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Divider(height: 1),
                                  ),
                                  _buildInfoRow(
                                    Icons.payments_outlined,
                                    'Total yang Harus Dibayar',
                                    formatCurrency(totalPayment + adminFee),
                                    isHighlighted: true,
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Alamat Pengiriman',
                        order['shipping_address'],
                      ),
                    ],
                  ),
                ),

                // Tombol Detail
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildOrderActions(order),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildHotelBookings() {
    return Obx(() {
      if (orderController.isLoadingHotel.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final filteredBookings = orderController.hotelBookings.where((booking) {
        return selectedFilter.value == 'all' ||
            booking['status'] == selectedFilter.value;
      }).toList();

      if (filteredBookings.isEmpty) {
        return _buildEmptyState('Belum ada booking hotel');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          return _buildHotelBookingCard(booking);
        },
      );
    });
  }

  Widget _buildHotelBookingCard(Map<String, dynamic> booking) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.hotel, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Booking ID: ${booking['id'].toString().substring(0, 8)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(booking['status']),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.business,
                  'Hotel',
                  booking['hotels']['name'] ?? 'Unknown Hotel',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.person,
                  'Tamu',
                  booking['guest_name'],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        Icons.calendar_today,
                        'Check-in',
                        DateFormat('dd MMM yyyy')
                            .format(DateTime.parse(booking['check_in'])),
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        Icons.calendar_today,
                        'Check-out',
                        DateFormat('dd MMM yyyy')
                            .format(DateTime.parse(booking['check_out'])),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  Icons.payments,
                  'Total Pembayaran',
                  formatCurrency(booking['total_price']),
                  isHighlighted: true,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => DetailPesananHotelScreen(booking: booking));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Tampilkan tombol rating hanya jika status completed dan belum diberi rating
                if (booking['status'] == 'completed' && !booking['has_rating'])
                  ElevatedButton(
                    onPressed: () => _showHotelRatingScreen(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Beri Rating',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: getStatusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk mulai belanja!',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted ? AppTheme.primary : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: isHighlighted ? AppTheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelBookingDialog(Map<String, dynamic> booking) {
    Get.dialog(
      AlertDialog(
        title: const Text('Batalkan Booking'),
        content: const Text('Apakah Anda yakin ingin membatalkan booking ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('hotel_bookings')
                    .update({'status': 'cancelled'}).eq('id', booking['id']);
                Get.back();
                orderController.fetchHotelBookings();
                Get.snackbar(
                  'Sukses',
                  'Booking berhasil dibatalkan',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Gagal membatalkan booking',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleteBookingDialog(Map<String, dynamic> booking) {
    Get.dialog(
      AlertDialog(
        title: const Text(
          'Selesaikan Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menyelesaikan pesanan ini?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Tidak',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('hotel_bookings')
                    .update({'status': 'completed'}).eq('id', booking['id']);
                Get.back();
                orderController.fetchHotelBookings();
                Get.snackbar(
                  'Sukses',
                  'Pesanan telah diselesaikan',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Gagal menyelesaikan pesanan',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text(
              'Ya, Selesaikan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Tambahkan fungsi dialog untuk menyelesaikan pesanan
  void _showCompleteOrderDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Selesaikan Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menyelesaikan pesanan ini?',
          style: AppTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _completeOrder(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              'Ya, Selesaikan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      // Ambil data order dengan merchant_id langsung dari tabel orders
      final orderData = await supabase
          .from('orders')
          .select('*, merchant_id, total_amount, shipping_cost')
          .eq('id', orderId)
          .single();

      if (orderData == null) {
        throw Exception('Order tidak ditemukan');
      }

      final totalAmount = double.parse(orderData['total_amount'].toString());
      final shippingCost = double.parse(orderData['shipping_cost'].toString());
      final merchantRevenue = totalAmount - shippingCost;

      // Ambil merchant_id langsung dari order
      final merchantId = orderData['merchant_id'];

      if (merchantId == null) {
        throw Exception('Merchant ID tidak ditemukan');
      }

      await supabase.rpc('complete_order', params: {
        'p_order_id': orderId,
        'p_merchant_id': merchantId,
        'p_amount': merchantRevenue,
      });

      Get.back();
      Get.snackbar(
        'Berhasil',
        'Pesanan telah diselesaikan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      orderController.fetchOrders();
    } catch (e) {
      print('Error completing order: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat menyelesaikan pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Tambahkan fungsi untuk menampilkan screen rating
  void _showRatingScreen(Map<String, dynamic> order) async {
    final result = await Get.to(() => HotelRatingScreen(booking: order));
    if (result == true) {
      orderController.fetchOrders();
    }
  }

  // Tambahkan fungsi untuk menampilkan screen rating hotel
  void _showHotelRatingScreen(Map<String, dynamic> booking) async {
    final result = await Get.to(() => HotelRatingScreen(booking: booking));
    if (result == true) {
      orderController.fetchHotelBookings();
    }
  }

  // Tambahkan widget untuk menampilkan shipping requests
  Widget _buildShippingRequests() {
    return Obx(() {
      if (isLoadingShipping.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final filteredRequests = shippingRequests.where((request) {
        if (selectedFilter.value == 'all') return true;
        
        // Map status filter ke status shipping
        switch (selectedFilter.value) {
          case 'pending':
            return request['status'] == 'pending' || request['status'] == 'waiting_verification';
          case 'processing':
            return request['status'] == 'confirmed' || request['status'] == 'picked_up';
          case 'shipping':
            return request['status'] == 'in_transit' || request['status'] == 'out_for_delivery';
          case 'completed':
            return request['status'] == 'delivered';
          case 'cancelled':
            return request['status'] == 'cancelled';
          default:
            return request['status'] == selectedFilter.value;
        }
      }).toList();

      if (filteredRequests.isEmpty) {
        return _buildEmptyState('Belum ada permintaan kirim barang');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredRequests.length,
        itemBuilder: (context, index) {
          final request = filteredRequests[index];
          return _buildShippingRequestCard(request);
        },
      );
    });
  }

  Widget _buildShippingRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kirim Barang #${request['id'].toString().length > 6
                          ? request['id'].toString().substring(request['id'].toString().length - 6)
                          : request['id'].toString()}',
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getShippingStatusColor(request['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getShippingStatusText(request['status']),
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: _getShippingStatusColor(request['status']),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.inventory_2_outlined,
                  'Nama Barang',
                  request['item_name'] ?? '-',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  Icons.scale_outlined,
                  'Berat',
                  '${request['weight']} kg',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  'Layanan Pengiriman',
                  request['pengiriman']?['nama_pengiriman'] ?? '-',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  Icons.payment_outlined,
                  'Metode Pembayaran',
                  request['payment_methods']?['name'] ?? '-',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  Icons.payments_outlined,
                  'Estimasi Biaya',
                  formatCurrency(request['estimated_cost']),
                  isHighlighted: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  'Tanggal Permintaan',
                  DateFormatter.formatShortDate(request['created_at'] ?? DateTime.now().toIso8601String()),
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: _buildShippingActions(request),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingActions(Map<String, dynamic> request) {
    final status = request['status'].toString().toLowerCase();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol batalkan untuk status pending
        if (status == 'pending')
          TextButton.icon(
            onPressed: () => _showCancelShippingDialog(request),
            icon: const Icon(
              Icons.cancel_outlined,
              color: Colors.red,
              size: 18,
            ),
            label: Text(
              'Batalkan',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        
        // Tombol lihat detail
        TextButton(
          onPressed: () {
            Get.to(() => DetailShippingRequestScreen(request: request));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          child: Row(
            children: [
              Text(
                'Lihat Detail',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getShippingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting_verification':
        return Colors.orange;
      case 'confirmed':
      case 'picked_up':
        return Colors.blue;
      case 'in_transit':
      case 'out_for_delivery':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getShippingStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'MENUNGGU';
      case 'waiting_verification':
        return 'VERIFIKASI';
      case 'confirmed':
        return 'DIKONFIRMASI';
      case 'picked_up':
        return 'DIAMBIL';
      case 'in_transit':
        return 'DALAM PERJALANAN';
      case 'out_for_delivery':
        return 'DIKIRIM';
      case 'delivered':
        return 'TERKIRIM';
      case 'cancelled':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }

  void _showCancelShippingDialog(Map<String, dynamic> request) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Batalkan Permintaan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan permintaan kirim barang ini?',
          style: AppTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Tidak',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _cancelShippingRequest(request['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelShippingRequest(String requestId) async {
    try {
      await supabase
          .from('shipping_requests')
          .update({'status': 'cancelled'})
          .eq('id', requestId);

      Get.back();
      Get.snackbar(
        'Berhasil',
        'Permintaan kirim barang berhasil dibatalkan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh data
      fetchShippingRequests();
    } catch (e) {
      print('Error cancelling shipping request: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat membatalkan permintaan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
void _showShippingDetail(Map<String, dynamic> request) {
  Get.dialog(
    AlertDialog(
      title: Text('Detail Kirim Barang'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(
              'ID Permintaan',
              '#${request['id'].toString().length >= 8
                  ? request['id'].toString().substring(request['id'].toString().length - 8)
                  : request['id'].toString()}'
            ),
            _buildDetailRow('Nama Barang', request['item_name'] ?? '-'),
            _buildDetailRow('Jenis Barang', request['item_type'] ?? '-'),
            _buildDetailRow('Berat', '${request['weight']} kg'),
            if (request['description'] != null && request['description'].toString().isNotEmpty)
              _buildDetailRow('Deskripsi', request['description']),
            _buildDetailRow('Pengirim', request['sender_name'] ?? '-'),
            _buildDetailRow('No. HP Pengirim', request['sender_phone'] ?? '-'),
            _buildDetailRow('Penerima', request['receiver_name'] ?? '-'),
            _buildDetailRow('No. HP Penerima', request['receiver_phone'] ?? '-'),
            _buildDetailRow('Layanan', request['pengiriman']?['nama_pengiriman'] ?? '-'),
            _buildDetailRow('Pembayaran', request['payment_methods']?['name'] ?? '-'),
            _buildDetailRow('Asuransi', request['insurance'] == true ? 'Ya' : 'Tidak'),
            _buildDetailRow('Estimasi Biaya', formatCurrency(request['estimated_cost'])),
            _buildDetailRow('Status', _getShippingStatusText(request['status'])),
            _buildDetailRow('Tanggal', DateFormatter.formatShortDate(request['created_at'])),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Tutup'),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.primary,
              fontSize: 12,
            ),
          ),
        ),
        Text(': ', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}


    }