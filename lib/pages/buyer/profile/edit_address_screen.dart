import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    addressController =
        TextEditingController(text: widget.initialAddress['address'] ?? '');
    detailAddressController = TextEditingController();
    provinceController = TextEditingController();
    cityController = TextEditingController();
    districtController = TextEditingController();
    postalCodeController = TextEditingController();

    if (widget.initialAddress.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchAddress(widget.initialAddress['address'] ?? '', isInitial: true);
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
      final response = await http.get(
        Uri.parse(
            "https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=id"),
        headers: {'User-Agent': 'Kumbly App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        // Parse data alamat dari OpenStreetMap ke format kita
        setState(() {
          detailAddressController.text = address['road'] ?? '';
          districtController.text =
              address['suburb'] ?? address['district'] ?? '';
          cityController.text =
              address['city'] ?? address['town'] ?? address['county'] ?? '';
          provinceController.text = address['state'] ?? '';
          postalCodeController.text = address['postcode'] ?? '';
          addressController.text = data['display_name'] ?? '';
        });
      }
    } catch (e) {
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
      final response = await http.get(
        Uri.parse(
            "https://nominatim.openstreetmap.org/search?format=json&q=$query&accept-language=id"),
        headers: {'User-Agent': 'Kumbly App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final address = data[0]['display_name'];

          setState(() {
            selectedLocation = LatLng(lat, lon);
            if (!isInitial) {
              addressController.text = address;
            }
            zoomLevel = 16.0;
          });

          mapController.move(selectedLocation, zoomLevel);
        } else if (!isInitial) {
          Get.snackbar(
            "Info",
            "Alamat tidak ditemukan",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
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

      Map<String, String> addressData = {
        'street': detailAddressController.text.trim(),
        'village': '', // Tambahkan field village jika diperlukan
        'district': districtController.text.trim(),
        'city': cityController.text.trim(),
        'province': provinceController.text.trim(),
        'postal_code': postalCodeController.text.trim(),
      };

      await supabase.from('users').update({
        'address': addressData,
      }).eq('id', userId);

      widget.onSave(addressData);
      Get.back();
      Get.snackbar(
        'Sukses',
        'Alamat berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.primary,
          title: Text(
            widget.initialAddress.isEmpty ? 'Tambah Alamat' : 'Ubah Alamat',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Peta'),
              Tab(text: 'Manual'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMapTab(),
            _buildManualTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Cari lokasi...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
                        child: Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Alamat Terpilih:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(addressController.text),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isLoading ? 'Menyimpan...' : 'Simpan Alamat',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: detailAddressController,
            decoration: InputDecoration(
              labelText: 'Alamat Lengkap',
              hintText: 'Masukkan nama jalan, nomor rumah, dll',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          SizedBox(height: 16),
          TextField(
            controller: districtController,
            decoration: InputDecoration(
              labelText: 'Kecamatan',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: cityController,
            decoration: InputDecoration(
              labelText: 'Kota/Kabupaten',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: provinceController,
            decoration: InputDecoration(
              labelText: 'Provinsi',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: postalCodeController,
            decoration: InputDecoration(
              labelText: 'Kode Pos',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: saveAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              isLoading ? 'Menyimpan...' : 'Simpan Alamat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
