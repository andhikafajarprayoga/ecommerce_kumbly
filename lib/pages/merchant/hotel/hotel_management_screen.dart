import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'add_edit_hotel_screen.dart';
import 'hotel_bookings_screen.dart';
import 'manage_room_types_screen.dart';

class HotelManagementScreen extends StatefulWidget {
  @override
  _HotelManagementScreenState createState() => _HotelManagementScreenState();
}

class _HotelManagementScreenState extends State<HotelManagementScreen> {
  final supabase = Supabase.instance.client;
  RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;
  RxMap<String, int> bookingCounts = <String, int>{}.obs;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
    _fetchBookingCounts();
  }

  Future<void> _fetchHotels() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      print('Debug userId: $userId'); // Debug print

      final response = await supabase
          .from('hotels')
          .select()
          .eq('merchant_id',
              userId) // Menggunakan userId langsung, bukan toString()
          .order('created_at', ascending: false);

      print('Debug hotels response: $response'); // Debug print

      hotels.value = List<Map<String, dynamic>>.from(response);
      isLoading.value = false;
    } catch (e) {
      print('Error fetching hotels: $e');
      isLoading.value = false;
    }
  }

  Future<void> _fetchBookingCounts() async {
    try {
      final response = await supabase
          .from('hotel_bookings')
          .select('hotel_id, status')
          .eq('status', 'pending');

      Map<String, int> counts = {};
      for (var booking in response) {
        String hotelId = booking['hotel_id'];
        counts[hotelId] = (counts[hotelId] ?? 0) + 1;
      }

      bookingCounts.value = counts;
    } catch (e) {
      print('Error fetching booking counts: $e');
    }
  }

  Future<void> _deleteHotel(String hotelId) async {
    try {
      await supabase.from('hotels').delete().eq('id', hotelId);
      await _fetchHotels();
      Get.snackbar(
        'Sukses',
        'Hotel berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus hotel: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _navigateToBookings(String hotelId) {
    print('Debug navigating to bookings with hotelId: $hotelId'); // Debug print
    if (hotelId.isNotEmpty) {
      Get.to(() => HotelBookingsScreen(hotelId: hotelId));
    } else {
      print('Error: Trying to navigate with empty hotelId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Hotel', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Tombol Tambah Hotel
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => AddEditHotelScreen())
                  ?.then((_) => _fetchHotels()),
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                'Tambah Hotel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),

          // List Hotel
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (hotels.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hotel_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada hotel',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Mulai tambahkan hotel Anda',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: hotels.length,
                itemBuilder: (context, index) {
                  final hotel = hotels[index];
                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  hotel['image_url'][0],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (bookingCounts[hotel['id']] != null)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.notifications_active,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '${bookingCounts[hotel['id']]} Menunggu',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  _buildActionButton(
                                    icon: Icons.edit,
                                    color: Colors.blue,
                                    onPressed: () => Get.to(() =>
                                            AddEditHotelScreen(hotel: hotel))
                                        ?.then((_) => _fetchHotels()),
                                  ),
                                  SizedBox(width: 5),
                                  _buildActionButton(
                                    icon: Icons.delete,
                                    color: Colors.red,
                                    onPressed: () => _showDeleteDialog(hotel),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Hotel Info
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      hotel['name'],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${hotel['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow(
                                icon: Icons.meeting_room,
                                label: 'Tipe Kamar',
                                value: '${(hotel['room_types'] ?? []).length}',
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.book_online,
                                      label: 'Lihat Booking',
                                      onTap: () =>
                                          _navigateToBookings(hotel['id']),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionCard(
                                      icon: Icons.meeting_room,
                                      label: 'Kelola Kamar',
                                      onTap: () => Get.to(() =>
                                          ManageRoomTypesScreen(
                                              hotelId: hotel['id'])),
                                      isPrimary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        constraints: BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppTheme.primary,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> hotel) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus hotel ${hotel['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _deleteHotel(hotel['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
