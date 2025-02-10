import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../hotel/hotel_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin, sin, pi;
import 'package:flutter/material.dart';

class HotelScreen extends StatefulWidget {
  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen>
    with RouteAware, WidgetsBindingObserver {
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
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reset filter saat pertama kali masuk
    _isNearestActive = false;
    _isPriceFilterActive = false;
    _fetchHotels();
    _getCurrentLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resetSearch();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    // Dipanggil ketika kembali ke halaman ini
    resetSearch();
  }

  @override
  void didPushNext() {
    // Dipanggil ketika meninggalkan halaman ini
    resetSearch();
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
    const double earthRadius = 6371; // Radius bumi dalam kilometer

    // Konversi ke radian
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c; // Jarak dalam kilometer
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _showFilterDialog() {
    // Format angka dengan koma
    final formatter = NumberFormat('#,###');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Sort Section
                        Text(
                          'Urutkan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: Text('Harga Tertinggi'),
                                value: 'price_high',
                                groupValue: sortBy,
                                onChanged: (value) {
                                  setModalState(() => sortBy = value);
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Divider(height: 1),
                              RadioListTile<String>(
                                title: Text('Harga Terendah'),
                                value: 'price_low',
                                groupValue: sortBy,
                                onChanged: (value) {
                                  setModalState(() => sortBy = value);
                                },
                                activeColor: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),

                        // Price Range Section
                        Text(
                          'Rentang Harga',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _minPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Harga Minimum',
                                    prefixText: 'Rp ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      // Hapus semua karakter non-digit
                                      String numericValue = value.replaceAll(
                                          RegExp(r'[^0-9]'), '');
                                      if (numericValue.isNotEmpty) {
                                        // Format angka dengan koma
                                        String formatted = formatter
                                            .format(int.parse(numericValue));
                                        _minPriceController.value =
                                            TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(
                                              offset: formatted.length),
                                        );
                                      }
                                    }
                                  },
                                ),
                                SizedBox(height: 12),
                                TextField(
                                  controller: _maxPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Harga Maksimum',
                                    prefixText: 'Rp ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      // Hapus semua karakter non-digit
                                      String numericValue = value.replaceAll(
                                          RegExp(r'[^0-9]'), '');
                                      if (numericValue.isNotEmpty) {
                                        // Format angka dengan koma
                                        String formatted = formatter
                                            .format(int.parse(numericValue));
                                        _maxPriceController.value =
                                            TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(
                                              offset: formatted.length),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Location Section
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  'Lokasi Terdekat',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
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
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  child: Text(
                                    'Aktifkan lokasi untuk menggunakan fitur ini',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Apply Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _isPriceFilterActive =
                                  _minPriceController.text.isNotEmpty ||
                                      _maxPriceController.text.isNotEmpty;
                              if (_isPriceFilterActive) {
                                // Hapus koma sebelum parsing
                                _minPrice = double.tryParse(_minPriceController
                                        .text
                                        .replaceAll(',', '')) ??
                                    0;
                                _maxPrice = double.tryParse(_maxPriceController
                                        .text
                                        .replaceAll(',', '')) ??
                                    10000000;
                              }
                              Navigator.pop(context);
                              _fetchHotels(search: _searchController.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Terapkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void resetSearch() {
    _searchController.clear();
    _isNearestActive = false;
    _isPriceFilterActive = false;
    sortBy = null;
    _minPriceController.text = '0';
    _maxPriceController.text = '10000000';
    _minPrice = 0;
    _maxPrice = 10000000;
    _fetchHotels();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        resetSearch();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          automaticallyImplyLeading: false,
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
                      hintText: 'Cari Hotel atau Lokasi',
                      hintStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textHint,
                              ),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) => _fetchHotels(search: value),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.tune, color: Colors.white),
                onPressed: () {
                  _showFilterDialog();
                },
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
                    final hotelAddress = hotel['address'] is Map
                        ? (hotel['address'] as Map)['full_address']
                        : hotel['address'] as String;

                    // Tambahkan informasi jarak jika ada
                    final String displayAddress = hotel['distance'] != null
                        ? '$hotelAddress (${hotel['distance'] < 1 ? '${(hotel['distance'] * 1000).toStringAsFixed(0)}m' : '${hotel['distance'].toStringAsFixed(1)}km'})'
                        : hotelAddress;

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            hotel['display_address'] ??
                                                'Alamat tidak tersedia',
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
                                                  size: 14,
                                                  color: Colors.amber),
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
                                            hotel['room_types'] != null
                                                ? NumberFormat.currency(
                                                    locale: 'id',
                                                    symbol: 'Rp ',
                                                    decimalDigits: 0,
                                                  ).format(_getLowestPrice(
                                                    hotel['room_types']))
                                                : 'Harga tidak tersedia',
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
      ),
    );
  }

  Future<void> _fetchHotels({String? search}) async {
    try {
      isLoading.value = true;

      // 1. Ambil data hotel dasar
      final response = await supabase.from('hotels').select('''
            *,
            merchants:merchant_id (
              store_name,
              store_address
            )
          ''');

      var filteredHotels = List<Map<String, dynamic>>.from(response);

      // 2. Filter pencarian berdasarkan nama hotel atau alamat
      if (search != null && search.isNotEmpty) {
        filteredHotels = filteredHotels.where((hotel) {
          final String hotelName = hotel['name'].toString().toLowerCase();
          final String hotelAddress = hotel['address'] is Map
              ? hotel['address']['full_address'].toString().toLowerCase()
              : hotel['address'].toString().toLowerCase();

          final String searchLower = search.toLowerCase();

          // Cari berdasarkan nama hotel atau alamat
          return hotelName.contains(searchLower) ||
              hotelAddress.contains(searchLower);
        }).toList();
      }

      // 3. Filter berdasarkan range harga
      if (_isPriceFilterActive) {
        filteredHotels = filteredHotels.where((hotel) {
          if (hotel['room_types'] == null) return false;
          double lowestPrice = _getLowestPrice(hotel['room_types']);
          return lowestPrice >= _minPrice && lowestPrice <= _maxPrice;
        }).toList();
      }

      // 4. Filter dan sort berdasarkan jarak
      if (_isNearestActive && _currentPosition != null) {
        // Hitung jarak untuk setiap hotel
        for (var hotel in filteredHotels) {
          if (hotel['latitude'] == null || hotel['longitude'] == null) {
            hotel['distance'] = double.infinity;
            continue;
          }

          try {
            hotel['distance'] = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              double.parse(hotel['latitude'].toString()),
              double.parse(hotel['longitude'].toString()),
            );
          } catch (e) {
            print('Error calculating distance for ${hotel['name']}: $e');
            hotel['distance'] = double.infinity;
          }
        }

        // Sort berdasarkan jarak
        filteredHotels.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));
      }

      // 5. Sort berdasarkan harga jika dipilih
      if (sortBy != null) {
        switch (sortBy) {
          case 'price_high':
            filteredHotels.sort((a, b) {
              final priceA = _getLowestPrice(a['room_types']);
              final priceB = _getLowestPrice(b['room_types']);
              return priceB.compareTo(priceA); // Harga tertinggi dulu
            });
            break;
          case 'price_low':
            filteredHotels.sort((a, b) {
              final priceA = _getLowestPrice(a['room_types']);
              final priceB = _getLowestPrice(b['room_types']);
              return priceA.compareTo(priceB); // Harga terendah dulu
            });
            break;
        }
      }

      // Handle alamat yang berbentuk Map
      for (var hotel in filteredHotels) {
        if (hotel['address'] is Map) {
          hotel['display_address'] = hotel['address']['full_address'];
        } else {
          hotel['display_address'] = hotel['address'].toString();
        }
      }

      hotels.value = filteredHotels;
    } catch (e) {
      print('Error in _fetchHotels: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data hotel: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Helper function untuk mendapatkan harga terendah
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
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }
}
