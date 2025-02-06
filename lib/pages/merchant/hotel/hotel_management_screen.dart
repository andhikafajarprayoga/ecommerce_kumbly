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

  @override
  void initState() {
    super.initState();
    _fetchHotels();
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
        title: Text('Kelola Hotel'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () =>
                Get.to(() => AddEditHotelScreen())?.then((_) => _fetchHotels()),
          ),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (hotels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Belum ada hotel'),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Get.to(() => AddEditHotelScreen())
                      ?.then((_) => _fetchHotels()),
                  icon: Icon(Icons.add),
                  label: Text('Tambah Hotel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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
              margin: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hotel Image
                  if (hotel['image_url'] != null &&
                      (hotel['image_url'] as List).isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        hotel['image_url'][0],
                        fit: BoxFit.cover,
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                hotel['name'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => Get.to(() =>
                                          AddEditHotelScreen(hotel: hotel))
                                      ?.then((_) => _fetchHotels()),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Konfirmasi'),
                                      content: Text(
                                          'Yakin ingin menghapus hotel ini?'),
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
                                          ),
                                          child: Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tipe Kamar: ${(hotel['room_types'] ?? []).length}',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Rating: ${hotel['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  print(
                                      'Debug hotel id before navigation: ${hotel['id']}'); // Debug print
                                  _navigateToBookings(hotel['id']);
                                },
                                child: Text('Lihat Booking'),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Get.to(() =>
                                    ManageRoomTypesScreen(
                                        hotelId: hotel['id'])),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                ),
                                child: Text('Kelola Kamar'),
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
    );
  }
}
