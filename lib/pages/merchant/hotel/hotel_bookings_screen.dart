import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase/supabase.dart';

class HotelBookingsScreen extends StatefulWidget {
  final String hotelId;

  const HotelBookingsScreen({Key? key, required this.hotelId})
      : super(key: key);

  @override
  _HotelBookingsScreenState createState() => _HotelBookingsScreenState();
}

class _HotelBookingsScreenState extends State<HotelBookingsScreen> {
  final supabase = Supabase.instance.client;
  RxList<Map<String, dynamic>> bookings = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final response = await supabase
          .from('hotel_bookings')
          .select('''
          *,
            users:user_id (
              email,
              phone
            )
          ''')
          .eq('hotel_id', widget.hotelId)
          .order('created_at', ascending: false);

      bookings.value = List<Map<String, dynamic>>.from(response);
      isLoading.value = false;
    } catch (e) {
      print('Error fetching bookings: $e');
    isLoading.value = false;
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await supabase
          .from('hotel_bookings')
          .update({'status': status}).eq('id', bookingId);

      await _fetchBookings();

      Get.snackbar(
        'Sukses',
        'Status booking berhasil diupdate',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengupdate status: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Booking'),
        backgroundColor: AppTheme.primary,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (bookings.isEmpty) {
          return Center(child: Text('Belum ada booking'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final checkIn = DateTime.parse(booking['check_in']);
            final checkOut = DateTime.parse(booking['check_out']);

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Booking #${booking['id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStatusChip(booking['status']),
                      ],
                    ),
                    Divider(),
                    _buildInfoRow('Tamu', booking['guest_name']),
                    _buildInfoRow('Telepon', booking['guest_phone']),
                    _buildInfoRow('Email', booking['users']['email']),
                    _buildInfoRow('Tipe Kamar', booking['room_type']),
                    _buildInfoRow(
                      'Check-in',
                      DateFormat('dd MMM yyyy').format(checkIn),
                    ),
                    _buildInfoRow(
                      'Check-out',
                      DateFormat('dd MMM yyyy').format(checkOut),
                    ),
                    _buildInfoRow(
                      'Total',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(booking['total_price']),
                    ),
                    if (booking['special_requests'] != null &&
                        booking['special_requests'].isNotEmpty)
                      _buildInfoRow(
                          'Permintaan Khusus', booking['special_requests']),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (booking['status'] == 'pending')
                          ElevatedButton(
                            onPressed: () => _updateBookingStatus(
                                booking['id'], 'confirmed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: Text('Konfirmasi'),
                          ),
                        if (booking['status'] == 'confirmed')
                          ElevatedButton(
                            onPressed: () => _updateBookingStatus(
                                booking['id'], 'completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                            ),
                            child: Text('Selesai'),
                          ),
                        if (booking['status'] == 'pending')
                          ElevatedButton(
                            onPressed: () => _updateBookingStatus(
                                booking['id'], 'cancelled'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('Tolak'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
