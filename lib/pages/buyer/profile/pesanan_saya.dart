import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../pages/buyer/profile/detail_pesanan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../pages/buyer/profile/detail_pesanan_hotel.dart';
import '../../../utils/date_formatter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  RxString selectedFilter = 'all'.obs;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _tabController = TabController(length: 2, vsync: this);
    orderController.fetchOrders();
    orderController.fetchHotelBookings();
    _listenToOrderChanges();
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
      return totalAmount + shippingCost;
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
      case 'shipped':
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

  // Tambahkan fungsi untuk menghapus pesanan
  void _showDeleteDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Hapus Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pesanan ini?',
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
            onPressed: () => _deleteOrder(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(String orderId) async {
    try {
      // Hapus order_items terlebih dahulu
      await supabase.from('order_items').delete().eq('order_id', orderId);

      // Hapus order_cancellations jika ada
      await supabase
          .from('order_cancellations')
          .delete()
          .eq('order_id', orderId);

      // Setelah semua dependensi dihapus, baru hapus order
      await supabase.from('orders').delete().eq('id', orderId);

      // Beri notifikasi sukses
      Get.back();
      Get.snackbar(
        'Berhasil',
        'Pesanan telah dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh daftar pesanan
      orderController.fetchOrders();
    } catch (e) {
      print('Error deleting order: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat menghapus pesanan: $e',
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

    return Row(
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
        else if (status == 'cancelled')
          TextButton.icon(
            onPressed: () => _showDeleteDialog(order),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 18,
            ),
            label: Text(
              'Hapus Pesanan',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
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
    );
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
                _filterChip('Semua', 'all'),
                _filterChip('Menunggu Pembayaran', 'pending'),
                _filterChip('Dikonfirmasi', 'confirmed'),
                _filterChip('Selesai', 'completed'),
                _filterChip('Dibatalkan', 'cancelled'),
              ],
            ),
          )),
    );
  }

  Widget _filterChip(String label, String value) {
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
        onSelected: (bool selected) {
          selectedFilter.value = value;
          orderController.filterOrders(value);
          orderController.filterHotelBookings(value);
        },
      ),
    );
  }

  Widget _buildProductOrders() {
    return Obx(() {
      if (orderController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (orderController.orders.isEmpty) {
        return _buildEmptyState('Belum ada pesanan');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orderController.orders.length,
        itemBuilder: (context, index) {
          final order = orderController.orders[index];
          final totalPayment = calculateTotalPayment(order);

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
                        'Total Pembayaran',
                        formatCurrency(totalPayment),
                      ),
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
                      'Booking ID: ${formatOrderId(booking['id'])}',
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
          // Tombol Detail - Selalu tampil untuk semua status
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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
            child: const Text('Ya, Selesaikan'),
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
}
