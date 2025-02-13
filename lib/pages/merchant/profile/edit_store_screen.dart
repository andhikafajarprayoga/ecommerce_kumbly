import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class EditStoreScreen extends StatefulWidget {
  @override
  _EditStoreScreenState createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _storePhoneController = TextEditingController();

  // Tambahkan controller baru untuk alamat terstruktur
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Tambahkan controller untuk koordinat
  final MapController _mapController = MapController();
  LatLng _selectedLocation = LatLng(-6.200000, 106.816666); // Default Jakarta

  // Tambahkan variable untuk menyimpan alamat referensi
  String _referenceAddress = '';

  // Tambahkan controller dan variable untuk search
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storePhoneController.dispose();
    _streetController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final storeData =
          await supabase.from('merchants').select().eq('id', userId).single();

      // Parse alamat dari JSON string
      Map<String, dynamic> addressData = {};
      try {
        if (storeData['store_address'] != null) {
          addressData =
              Map<String, dynamic>.from(jsonDecode(storeData['store_address']));
        }
      } catch (e) {
        print('Error parsing address: $e');
      }

      setState(() {
        _storeNameController.text = storeData['store_name'] ?? '';
        _storeDescriptionController.text = storeData['store_description'] ?? '';
        _storePhoneController.text = storeData['store_phone'] ?? '';

        // Set nilai untuk field alamat
        _streetController.text = addressData['street'] ?? '';
        _villageController.text = addressData['village'] ?? '';
        _districtController.text = addressData['district'] ?? '';
        _cityController.text = addressData['city'] ?? '';
        _provinceController.text = addressData['province'] ?? '';
        _postalCodeController.text = addressData['postal_code'] ?? '';

        // Tambahkan loading koordinat
        if (addressData['latitude'] != null &&
            addressData['longitude'] != null) {
          _selectedLocation = LatLng(double.parse(addressData['latitude']),
              double.parse(addressData['longitude']));
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading store data: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data toko',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateStore() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar(
        'Error',
        'User tidak ditemukan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      Get.snackbar(
        'Error',
        'Mohon lengkapi data yang diperlukan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final addressData = {
        'street': _streetController.text,
        'village': _villageController.text,
        'district': _districtController.text,
        'city': _cityController.text,
        'province': _provinceController.text,
        'postal_code': _postalCodeController.text,
        'latitude': _selectedLocation.latitude.toString(),
        'longitude': _selectedLocation.longitude.toString(),
      };

      await supabase.from('merchants').update({
        'store_name': _storeNameController.text,
        'store_description': _storeDescriptionController.text,
        'store_phone': _storePhoneController.text,
        'store_address': jsonEncode(addressData),
      }).eq('id', userId);

      Get.snackbar(
        'Sukses',
        'Data toko berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await Future.delayed(Duration(seconds: 1));
      Get.offAll(() => MerchantHomeScreen(sellerId: userId));
    } catch (e) {
      print('Error updating store: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui data toko: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
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
          _referenceAddress = '${place.street}, ${place.subLocality}, '
              '${place.locality}, ${place.subAdministrativeArea}, '
              '${place.administrativeArea} ${place.postalCode}';

          _streetController.text = '${place.street}';
          _villageController.text = '${place.subLocality}';
          _districtController.text = '${place.locality}';
          _cityController.text = '${place.subAdministrativeArea}';
          _provinceController.text = '${place.administrativeArea}';
          _postalCodeController.text = '${place.postalCode}';
        });

        Get.snackbar(
          'Sukses',
          'Lokasi berhasil dipilih',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: Duration(seconds: 3),
          margin: EdgeInsets.all(10),
          borderRadius: 8,
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
      }
    } catch (e) {
      print('Error getting address: $e');
      Get.snackbar(
        'Error',
        'Gagal mendapatkan alamat: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 8,
        icon: Icon(Icons.error, color: Colors.white),
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
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://nominatim.openstreetmap.org/search'
          '?q=$encodedQuery'
          '&format=json'
          '&limit=5';

      print('Searching URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept-Language': 'id',
          'User-Agent': 'Kumbly/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Search results: ${data.length}');

        if (data.isNotEmpty) {
          setState(() {
            _searchResults = data
                .map((item) => {
                      'display_name': item['display_name'],
                      'lat': double.parse(item['lat']),
                      'lon': double.parse(item['lon']),
                    })
                .toList();
          });
        } else {
          Get.snackbar(
            'Info',
            'Lokasi tidak ditemukan',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: Duration(seconds: 3),
            margin: EdgeInsets.all(10),
            borderRadius: 8,
            icon: Icon(Icons.info, color: Colors.white),
          );
        }
      } else {
        print('Error status code: ${response.statusCode}');
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      print('Error detail: $e');
      Get.snackbar(
        'Error',
        'Gagal mencari lokasi: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 8,
        icon: Icon(Icons.error, color: Colors.white),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Toko', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _storeNameController,
                      label: 'Nama Toko',
                      hint: 'Masukkan nama toko',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Nama toko tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _storeDescriptionController,
                      label: 'Deskripsi Toko',
                      hint: 'Masukkan deskripsi toko',
                      maxLines: 2,
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _storePhoneController,
                      label: 'Nomor Telepon',
                      hint: 'Contoh: 08123456789',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Nomor telepon tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Pilih Lokasi Toko',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    // Tambahkan keterangan untuk berhati-hati dalam menentukan lokasi
                    Text(
                      'Harap berhati-hati dalam menentukan titik lokasi, karena ini dapat mempengaruhi ongkir pengiriman toko Anda.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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
                                userAgentPackageName: 'com.example.app',
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
                                    onChanged: (value) =>
                                        _searchLocation(value),
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
                                              onTap: () async {
                                                final newLocation = LatLng(
                                                  result['lat'],
                                                  result['lon'],
                                                );
                                                setState(() {
                                                  _selectedLocation =
                                                      newLocation;
                                                  _searchResults = [];
                                                  _searchController.clear();
                                                });
                                                _mapController.move(
                                                    newLocation, 15);
                                                await _getAddressFromLatLng(
                                                    newLocation);
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
                            bottom: 16,
                            child: ElevatedButton(
                              onPressed: _getCurrentLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 255, 255, 255),
                                side: BorderSide(
                                    color:
                                        const Color.fromARGB(255, 251, 93, 93)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 90),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.my_location, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Gunakan Lokasi Saat Ini',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
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
                          if (_referenceAddress.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.home,
                                    size: 16, color: AppTheme.primary),
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
                    Text(
                      'Detail Alamat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildTextField(
                      controller: _streetController,
                      label: 'Alamat Lengkap',
                      hint: 'Contoh: Jl. Sudirman No. 123',
                      maxLines: 2,
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _villageController,
                      label: 'Kelurahan/Desa',
                      hint: 'Masukkan kelurahan/desa',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _districtController,
                      label: 'Kecamatan',
                      hint: 'Masukkan kecamatan',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _cityController,
                      label: 'Kota/Kabupaten',
                      hint: 'Masukkan kota/kabupaten',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _provinceController,
                      label: 'Provinsi',
                      hint: 'Masukkan provinsi',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _postalCodeController,
                      label: 'Kode Pos',
                      hint: 'Masukkan kode pos',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
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
    String? Function(String?)? validator,
    int? maxLines,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isDense: true,
          ),
          validator: validator,
          maxLines: maxLines ?? 1,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
