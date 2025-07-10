import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterMerchantScreen extends StatefulWidget {
  final String sellerId;

  const RegisterMerchantScreen({super.key, required this.sellerId});

  @override
  _RegisterMerchantScreenState createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeDescController = TextEditingController();
  final _storePhoneController = TextEditingController();

  // Tambahan controller untuk alamat terpisah
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();

  final supabase = Supabase.instance.client;

  // Tambahkan variable untuk maps
  final MapController _mapController = MapController();
  LatLng _selectedLocation = LatLng(-8.988952, 117.213519); // Default Jakarta
  String _referenceAddress = '';

  // Tambahkan controller untuk search
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _registerMerchant() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Cek dulu apakah merchant sudah ada
        final existingMerchant = await supabase
            .from('merchants')
            .select()
            .eq('id', widget.sellerId)
            .maybeSingle();

        // Buat objek alamat yang menyertakan latitude dan longitude
        final storeAddress = {
          "street": _streetController.text,
          "village": _villageController.text,
          "district": _districtController.text,
          "city": _cityController.text,
          "province": _provinceController.text,
          "postal_code": _postalCodeController.text,
          "latitude": _selectedLocation.latitude.toString(),
          "longitude": _selectedLocation.longitude.toString()
        };

        if (existingMerchant != null) {
          // Jika sudah ada, lakukan update
          await supabase.from('merchants').update({
            'store_name': _storeNameController.text,
            'store_description': _storeDescController.text,
            'store_address': storeAddress,
            'store_phone': _storePhoneController.text,
          }).eq('id', widget.sellerId);
        } else {
          // Jika belum ada, lakukan insert
          await supabase.from('merchants').insert({
            'id': widget.sellerId,


            
            'store_name': _storeNameController.text,
            'store_description': _storeDescController.text,
            'store_address': storeAddress,
            'store_phone': _storePhoneController.text,
          });
        }

        // Update role user menjadi seller
        await supabase
            .from('users')
            .update({'role': 'seller'}).eq('id', widget.sellerId);

        Get.snackbar(
          'Sukses',
          'Selamat! Pendaftaran merchant berhasil.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );

        Get.offAll(() => MerchantHomeScreen(sellerId: widget.sellerId));
      } catch (e) {
        Get.snackbar(
          'Error',
          'Gagal mendaftar merchant: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // Update reference address
          _referenceAddress = '${place.street}, ${place.subLocality}, '
              '${place.locality}, ${place.subAdministrativeArea}, '
              '${place.administrativeArea} ${place.postalCode}';

          // Auto-fill form fields
          _streetController.text = place.street ?? '';
          _villageController.text = place.subLocality ?? '';
          _districtController.text = place.locality ?? '';
          _cityController.text = place.subAdministrativeArea ?? '';
          _provinceController.text = place.administrativeArea ?? '';
          _postalCodeController.text = place.postalCode ?? '';

          Get.snackbar(
            'Info',
            'Field alamat telah diisi otomatis berdasarkan lokasi yang dipilih',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: Duration(seconds: 2),
          );
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      Get.snackbar(
        'Error',
        'Gagal mendapatkan detail alamat',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 2),
      );
    }
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
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = newLocation;
        });
        _mapController.move(_selectedLocation, 15);
        await _getAddressFromLatLng(_selectedLocation);
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  // Tambahkan fungsi search
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _searchResults = data
              .map((item) => {
                    'display_name': item['display_name'],
                    'lat': double.parse(item['lat']),
                    'lon': double.parse(item['lon']),
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error searching location: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Toko'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informasi Dasar Toko
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Dasar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Nama Toko',
                        hint: 'Masukkan nama toko',
                        icon: Icons.store,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nama toko wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _storeDescController,
                        label: 'Deskripsi Toko',
                        hint: 'Ceritakan tentang toko Anda',
                        icon: Icons.description,
                        maxLines: 2,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Deskripsi toko wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _storePhoneController,
                        label: 'Nomor Telepon',
                        hint: 'Contoh: 08123456789',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nomor telepon wajib diisi'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Pilih Lokasi Toko
              Text(
                'Pilih Lokasi Toko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 15,
                        onTap: (tapPosition, point) async {
                          setState(() {
                            _selectedLocation = point;
                          });
                          await _getAddressFromLatLng(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.saraja.kumblyecommerce.v2.app',
                          additionalOptions: {
                            'User-Agent': 'Saraja Kumbly App (com.saraja.kumblyecommerce.v2.app)',
                          },
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 80,
                              height: 80,
                              child: Icon(
                                Icons.location_pin,
                                color: AppTheme.primary,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Column(
                        children: [
                          Container(
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
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari lokasi...',
                                prefixIcon: Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) => _searchLocation(value),
                            ),
                          ),
                          if (_searchResults.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 4),
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
                              child: Column(
                                children: _searchResults
                                    .map(
                                      (result) => ListTile(
                                        title: Text(
                                          result['display_name'],
                                          style: TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () {
                                          final newLocation = LatLng(
                                            result['lat'],
                                            result['lon'],
                                          );
                                          setState(() {
                                            _selectedLocation = newLocation;
                                            _searchResults = [];
                                            _searchController.clear();
                                          });
                                          _mapController.move(newLocation, 15);
                                          _getAddressFromLatLng(newLocation);
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _getCurrentLocation,
                        child: Icon(Icons.my_location),
                        backgroundColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          'Koordinat: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    // Tambahkan alert untuk mengingatkan seller
                    SizedBox(height: 8),
                    Text(
                      'Harap perhatikan titik lokasi Anda, karena ini akan menjadi acuan untuk ongkir.',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    if (_referenceAddress.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.home, size: 16, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _referenceAddress,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Alamat Toko
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alamat Toko',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _streetController,
                        label: 'Nama Jalan',
                        hint: 'Contoh: Jln Sigra No. 123',
                        icon: Icons.location_on,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nama jalan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _villageController,
                        label: 'Desa/Kelurahan',
                        hint: 'Contoh: Cisetu',
                        icon: Icons.location_city,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Desa/Kelurahan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _districtController,
                        label: 'Kecamatan',
                        hint: 'Contoh: Rajagaluh',
                        icon: Icons.location_on,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kecamatan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _cityController,
                        label: 'Kota/Kabupaten',
                        hint: 'Contoh: Majalengka',
                        icon: Icons.location_city,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kota/Kabupaten wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _provinceController,
                        label: 'Provinsi',
                        hint: 'Contoh: Jawa Barat',
                        icon: Icons.map,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Provinsi wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _postalCodeController,
                        label: 'Kode Pos',
                        hint: 'Contoh: 45471',
                        icon: Icons.local_post_office,
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kode pos wajib diisi'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _registerMerchant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Daftar Merchant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primary),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
