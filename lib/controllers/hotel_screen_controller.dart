import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class HotelScreenController extends GetxController {
  final searchController = TextEditingController();
  final TextEditingController minPriceController =
      TextEditingController(text: '0');
  final TextEditingController maxPriceController =
      TextEditingController(text: '10000000');
  final RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final RxString sortBy = ''.obs;
  final RxBool isNearestActive = false.obs;
  final RxBool isPriceFilterActive = false.obs;
  final Rxn<Position> currentPosition = Rxn<Position>();
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 10000000.0.obs;
  final supabase = Supabase.instance.client;

  @override
  void onInit() {
    super.onInit();
    getCurrentLocation();
  }

  void resetSearch() {
    searchController.clear();
    minPriceController.text = '0';
    maxPriceController.text = '10000000';
    sortBy.value = '';
    isNearestActive.value = false;
    isPriceFilterActive.value = false;
    fetchHotels();
  }

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        currentPosition.value = position;
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius bumi dalam kilometer
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<void> fetchHotels({String? search}) async {
    try {
      isLoading.value = true;

      // Query dasar tanpa filter is_active
      final response = await supabase.from('hotels').select('''
            *,
            merchants:merchant_id (
              store_name,
              store_address
            )
          ''');

      var filteredHotels = List<Map<String, dynamic>>.from(response);

      // Filter hanya hotel yang aktif (jika ada kolom status)
      filteredHotels = filteredHotels
          .where((hotel) =>
              hotel['status'] != 'inactive' && hotel['status'] != 'deleted')
          .toList();

      // Filter pencarian
      if (search != null && search.isNotEmpty) {
        final searchLower = search.toLowerCase();
        filteredHotels = filteredHotels.where((hotel) {
          final String hotelName = hotel['name'].toString().toLowerCase();
          final String hotelAddress = hotel['address'] is Map
              ? hotel['address']['full_address'].toString().toLowerCase()
              : hotel['address'].toString().toLowerCase();
          return hotelName.contains(searchLower) ||
              hotelAddress.contains(searchLower);
        }).toList();
      }

      // Filter harga
      if (isPriceFilterActive.value) {
        filteredHotels = filteredHotels.where((hotel) {
          if (hotel['room_types'] == null) return false;
          double lowestPrice = getLowestPrice(hotel['room_types']);
          return lowestPrice >= minPrice.value && lowestPrice <= maxPrice.value;
        }).toList();
      }

      // Tambahkan perhitungan jarak jika lokasi aktif
      if (isNearestActive.value && currentPosition.value != null) {
        // Hitung jarak untuk setiap hotel
        for (var hotel in filteredHotels) {
          if (hotel['latitude'] != null && hotel['longitude'] != null) {
            hotel['distance'] = _calculateDistance(
              currentPosition.value!.latitude,
              currentPosition.value!.longitude,
              double.parse(hotel['latitude'].toString()),
              double.parse(hotel['longitude'].toString()),
            );
          } else {
            hotel['distance'] = double.infinity;
          }
        }

        // Sort berdasarkan jarak
        filteredHotels.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));
      }

      // Sort berdasarkan harga
      if (sortBy.value.isNotEmpty) {
        filteredHotels.sort((a, b) {
          final priceA = getLowestPrice(a['room_types']);
          final priceB = getLowestPrice(b['room_types']);
          return sortBy.value == 'price_high'
              ? priceB.compareTo(priceA)
              : priceA.compareTo(priceB);
        });
      }

      // Format alamat untuk tampilan
      for (var hotel in filteredHotels) {
        if (hotel['address'] is Map) {
          hotel['display_address'] = hotel['address']['full_address'];
        } else {
          hotel['display_address'] = hotel['address'].toString();
        }
      }

      hotels.value = filteredHotels;
    } catch (e) {
      print('Error in fetchHotels: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data hotel',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  double getLowestPrice(List<dynamic> roomTypes) {
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
  void onClose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.onClose();
  }
}
