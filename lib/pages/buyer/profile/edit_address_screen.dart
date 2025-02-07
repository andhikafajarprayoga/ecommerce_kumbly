import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:geolocator/geolocator.dart';

class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic> initialAddress;
  final Function(Map<String, dynamic>) onSave;

  const EditAddressScreen({
    super.key,
    required this.initialAddress,
    required this.onSave,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  late TextEditingController addressController;
  late TextEditingController detailAddressController;
  late TextEditingController provinceController;
  late TextEditingController cityController;
  late TextEditingController districtController;
  late TextEditingController postalCodeController;
  TextEditingController searchController = TextEditingController();
  MapController mapController = MapController();
  LatLng selectedLocation =
      const LatLng(-6.200000, 106.816666); // Default Jakarta
  double zoomLevel = 15.0;
  bool isLoading = false;
  bool showMap = false;

  @override
  void initState() {
    super.initState();
    addressController =
        TextEditingController(text: widget.initialAddress['street'] ?? '');
    detailAddressController =
        TextEditingController(text: widget.initialAddress['street'] ?? '');
    provinceController =
        TextEditingController(text: widget.initialAddress['province'] ?? '');
    cityController =
        TextEditingController(text: widget.initialAddress['city'] ?? '');
    districtController =
        TextEditingController(text: widget.initialAddress['district'] ?? '');
    postalCodeController =
        TextEditingController(text: widget.initialAddress['postal_code'] ?? '');

    if (widget.initialAddress['street']?.toString().isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchAddress(widget.initialAddress['street'], isInitial: true);
      });
    } else {
      fetchAddressFromCoordinates(selectedLocation);
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    detailAddressController.dispose();
    provinceController.dispose();
    cityController.dispose();
    districtController.dispose();
    postalCodeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAddressFromCoordinates(LatLng latLng) async {
    setState(() {
      isLoading = true;
    });

    try {
      print(
          'Fetching address for coordinates: ${latLng.latitude}, ${latLng.longitude}');

      final response = await http.get(
        Uri.parse(
            "https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=id"),
        headers: {'User-Agent': 'Kumbly App'},
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Raw response data: $data');

        final address = data['address'];
        print('Parsed address data: $address');

        // Parse data alamat dari OpenStreetMap ke format kita
        setState(() {
          detailAddressController.text = address['road'] ?? '';
          print('Road: ${address['road']}');

          districtController.text =
              address['suburb'] ?? address['district'] ?? '';
          print('District: ${districtController.text}');

          cityController.text =
              address['city'] ?? address['town'] ?? address['county'] ?? '';
          print('City: ${cityController.text}');

          provinceController.text = address['state'] ?? '';
          print('Province: ${provinceController.text}');

          postalCodeController.text = address['postcode'] ?? '';
          print('Postal code: ${postalCodeController.text}');

          addressController.text = data['display_name'] ?? '';
          print('Full address: ${addressController.text}');
        });
      }
    } catch (e) {
      print('Error fetching address: $e');
      Get.snackbar(
        "Error",
        "Gagal mengambil nama jalan: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> searchAddress(String query, {bool isInitial = false}) async {
    if (query.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      print('Searching for address: $query');

      final response = await http.get(
        Uri.parse(
            "https://nominatim.openstreetmap.org/search?format=json&q=$query&accept-language=id"),
        headers: {'User-Agent': 'Kumbly App'},
      );

      print('Search response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Search results: $data');

        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final address = data[0]['display_name'];

          print('Found location: $lat, $lon');
          print('Display name: $address');

          setState(() {
            selectedLocation = LatLng(lat, lon);
            if (!isInitial) {
              addressController.text = address;
            }
            zoomLevel = 16.0;
          });

          mapController.move(selectedLocation, zoomLevel);

          // Fetch detailed address after moving to location
          await fetchAddressFromCoordinates(selectedLocation);
        } else if (!isInitial) {
          print('No results found for query: $query');
          Get.snackbar(
            "Info",
            "Alamat tidak ditemukan",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      print('Error searching address: $e');
      if (!isInitial) {
        Get.snackbar(
          "Error",
          "Gagal mencari alamat: $e",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      setState(() {
        isLoading = true;
      });

      Map<String, dynamic> addressData = {
        'street': detailAddressController.text.trim(),
        'village': '',
        'district': districtController.text.trim(),
        'city': cityController.text.trim(),
        'province': provinceController.text.trim(),
        'postal_code': postalCodeController.text.trim(),
        'latitude': selectedLocation.latitude.toString(),
        'longitude': selectedLocation.longitude.toString(),
      };

      // Cek alamat yang tersedia
      final userResponse = await supabase
          .from('users')
          .select('address, address2, address3, address4')
          .eq('id', userId)
          .single();

      String fieldToUpdate = '';

      // Jika sedang edit alamat yang sudah ada
      if (widget.initialAddress.isNotEmpty) {
        // Cek persis di field mana alamat yang sedang diedit
        if (mapEquals(userResponse['address'], widget.initialAddress)) {
          fieldToUpdate = 'address';
        } else if (mapEquals(userResponse['address2'], widget.initialAddress)) {
          fieldToUpdate = 'address2';
        } else if (mapEquals(userResponse['address3'], widget.initialAddress)) {
          fieldToUpdate = 'address3';
        } else if (mapEquals(userResponse['address4'], widget.initialAddress)) {
          fieldToUpdate = 'address4';
        }

        // Jika tidak ditemukan field yang cocok, kembalikan error
        if (fieldToUpdate.isEmpty) {
          throw Exception('Alamat yang diedit tidak ditemukan');
        }
      }
      // Jika menambah alamat baru
      else {
        // Cari slot kosong pertama
        if (userResponse['address'] == null) {
          fieldToUpdate = 'address';
        } else if (userResponse['address2'] == null) {
          fieldToUpdate = 'address2';
        } else if (userResponse['address3'] == null) {
          fieldToUpdate = 'address3';
        } else if (userResponse['address4'] == null) {
          fieldToUpdate = 'address4';
        }

        if (fieldToUpdate.isEmpty) {
          throw Exception('Tidak ada slot alamat yang tersedia');
        }
      }

      print('Saving address to field: $fieldToUpdate'); // Debug print

      // Update alamat
      await supabase
          .from('users')
          .update({fieldToUpdate: addressData}).eq('id', userId);

      widget.onSave(addressData);
      Get.back();
      Get.snackbar(
        'Sukses',
        'Alamat berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving address: $e'); // Debug print
      Get.snackbar(
        'Error',
        'Gagal menyimpan alamat: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        zoomLevel = 16.0;
      });

      mapController.move(selectedLocation, zoomLevel);
      fetchAddressFromCoordinates(selectedLocation);
    } catch (e) {
      Get.snackbar(
        "Error",
        "Gagal mendapatkan lokasi: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: Text(
          widget.initialAddress['street']?.isEmpty ?? true
              ? 'Tambah Alamat'
              : 'Ubah Alamat',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding:
                EdgeInsets.only(bottom: 100), // Padding untuk tombol simpan
            child: Column(
              children: [
                _buildAddressForm(),
                if (showMap) _buildMapSection(),
              ],
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Menambahkan card untuk full address
          if (addressController.text.isNotEmpty)
            Card(
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posisi anda saat ini (Referensi):',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      addressController.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: detailAddressController,
            decoration: _buildInputDecoration(
              'Alamat Lengkap *',
              'Contoh: Jl. Sudirman No. 123, RT 01/RW 02',
              Icons.location_on,
            ),
            maxLines: 2,
          ),
          SizedBox(height: 16),
          TextField(
            controller: districtController,
            decoration: _buildInputDecoration(
              'Kecamatan *',
              'Masukkan nama kecamatan',
              Icons.location_city,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: cityController,
            decoration: _buildInputDecoration(
              'Kota/Kabupaten *',
              'Masukkan nama kota/kabupaten',
              Icons.business,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: provinceController,
            decoration: _buildInputDecoration(
              'Provinsi *',
              'Masukkan nama provinsi',
              Icons.map,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: postalCodeController,
            decoration: _buildInputDecoration(
              'Kode Pos *',
              'Masukkan kode pos',
              Icons.local_post_office,
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => showMap = !showMap);
            },
            icon: Icon(Icons.map, color: Colors.white),
            label: Text(
              showMap ? 'Sembunyikan Peta' : 'Pilih Lokasi dari Peta',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: getCurrentLocation,
            icon: Icon(Icons.my_location, color: AppTheme.primary),
            label: Text(
              'Gunakan Lokasi Saat Ini',
              style: TextStyle(color: AppTheme.primary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '* Wajib diisi',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(
      String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 400,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Cari lokasi...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (value) => searchAddress(value),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: selectedLocation,
                      initialZoom: zoomLevel,
                      onTap: (tapPosition, point) {
                        setState(() {
                          selectedLocation = point;
                        });
                        fetchAddressFromCoordinates(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.location_pin,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : saveAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isLoading ? 'Menyimpan...' : 'Simpan Alamat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
