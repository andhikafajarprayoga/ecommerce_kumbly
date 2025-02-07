import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ManageRoomTypesScreen extends StatefulWidget {
  final String hotelId;

  const ManageRoomTypesScreen({Key? key, required this.hotelId})
      : super(key: key);

  @override
  _ManageRoomTypesScreenState createState() => _ManageRoomTypesScreenState();
}

class _ManageRoomTypesScreenState extends State<ManageRoomTypesScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? hotel;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHotel();
  }

  Future<void> _fetchHotel() async {
    try {
      final response = await supabase
          .from('hotels')
          .select()
          .eq('id', widget.hotelId)
          .single();

      setState(() {
        hotel = response;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching hotel: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateRoomTypes(List<dynamic> roomTypes) async {
    try {
      await supabase
          .from('hotels')
          .update({'room_types': roomTypes}).eq('id', widget.hotelId);

      await _fetchHotel();

      Get.snackbar(
        'Sukses',
        'Tipe kamar berhasil diupdate',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengupdate tipe kamar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showAddEditRoomDialog([Map<String, dynamic>? roomType, int? index]) {
    final _typeController = TextEditingController(text: roomType?['type']);
    final _priceController = TextEditingController(
        text: roomType?['price_per_night']?.toString() ?? '');
    final _capacityController =
        TextEditingController(text: roomType?['capacity']?.toString() ?? '');
    final _availableRoomsController = TextEditingController(
        text: roomType?['available_rooms']?.toString() ?? '');
    final _amenitiesController = TextEditingController(
        text: (roomType?['amenities'] as List?)?.join(', ') ?? '');

    Get.dialog(
      AlertDialog(
        title: Text(roomType == null ? 'Tambah Tipe Kamar' : 'Edit Tipe Kamar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _typeController,
                decoration: InputDecoration(labelText: 'Tipe Kamar'),
              ),
              TextField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Harga per Malam'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _capacityController,
                decoration: InputDecoration(labelText: 'Kapasitas (orang)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _availableRoomsController,
                decoration: InputDecoration(labelText: 'Jumlah Kamar Tersedia'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _amenitiesController,
                decoration: InputDecoration(
                  labelText: 'Fasilitas Kamar (pisahkan dengan koma)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newRoomType = {
                'type': _typeController.text,
                'price_per_night': int.tryParse(_priceController.text) ?? 0,
                'capacity': int.tryParse(_capacityController.text) ?? 0,
                'available_rooms':
                    int.tryParse(_availableRoomsController.text) ?? 0,
                'amenities': _amenitiesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              };

              final List<dynamic> currentRoomTypes =
                  List.from(hotel?['room_types'] ?? []);

              if (index != null) {
                currentRoomTypes[index] = newRoomType;
              } else {
                currentRoomTypes.add(newRoomType);
              }

              _updateRoomTypes(currentRoomTypes);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: Text(roomType == null ? 'Tambah' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kelola Tipe Kamar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Tombol Tambah Tipe Kamar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditRoomDialog(),
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                'Tambah Tipe Kamar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),

          // List Tipe Kamar
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : hotel == null
                    ? Center(child: Text('Hotel tidak ditemukan'))
                    : (hotel!['room_types'] == null ||
                            (hotel!['room_types'] as List).isEmpty)
                        ? Center(
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
                                  'Belum ada tipe kamar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Mulai tambahkan tipe kamar',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: (hotel!['room_types'] as List).length,
                            itemBuilder: (context, index) {
                              final roomType =
                                  (hotel!['room_types'] as List)[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              roomType['type'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.edit,
                                                    color: Colors.blue),
                                                onPressed: () =>
                                                    _showAddEditRoomDialog(
                                                        roomType, index),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  final currentRoomTypes =
                                                      List.from(
                                                          hotel!['room_types']);
                                                  currentRoomTypes
                                                      .removeAt(index);
                                                  _updateRoomTypes(
                                                      currentRoomTypes);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'id',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(roomType['price_per_night']),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      _buildInfoRow(Icons.person, 'Kapasitas',
                                          '${roomType['capacity']} orang'),
                                      SizedBox(height: 8),
                                      _buildInfoRow(
                                          Icons.meeting_room,
                                          'Kamar tersedia',
                                          '${roomType['available_rooms']}'),
                                      SizedBox(height: 12),
                                      Text(
                                        'Fasilitas:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            (roomType['amenities'] as List)
                                                .map((amenity) {
                                          return Chip(
                                            label: Text(
                                              amenity,
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: AppTheme.primary
                                                .withOpacity(0.1),
                                            labelStyle: TextStyle(
                                                color: AppTheme.primary),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
}
