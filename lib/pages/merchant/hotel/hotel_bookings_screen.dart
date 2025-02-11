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
  RxList<Map<String, dynamic>> filteredBookings = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;
  final TextEditingController searchController = TextEditingController();
  RxMap<String, bool> expandedCards = <String, bool>{}.obs;

  @override
  void initState() {
    super.initState();
    print('Debug initState hotelId: ${widget.hotelId}');
    _fetchBookings();
    filteredBookings.value = bookings;
  }

  @override
  void dispose() {
    searchController.dispose();
    expandedCards.close();
    super.dispose();
  }

  void filterBookings(String query) {
    if (query.isEmpty) {
      filteredBookings.value = bookings;
    } else {
      filteredBookings.value = bookings.where((booking) {
        final bookingId = booking['id'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return bookingId.contains(searchQuery);
      }).toList();
    }
    print('Filtered bookings: ${filteredBookings.length}'); // Debug print
  }

  Future<void> _fetchBookings() async {
    try {
      if (widget.hotelId.isEmpty) {
        print('Error: hotelId is empty string');
        return;
      }

      final response = await supabase
          .from('hotel_bookings')
          .select()
          .eq('hotel_id', widget.hotelId)
          .order('created_at', ascending: false);

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

      // Urutkan booking: pending di atas, lainnya berdasarkan created_at
      bookingsWithUserData.sort((a, b) {
        if (a['status'] == 'pending' && b['status'] != 'pending') {
          return -1;
        } else if (a['status'] != 'pending' && b['status'] == 'pending') {
          return 1;
        } else {
          return DateTime.parse(b['created_at'])
              .compareTo(DateTime.parse(a['created_at']));
        }
      });

      bookings.value = bookingsWithUserData;
      filteredBookings.value = bookingsWithUserData;
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
        title: Text('Daftar Booking', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan ID Booking...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: filterBookings,
            ),
          ),
          // Booking List
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              final displayedBookings =
                  searchController.text.isEmpty ? bookings : filteredBookings;

              if (displayedBookings.isEmpty) {
                return Center(
                  child: Text(searchController.text.isEmpty
                      ? 'Belum ada booking'
                      : 'Tidak ada hasil pencarian'),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: displayedBookings.length,
                itemBuilder: (context, index) {
                  final booking = displayedBookings[index];
                  return _buildBookingCard(booking);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isExpanded = expandedCards[booking['id']] ?? true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() {
              expandedCards[booking['id']] =
                  !(expandedCards[booking['id']] ?? true);
            }),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.confirmation_number_outlined,
                                    size: 20, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Text(
                                  '#${booking['id'].toString().substring(0, 8)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildStatusChip(booking['status']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Column(
              children: [
                if (booking['status'] == 'pending')
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    child: Column(
                      children: [
                        // Status Pembayaran
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: booking['keterangan'] == true
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: booking['keterangan'] == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                booking['keterangan'] == true
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: booking['keterangan'] == true
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text(
                                booking['keterangan'] == true
                                    ? 'Pembayaran sudah dikonfirmasi admin'
                                    : 'Menunggu konfirmasi keterangan dari admin',
                                style: TextStyle(
                                  color: booking['keterangan'] == true
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tombol Aksi
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: booking['keterangan'] == true
                                    ? () => _updateBookingStatus(
                                        booking['id'], 'TRUE')
                                    : null,
                                icon: Icon(Icons.check_circle_outline,
                                    color: Colors.white),
                                label: Text(
                                  'Konfirmasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateBookingStatus(
                                    booking['id'], 'cancelled'),
                                icon: Icon(Icons.cancel_outlined,
                                    color: Colors.white),
                                label: Text(
                                  'Tolak',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                _buildBookingDetails(booking),
                if (booking['image_url'] != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long,
                                color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Bukti Pembayaran',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(booking['image_url']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    String displayValue = value;
    if (label == 'Telepon') {
      displayValue = value == 'N/A' ? 'Tidak ada nomor telepon' : value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            displayValue,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetails(Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
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
            _buildInfoRow('Permintaan', booking['special_requests']),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Menunggu Konfirmasi';
        statusIcon = Icons.access_time;
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'Dikonfirmasi';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Selesai';
        statusIcon = Icons.task_alt;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Dibatalkan';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status.toUpperCase();
        statusIcon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
