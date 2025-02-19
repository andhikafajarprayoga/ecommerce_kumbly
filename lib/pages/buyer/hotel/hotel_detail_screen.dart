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
  Map<String, dynamic> merchantInfo = {};

  @override
  void initState() {
    super.initState();
    _fetchHotelAndMerchantDetails();
  }

  Future<void> _fetchHotelAndMerchantDetails() async {
    try {
      final response = await supabase.from('hotels').select('''
            *,
            merchants!inner (
              id,
              store_name,
              store_address
            )
          ''').eq('id', widget.hotel['id']).single();

      setState(() {
        merchantInfo = response['merchants'] ?? {};
      });
    } catch (e) {
      print('Error fetching hotel and merchant details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Location and Merchant Info in a Card
                  Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 16, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatAddress(widget.hotel['address']),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 16),
                          // Merchant Info
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.store_outlined,
                                  size: 16, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      merchantInfo['store_name'] ?? '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Description
                  Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.hotel['description'] ?? 'Tidak ada deskripsi',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Facilities
                  Text(
                    'Fasilitas Publik',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: (widget.hotel['facilities'] as List)
                              .take(10)
                              .map<Widget>((facility) {
                            IconData getIcon() {
                              final String facilityLower =
                                  facility.toString().toLowerCase();

                              if (facilityLower.contains('wifi'))
                                return Icons.wifi;
                              if (facilityLower.contains('ac'))
                                return Icons.ac_unit;
                              if (facilityLower.contains('aula'))
                                return Icons.audiotrack;
                              if (facilityLower.contains('restoran'))
                                return Icons.restaurant;

                              if (facilityLower.contains('kopi') ||
                                  facilityLower.contains('kafe'))
                                return Icons.coffee;
                              if (facilityLower.contains('check') ||
                                  facilityLower.contains('resepsionis'))
                                return Icons.access_time;
                              if (facilityLower.contains('kamar'))
                                return Icons.bedroom_parent;
                              if (facilityLower.contains('parkir'))
                                return Icons.local_parking;
                              if (facilityLower.contains('kolam'))
                                return Icons.pool;
                              if (facilityLower.contains('kebugaran') ||
                                  facilityLower.contains('gym'))
                                return Icons.fitness_center;
                              if (facilityLower.contains('spa') ||
                                  facilityLower.contains('pijat') ||
                                  facilityLower.contains('sauna'))
                                return Icons.spa;
                              if (facilityLower.contains('pertemuan') ||
                                  facilityLower.contains('ballroom'))
                                return Icons.meeting_room;
                              if (facilityLower.contains('lift'))
                                return Icons.elevator;
                              if (facilityLower.contains('laundry'))
                                return Icons.local_laundry_service;
                              if (facilityLower.contains('merokok'))
                                return Icons.smoking_rooms;
                              if (facilityLower.contains('antar') ||
                                  facilityLower.contains('jemput'))
                                return Icons.airport_shuttle;
                              if (facilityLower.contains('mobil'))
                                return Icons.directions_car;
                              if (facilityLower.contains('bagasi'))
                                return Icons.luggage;
                              if (facilityLower.contains('keamanan') ||
                                  facilityLower.contains('cctv'))
                                return Icons.security;
                              if (facilityLower.contains('bisnis'))
                                return Icons.business_center;

                              return Icons.check_circle_outline;
                            }

                            return Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(getIcon(),
                                      size: 20, color: AppTheme.primary),
                                  SizedBox(width: 12),
                                  Text(
                                    facility,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if ((widget.hotel['facilities'] as List).length > 10) ...[
                        SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: (widget.hotel['facilities'] as List)
                                .skip(10)
                                .map<Widget>((facility) {
                              IconData getIcon() {
                                final String facilityLower =
                                    facility.toString().toLowerCase();

                                if (facilityLower.contains('wifi'))
                                  return Icons.wifi;
                                if (facilityLower.contains('restoran'))
                                  return Icons.restaurant;
                                if (facilityLower.contains('kopi') ||
                                    facilityLower.contains('kafe'))
                                  return Icons.coffee;
                                if (facilityLower.contains('check') ||
                                    facilityLower.contains('resepsionis'))
                                  return Icons.access_time;
                                if (facilityLower.contains('kamar'))
                                  return Icons.bedroom_parent;
                                if (facilityLower.contains('parkir'))
                                  return Icons.local_parking;
                                if (facilityLower.contains('kolam'))
                                  return Icons.pool;
                                if (facilityLower.contains('kebugaran') ||
                                    facilityLower.contains('gym'))
                                  return Icons.fitness_center;
                                if (facilityLower.contains('spa') ||
                                    facilityLower.contains('pijat') ||
                                    facilityLower.contains('sauna'))
                                  return Icons.spa;
                                if (facilityLower.contains('pertemuan') ||
                                    facilityLower.contains('ballroom'))
                                  return Icons.meeting_room;
                                if (facilityLower.contains('lift'))
                                  return Icons.elevator;
                                if (facilityLower.contains('laundry'))
                                  return Icons.local_laundry_service;
                                if (facilityLower.contains('merokok'))
                                  return Icons.smoking_rooms;
                                if (facilityLower.contains('antar') ||
                                    facilityLower.contains('jemput'))
                                  return Icons.airport_shuttle;
                                if (facilityLower.contains('mobil'))
                                  return Icons.directions_car;
                                if (facilityLower.contains('bagasi'))
                                  return Icons.luggage;
                                if (facilityLower.contains('keamanan') ||
                                    facilityLower.contains('cctv'))
                                  return Icons.security;
                                if (facilityLower.contains('bisnis'))
                                  return Icons.business_center;

                                return Icons.check_circle_outline;
                              }

                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(getIcon(),
                                        size: 20, color: AppTheme.primary),
                                    SizedBox(width: 12),
                                    Text(
                                      facility,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textPrimary),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
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
                                  final currentUser = supabase.auth.currentUser;

                                  if (currentUser == null) {
                                    // Jika user belum login, tampilkan snackbar dan arahkan ke login screen
                                    Get.snackbar(
                                      'Perhatian',
                                      'Silakan login terlebih dahulu untuk melakukan pemesanan',
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                    );
                                    Get.toNamed(
                                        '/login'); // Pastikan route '/login' sudah terdaftar
                                    return;
                                  }

                                  // Jika sudah login, lanjut ke halaman booking
                                  Get.to(() => HotelBookingScreen(
                                        hotel: widget.hotel,
                                        roomType: room,
                                      ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'Pesan Sekarang',
                                  style: TextStyle(color: Colors.white),
                                ),
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

  String _formatAddress(dynamic address) {
    if (address is Map) {
      return address['full_address'] ?? 'Alamat tidak tersedia';
    }
    return address?.toString() ?? 'Alamat tidak tersedia';
  }
}
