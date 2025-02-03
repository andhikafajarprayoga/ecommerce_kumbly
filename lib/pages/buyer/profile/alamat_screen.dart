import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AlamatScreen extends StatefulWidget {
  const AlamatScreen({super.key});

  @override
  State<AlamatScreen> createState() => _AlamatScreenState();
}

class _AlamatScreenState extends State<AlamatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  String? address;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAddress();
  }

  Future<void> fetchAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('users')
          .select('address')
          .eq('id', userId)
          .single();

      setState(() {
        address = response['address'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar('Error', 'Gagal mengambil alamat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          'Alamat Saya',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Text(
                                'Alamat Pengiriman',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: TextEditingController(text: address),
                            readOnly: true,
                            maxLines: 3,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              hintText: 'Belum ada alamat',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (address == null || address!.isEmpty)
                      _buildButton(
                        'Tambah Alamat',
                        Icons.add_location_alt,
                        () {
                          Get.to(() => EditAddressScreen(
                                initialAddress: '',
                                onSave: (newAddress) {
                                  setState(() {
                                    address = newAddress;
                                  });
                                },
                              ));
                        },
                      )
                    else
                      _buildButton(
                        'Ubah Alamat',
                        Icons.edit_location_alt,
                        () {
                          Get.to(() => EditAddressScreen(
                                initialAddress: address!,
                                onSave: (newAddress) {
                                  setState(() {
                                    address = newAddress;
                                  });
                                },
                              ));
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Halaman Edit/Tambah Alamat dengan Peta
class EditAddressScreen extends StatefulWidget {
  final String initialAddress;
  final Function(String) onSave;

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
  TextEditingController searchController = TextEditingController();
  LatLng selectedLocation = LatLng(-6.200000, 106.816666); // Default Jakarta
  double zoomLevel = 15.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    addressController = TextEditingController(text: widget.initialAddress);
    if (widget.initialAddress.isEmpty) {
      fetchAddressFromCoordinates(selectedLocation);
    }
  }

  Future<void> fetchAddressFromCoordinates(LatLng latLng) async {
    setState(() {
      isLoading = true;
    });

    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] ?? 'Alamat tidak ditemukan';

        setState(() {
          addressController.text = address;
        });
      }
    } catch (e) {
      Get.snackbar("Error", "Gagal mengambil nama jalan: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> searchAddress(String query) async {
    setState(() {
      isLoading = true;
    });

    final url =
        "https://nominatim.openstreetmap.org/search?format=json&q=$query";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final address = data[0]['display_name'];

          setState(() {
            selectedLocation = LatLng(lat, lon);
            addressController.text = address;
            zoomLevel = 16.0; // Zoom lebih dekat setelah mencari alamat
          });
        } else {
          Get.snackbar("Error", "Alamat tidak ditemukan.");
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Gagal mencari alamat: $e");
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

      final newAddress = addressController.text;

      await supabase
          .from('users')
          .update({'address': newAddress}).eq('id', userId);

      widget.onSave(newAddress);
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan alamat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          'Pilih Lokasi Alamat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Cari alamat...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      if (searchController.text.isNotEmpty) {
                        searchAddress(searchController.text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: selectedLocation,
                    initialZoom: zoomLevel,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        selectedLocation = latLng;
                      });
                      fetchAddressFromCoordinates(latLng);
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
                          width: 50.0,
                          height: 50.0,
                          point: selectedLocation,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildZoomButton(
                        Icons.add,
                        () => setState(() => zoomLevel += 1),
                      ),
                      const SizedBox(height: 8),
                      _buildZoomButton(
                        Icons.remove,
                        () => setState(() => zoomLevel -= 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: addressController,
                  readOnly: true,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Alamat Terpilih',
                    labelStyle: const TextStyle(color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.location_on, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.blue),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saveAddress,
          borderRadius: BorderRadius.circular(12),
          child: const Center(
            child: Text(
              'Simpan Alamat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
