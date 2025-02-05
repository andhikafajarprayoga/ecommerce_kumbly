import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:convert';
import '../hotel/hotel_booking_screen.dart';
import 'chat/chat_room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class HotelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hotel;

  const HotelDetailScreen({Key? key, required this.hotel}) : super(key: key);

  @override
  _HotelDetailScreenState createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  int _currentImageIndex = 0;
  final CarouselSliderController _imageController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final merchantAddress =
        jsonDecode(widget.hotel['merchants']['store_address'] ?? '{}');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image Carousel with Back Button
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  CarouselSlider(
                    carouselController: _imageController,
                    options: CarouselOptions(
                      height: double.infinity,
                      viewportFraction: 1.0,
                      onPageChanged: (index, reason) {
                        setState(() => _currentImageIndex = index);
                      },
                    ),
                    items: (widget.hotel['image_url'] as List).map((imageUrl) {
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    }).toList(),
                  ),
                  // Image indicators
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.hotel['image_url']
                          .asMap()
                          .entries
                          .map<Widget>((entry) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == entry.key
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            actions: [
              // Add chat button
              IconButton(
                icon: Icon(Icons.chat, color: Colors.white),
                onPressed: () async {
                  final currentUser = supabase.auth.currentUser;
                  final merchantId = widget.hotel['merchant_id'];

                  if (currentUser == null || merchantId == null) {
                    Get.snackbar(
                      'Error',
                      'Tidak dapat memulai chat',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  try {
                    // Debug print untuk memeriksa nilai
                    print('Current User: ${currentUser.id}');
                    print('Merchant ID: $merchantId');
                    print('Hotel Name: ${widget.hotel['name']}');

                    // Cek apakah chat room sudah ada
                    final existingRoom = await supabase
                        .from('chat_rooms')
                        .select('id')
                        .eq('buyer_id', currentUser.id)
                        .eq('seller_id', merchantId)
                        .maybeSingle();

                    final String roomId;

                    if (existingRoom == null) {
                      // Buat chat room baru
                      final newRoom = await supabase
                          .from('chat_rooms')
                          .insert({
                            'buyer_id': currentUser.id,
                            'seller_id': merchantId,
                          })
                          .select('id')
                          .single();
                      roomId = newRoom['id'];

                      // Tambahkan pesan awal otomatis
                      await supabase.from('chat_messages').insert({
                        'room_id': roomId,
                        'sender_id': currentUser.id,
                        'message':
                            'Halo, saya tertarik dengan ${widget.hotel['name']}',
                      });
                    } else {
                      roomId = existingRoom['id'];
                    }

                    // Navigate to chat room
                    Get.to(() => ChatRoomScreen(
                          roomId: roomId,
                          otherUserId: merchantId,
                          hotelName: widget.hotel['name'] ?? 'Hotel',
                        ));
                  } catch (e) {
                    print('Error creating/getting chat room: $e');
                    Get.snackbar(
                      'Error',
                      'Gagal membuka chat: $e',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
              ),
            ],
          ),

          // Hotel Details
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hotel Name and Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.hotel['name'],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          SizedBox(width: 4),
                          Text(
                            '${widget.hotel['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: AppTheme.textHint),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${merchantAddress['street']}, ${merchantAddress['district']}, '
                          '${merchantAddress['city']}, ${merchantAddress['province']}',
                          style: TextStyle(color: AppTheme.textHint),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Description
                  Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.hotel['description'] ?? 'Tidak ada deskripsi',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 16),

                  // Facilities
                  Text(
                    'Fasilitas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        (widget.hotel['facilities'] as List).map((facility) {
                      return Chip(
                        label: Text(facility),
                        backgroundColor: AppTheme.primaryLight.withOpacity(0.1),
                        labelStyle: TextStyle(color: AppTheme.primary),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),

                  // Room Types
                  Text(
                    'Tipe Kamar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...(widget.hotel['room_types'] as List).map((room) {
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  room['type'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(
                                    locale: 'id',
                                    symbol: 'Rp ',
                                    decimalDigits: 0,
                                  ).format(room['price_per_night']),
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('Kapasitas: ${room['capacity']} orang'),
                            SizedBox(height: 4),
                            Text('Kamar tersedia: ${room['available_rooms']}'),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children:
                                  (room['amenities'] as List).map((amenity) {
                                return Chip(
                                  label: Text(amenity),
                                  backgroundColor: Colors.grey[100],
                                  labelStyle: TextStyle(fontSize: 12),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Navigate to booking screen
                                  Get.to(() => HotelBookingScreen(
                                        hotel: widget.hotel,
                                        roomType: room,
                                      ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('Pesan Sekarang'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
