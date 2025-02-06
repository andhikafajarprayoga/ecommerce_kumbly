import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../hotel/hotel_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;

class HotelScreen extends StatefulWidget {
  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController =
      TextEditingController(text: '0');
  final TextEditingController _maxPriceController =
      TextEditingController(text: '10000000');
  RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;
  RxBool isLoading = true.obs;
  String? sortBy;
  double _minPrice = 0;
  double _maxPrice = 10000000;
  bool _isPriceFilterActive = false;
  Position? _currentPosition;
  bool _isNearestActive = false;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _showFilterDialog() {
    // Format angka dengan koma
    final formatter = NumberFormat('#,###');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Drawer(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          Divider(),
                          Text(
                            'Urutkan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          RadioListTile<String>(
                            title: Text('Harga Tertinggi'),
                            value: 'price_high',
                            groupValue: sortBy,
                            onChanged: (value) {
                              setModalState(() => sortBy = value);
                            },
                            activeColor: AppTheme.primary,
                          ),
                          RadioListTile<String>(
                            title: Text('Harga Terendah'),
                            value: 'price_low',
                            groupValue: sortBy,
                            onChanged: (value) {
                              setModalState(() => sortBy = value);
                            },
                            activeColor: AppTheme.primary,
                          ),
                          Divider(),
                          Text(
                            'Rentang Harga',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Harga Minimum',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                // Hapus semua karakter non-digit
                                String numericValue =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                if (numericValue.isNotEmpty) {
                                  // Format angka dengan koma
                                  String formatted =
                                      formatter.format(int.parse(numericValue));
                                  _minPriceController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                        offset: formatted.length),
                                  );
                                }
                              }
                            },
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Harga Maksimum',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                // Hapus semua karakter non-digit
                                String numericValue =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                if (numericValue.isNotEmpty) {
                                  // Format angka dengan koma
                                  String formatted =
                                      formatter.format(int.parse(numericValue));
                                  _maxPriceController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                        offset: formatted.length),
                                  );
                                }
                              }
                            },
                          ),
                          Divider(),
                          SwitchListTile(
                            title: Text('Lokasi Terdekat'),
                            value: _isNearestActive,
                            onChanged: _currentPosition == null
                                ? null
                                : (value) {
                                    setModalState(() {
                                      _isNearestActive = value;
                                    });
                                  },
                            activeColor: AppTheme.primary,
                          ),
                          if (_currentPosition == null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Aktifkan lokasi untuk menggunakan fitur ini',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _isPriceFilterActive =
                                    _minPriceController.text.isNotEmpty ||
                                        _maxPriceController.text.isNotEmpty;
                                if (_isPriceFilterActive) {
                                  // Hapus koma sebelum parsing
                                  _minPrice = double.tryParse(
                                          _minPriceController.text
                                              .replaceAll(',', '')) ??
                                      0;
                                  _maxPrice = double.tryParse(
                                          _maxPriceController.text
                                              .replaceAll(',', '')) ??
                                      10000000;
                                }
                                Navigator.pop(context);
                                _fetchHotels(
                                    search: _searchController.text,
                                    sort: sortBy);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Terapkan',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
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
                  onSubmitted: (value) =>
                      _fetchHotels(search: value, sort: sortBy),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: Colors.white),
              onPressed: _showFilterDialog,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Existing Obx and ListView
          Expanded(
            child: Obx(() {
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
                  final hotelAddress = hotel['address'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () =>
                          Get.to(() => HotelDetailScreen(hotel: hotel)),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Text(
                                          hotelAddress,
                                          style: TextStyle(
                                            color: AppTheme.textHint,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                          ).format(_getLowestPrice(
                                              hotel['room_types'])),
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
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHotels({String? search, String? sort}) async {
    try {
      isLoading.value = true;
      var query = supabase.from('hotels').select('''
        *,
        merchants:merchant_id (
          store_name,
          store_address
        )
      ''');

      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }

      final response = await query;
      var filteredHotels = List<Map<String, dynamic>>.from(response);

      // Filter berdasarkan jarak jika aktif
      if (_isNearestActive && _currentPosition != null) {
        filteredHotels.forEach((hotel) {
          final address = Map<String, dynamic>.from(hotel['address']);
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            double.parse(address['latitude'].toString()),
            double.parse(address['longitude'].toString()),
          );
          hotel['distance'] = distance;
        });

        filteredHotels.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));
      }

      // Filter berdasarkan range harga hanya jika aktif
      if (_isPriceFilterActive) {
        filteredHotels = filteredHotels.where((hotel) {
          double lowestPrice = _getLowestPrice(hotel['room_types']);
          return lowestPrice >= _minPrice && lowestPrice <= _maxPrice;
        }).toList();
      }

      // Sort if needed
      if (sort != null) {
        switch (sort) {
          case 'price_high':
            filteredHotels.sort((a, b) {
              final aPrice = _getLowestPrice(a['room_types']);
              final bPrice = _getLowestPrice(b['room_types']);
              return bPrice.compareTo(aPrice);
            });
            break;
          case 'price_low':
            filteredHotels.sort((a, b) {
              final aPrice = _getLowestPrice(a['room_types']);
              final bPrice = _getLowestPrice(b['room_types']);
              return aPrice.compareTo(bPrice);
            });
            break;
        }
      }

      hotels.value = filteredHotels;
    } catch (e) {
      print('Error fetching hotels: $e');
    } finally {
      isLoading.value = false;
    }
  }

  double _getLowestPrice(List<dynamic> roomTypes) {
    if (roomTypes.isEmpty) return 0;
    try {
      List<double> prices = roomTypes
          .map((room) => double.parse(room['price_per_night'].toString()))
          .toList();
      return prices.reduce((curr, next) => curr < next ? curr : next);
    } catch (e) {
      print('Error parsing room price: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }
}
