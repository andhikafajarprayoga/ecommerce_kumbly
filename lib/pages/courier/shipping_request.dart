import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'dart:convert';
import 'courier_package_detail_screen.dart';
import 'courier_delivered_screen.dart';
import 'shipping_request_detail_screen.dart';

class ShippingRequestScreen extends StatefulWidget {
  @override
  _ShippingRequestScreenState createState() => _ShippingRequestScreenState();
}

class _ShippingRequestScreenState extends State<ShippingRequestScreen> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> availableRequests = [];
  List<Map<String, dynamic>> myRequests = [];
  bool isLoading = true;
  bool isLoadingMy = false;
  int selectedTab = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchAvailableRequests();
    fetchMyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAvailableRequests() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('shipping_requests')
          .select('''
            *,
            pengiriman(nama_pengiriman),
            payment_methods(name)
          ''')
          .eq('courier_status', 'waiting')
          .order('created_at', ascending: false);

      setState(() {
        availableRequests = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching available requests: $e');
      Get.snackbar('Error', 'Gagal memuat pesanan tersedia');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchMyRequests() async {
    setState(() => isLoadingMy = true);
    try {
      // Ambil nama kurir dari auth user
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .single();

      final courierName = userResponse['full_name'];

      final response = await supabase
          .from('shipping_requests')
          .select('''
            *,
            pengiriman(nama_pengiriman),
            payment_methods(name)
          ''')
          .eq('courier_name', courierName)
          .neq('courier_status', 'waiting')
          .order('created_at', ascending: false);

      setState(() {
        myRequests = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching my requests: $e');
    } finally {
      setState(() => isLoadingMy = false);
    }
  }

  Future<void> takeOrder(Map<String, dynamic> request) async {
    try {
      // Konfirmasi dulu
      bool confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text('Konfirmasi Ambil Pesanan'),
          content: Text('Apakah Anda yakin ingin mengambil pesanan ini?\n\nBarang: ${request['item_name']}\nBerat: ${request['weight']} kg\nEstimasi: ${formatCurrency(request['estimated_cost'])}'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('Ya, Ambil', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmed) return;

      // Loading
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Ambil nama kurir dari auth user
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      final userResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .single();

      final courierName = userResponse['full_name'];

      // Update pesanan dengan nama kurir dan status
      await supabase
          .from('shipping_requests')
          .update({
            'courier_name': courierName,
            'courier_status': 'taken',
            'status': 'confirmed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id'])
          .eq('courier_status', 'waiting'); // Pastikan masih waiting saat update

      Get.back(); // Tutup loading

      Get.snackbar(
        'Berhasil!',
        'Pesanan berhasil diambil. Pesanan akan muncul di tab "Pesanan Saya".',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh data
      fetchAvailableRequests();
      fetchMyRequests();

    } catch (e) {
      Get.back(); // Tutup loading jika ada
      print('Error taking order: $e');
      
      if (e.toString().contains('duplicate') || e.toString().contains('constraint')) {
        Get.snackbar(
          'Gagal',
          'Pesanan sudah diambil kurir lain. Silakan pilih pesanan lain.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Gagal mengambil pesanan: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }

      // Refresh untuk update status terbaru
      fetchAvailableRequests();
    }
  }

  Future<void> updateMyOrderStatus(Map<String, dynamic> request, String newStatus) async {
    try {
      await supabase
          .from('shipping_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', request['id']);

      Get.snackbar('Berhasil', 'Status pesanan berhasil diperbarui');
      fetchMyRequests();
    } catch (e) {
      print('Error updating status: $e');
      Get.snackbar('Error', 'Gagal memperbarui status');
    }
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String parseAddress(String? addressJson) {
    if (addressJson == null) return '-';
    try {
      Map<String, dynamic> address = json.decode(addressJson);
      List<String> parts = [];
      
      if (address['street'] != null) parts.add(address['street']);
      if (address['village'] != null) parts.add(address['village']);
      if (address['district'] != null) parts.add(address['district']);
      if (address['city'] != null) parts.add(address['city']);
      
      return parts.join(', ');
    } catch (e) {
      return addressJson;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting':
        return Colors.blue;
      case 'confirmed':
      case 'taken':
        return Colors.blue;
      case 'picked_up':
        return Colors.purple;
      case 'in_transit':
        return Colors.indigo;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'waiting':
        return 'Menunggu Kurir';
      case 'confirmed':
      case 'taken':
        return 'Diambil';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'in_transit':
        return 'Dalam Perjalanan';
      case 'out_for_delivery':
        return 'Sedang Dikirim';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lelang Pesanan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () => Get.to(() => CourierDeliveredScreen()),
            tooltip: 'Paket Terkirim & COD',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              fetchAvailableRequests();
              fetchMyRequests();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() => selectedTab = index),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined),
                  SizedBox(width: 4),
                  Text('Pesanan Tersedia'),
                  SizedBox(width: 4),
                  if (availableRequests.where((r) => r['status'] != 'pending').isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        availableRequests.where((r) => r['status'] != 'pending').length.toString(),
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined),
                  SizedBox(width: 4),
                  Text('Perlu Dikirim'),
                  SizedBox(width: 4),
                  if (myRequests
                          .where((r) =>
                              r['status'] != 'delivered' &&
                              r['status'] != 'cancelled' &&
                              r['status'] != 'completed')
                          .isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        myRequests
                            .where((r) =>
                                r['status'] != 'delivered' &&
                                r['status'] != 'cancelled' &&
                                r['status'] != 'completed')
                            .length
                            .toString(),
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableRequests(),
          _buildMyRequests(),
        ],
      ),
    );
  }

  Widget _buildAvailableRequests() {
    return RefreshIndicator(
      onRefresh: fetchAvailableRequests,
      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : availableRequests
              .where((r) => r['status'] != 'pending')
              .isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Tidak ada pesanan tersedia', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: fetchAvailableRequests,
                        child: Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: availableRequests
                      .where((r) => r['status'] != 'pending')
                      .length,
                  itemBuilder: (context, index) {
                    final filtered = availableRequests
                        .where((r) => r['status'] != 'pending')
                        .toList();
                    final request = filtered[index];
                    return _buildAvailableRequestCard(request);
                  },
                ),
    );
  }

  Widget _buildMyRequests() {
    return RefreshIndicator(
      onRefresh: fetchMyRequests,
      child: isLoadingMy
          ? Center(child: CircularProgressIndicator())
          : myRequests
              .where((r) =>
                  r['status'] != 'delivered' &&
                  r['status'] != 'cancelled' &&
                  r['status'] != 'completed')
              .isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Belum ada pesanan yang diambil', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: myRequests
                      .where((r) =>
                          r['status'] != 'delivered' &&
                          r['status'] != 'cancelled' &&
                          r['status'] != 'completed')
                      .length,
                  itemBuilder: (context, index) {
                    final filtered = myRequests
                        .where((r) =>
                            r['status'] != 'delivered' &&
                            r['status'] != 'cancelled' &&
                            r['status'] != 'completed')
                        .toList();
                    final request = filtered[index];
                    return _buildMyRequestCard(request);
                  },
                ),
    );
  }

  Widget _buildAvailableRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Get.to(() => ShippingRequestDetailScreen(request: request)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'SR#${request['id'].toString().padLeft(6, '0')}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(
                      'TERSEDIA',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Item Info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['item_name'],
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                        Text(
                          '${request['weight']} kg',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Jenis: ${request['item_type']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),

              // Address Info
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dari: ${parseAddress(request['sender_address'])}',
                          style: TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ke: ${parseAddress(request['receiver_address'])}',
                          style: TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Payment Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimasi Biaya',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        formatCurrency(request['estimated_cost']),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['created_at'])),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => takeOrder(request),
                  icon: Icon(Icons.assignment_turned_in, color: Colors.white),
                  label: Text(
                    'Ambil Pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildMyRequestCard(Map<String, dynamic> request) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Get.to(() => CourierPackageDetailScreen(request: request)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SR#${request['id'].toString().padLeft(6, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(request['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getStatusColor(request['status'])),
                    ),
                    child: Text(
                      getStatusText(request['status']),
                      style: TextStyle(
                        color: getStatusColor(request['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Item Info
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request['item_name'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${request['weight']} kg',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Contact Info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${request['sender_name']} → ${request['receiver_name']}',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Cost & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatCurrency(request['estimated_cost']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['created_at'])),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // View Detail Button
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => CourierPackageDetailScreen(request: request)),
                        icon: Icon(Icons.info_outline, size: 18),
                        label: Text('Lihat Detail'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Status action button tetap ada di sebelah kanan
                    if (request['status'] == 'confirmed')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateMyOrderStatus(request, 'picked_up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Ambil Barang', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    if (request['status'] == 'picked_up')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateMyOrderStatus(request, 'in_transit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Mulai Kirim', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    if (request['status'] == 'in_transit')
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateMyOrderStatus(request, 'delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Selesai Kirim', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}