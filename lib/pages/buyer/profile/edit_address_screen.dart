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
  final String? addressField;

  const EditAddressScreen({
    super.key,
    required this.initialAddress,
    required this.onSave,
    this.addressField,
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
  bool showMap = true;
  bool hasSelectedFromMap = false;

  @override
  void initState() {
    super.initState();
    addressController =
        TextEditingController(text: widget.initialAddress['street'] ?? '');
    detailAddressController = TextEditingController(text: '');
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

    // Tampilkan alert untuk mengingatkan pengguna tentang posisi peta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          title: Text('Perhatian Posisi Peta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pastikan posisi peta menunjukkan lokasi yang benar.'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Titik lokasi di peta akan digunakan untuk perhitungan ongkos kirim.',
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Tutup', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
    });
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
      hasSelectedFromMap = true;
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
          if (widget.initialAddress.isEmpty) {
            detailAddressController.text = address['road'] ?? '';
          }
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
    if (!hasSelectedFromMap) {
      Get.snackbar(
        'Perhatian',
        'Silakan pilih lokasi dari peta terlebih dahulu',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
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

      // Tentukan field yang akan diupdate berdasarkan parameter yang dikirim
      String targetField = widget.addressField ??
          ''; // Tambahkan parameter addressField di constructor

      if (targetField.isEmpty) {
        throw Exception('Silakan pilih slot alamat (1-4)');
      }

      // Update alamat ke field yang ditentukan
      await supabase
          .from('users')
          .update({targetField: addressData}).eq('id', userId);

      widget.onSave(addressData);
      Get.back();
      Get.snackbar(
        'Sukses',
        'Alamat berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error saving address: $e');
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

  Future<void> deleteAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      setState(() {
        isLoading = true;
      });

      // Cek alamat yang akan dihapus
      final userResponse = await supabase
          .from('users')
          .select('address, address2, address3, address4')
          .eq('id', userId)
          .single();

      String fieldToDelete = '';

      // Tentukan field yang akan dihapus dengan membandingkan nilai sebenarnya
      if (mapEquals(userResponse['address'], widget.initialAddress)) {
        fieldToDelete = 'address';
      } else if (mapEquals(userResponse['address2'], widget.initialAddress)) {
        fieldToDelete = 'address2';
      } else if (mapEquals(userResponse['address3'], widget.initialAddress)) {
        fieldToDelete = 'address3';
      } else if (mapEquals(userResponse['address4'], widget.initialAddress)) {
        fieldToDelete = 'address4';
      }

      if (fieldToDelete.isEmpty) {
        throw Exception('Alamat tidak ditemukan');
      }

      // Update hanya field yang akan dihapus
      Map<String, dynamic> updateData = {fieldToDelete: null};

      // Update database dengan menghapus alamat yang dipilih
      await supabase.from('users').update(updateData).eq('id', userId);

      Get.back();
      Get.snackbar(
        'Sukses',
        'Alamat berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error deleting address: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus alamat: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
            padding: EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                _buildMapSection(),
                _buildAddressForm(),
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
          // Form fields yang sudah ada
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
    return Column(
      children: [
        Container(
          height: 400,
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Search bar dan tombol lokasi saat ini
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari lokasi...',
                            prefixIcon:
                                Icon(Icons.search, color: AppTheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: (value) => searchAddress(value),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton.icon(
                          onPressed: getCurrentLocation,
                          icon: Icon(Icons.my_location,
                              color: Colors.white, size: 20),
                          label: Text('Lokasi',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
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
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tambahkan referensi alamat di bawah peta
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alamat yang dipilih: ${addressController.text}',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
      ],
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
