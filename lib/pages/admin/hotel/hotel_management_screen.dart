import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'hotel_booking_detail_screen.dart';

class HotelManagementScreen extends StatefulWidget {
  @override
  _HotelManagementScreenState createState() => _HotelManagementScreenState();
}

class _HotelManagementScreenState extends State<HotelManagementScreen> {
  final supabase = Supabase.instance.client;
  String selectedStatus = 'all';
  List<Map<String, dynamic>> allBookings = [];
  List<Map<String, dynamic>> filteredBookings = [];
  final TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    try {
      setState(() => isLoading = true);

      var query = supabase.from('hotel_bookings').select('''
            id,
            hotel_id,
            user_id,
            room_type,
            check_in,
            check_out,
            total_nights,
            total_price,
            admin_fee,
            app_fee,
            status,
            guest_name,
            guest_phone,
            special_requests,
            created_at,
            payment_method_id,
            image_url,
            keterangan,
            hotels(id, name),
            payment_methods(id, name)
          ''');

      if (selectedStatus != 'all') {
        query = query.eq('status', selectedStatus);
      }

      final response = await query.order('created_at', ascending: false);
      print(
          'Debug - Full Response: $response'); // Debug print untuk melihat seluruh response

      setState(() {
        allBookings = List<Map<String, dynamic>>.from(response);
        applyFilters(searchController.text);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() => isLoading = false);
    }
  }

  void applyFilters(String searchQuery) {
    setState(() {
      filteredBookings = allBookings.where((booking) {
        if (searchQuery.isEmpty) return true;

        final id = booking['id'].toString().toLowerCase();
        final guestName = booking['guest_name'].toString().toLowerCase();
        final hotelName =
            booking['hotels']?['name']?.toString().toLowerCase() ?? '';
        final searchLower = searchQuery.toLowerCase();

        return id.contains(searchLower) ||
            guestName.contains(searchLower) ||
            hotelName.contains(searchLower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Hotel'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari booking ID atau nama tamu...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: applyFilters,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'Semua'),
                SizedBox(width: 8),
                _buildFilterChip('pending', 'Menunggu'),
                SizedBox(width: 8),
                _buildFilterChip('confirmed', 'Dikonfirmasi'),
                SizedBox(width: 8),
                _buildFilterChip('completed', 'Selesai'),
                SizedBox(width: 8),
                _buildFilterChip('cancelled', 'Dibatalkan'),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredBookings.isEmpty
                    ? Center(
                        child: Text('Tidak ada booking ditemukan'),
                      )
                    : ListView.builder(
                        itemCount: filteredBookings.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final booking = filteredBookings[index];
                          return _buildBookingCard(booking);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    return FilterChip(
      selected: selectedStatus == status,
      label: Text(label),
      onSelected: (selected) {
        setState(() => selectedStatus = status);
        fetchBookings();
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selectedStatus == status ? Colors.green : Colors.black87,
        fontWeight:
            selectedStatus == status ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final checkIn = DateTime.parse(booking['check_in']);
    final checkOut = DateTime.parse(booking['check_out']);

    // Hitung total keseluruhan
    double totalPrice = (booking['total_price'] ?? 0).toDouble();
    double adminFee = (booking['admin_fee'] ?? 0).toDouble();
    double appFee = (booking['app_fee'] ?? 0).toDouble();
    double grandTotal = totalPrice + adminFee + appFee;

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Booking ID: ${booking['id'].toString().substring(0, 8)}...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(booking['status']),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.hotel, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${booking['hotels']?['name'] ?? 'Unknown'}',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  '${booking['guest_name']}',
                  style: TextStyle(fontSize: 15),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check-in',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(checkIn),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Check-out',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(checkOut),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.payment, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pembayaran:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,###').format(grandTotal)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      booking['keterangan'] ?? false
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: Colors.white,
                    ),
                    label: Text(
                      booking['keterangan'] ?? false
                          ? 'Sudah Bayar'
                          : 'Belum Bayar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: booking['keterangan'] ?? false
                          ? Colors.green
                          : Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _updateKeterangan(
                        booking['id'], !(booking['keterangan'] ?? false)),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () =>
                      Get.to(() => HotelBookingDetailScreen(booking: booking)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Menunggu';
        break;
      case 'confirmed':
        color = Colors.blue;
        label = 'Dikonfirmasi';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Selesai';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Dibatalkan';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Future<void> _updateKeterangan(String bookingId, bool value) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Konfirmasi'),
        content: Text(value
            ? 'Tandai sebagai sudah dibayar?'
            : 'Tandai sebagai belum dibayar?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: value ? Colors.green : Colors.red,
            ),
            child: Text(
              'Ya, Lanjutkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await supabase
            .from('hotel_bookings')
            .update({'keterangan': value}).eq('id', bookingId);

        fetchBookings(); // Refresh data
        Get.snackbar(
          'Sukses',
          'Status pembayaran berhasil diperbarui',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        print('Error updating keterangan: $e');
        Get.snackbar(
          'Error',
          'Gagal memperbarui status pembayaran',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
