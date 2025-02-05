import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../hotel/hotel_detail_screen.dart';

class HotelScreen extends StatefulWidget {
  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
  }

  Future<void> _fetchHotels() async {
    try {
      final response = await supabase.from('hotels').select('''
        *,
        merchants:merchant_id (
          store_name,
          store_address
        )
      ''').order('created_at', ascending: false);
      hotels.value = List<Map<String, dynamic>>.from(response);
      isLoading.value = false;
    } catch (e) {
      print('Error fetching hotels: $e');
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Cari Hotel',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textHint,
                  ),
              prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (value) async {
              try {
                isLoading.value = true;
                final response = await supabase
                    .from('hotels')
                    .select('''
                      *,
                      merchants:merchant_id (
                        store_name,
                        store_address
                      )
                    ''')
                    .ilike('name', '%$value%')
                    .order('created_at', ascending: false);
                hotels.value = List<Map<String, dynamic>>.from(response);
              } catch (e) {
                print('Error searching hotels: $e');
              } finally {
                isLoading.value = false;
              }
            },
          ),
        ),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (hotels.isEmpty) {
          return const Center(child: Text('Tidak ada hotel tersedia'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: hotels.length,
          itemBuilder: (context, index) {
            final hotel = hotels[index];
            final merchantAddress =
                jsonDecode(hotel['merchants']['store_address'] ?? '{}');

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Get.to(() => HotelDetailScreen(hotel: hotel)),
                child: SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      // Hotel Image
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4)),
                        child: Image.network(
                          hotel['image_url'][0],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hotel Name
                                  Text(
                                    hotel['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Location
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 14, color: AppTheme.textHint),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${merchantAddress['district']}, ${merchantAddress['city']}',
                                          style: TextStyle(
                                            color: AppTheme.textHint,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Rating
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${hotel['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                                        style: TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Price
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'id',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(
                                        _getLowestPrice(hotel['room_types'])),
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  int _getLowestPrice(List<dynamic> roomTypes) {
    if (roomTypes == null || roomTypes.isEmpty) return 0;
    return roomTypes
        .map((room) => room['price_per_night'] as int)
        .reduce((a, b) => a < b ? a : b);
  }
}
