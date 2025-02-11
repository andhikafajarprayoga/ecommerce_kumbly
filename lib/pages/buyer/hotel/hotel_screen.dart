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
import '../../../controllers/hotel_screen_controller.dart';

class HotelScreen extends StatefulWidget {
  @override
  _HotelScreenState createState() => _HotelScreenState();
}

class _HotelScreenState extends State<HotelScreen>
    with RouteAware, WidgetsBindingObserver {
  final HotelScreenController controller = Get.put(HotelScreenController());
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final TextEditingController _minPriceController =
      TextEditingController(text: '0');
  final TextEditingController _maxPriceController =
      TextEditingController(text: '10000000');
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.fetchHotels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.resetSearch();
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
    controller.resetSearch();
  }

  @override
  void didPushNext() {
    // Dipanggil ketika meninggalkan halaman ini
    controller.resetSearch();
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
        controller.currentPosition.value = position;
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
                                groupValue: controller.sortBy.value,
                                onChanged: (value) {
                                  setModalState(() =>
                                      controller.sortBy.value = value ?? '');
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Divider(height: 1),
                              RadioListTile<String>(
                                title: Text('Harga Terendah'),
                                value: 'price_low',
                                groupValue: controller.sortBy.value,
                                onChanged: (value) {
                                  setModalState(() =>
                                      controller.sortBy.value = value ?? '');
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
                                value: controller.isNearestActive.value,
                                onChanged:
                                    controller.currentPosition.value == null
                                        ? null
                                        : (value) {
                                            setModalState(() {
                                              controller.isNearestActive.value =
                                                  value;
                                            });
                                          },
                                activeColor: AppTheme.primary,
                              ),
                              if (controller.currentPosition.value == null)
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
                              controller.isPriceFilterActive.value =
                                  _minPriceController.text.isNotEmpty ||
                                      _maxPriceController.text.isNotEmpty;
                              if (controller.isPriceFilterActive.value) {
                                // Hapus koma sebelum parsing
                                controller.minPrice.value = double.tryParse(
                                        _minPriceController.text
                                            .replaceAll(',', '')) ??
                                    0;
                                controller.maxPrice.value = double.tryParse(
                                        _maxPriceController.text
                                            .replaceAll(',', '')) ??
                                    10000000;
                              }
                              Navigator.pop(context);
                              controller.fetchHotels(
                                  search: searchController.text);
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        controller.resetSearch();
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
                    controller: searchController,
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
                    onSubmitted: (value) =>
                        controller.fetchHotels(search: value),
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
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.hotels.isEmpty) {
                  return const Center(child: Text('Tidak ada hotel tersedia'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: controller.hotels.length,
                  itemBuilder: (context, index) {
                    final hotel = controller.hotels[index];
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
                                                  ).format(
                                                    controller.getLowestPrice(
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

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }
}
