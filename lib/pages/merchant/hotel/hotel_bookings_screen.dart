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
    print('Debug initState hotelId: ${widget.hotelId}'); // Debug print
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      if (widget.hotelId.isEmpty) {
        print('Error: hotelId is empty string'); // Debug print
        return;
      }

      print(
          'Debug fetching bookings for hotelId: ${widget.hotelId}'); // Debug print

      final response = await supabase
          .from('hotel_bookings')
          .select()
          .eq('hotel_id', widget.hotelId)
          .order('created_at', ascending: false);

      print('Debug bookings response: $response'); // Debug print

      // Ambil data user untuk setiap booking
      final List<Map<String, dynamic>> bookingsWithUserData = [];
      for (var booking in response) {
        if (booking['user_id'] != null) {
          try {
            final userData = await supabase
                .from('users')
                .select('email, full_name')
                .eq('id', booking['user_id'])
                .single();

            booking['user_data'] = userData;
          } catch (e) {
            print('Error fetching user data for booking ${booking['id']}: $e');
            booking['user_data'] = {
              'email': 'N/A',
              'full_name': 'User tidak ditemukan'
            };
          }
        } else {
          booking['user_data'] = {
            'email': 'N/A',
            'full_name': 'User tidak ditemukan'
          };
        }

        bookingsWithUserData.add(booking);
      }

      print('Debug final bookings data: $bookingsWithUserData'); // Debug print
      bookings.value = bookingsWithUserData;
    } catch (e) {
      print('Error fetching bookings: $e');
    } finally {
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
            return _buildBookingCard(booking);
          },
        );
      }),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Status', booking['status'] ?? 'N/A'),
            _buildInfoRow('Tamu', booking['guest_name'] ?? 'N/A'),
            _buildInfoRow('Telepon', booking['guest_phone'] ?? 'N/A'),
            _buildInfoRow('Email', booking['user_data']?['email'] ?? 'N/A'),
            _buildInfoRow(
              'Check In',
              DateFormat('dd MMM yyyy')
                  .format(DateTime.parse(booking['check_in'])),
            ),
            _buildInfoRow(
              'Check Out',
              DateFormat('dd MMM yyyy')
                  .format(DateTime.parse(booking['check_out'])),
            ),
            _buildInfoRow('Tipe Kamar', booking['room_type'] ?? 'N/A'),
            _buildInfoRow('Jumlah Malam', '${booking['total_nights']} malam'),
            _buildInfoRow(
              'Total Pembayaran',
              NumberFormat.currency(
                locale: 'id',
                symbol: 'Rp ',
                decimalDigits: 0,
              ).format(booking['total_price']),
            ),
            if (booking['special_requests'] != null &&
                booking['special_requests'].isNotEmpty)
              _buildInfoRow('Permintaan Khusus', booking['special_requests']),
            const SizedBox(height: 16),
            if (booking['status'] == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        _updateBookingStatus(booking['id'], 'confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Terima'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _updateBookingStatus(booking['id'], 'cancelled'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Tolak'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
